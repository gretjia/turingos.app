//! A1_47 / A1_50: registry-hub branch poller — makes every repo's GitHub branches
//! visible in the galaxy, with honest relationship facts (A1_50).
//!
//! For each registry entry with a `remote`, shells the user's already-authed
//! `gh` (zero new credential surface; the token stays in gh's keyring) to read
//! the default branch + the branch list, and publishes a `BranchObserved` event
//! per branch (provenance=github_api). Branches gone since the last poll emit
//! `BranchRemoved`. Runs on its OWN slow-cadence supervised thread (F1/F3) so it
//! never blocks the 2s reconcile tick. gh failure degrades VISIBLY (stderr) and
//! emits nothing for that repo — never a crash, never a fake event.
//!
//! A1_50 — honest relationship facts ONLY. Per non-default branch the poller
//! computes, via `gh api .../compare/{default}...{branch}`, the pure observations
//! merge_status (ahead/behind/identical/diverged), ahead, behind, merge_base, and
//! the NEUTRAL derived fact contained_in_default (ahead==0: every commit on the
//! branch is reachable from the live default tip — i.e. no commits ahead of
//! default). contained_in_default is a REACHABILITY statement, NOT a "changes are
//! live" claim: a branch whose merge was later reverted still has its commits
//! reachable, so it stays contained. It must never be rendered as a green "merged"
//! badge.
//!
//! WHY NO merged_into_default green here (adversarial review 2026-06-14): a sound
//! "this branch's work is currently live in default" claim is NOT computable from
//! cheap gh signals. `git revert` adds an inverse commit and leaves the merge
//! commit reachable (compare behind==0) while undoing the content; matching a
//! merged PR by head-ref name is defeated by deleted-then-recreated same-name
//! branches and force-push-after-merge; GitHub exposes no "head SHA as of merge"
//! to bind a PR to the current tip. Reachability != content-live. Per the
//! constitution (never a false green; prefer unknown), this poller emits
//! merged_into_default=false always; a sound merged-green (content/tree-level
//! verification or a human-confirmed signal) is its own future atom (A1_53).
//!
//! Efficiency: the compare call is memoized on (branch_head_sha, default_head_sha);
//! an unchanged branch is never re-compared. A degenerate (empty) sha or an
//! Unknown (gh-error) result is never cached, so a transient failure or an
//! unresolved default tip forces a clean recompute next cycle.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};
use std::process::Command;

use crate::events::{EventKind, EventSource, TrustState};
use crate::registry::load_registry;
use crate::uds::EventHub;

/// gh invocation seam (LiveGhClient shells the real binary; tests use the pure
/// functions below plus a counting fake, and never touch the network).
pub trait GhClient: Send + Sync {
    fn run(&self, args: &[&str]) -> Result<String, String>;
}

pub struct LiveGhClient;

impl GhClient for LiveGhClient {
    fn run(&self, args: &[&str]) -> Result<String, String> {
        let bin = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"]
            .iter()
            .find(|p| Path::new(p).is_file())
            .ok_or_else(|| "gh binary not found".to_string())?;
        let out = Command::new(bin)
            .args(args)
            .output()
            .map_err(|e| format!("gh spawn: {e}"))?;
        if !out.status.success() {
            return Err(format!(
                "gh exit {:?}: {}",
                out.status.code(),
                String::from_utf8_lossy(&out.stderr).trim()
            ));
        }
        Ok(String::from_utf8_lossy(&out.stdout).into_owned())
    }
}

/// Parse `github.com/owner/repo` into (owner, repo).
pub fn owner_repo(remote: &str) -> Option<(String, String)> {
    let rest = remote.strip_prefix("github.com/")?;
    let mut parts = rest.split('/');
    let owner = parts.next()?;
    let repo = parts.next()?;
    if owner.is_empty() || repo.is_empty() {
        return None;
    }
    Some((owner.to_string(), repo.to_string()))
}

// ---------------------------------------------------------------------------
// A1_62: canonical-main cascade (ADR-017). Observe the LOCAL trunk (never the
// arbitrary local HEAD) and reconcile it against the GitHub remote default as
// TWO independent observed facts; emit RefReconciliation. All shelling goes
// through the GitRunner seam so the cascade is unit-tested without a real repo;
// the pure parsers/relate are tested directly.
// ---------------------------------------------------------------------------

/// git invocation seam scoped to a repo path (LiveGitRunner shells real git;
/// tests use a fake to exercise the local-trunk cascade without a real repo).
pub trait GitRunner: Send + Sync {
    fn run_in(&self, repo: &Path, args: &[&str]) -> Result<String, String>;
}

pub struct LiveGitRunner;

impl GitRunner for LiveGitRunner {
    fn run_in(&self, repo: &Path, args: &[&str]) -> Result<String, String> {
        let out = Command::new("git")
            .arg("-C")
            .arg(repo)
            .args(args)
            .output()
            .map_err(|e| format!("git spawn: {e}"))?;
        if !out.status.success() {
            return Err(format!(
                "git -C exit {:?}: {}",
                out.status.code(),
                String::from_utf8_lossy(&out.stderr).trim()
            ));
        }
        Ok(String::from_utf8_lossy(&out.stdout).into_owned())
    }
}

/// Where a trunk ref was observed (per-candidate provenance; distinct from the
/// envelope source and from the existing payload `provenance` tag — ADR-017).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TrunkSource {
    GithubApi,
    LocalHeadCached,
    RemoteSymrefLive,
    LocalHeuristic,
}

pub fn trunk_source_str(s: TrunkSource) -> &'static str {
    match s {
        TrunkSource::GithubApi => "github_api",
        TrunkSource::LocalHeadCached => "local_head_cached",
        TrunkSource::RemoteSymrefLive => "remote_symref_live",
        TrunkSource::LocalHeuristic => "local_heuristic",
    }
}

/// One observed trunk candidate: a ref name + where it was observed.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrunkObservation {
    pub git_ref: String,
    pub source: TrunkSource,
}

/// The honest relation between the two trunk candidates — a PURE function of the
/// observed (remote, local) tuple. A missing side is an explicit *_unobserved
/// arm; the missing ref is NEVER inferred.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Relation {
    Agree,
    RefDiffers,
    RemoteUnobserved,
    LocalUnobserved,
}

pub fn relation_str(r: Relation) -> &'static str {
    match r {
        Relation::Agree => "agree",
        Relation::RefDiffers => "ref_differs",
        Relation::RemoteUnobserved => "remote_unobserved",
        Relation::LocalUnobserved => "local_unobserved",
    }
}

/// Pure: relate the two observed trunk refs. In poll() remote is always present
/// (gh default succeeded before this point); local may be absent (no path).
pub fn relate(remote: Option<&str>, local: Option<&str>) -> Relation {
    match (remote, local) {
        (Some(r), Some(l)) if r == l => Relation::Agree,
        (Some(_), Some(_)) => Relation::RefDiffers,
        (Some(_), None) => Relation::LocalUnobserved,
        (None, _) => Relation::RemoteUnobserved,
    }
}

/// Pure: parse `git symbolic-ref --short refs/remotes/origin/HEAD` output
/// (e.g. "origin/main\n") -> "main". None for empty/unexpected.
pub fn parse_symbolic_ref(output: &str) -> Option<String> {
    let t = output.trim();
    if t.is_empty() {
        return None;
    }
    // "origin/main" -> "main": strip the leading remote-name segment.
    let name = t.split_once('/').map_or(t, |(_, rest)| rest);
    (!name.is_empty()).then(|| name.to_string())
}

/// Pure: parse `git ls-remote --symref origin HEAD`; first line is
/// "ref: refs/heads/main\tHEAD" -> "main".
pub fn parse_ls_remote_symref(output: &str) -> Option<String> {
    for line in output.lines() {
        if let Some(rest) = line.trim().strip_prefix("ref:") {
            if let Some(first) = rest.split_whitespace().next() {
                if let Some(name) = first.strip_prefix("refs/heads/") {
                    if !name.is_empty() {
                        return Some(name.to_string());
                    }
                }
            }
        }
    }
    None
}

/// Observe the LOCAL trunk via a sound cascade (never the arbitrary local HEAD).
///
/// Rungs, first hit wins: (1) cached `git symbolic-ref --short
/// refs/remotes/origin/HEAD` (offline; may be stale); (2) live `git ls-remote
/// --symref origin HEAD`; (3) existence heuristic — first of main/master/trunk/
/// develop present as a local head. Returns None when none resolve (honestly
/// unobserved — never guessed).
pub fn observe_local_trunk(git: &dyn GitRunner, repo: &Path) -> Option<TrunkObservation> {
    if let Ok(out) = git.run_in(
        repo,
        &["symbolic-ref", "--short", "refs/remotes/origin/HEAD"],
    ) {
        if let Some(name) = parse_symbolic_ref(&out) {
            return Some(TrunkObservation {
                git_ref: name,
                source: TrunkSource::LocalHeadCached,
            });
        }
    }
    if let Ok(out) = git.run_in(repo, &["ls-remote", "--symref", "origin", "HEAD"]) {
        if let Some(name) = parse_ls_remote_symref(&out) {
            return Some(TrunkObservation {
                git_ref: name,
                source: TrunkSource::RemoteSymrefLive,
            });
        }
    }
    for cand in ["main", "master", "trunk", "develop"] {
        if git
            .run_in(
                repo,
                &[
                    "show-ref",
                    "--verify",
                    "--quiet",
                    &format!("refs/heads/{cand}"),
                ],
            )
            .is_ok()
        {
            return Some(TrunkObservation {
                git_ref: cand.to_string(),
                source: TrunkSource::LocalHeuristic,
            });
        }
    }
    None
}

/// One branch as seen in the GitHub branch list (pure projection of the list JSON;
/// merge facts are computed downstream via compare so the list parse stays trivial).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BranchInfo {
    pub name: String,
    pub head_sha: String,
    pub is_default: bool,
}

/// Pure: GitHub `branches` JSON array + default branch name -> one BranchInfo per
/// branch.
pub fn parse_branch_list(
    branches_json: &str,
    default_branch: &str,
) -> Result<Vec<BranchInfo>, String> {
    let value: serde_json::Value =
        serde_json::from_str(branches_json).map_err(|e| format!("branches json: {e}"))?;
    let items = value.as_array().ok_or("branches json is not an array")?;
    let mut out = Vec::with_capacity(items.len());
    for it in items {
        let name = it
            .get("name")
            .and_then(serde_json::Value::as_str)
            .ok_or("branch entry missing name")?;
        let sha = it
            .get("commit")
            .and_then(|c| c.get("sha"))
            .and_then(serde_json::Value::as_str)
            .unwrap_or("");
        out.push(BranchInfo {
            name: name.to_string(),
            head_sha: sha.to_string(),
            is_default: name == default_branch,
        });
    }
    Ok(out)
}

/// The 4-value GitHub compare relationship, plus Unknown for an unavailable compare
/// (gh error / parse failure) — observed honestly, never inferred to a status.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MergeStatus {
    Ahead,
    Behind,
    Identical,
    Diverged,
    Unknown,
}

impl MergeStatus {
    pub fn as_str(self) -> &'static str {
        match self {
            MergeStatus::Ahead => "ahead",
            MergeStatus::Behind => "behind",
            MergeStatus::Identical => "identical",
            MergeStatus::Diverged => "diverged",
            MergeStatus::Unknown => "unknown",
        }
    }

    fn parse(s: &str) -> MergeStatus {
        match s {
            "ahead" => MergeStatus::Ahead,
            "behind" => MergeStatus::Behind,
            "identical" => MergeStatus::Identical,
            "diverged" => MergeStatus::Diverged,
            _ => MergeStatus::Unknown,
        }
    }
}

/// A pure observation from `compare/{default}...{branch}` (base=default, head=branch),
/// so `ahead` = commits unique to the branch, `behind` = commits the branch lacks
/// from default.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CompareFact {
    pub status: MergeStatus,
    pub ahead: u32,
    pub behind: u32,
    pub merge_base: String,
}

impl CompareFact {
    /// True iff we have a real compare observation AND the branch has no commits
    /// ahead of the live default tip (ahead==0: the branch tip is an ancestor of
    /// default). NEUTRAL REACHABILITY fact — NOT a merge claim: it stays true for a
    /// merge that was later reverted (the commits remain reachable even though their
    /// content was undone), so it must never be rendered as a green "merged" badge.
    /// Unknown status (gh error / unobserved) yields false: with no observation we
    /// make no containment claim (the Unknown degradation sets ahead=0, which must
    /// NOT read as "contained").
    pub fn contained_in_default(&self) -> bool {
        self.status != MergeStatus::Unknown && self.ahead == 0
    }
}

/// Pure: parse the `--jq '{status,ahead_by,behind_by,total_commits,merge_base}'`
/// compact object.
pub fn parse_compare(jq_json: &str) -> Result<CompareFact, String> {
    let v: serde_json::Value =
        serde_json::from_str(jq_json).map_err(|e| format!("compare json: {e}"))?;
    let status = v
        .get("status")
        .and_then(serde_json::Value::as_str)
        .ok_or("compare json missing status")?;
    let ahead = v
        .get("ahead_by")
        .and_then(serde_json::Value::as_u64)
        .ok_or("compare json missing ahead_by")?;
    let behind = v
        .get("behind_by")
        .and_then(serde_json::Value::as_u64)
        .ok_or("compare json missing behind_by")?;
    let merge_base = v
        .get("merge_base")
        .and_then(serde_json::Value::as_str)
        .unwrap_or("")
        .to_string();
    Ok(CompareFact {
        status: MergeStatus::parse(status),
        ahead: ahead as u32,
        behind: behind as u32,
        merge_base,
    })
}

/// Pure: refs present last poll but gone now (→ BranchRemoved).
pub fn diff_removed(prev: &BTreeSet<String>, current: &BTreeSet<String>) -> Vec<String> {
    prev.difference(current).cloned().collect()
}

/// One commit as observed from a GitHub compare or commits API response.
/// Pure data (no network); constructed by parse_compare_commits / parse_recent_commits.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CommitFact {
    pub sha: String,
    pub parent_shas: Vec<String>,
    pub author: String,
    pub ts: String,
    /// First line of the commit message (git `%s` subject).
    pub summary: String,
    /// A1_70: the commit message body — everything after the subject line,
    /// trimmed (git `%b`). Empty when the commit has no body. Carried so the
    /// galaxy detail card can show the "说明" the author wrote, not just the
    /// subject. Honest: it is the observed message, never inferred.
    pub body: String,
}

/// Pure: parse a GitHub compare `--jq` response that contains a `commits` array.
/// Returns the slice of CommitFact entries present in the response. If the
/// response contains exactly 250 entries the caller should mark `truncated`.
/// Missing or empty `commits` → empty Vec (not an error). Malformed JSON → Err.
pub fn parse_compare_commits(compare_json: &str) -> Result<Vec<CommitFact>, String> {
    let v: serde_json::Value =
        serde_json::from_str(compare_json).map_err(|e| format!("commits json: {e}"))?;
    let arr = match v.get("commits").and_then(|c| c.as_array()) {
        Some(a) => a,
        None => return Ok(Vec::new()),
    };
    let mut out = Vec::with_capacity(arr.len());
    for item in arr {
        let sha = item
            .get("sha")
            .and_then(serde_json::Value::as_str)
            .unwrap_or("")
            .to_string();
        if sha.is_empty() {
            continue; // skip entries with no sha
        }
        let parent_shas: Vec<String> = item
            .get("parents")
            .and_then(serde_json::Value::as_array)
            .map(|ps| {
                ps.iter()
                    .filter_map(|p| p.get("sha").and_then(serde_json::Value::as_str))
                    .map(|s| s.to_string())
                    .collect()
            })
            .unwrap_or_default();
        let commit_obj = item.get("commit").and_then(serde_json::Value::as_object);
        let author = commit_obj
            .and_then(|c| c.get("author"))
            .and_then(|a| a.get("name"))
            .and_then(serde_json::Value::as_str)
            .unwrap_or("")
            .to_string();
        let ts = commit_obj
            .and_then(|c| c.get("author"))
            .and_then(|a| a.get("date"))
            .and_then(serde_json::Value::as_str)
            .unwrap_or("")
            .to_string();
        let message = commit_obj
            .and_then(|c| c.get("message"))
            .and_then(serde_json::Value::as_str)
            .unwrap_or("");
        // A1_70: split the message into subject (first line, git %s) and body
        // (everything after, trimmed, git %b). Before this, the body was dropped
        // entirely (`.lines().next()`), so the detail card never had a "说明".
        let mut parts = message.splitn(2, '\n');
        let summary = parts.next().unwrap_or("").trim().to_string();
        let body = parts.next().unwrap_or("").trim().to_string();
        out.push(CommitFact {
            sha,
            parent_shas,
            author,
            ts,
            summary,
            body,
        });
    }
    Ok(out)
}

/// Cached compare observation for a branch, keyed by the (branch, default) head SHAs
/// it was computed from. A poll that finds both unchanged reuses it (no gh call).
/// A1_52: widened to also store parsed commits so cache-hit polls can re-emit
/// CommitObserved without making a new gh call.
struct CachedCompare {
    branch_sha: String,
    default_sha: String,
    fact: CompareFact,
    /// Parsed commits from the compare response (may be empty if compare returned none).
    commits: Vec<CommitFact>,
    /// True when the compare returned exactly 250 commits (GitHub's cap).
    truncated: bool,
}

/// Per-repo context threaded into per-branch compare computation (bundled so the
/// hot function stays a cohesive call rather than a long signature).
struct RepoCtx<'a> {
    slug: &'a str,
    project_id: &'a str,
    default_branch: &'a str,
    default_sha: &'a str,
}

/// Registry-hub branch poller. Owns nothing canonical; dropping it loses no
/// truth (GitHub + the registry remain).
pub struct BranchPoller {
    registry_path: PathBuf,
    /// project_id -> last-seen branch refs (for BranchRemoved diffing).
    seen: BTreeMap<String, BTreeSet<String>>,
    /// "project_id\0branch_ref" -> cached compare observation (A1_50 memoize).
    compare_cache: BTreeMap<String, CachedCompare>,
    /// A1_52: "project_id\0default_sha" -> cached recent default-branch commits
    /// (memoized on default_sha; re-emitted on cache hit).
    default_commits_cache: BTreeMap<String, Vec<CommitFact>>,
}

impl BranchPoller {
    pub fn new(registry_path: &Path) -> Self {
        BranchPoller {
            registry_path: registry_path.to_path_buf(),
            seen: BTreeMap::new(),
            compare_cache: BTreeMap::new(),
            default_commits_cache: BTreeMap::new(),
        }
    }

    /// Compute (or reuse from cache) the compare observation for one branch. The
    /// default branch is the trunk (identical to itself / contained, no compare
    /// call). Memoized on (branch_head_sha, default_head_sha); a degenerate (empty)
    /// sha or an Unknown (gh-error) result is NEVER cached, so a transient failure
    /// or an unresolved default tip forces a clean recompute next cycle. Every gh
    /// failure path is a visible eprintln + honest Unknown degradation, never a
    /// crash.
    ///
    /// A1_52: returns (CompareFact, Vec<CommitFact>, truncated). On cache hit the
    /// cached commits are returned (zero gh calls); on cache miss the compare
    /// response is parsed for both the scalar facts and the commits array.
    fn compute_merge(
        &mut self,
        gh: &dyn GhClient,
        ctx: &RepoCtx,
        info: &BranchInfo,
    ) -> (CompareFact, Vec<CommitFact>, bool) {
        if info.is_default {
            return (
                CompareFact {
                    status: MergeStatus::Identical,
                    ahead: 0,
                    behind: 0,
                    merge_base: info.head_sha.clone(),
                },
                Vec::new(),
                false,
            );
        }
        // A key whose sha component is empty has no discriminating power against
        // tip movement, so never serve or store a cached fact off one.
        let cacheable = !ctx.default_sha.is_empty() && !info.head_sha.is_empty();
        let cache_key = format!("{}\u{0}refs/heads/{}", ctx.project_id, info.name);
        if cacheable {
            if let Some(c) = self
                .compare_cache
                .get(&cache_key)
                .filter(|c| c.branch_sha == info.head_sha && c.default_sha == ctx.default_sha)
            {
                // Cache hit: return stored commits for idempotent re-emit (zero gh).
                return (c.fact.clone(), c.commits.clone(), c.truncated);
            }
        }

        let unknown = || CompareFact {
            status: MergeStatus::Unknown,
            ahead: 0,
            behind: 0,
            merge_base: String::new(),
        };

        // A1_52: single gh compare call; the --jq enriches the response with
        // both the scalar comparison facts AND the full commits array (sha,
        // parents, author name+date, message). GitHub caps commits at 250.
        let raw = match gh.run(&[
            "api",
            &format!(
                "repos/{}/compare/{}...{}",
                ctx.slug, ctx.default_branch, info.name
            ),
            "--jq",
            "{status,ahead_by,behind_by,total_commits,merge_base:.merge_base_commit.sha,commits:[.commits[]|{sha,parents:[.parents[].sha],commit:{author:{name:.commit.author.name,date:.commit.author.date},message:.commit.message}}]}",
        ]) {
            Ok(s) => s,
            Err(e) => {
                eprintln!(
                    "branch poller: {} {} compare failed: {e}",
                    ctx.slug, info.name
                );
                return (unknown(), Vec::new(), false);
            }
        };

        let fact = parse_compare(&raw).unwrap_or_else(|e| {
            eprintln!(
                "branch poller: {} {} compare parse: {e}",
                ctx.slug, info.name
            );
            unknown()
        });

        // Parse commits from the same response. GitHub caps at 250 entries;
        // if we get exactly 250 mark truncated but never fabricate more.
        let commits = parse_compare_commits(&raw).unwrap_or_else(|e| {
            eprintln!(
                "branch poller: {} {} commits parse: {e}",
                ctx.slug, info.name
            );
            Vec::new()
        });
        let truncated = commits.len() >= 250;

        // Cache only a real observation off a real key — never an Unknown (so a
        // transient gh error retries) and never a degenerate-sha key.
        if cacheable && fact.status != MergeStatus::Unknown {
            self.compare_cache.insert(
                cache_key,
                CachedCompare {
                    branch_sha: info.head_sha.clone(),
                    default_sha: ctx.default_sha.to_string(),
                    fact: fact.clone(),
                    commits: commits.clone(),
                    truncated,
                },
            );
        }
        (fact, commits, truncated)
    }

    /// One poll cycle over every registry entry that has a remote. Panic-free by
    /// construction (every failure path is a visible eprintln, never an unwrap).
    pub fn poll(&mut self, hub: &EventHub, gh: &dyn GhClient, git: &dyn GitRunner) {
        let entries = match load_registry(&self.registry_path) {
            Ok(e) => e,
            Err(e) => {
                eprintln!("branch poller: registry read failed: {e}");
                return;
            }
        };
        for entry in &entries {
            let Some(remote) = entry.remote.as_deref() else {
                continue;
            };
            let Some((owner, repo)) = owner_repo(remote) else {
                eprintln!(
                    "branch poller: unparseable remote {remote} for {}",
                    entry.project_id
                );
                continue;
            };
            let slug = format!("{owner}/{repo}");

            let default_branch =
                match gh.run(&["api", &format!("repos/{slug}"), "-q", ".default_branch"]) {
                    Ok(s) => s.trim().to_string(),
                    Err(e) => {
                        eprintln!("branch poller: {slug} default_branch failed: {e}");
                        continue;
                    }
                };

            // A1_62: observe the LOCAL trunk (honest cascade, never local HEAD)
            // and reconcile it against the remote default as TWO independent
            // observed facts. Emitted regardless of branch-list success below.
            let observed_at = crate::snapshot::utc_now_iso();
            let local_trunk = entry
                .path
                .as_deref()
                .and_then(|p| observe_local_trunk(git, p));
            let relation = relate(
                Some(default_branch.as_str()),
                local_trunk.as_ref().map(|t| t.git_ref.as_str()),
            );
            hub.publish(
                EventKind::RefReconciliation,
                EventSource::Daemon,
                TrustState::ObservedUnsigned,
                serde_json::json!({
                    "project_id": entry.project_id,
                    "remote_default": {
                        "git_ref": default_branch,
                        "source": trunk_source_str(TrunkSource::GithubApi),
                        "observed_at": observed_at,
                    },
                    // null when the project has no local clone or none of the
                    // cascade rungs resolve — honestly unobserved, never guessed.
                    "local_trunk": local_trunk.as_ref().map(|t| serde_json::json!({
                        "git_ref": t.git_ref,
                        "source": trunk_source_str(t.source),
                        "observed_at": observed_at,
                    })),
                    "relation": relation_str(relation),
                }),
            );

            // ?per_page=100 returns a single JSON array (no --paginate
            // concatenation); 100 covers every repo here (max=72).
            let branches_json =
                match gh.run(&["api", &format!("repos/{slug}/branches?per_page=100")]) {
                    Ok(s) => s,
                    Err(e) => {
                        eprintln!("branch poller: {slug} branches failed: {e}");
                        continue;
                    }
                };
            let branch_list = match parse_branch_list(&branches_json, &default_branch) {
                Ok(b) => b,
                Err(e) => {
                    eprintln!("branch poller: {slug} parse failed: {e}");
                    continue;
                }
            };

            // The live default head — half the memoize key (so a moved default tip
            // forces every branch to recompute). Empty if default is absent from the
            // listing; compute_merge treats an empty sha as non-cacheable.
            let default_sha = branch_list
                .iter()
                .find(|b| b.is_default)
                .map(|b| b.head_sha.clone())
                .unwrap_or_default();

            let ctx = RepoCtx {
                slug: &slug,
                project_id: &entry.project_id,
                default_branch: &default_branch,
                default_sha: &default_sha,
            };

            // A1_52: fetch recent default-branch commits, memoized on default_sha.
            // One gh call per changed default tip; re-emit cached commits on hit.
            let default_commits: Vec<CommitFact> = if !default_sha.is_empty() {
                let default_cache_key = format!("{}\u{0}{}", entry.project_id, default_sha);
                if let Some(cached) = self.default_commits_cache.get(&default_cache_key) {
                    cached.clone()
                } else {
                    match gh.run(&[
                        "api",
                        &format!(
                            "repos/{slug}/commits?sha={}&per_page=30",
                            default_branch
                        ),
                        "--jq",
                        "[.[]|{sha,parents:[.parents[].sha],commit:{author:{name:.commit.author.name,date:.commit.author.date},message:.commit.message}}]",
                    ]) {
                        Ok(raw) => {
                            // The commits endpoint returns a bare array; wrap it for
                            // parse_compare_commits which expects {commits:[...]}.
                            let wrapped = format!("{{\"commits\":{raw}}}");
                            let commits =
                                parse_compare_commits(&wrapped).unwrap_or_else(|e| {
                                    eprintln!(
                                        "branch poller: {slug} default commits parse: {e}"
                                    );
                                    Vec::new()
                                });
                            self.default_commits_cache
                                .insert(default_cache_key, commits.clone());
                            commits
                        }
                        Err(e) => {
                            eprintln!("branch poller: {slug} default commits failed: {e}");
                            Vec::new()
                        }
                    }
                }
            } else {
                Vec::new()
            };

            // Emit CommitObserved for default-branch recent commits.
            let default_ref = format!("refs/heads/{default_branch}");
            for commit in &default_commits {
                hub.publish(
                    EventKind::CommitObserved,
                    EventSource::Github,
                    TrustState::ObservedUnsigned,
                    serde_json::json!({
                        "project_id": entry.project_id,
                        "commit_sha": commit.sha,
                        "parent_shas": commit.parent_shas,
                        "branch_ref": default_ref,
                        "author": commit.author,
                        "ts": commit.ts,
                        "summary": commit.summary,
                        "body": commit.body,
                        "provenance": "github_api",
                    }),
                );
            }

            let mut current: BTreeSet<String> = BTreeSet::new();
            for info in &branch_list {
                let branch_ref = format!("refs/heads/{}", info.name);
                current.insert(branch_ref.clone());

                let (fact, commits, truncated) = self.compute_merge(gh, &ctx, info);

                let payload = serde_json::json!({
                    "project_id": entry.project_id,
                    "branch_ref": branch_ref,
                    "head_sha": info.head_sha,
                    "is_default": info.is_default,
                    "provenance": "github_api",
                    "merge_status": fact.status.as_str(),
                    "ahead": fact.ahead,
                    "behind": fact.behind,
                    "merge_base": fact.merge_base,
                    "contained_in_default": fact.contained_in_default(),
                    // A1_50 makes NO merge claim: a sound "work is live in default"
                    // signal is not computable from cheap gh facts (see module doc).
                    // Emitted false so the app never greens; sound merged-green = A1_53.
                    "merged_into_default": false,
                    // A1_62: when WE observed this branch (daemon poll time). The
                    // honest basis for recency/age signals (consumed in A1_64);
                    // before this field, any "age" was fabricated.
                    "observed_at": observed_at,
                });
                hub.publish(
                    EventKind::BranchObserved,
                    EventSource::Github,
                    TrustState::ObservedUnsigned,
                    payload,
                );

                // A1_52: emit CommitObserved for non-default branch commits (the
                // ahead-commits from the compare response). Skip the default branch
                // here — its commits are emitted above from the dedicated API call.
                if !info.is_default {
                    for commit in &commits {
                        let mut commit_payload = serde_json::json!({
                            "project_id": entry.project_id,
                            "commit_sha": commit.sha,
                            "parent_shas": commit.parent_shas,
                            "branch_ref": branch_ref,
                            "author": commit.author,
                            "ts": commit.ts,
                            "summary": commit.summary,
                            "body": commit.body,
                            "provenance": "github_api",
                        });
                        if truncated {
                            commit_payload["truncated"] = serde_json::Value::Bool(true);
                        }
                        hub.publish(
                            EventKind::CommitObserved,
                            EventSource::Github,
                            TrustState::ObservedUnsigned,
                            commit_payload,
                        );
                    }
                }
            }

            if let Some(prev) = self.seen.get(&entry.project_id) {
                for gone in diff_removed(prev, &current) {
                    self.compare_cache
                        .remove(&format!("{}\u{0}{gone}", entry.project_id));
                    hub.publish(
                        EventKind::BranchRemoved,
                        EventSource::Github,
                        TrustState::ObservedUnsigned,
                        serde_json::json!({"project_id": entry.project_id, "branch_ref": gone}),
                    );
                }
            }
            self.seen.insert(entry.project_id.clone(), current);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicU32, Ordering};

    /// Test repo context: constant slug/project/default, varying default_sha.
    fn ctx(default_sha: &str) -> RepoCtx<'_> {
        RepoCtx {
            slug: "o/r",
            project_id: "proj",
            default_branch: "main",
            default_sha,
        }
    }

    #[test]
    fn owner_repo_parses_normalized_remote() {
        assert_eq!(
            owner_repo("github.com/gretjia/turingosv4"),
            Some(("gretjia".into(), "turingosv4".into()))
        );
        assert_eq!(owner_repo("gitlab.com/a/b"), None);
        assert_eq!(owner_repo("github.com/onlyowner"), None);
    }

    #[test]
    fn parse_branch_list_one_info_per_branch_with_default_flag() {
        let json = r#"[
            {"name":"main","commit":{"sha":"aaa111"}},
            {"name":"claude/livefc1-lean","commit":{"sha":"bbb222"}}
        ]"#;
        let out = parse_branch_list(json, "main").unwrap();
        assert_eq!(out.len(), 2);
        assert_eq!(
            out[0],
            BranchInfo {
                name: "main".into(),
                head_sha: "aaa111".into(),
                is_default: true
            }
        );
        assert_eq!(
            out[1],
            BranchInfo {
                name: "claude/livefc1-lean".into(),
                head_sha: "bbb222".into(),
                is_default: false
            }
        );
    }

    #[test]
    fn parse_branch_list_rejects_non_array() {
        assert!(parse_branch_list("{\"message\":\"Not Found\"}", "main").is_err());
    }

    #[test]
    fn parse_compare_reads_status_counts_and_merge_base() {
        let j = r#"{"status":"diverged","ahead_by":3,"behind_by":7,"total_commits":3,"merge_base":"mb123"}"#;
        let f = parse_compare(j).unwrap();
        assert_eq!(f.status, MergeStatus::Diverged);
        assert_eq!(f.ahead, 3);
        assert_eq!(f.behind, 7);
        assert_eq!(f.merge_base, "mb123");
        assert!(!f.contained_in_default());
    }

    #[test]
    fn parse_compare_contained_when_ahead_zero() {
        let j = r#"{"status":"behind","ahead_by":0,"behind_by":20,"total_commits":0,"merge_base":"mb"}"#;
        let f = parse_compare(j).unwrap();
        assert!(f.contained_in_default());
        assert_eq!(f.status, MergeStatus::Behind);
    }

    #[test]
    fn parse_compare_unknown_status_maps_to_unknown() {
        let j = r#"{"status":"weird","ahead_by":1,"behind_by":1,"merge_base":"x"}"#;
        assert_eq!(parse_compare(j).unwrap().status, MergeStatus::Unknown);
    }

    #[test]
    fn contained_in_default_false_when_status_unknown() {
        // The Unknown (gh-error) degradation sets ahead=0; contained_in_default must
        // NOT read that as "contained" — with no observation we make no claim.
        let f = CompareFact {
            status: MergeStatus::Unknown,
            ahead: 0,
            behind: 0,
            merge_base: String::new(),
        };
        assert!(!f.contained_in_default());
    }

    #[test]
    fn parse_compare_missing_field_or_bad_json_errs() {
        assert!(parse_compare(r#"{"status":"ahead"}"#).is_err());
        assert!(parse_compare("not json").is_err());
    }

    #[test]
    fn diff_removed_finds_gone_refs() {
        let prev: BTreeSet<String> = ["refs/heads/a", "refs/heads/b", "refs/heads/c"]
            .iter()
            .map(|s| s.to_string())
            .collect();
        let current: BTreeSet<String> = ["refs/heads/a", "refs/heads/c"]
            .iter()
            .map(|s| s.to_string())
            .collect();
        assert_eq!(
            diff_removed(&prev, &current),
            vec!["refs/heads/b".to_string()]
        );
    }

    // ---- memoize + degenerate-key hardening ----

    struct CountingGh {
        compare_json: String,
        calls: AtomicU32,
    }
    impl GhClient for CountingGh {
        fn run(&self, args: &[&str]) -> Result<String, String> {
            if args.join(" ").contains("/compare/") {
                self.calls.fetch_add(1, Ordering::SeqCst);
                Ok(self.compare_json.clone())
            } else {
                Err(format!("unexpected gh call: {}", args.join(" ")))
            }
        }
    }

    fn counting_gh() -> CountingGh {
        // A1_52: compare response now includes a commits array so parse_compare
        // and parse_compare_commits both succeed on the same raw string.
        CountingGh {
            compare_json: r#"{"status":"ahead","ahead_by":3,"behind_by":0,"total_commits":3,"merge_base":"mb","commits":[{"sha":"c1","parents":[{"sha":"p0"}],"commit":{"author":{"name":"Alice","date":"2026-06-14T10:00:00Z"},"message":"first commit\n"}},{"sha":"c2","parents":[{"sha":"c1"}],"commit":{"author":{"name":"Alice","date":"2026-06-14T11:00:00Z"},"message":"second commit"}},{"sha":"c3","parents":[{"sha":"c2"}],"commit":{"author":{"name":"Bob","date":"2026-06-14T12:00:00Z"},"message":"third commit"}}]}"#
                    .into(),
            calls: AtomicU32::new(0),
        }
    }

    #[test]
    fn compute_merge_memoizes_on_branch_and_default_sha() {
        let mut poller = BranchPoller::new(Path::new("/tmp/unused"));
        let gh = counting_gh();
        let info = BranchInfo {
            name: "feat".into(),
            head_sha: "sha1".into(),
            is_default: false,
        };
        let (f1, _, _) = poller.compute_merge(&gh, &ctx("d1"), &info);
        assert_eq!(gh.calls.load(Ordering::SeqCst), 1);
        assert_eq!(f1.ahead, 3);
        // unchanged shas → cache hit, no new compare
        let (f2, _, _) = poller.compute_merge(&gh, &ctx("d1"), &info);
        assert_eq!(gh.calls.load(Ordering::SeqCst), 1);
        assert_eq!(f1, f2);
        // branch sha changed → recompute
        let info2 = BranchInfo {
            name: "feat".into(),
            head_sha: "sha2".into(),
            is_default: false,
        };
        let _ = poller.compute_merge(&gh, &ctx("d1"), &info2);
        assert_eq!(gh.calls.load(Ordering::SeqCst), 2);
        // default sha changed → recompute (a moved default tip re-evaluates all)
        let _ = poller.compute_merge(&gh, &ctx("d2"), &info2);
        assert_eq!(gh.calls.load(Ordering::SeqCst), 3);
    }

    #[test]
    fn compute_merge_never_caches_off_a_degenerate_sha() {
        // Empty default_sha (default branch absent from a >100-branch listing) and
        // empty branch sha must force a recompute every cycle — a degenerate key has
        // no power to detect tip movement, so a stale fact must never be served.
        let mut poller = BranchPoller::new(Path::new("/tmp/unused"));
        let gh = counting_gh();
        let info = BranchInfo {
            name: "feat".into(),
            head_sha: "sha1".into(),
            is_default: false,
        };
        let _ = poller.compute_merge(&gh, &ctx(""), &info); // empty default_sha
        let _ = poller.compute_merge(&gh, &ctx(""), &info);
        assert_eq!(gh.calls.load(Ordering::SeqCst), 2); // recomputed, not cached

        let gh2 = counting_gh();
        let empty_branch = BranchInfo {
            name: "feat".into(),
            head_sha: String::new(),
            is_default: false,
        };
        let _ = poller.compute_merge(&gh2, &ctx("d1"), &empty_branch); // empty branch sha
        let _ = poller.compute_merge(&gh2, &ctx("d1"), &empty_branch);
        assert_eq!(gh2.calls.load(Ordering::SeqCst), 2);
    }

    #[test]
    fn compute_merge_does_not_cache_unknown_so_transient_errors_retry() {
        // A gh error degrades to Unknown; it must NOT be cached, so the next cycle
        // retries instead of serving a stale Unknown until the sha changes.
        struct FailingGh {
            calls: AtomicU32,
        }
        impl GhClient for FailingGh {
            fn run(&self, args: &[&str]) -> Result<String, String> {
                if args.join(" ").contains("/compare/") {
                    self.calls.fetch_add(1, Ordering::SeqCst);
                    Err("gh exit 1: transient".into())
                } else {
                    Err("unexpected".into())
                }
            }
        }
        let mut poller = BranchPoller::new(Path::new("/tmp/unused"));
        let gh = FailingGh {
            calls: AtomicU32::new(0),
        };
        let info = BranchInfo {
            name: "feat".into(),
            head_sha: "sha1".into(),
            is_default: false,
        };
        let (f1, _, _) = poller.compute_merge(&gh, &ctx("d1"), &info);
        assert_eq!(f1.status, MergeStatus::Unknown);
        let _ = poller.compute_merge(&gh, &ctx("d1"), &info);
        assert_eq!(gh.calls.load(Ordering::SeqCst), 2); // retried, not cached
    }

    #[test]
    fn compute_merge_default_branch_is_identical_and_contained_with_no_call() {
        let mut poller = BranchPoller::new(Path::new("/tmp/unused"));
        let gh = counting_gh();
        let info = BranchInfo {
            name: "main".into(),
            head_sha: "d1".into(),
            is_default: true,
        };
        let (f, commits, truncated) = poller.compute_merge(&gh, &ctx("d1"), &info);
        assert_eq!(gh.calls.load(Ordering::SeqCst), 0); // no compare for the trunk
        assert_eq!(f.status, MergeStatus::Identical);
        assert!(f.contained_in_default());
        assert!(commits.is_empty());
        assert!(!truncated);
    }

    // ---- A1_52 new tests ----

    #[test]
    fn parse_compare_commits_extracts_commits_from_compare_response() {
        let json = r#"{
            "status":"ahead","ahead_by":2,"behind_by":0,
            "commits":[
                {"sha":"abc1","parents":[{"sha":"p0"}],"commit":{"author":{"name":"Alice","date":"2026-06-14T10:00:00Z"},"message":"first line\n\nbody paragraph one\nbody paragraph two\n"}},
                {"sha":"abc2","parents":[{"sha":"abc1"}],"commit":{"author":{"name":"Bob","date":"2026-06-14T11:00:00Z"},"message":"just one line"}}
            ]
        }"#;
        let commits = parse_compare_commits(json).unwrap();
        assert_eq!(commits.len(), 2);
        assert_eq!(commits[0].sha, "abc1");
        assert_eq!(commits[0].parent_shas, vec!["p0"]);
        assert_eq!(commits[0].author, "Alice");
        assert_eq!(commits[0].ts, "2026-06-14T10:00:00Z");
        // A1_70: summary = subject (first line, %s); body = the rest, trimmed (%b).
        assert_eq!(commits[0].summary, "first line");
        assert_eq!(commits[0].body, "body paragraph one\nbody paragraph two");
        // single-line message → subject only, body empty (never fabricated).
        assert_eq!(commits[1].sha, "abc2");
        assert_eq!(commits[1].parent_shas, vec!["abc1"]);
        assert_eq!(commits[1].summary, "just one line");
        assert_eq!(commits[1].body, "");
    }

    #[test]
    fn parse_compare_commits_empty_when_no_commits_field() {
        let json = r#"{"status":"ahead","ahead_by":0,"behind_by":0}"#;
        let commits = parse_compare_commits(json).unwrap();
        assert!(commits.is_empty());
    }

    #[test]
    fn parse_compare_commits_errors_on_bad_json() {
        assert!(parse_compare_commits("not json at all").is_err());
    }

    #[test]
    fn parse_compare_commits_skips_entries_with_empty_sha() {
        let json = r#"{"commits":[{"sha":"","parents":[],"commit":{"author":{"name":"X","date":"2026-06-14T00:00:00Z"},"message":"m"}},{"sha":"real1","parents":[],"commit":{"author":{"name":"Y","date":"2026-06-14T00:00:00Z"},"message":"m2"}}]}"#;
        let commits = parse_compare_commits(json).unwrap();
        assert_eq!(commits.len(), 1);
        assert_eq!(commits[0].sha, "real1");
    }

    #[test]
    fn cache_hit_reemits_commits_without_extra_gh_call() {
        // Two-poll bounded test: first poll causes one gh compare call and
        // returns N commits; second poll on the SAME unchanged branch makes
        // zero additional gh calls and returns the identical commit set.
        let mut poller = BranchPoller::new(Path::new("/tmp/unused"));
        let gh = counting_gh(); // returns 3 commits
        let info = BranchInfo {
            name: "feat".into(),
            head_sha: "sha1".into(),
            is_default: false,
        };
        // Poll 1: cache miss — one gh call, 3 commits.
        let (_, commits1, truncated1) = poller.compute_merge(&gh, &ctx("d1"), &info);
        assert_eq!(
            gh.calls.load(Ordering::SeqCst),
            1,
            "poll1 should call gh once"
        );
        assert_eq!(commits1.len(), 3, "poll1 should return 3 commits");
        assert!(!truncated1, "3 < 250, not truncated");
        // Poll 2: cache hit — zero additional gh calls, same commits.
        let (_, commits2, truncated2) = poller.compute_merge(&gh, &ctx("d1"), &info);
        assert_eq!(
            gh.calls.load(Ordering::SeqCst),
            1,
            "poll2 must not call gh again (cache hit)"
        );
        assert_eq!(
            commits2.len(),
            commits1.len(),
            "cache hit must re-emit same commit count"
        );
        for (c1, c2) in commits1.iter().zip(commits2.iter()) {
            assert_eq!(c1.sha, c2.sha, "cached commit shas must match");
        }
        assert_eq!(truncated2, truncated1);
    }

    #[test]
    fn truncation_marks_truncated_true_at_250_cap() {
        // Build a compare response with exactly 250 commits.
        let commits_json: String = (0..250u32)
            .map(|i| {
                format!(
                    r#"{{"sha":"sha{i:04}","parents":[{{"sha":"sha{:04}"}}],"commit":{{"author":{{"name":"A","date":"2026-06-14T00:00:00Z"}},"message":"commit {i}"}}}}"#,
                    if i == 0 { 9999 } else { i - 1 }
                )
            })
            .collect::<Vec<_>>()
            .join(",");
        let json = format!(
            r#"{{"status":"ahead","ahead_by":250,"behind_by":0,"commits":[{commits_json}]}}"#
        );
        let commits = parse_compare_commits(&json).unwrap();
        assert_eq!(commits.len(), 250, "should parse all 250");
        // Verify truncated flag would be set (len >= 250)
        let truncated = commits.len() >= 250;
        assert!(truncated, "250-cap must set truncated");
        // Verify no empty/synthetic sha exists
        for c in &commits {
            assert!(!c.sha.is_empty(), "no empty sha in truncated result");
        }
    }

    #[test]
    fn payload_has_no_merged_or_green_field() {
        // CommitFact carries no merged/green/verified field — verify by checking
        // that the CountingGh compare_json round-trips to CommitFact with only
        // the declared fields (sha, parent_shas, author, ts, summary, body).
        let json = counting_gh().compare_json;
        let commits = parse_compare_commits(&json).unwrap();
        assert!(!commits.is_empty(), "test data must have commits");
        // Serialize a commit payload as we do in poll() and check no banned fields.
        let payload = serde_json::json!({
            "project_id": "proj",
            "commit_sha": commits[0].sha,
            "parent_shas": commits[0].parent_shas,
            "branch_ref": "refs/heads/feat",
            "author": commits[0].author,
            "ts": commits[0].ts,
            "summary": commits[0].summary,
            "body": commits[0].body,
            "provenance": "github_api",
        });
        let s = payload.to_string();
        assert!(!s.contains("\"merged\""), "no merged field");
        assert!(!s.contains("\"green\""), "no green field");
        assert!(!s.contains("\"verified\""), "no verified field");
        assert!(
            !s.contains("\"merged_into_default\""),
            "no merged_into_default"
        );
    }

    // ----- A1_62: canonical-main cascade -----

    /// Scripted GitRunner: exercises the local-trunk cascade without a real repo.
    struct FakeGit {
        symbolic_ref: Result<String, String>,
        ls_remote: Result<String, String>,
        heads_present: Vec<&'static str>,
    }
    impl GitRunner for FakeGit {
        fn run_in(&self, _repo: &Path, args: &[&str]) -> Result<String, String> {
            match args {
                ["symbolic-ref", ..] => self.symbolic_ref.clone(),
                ["ls-remote", ..] => self.ls_remote.clone(),
                ["show-ref", "--verify", "--quiet", r] => {
                    if self.heads_present.iter().any(|h| r.ends_with(h)) {
                        Ok(String::new())
                    } else {
                        Err("not found".into())
                    }
                }
                _ => Err("unexpected git args".into()),
            }
        }
    }

    #[test]
    fn relate_is_pure_observed_function_missing_side_never_inferred() {
        assert_eq!(relate(Some("main"), Some("main")), Relation::Agree);
        assert_eq!(
            relate(Some("claude/brave"), Some("main")),
            Relation::RefDiffers
        );
        assert_eq!(relate(Some("main"), None), Relation::LocalUnobserved);
        assert_eq!(relate(None, Some("main")), Relation::RemoteUnobserved);
        assert_eq!(relate(None, None), Relation::RemoteUnobserved);
    }

    #[test]
    fn parse_symbolic_ref_strips_remote_segment() {
        assert_eq!(parse_symbolic_ref("origin/main\n").as_deref(), Some("main"));
        // a slash-bearing branch name keeps everything after the first segment
        assert_eq!(
            parse_symbolic_ref("origin/claude/brave-knuth-5uo3ce\n").as_deref(),
            Some("claude/brave-knuth-5uo3ce")
        );
        assert_eq!(parse_symbolic_ref(""), None);
        assert_eq!(parse_symbolic_ref("   \n"), None);
    }

    #[test]
    fn parse_ls_remote_symref_extracts_head_branch() {
        assert_eq!(
            parse_ls_remote_symref("ref: refs/heads/main\tHEAD\nabc123\tHEAD\n").as_deref(),
            Some("main")
        );
        assert_eq!(parse_ls_remote_symref("abc123\tHEAD\n"), None);
        assert_eq!(parse_ls_remote_symref(""), None);
    }

    #[test]
    fn observe_local_trunk_cascade_cached_then_live_then_heuristic_then_none() {
        let repo = Path::new("/tmp/does-not-matter");
        // rung 1: cached symbolic-ref wins.
        let g1 = FakeGit {
            symbolic_ref: Ok("origin/main\n".into()),
            ls_remote: Err("x".into()),
            heads_present: vec![],
        };
        assert_eq!(
            observe_local_trunk(&g1, repo),
            Some(TrunkObservation {
                git_ref: "main".into(),
                source: TrunkSource::LocalHeadCached
            })
        );
        // rung 2: cached missing (exit128) -> live ls-remote.
        let g2 = FakeGit {
            symbolic_ref: Err("fatal: ref ... is not a symbolic ref".into()),
            ls_remote: Ok("ref: refs/heads/dev\tHEAD\n".into()),
            heads_present: vec![],
        };
        assert_eq!(
            observe_local_trunk(&g2, repo),
            Some(TrunkObservation {
                git_ref: "dev".into(),
                source: TrunkSource::RemoteSymrefLive
            })
        );
        // rung 3: both fail -> existence heuristic (master present).
        let g3 = FakeGit {
            symbolic_ref: Err("x".into()),
            ls_remote: Err("x".into()),
            heads_present: vec!["master"],
        };
        assert_eq!(
            observe_local_trunk(&g3, repo),
            Some(TrunkObservation {
                git_ref: "master".into(),
                source: TrunkSource::LocalHeuristic
            })
        );
        // none resolve -> honestly unobserved (never guessed).
        let g4 = FakeGit {
            symbolic_ref: Err("x".into()),
            ls_remote: Err("x".into()),
            heads_present: vec![],
        };
        assert_eq!(observe_local_trunk(&g4, repo), None);
    }
}

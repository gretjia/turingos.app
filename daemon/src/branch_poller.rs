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

/// Cached compare observation for a branch, keyed by the (branch, default) head SHAs
/// it was computed from. A poll that finds both unchanged reuses it (no gh call).
struct CachedCompare {
    branch_sha: String,
    default_sha: String,
    fact: CompareFact,
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
}

impl BranchPoller {
    pub fn new(registry_path: &Path) -> Self {
        BranchPoller {
            registry_path: registry_path.to_path_buf(),
            seen: BTreeMap::new(),
            compare_cache: BTreeMap::new(),
        }
    }

    /// Compute (or reuse from cache) the compare observation for one branch. The
    /// default branch is the trunk (identical to itself / contained, no compare
    /// call). Memoized on (branch_head_sha, default_head_sha); a degenerate (empty)
    /// sha or an Unknown (gh-error) result is NEVER cached, so a transient failure
    /// or an unresolved default tip forces a clean recompute next cycle. Every gh
    /// failure path is a visible eprintln + honest Unknown degradation, never a
    /// crash.
    fn compute_merge(
        &mut self,
        gh: &dyn GhClient,
        ctx: &RepoCtx,
        info: &BranchInfo,
    ) -> CompareFact {
        if info.is_default {
            return CompareFact {
                status: MergeStatus::Identical,
                ahead: 0,
                behind: 0,
                merge_base: info.head_sha.clone(),
            };
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
                return c.fact.clone();
            }
        }

        let unknown = || CompareFact {
            status: MergeStatus::Unknown,
            ahead: 0,
            behind: 0,
            merge_base: String::new(),
        };
        let fact = match gh.run(&[
            "api",
            &format!(
                "repos/{}/compare/{}...{}",
                ctx.slug, ctx.default_branch, info.name
            ),
            "--jq",
            "{status,ahead_by,behind_by,total_commits,merge_base:.merge_base_commit.sha}",
        ]) {
            Ok(s) => parse_compare(&s).unwrap_or_else(|e| {
                eprintln!(
                    "branch poller: {} {} compare parse: {e}",
                    ctx.slug, info.name
                );
                unknown()
            }),
            Err(e) => {
                eprintln!(
                    "branch poller: {} {} compare failed: {e}",
                    ctx.slug, info.name
                );
                unknown()
            }
        };

        // Cache only a real observation off a real key — never an Unknown (so a
        // transient gh error retries) and never a degenerate-sha key.
        if cacheable && fact.status != MergeStatus::Unknown {
            self.compare_cache.insert(
                cache_key,
                CachedCompare {
                    branch_sha: info.head_sha.clone(),
                    default_sha: ctx.default_sha.to_string(),
                    fact: fact.clone(),
                },
            );
        }
        fact
    }

    /// One poll cycle over every registry entry that has a remote. Panic-free by
    /// construction (every failure path is a visible eprintln, never an unwrap).
    pub fn poll(&mut self, hub: &EventHub, gh: &dyn GhClient) {
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

            let mut current: BTreeSet<String> = BTreeSet::new();
            for info in &branch_list {
                let branch_ref = format!("refs/heads/{}", info.name);
                current.insert(branch_ref.clone());

                let fact = self.compute_merge(gh, &ctx, info);

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
                });
                hub.publish(
                    EventKind::BranchObserved,
                    EventSource::Github,
                    TrustState::ObservedUnsigned,
                    payload,
                );
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
        CountingGh {
            compare_json:
                r#"{"status":"ahead","ahead_by":3,"behind_by":0,"total_commits":3,"merge_base":"mb"}"#
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
        let f1 = poller.compute_merge(&gh, &ctx("d1"), &info);
        assert_eq!(gh.calls.load(Ordering::SeqCst), 1);
        assert_eq!(f1.ahead, 3);
        // unchanged shas → cache hit, no new compare
        let f2 = poller.compute_merge(&gh, &ctx("d1"), &info);
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
        let f1 = poller.compute_merge(&gh, &ctx("d1"), &info);
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
        let f = poller.compute_merge(&gh, &ctx("d1"), &info);
        assert_eq!(gh.calls.load(Ordering::SeqCst), 0); // no compare for the trunk
        assert_eq!(f.status, MergeStatus::Identical);
        assert!(f.contained_in_default());
    }
}

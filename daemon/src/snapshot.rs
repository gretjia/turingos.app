//! A1_02: read-only worktree snapshot kernel.
//!
//! Topology comes from `git worktree list --porcelain -z` (R1_memo §1: -z is
//! the only quoting-safe mode - attributes are NUL-terminated and entries are
//! separated by an empty attribute). git2 supplies the cross-check lane
//! (`validate`/`is_locked`/`is_prunable`, keyed by recorded worktree path) so
//! a stale registry surfaces as drift instead of being trusted. Dirty state
//! comes from `git status --porcelain=v2 -z` + `git diff --numstat -z HEAD`
//! inside each live worktree (HEAD-relative so staged work is counted;
//! S-stage critique finding). Everything projects into contract event
//! envelopes; nothing here writes a single byte into a user repository
//! (`--no-optional-locks` keeps even `git status` from refreshing the index).

use std::collections::{BTreeMap, BTreeSet};
use std::io::Read;
use std::path::Path;
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

use sha2::{Digest, Sha256};

use crate::events::{EventEnvelope, EventKind, EventSource, TrustState, EVENT_SCHEMA_VERSION};

#[derive(Debug)]
pub enum SnapshotError {
    Spawn(String),
    Git(String),
    Git2(git2::Error),
}

impl std::fmt::Display for SnapshotError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            SnapshotError::Spawn(e) => write!(f, "failed to spawn git: {e}"),
            SnapshotError::Git(e) => write!(f, "git exited non-zero: {e}"),
            SnapshotError::Git2(e) => write!(f, "git2: {e}"),
        }
    }
}

impl std::error::Error for SnapshotError {}

impl From<git2::Error> for SnapshotError {
    fn from(e: git2::Error) -> Self {
        SnapshotError::Git2(e)
    }
}

/// One entry from `git worktree list --porcelain -z` (R1_memo §1.1-§1.2).
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct WorktreeEntry {
    pub path: String,
    /// Empty for bare entries (they carry no HEAD line).
    pub head: String,
    /// Full ref (`refs/heads/x`). `None` == detached or bare (R1_memo §1.4).
    pub branch: Option<String>,
    pub bare: bool,
    pub detached: bool,
    /// `Some(reason)` when locked; reason may be empty (R1_memo §1.2).
    pub locked: Option<String>,
    /// `Some(reason)` when git itself reports the entry prunable.
    pub prunable: Option<String>,
}

/// Parse `git worktree list --porcelain -z`: attributes are NUL-terminated,
/// an empty attribute closes an entry. Never split on newlines - paths may
/// contain them (R1_memo §1.1).
pub fn parse_worktree_list_z(raw: &[u8]) -> Vec<WorktreeEntry> {
    let mut out = Vec::new();
    let mut cur: Option<WorktreeEntry> = None;
    for tok in raw.split(|b| *b == 0) {
        let tok = String::from_utf8_lossy(tok);
        if tok.is_empty() {
            if let Some(e) = cur.take() {
                out.push(e);
            }
            continue;
        }
        if let Some(p) = tok.strip_prefix("worktree ") {
            // Defensive: porcelain always closes entries with an empty token,
            // but a truncated stream must not merge two entries.
            if let Some(e) = cur.take() {
                out.push(e);
            }
            cur = Some(WorktreeEntry {
                path: p.to_string(),
                ..Default::default()
            });
            continue;
        }
        let Some(e) = cur.as_mut() else { continue };
        if let Some(h) = tok.strip_prefix("HEAD ") {
            e.head = h.to_string();
        } else if let Some(b) = tok.strip_prefix("branch ") {
            e.branch = Some(b.to_string());
        } else if tok == "detached" {
            e.detached = true;
        } else if tok == "bare" {
            e.bare = true;
        } else if tok == "locked" {
            e.locked = Some(String::new());
        } else if let Some(r) = tok.strip_prefix("locked ") {
            e.locked = Some(r.to_string());
        } else if tok == "prunable" {
            e.prunable = Some(String::new());
        } else if let Some(r) = tok.strip_prefix("prunable ") {
            e.prunable = Some(r.to_string());
        }
    }
    if let Some(e) = cur.take() {
        out.push(e);
    }
    out
}

/// Distilled `git status --porcelain=v2 -z --branch` (R1_memo §2.b/§2.d).
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct StatusReport {
    pub branch_oid: Option<String>,
    pub branch_head: Option<String>,
    /// Tracked changes (types `1`/`2`/`u`); rename records contribute the
    /// destination path.
    pub changed_paths: Vec<String>,
    pub renamed: u64,
    /// Records whose submodule field is `S<c><m><u>` (mode 160000 gitlink).
    pub submodules_dirty: u64,
    pub conflicted: u64,
    pub untracked: Vec<String>,
    pub ignored: Vec<String>,
}

/// Token-stream parser for porcelain v2 `-z`. The critical -z subtlety: a
/// rename record (`2`) is followed by the *original* path as a separate
/// NUL-terminated token (R1_memo §2.d: always parse v2 with -z).
pub fn parse_status_v2_z(raw: &[u8]) -> StatusReport {
    let mut r = StatusReport::default();
    let mut toks = raw.split(|b| *b == 0).map(String::from_utf8_lossy);
    while let Some(tok) = toks.next() {
        if tok.is_empty() {
            continue;
        }
        if let Some(h) = tok.strip_prefix("# ") {
            if let Some(v) = h.strip_prefix("branch.oid ") {
                r.branch_oid = Some(v.to_string());
            } else if let Some(v) = h.strip_prefix("branch.head ") {
                r.branch_head = Some(v.to_string());
            }
            continue;
        }
        match tok.as_bytes().first() {
            Some(b'1') => {
                // 1 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <path>
                let f: Vec<&str> = tok.splitn(9, ' ').collect();
                if f.len() == 9 {
                    if f[2].starts_with('S') {
                        r.submodules_dirty += 1;
                    }
                    r.changed_paths.push(f[8].to_string());
                }
            }
            Some(b'2') => {
                // 2 <XY> <sub> <mH> <mI> <mW> <hH> <hI> <X><score> <path>
                // ... then NUL, then <origPath> as its own token.
                let f: Vec<&str> = tok.splitn(10, ' ').collect();
                let _orig = toks.next();
                if f.len() == 10 {
                    if f[2].starts_with('S') {
                        r.submodules_dirty += 1;
                    }
                    r.renamed += 1;
                    r.changed_paths.push(f[9].to_string());
                }
            }
            Some(b'u') => {
                // u <XY> <sub> <m1> <m2> <m3> <mW> <h1> <h2> <h3> <path>
                let f: Vec<&str> = tok.splitn(11, ' ').collect();
                if f.len() == 11 {
                    r.conflicted += 1;
                    r.changed_paths.push(f[10].to_string());
                }
            }
            Some(b'?') => {
                if let Some(p) = tok.strip_prefix("? ") {
                    r.untracked.push(p.to_string());
                }
            }
            Some(b'!') => {
                if let Some(p) = tok.strip_prefix("! ") {
                    r.ignored.push(p.to_string());
                }
            }
            _ => {}
        }
    }
    r
}

/// One `git diff --numstat -z` record. `None` counts == binary fingerprint
/// (`-\t-`, R1_memo §2.c).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NumstatRecord {
    pub insertions: Option<u64>,
    pub deletions: Option<u64>,
    pub path: String,
}

/// Parse `git diff --numstat -z`. Rename records carry an empty path inside
/// the stat token, followed by source and destination as two extra tokens
/// (real-git golden: `0\t0\t<NUL>name1.txt<NUL>name2.txt<NUL>`).
pub fn parse_diff_numstat_z(raw: &[u8]) -> Vec<NumstatRecord> {
    fn num(s: &str) -> Option<u64> {
        if s == "-" {
            None
        } else {
            s.parse::<u64>().ok()
        }
    }
    let mut out = Vec::new();
    let mut toks = raw.split(|b| *b == 0).map(String::from_utf8_lossy);
    while let Some(tok) = toks.next() {
        if tok.is_empty() {
            continue;
        }
        let mut parts = tok.splitn(3, '\t');
        let ins = parts.next().unwrap_or("");
        let del = parts.next().unwrap_or("");
        let path = parts.next().unwrap_or("");
        if path.is_empty() {
            let _src = toks.next();
            let dst = toks.next().map(|c| c.to_string()).unwrap_or_default();
            out.push(NumstatRecord {
                insertions: num(ins),
                deletions: num(del),
                path: dst,
            });
        } else {
            out.push(NumstatRecord {
                insertions: num(ins),
                deletions: num(del),
                path: path.to_string(),
            });
        }
    }
    out
}

/// LFS pointers are small text files whose first line is
/// `version https://git-lfs.github.com/spec/v1` - numstat cannot identify
/// them, only content sniffing can (R1_memo §2.c). The prefix pins the full
/// spec-URL stem to keep the false-positive surface minimal.
pub const LFS_POINTER_PREFIX: &[u8] = b"version https://git-lfs.github.com/spec/";

pub fn sniff_lfs_pointer(path: &Path) -> bool {
    let Ok(f) = std::fs::File::open(path) else {
        return false;
    };
    let mut buf = Vec::with_capacity(64);
    if f.take(64).read_to_end(&mut buf).is_err() {
        return false;
    }
    buf.starts_with(LFS_POINTER_PREFIX)
}

/// Radar row dirty fingerprint: counts only, no file contents (Projection
/// API discipline - the UI renders +-lines/Bin/LFS badges from this).
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct DirtyFingerprint {
    pub files_changed: u64,
    pub insertions: u64,
    pub deletions: u64,
    pub binary_files: u64,
    pub lfs_pointer_files: u64,
    pub untracked: u64,
    pub renamed: u64,
    pub submodules_dirty: u64,
    pub conflicted: u64,
    /// sha256 over status records (volatile `# branch.*` headers excluded,
    /// so a no-op commit does not flip the hash) + numstat bytes: cheap
    /// identity for "did the dirty state change since the last snapshot".
    pub diff_hash: String,
}

impl DirtyFingerprint {
    pub fn is_dirty(&self) -> bool {
        self.files_changed > 0 || self.untracked > 0
    }
}

fn run_git(dir: &Path, args: &[&str]) -> Result<Vec<u8>, SnapshotError> {
    let out = Command::new("git")
        .arg("-C")
        .arg(dir)
        .args(args)
        .output()
        .map_err(|e| SnapshotError::Spawn(e.to_string()))?;
    if !out.status.success() {
        return Err(SnapshotError::Git(format!(
            "git {:?} in {}: {}",
            args,
            dir.display(),
            String::from_utf8_lossy(&out.stderr).trim()
        )));
    }
    Ok(out.stdout)
}

/// Explicit unborn-HEAD detection (a brand-new repo before its first commit).
/// No silent fallback: the numstat strategy branches on this fact.
fn head_exists(dir: &Path) -> bool {
    Command::new("git")
        .arg("-C")
        .arg(dir)
        .args(["rev-parse", "--quiet", "--verify", "HEAD"])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

/// Compute the dirty fingerprint of one live worktree. Read-only: git spawns
/// with `--no-optional-locks` (status must not refresh the index) + bounded
/// 64-byte sniffs of changed/untracked files. Flags are pinned per
/// invocation (`--untracked-files=normal`) so a user's global git config
/// cannot silently change what the Radar sees (S-stage critique finding).
pub fn fingerprint_worktree(wt_path: &Path) -> Result<DirtyFingerprint, SnapshotError> {
    let status_raw = run_git(
        wt_path,
        &[
            "--no-optional-locks",
            "status",
            "--porcelain=v2",
            "-z",
            "--branch",
            "--untracked-files=normal",
        ],
    )?;
    // HEAD-relative numstat counts staged AND unstaged line deltas, matching
    // the porcelain-v2 change set (plain `diff --numstat` sees only unstaged
    // work and silently zeroes staged stats - S-stage critique blocker).
    // Unborn HEAD (verified: `diff HEAD` exits 128 there) -> index-vs-empty
    // (`--cached`) plus worktree-vs-index, both verified exit-0 on unborn.
    let numstat_raws: Vec<Vec<u8>> = if head_exists(wt_path) {
        vec![run_git(
            wt_path,
            &["--no-optional-locks", "diff", "--numstat", "-z", "HEAD"],
        )?]
    } else {
        vec![
            run_git(
                wt_path,
                &["--no-optional-locks", "diff", "--numstat", "-z", "--cached"],
            )?,
            run_git(wt_path, &["--no-optional-locks", "diff", "--numstat", "-z"])?,
        ]
    };
    let st = parse_status_v2_z(&status_raw);
    let ns: Vec<NumstatRecord> = numstat_raws
        .iter()
        .flat_map(|raw| parse_diff_numstat_z(raw))
        .collect();

    let (mut insertions, mut deletions, mut binary_files) = (0u64, 0u64, 0u64);
    for rec in &ns {
        match (rec.insertions, rec.deletions) {
            (Some(i), Some(d)) => {
                insertions += i;
                deletions += d;
            }
            _ => binary_files += 1,
        }
    }
    let mut lfs_pointer_files = 0u64;
    for p in st.changed_paths.iter().chain(st.untracked.iter()) {
        if sniff_lfs_pointer(&wt_path.join(p.as_str())) {
            lfs_pointer_files += 1;
        }
    }
    // Hash only the change records: `# branch.oid` flips on every commit and
    // must not masquerade as a dirty-state change.
    let mut h = Sha256::new();
    for tok in status_raw.split(|b| *b == 0) {
        if tok.is_empty() || tok.starts_with(b"# ") {
            continue;
        }
        h.update(tok);
        h.update([0u8]);
    }
    for raw in &numstat_raws {
        h.update(raw);
    }

    Ok(DirtyFingerprint {
        files_changed: st.changed_paths.len() as u64,
        insertions,
        deletions,
        binary_files,
        lfs_pointer_files,
        untracked: st.untracked.len() as u64,
        renamed: st.renamed,
        submodules_dirty: st.submodules_dirty,
        conflicted: st.conflicted,
        diff_hash: format!("sha256:{:x}", h.finalize()),
    })
}

/// Same-branch double checkout (only `--force` or external tooling can
/// produce it - R1_memo §1.3/§2.e). Detached entries carry no branch and
/// never participate. BTreeMap keeps the report deterministic.
pub fn same_branch_conflicts(entries: &[WorktreeEntry]) -> Vec<String> {
    let mut by_branch: BTreeMap<&str, u64> = BTreeMap::new();
    for e in entries {
        if let Some(b) = &e.branch {
            *by_branch.entry(b.as_str()).or_default() += 1;
        }
    }
    by_branch
        .into_iter()
        .filter(|(_, n)| *n >= 2)
        .map(|(b, _)| b.to_string())
        .collect()
}

/// git2 cross-check lane (R1_memo §1.5/§5), keyed by the worktree's
/// *recorded path* - the one join key shared with porcelain output. git2's
/// internal names (admin-dir ids like `dup`/`dup1`) are carried along as the
/// stable identity component; path basenames are NOT unique (S-stage
/// critique blocker).
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Git2WorktreeState {
    /// git2's unique internal worktree name ($GIT_DIR/worktrees/<name>).
    pub name: String,
    /// `validate()` failed: gitdir dead link / missing tree - orphan.
    pub invalid: bool,
    pub locked: bool,
    pub prunable: bool,
}

pub fn git2_crosscheck(
    repo_path: &Path,
) -> Result<BTreeMap<String, Git2WorktreeState>, SnapshotError> {
    let repo = git2::Repository::open(repo_path)?;
    let mut by_path = BTreeMap::new();
    for name in repo.worktrees()?.iter().flatten() {
        let wt = repo.find_worktree(name)?;
        by_path.insert(
            wt.path().to_string_lossy().to_string(),
            Git2WorktreeState {
                name: name.to_string(),
                invalid: wt.validate().is_err(),
                locked: matches!(wt.is_locked(), Ok(git2::WorktreeLockStatus::Locked(_))),
                prunable: wt.is_prunable(None).unwrap_or(false),
            },
        );
    }
    Ok(by_path)
}

/// One Radar row: porcelain entry + fingerprint + anomaly flags.
#[derive(Debug, Clone)]
pub struct WorktreeStatusRow {
    pub entry: WorktreeEntry,
    /// `wt_<stable-name>_<8-hex sha256(path)>`: git2's unique internal name
    /// (or basename for the main/bare entry) + a path digest, so basename
    /// collisions cannot merge two rows in downstream projections.
    pub worktree_id: String,
    /// `None` when the tree is bare/prunable/missing or its fingerprint
    /// failed - absence is a visible state, not an error (D3).
    pub fingerprint: Option<DirtyFingerprint>,
    /// Why the fingerprint is missing on a live-looking tree (permissions,
    /// corrupt index, mid-operation lock). One sick worktree must not take
    /// down the whole snapshot (D3; S-stage critique finding).
    pub fingerprint_error: Option<String>,
    pub same_branch_conflict: bool,
    /// Registry entry fails git2 `validate()` - orphan found by reconciliation.
    pub git2_invalid: bool,
}

#[derive(Debug, Clone)]
pub struct RepoSnapshot {
    pub project_id: String,
    pub rows: Vec<WorktreeStatusRow>,
}

fn sanitize_id(s: &str) -> String {
    let mut out: String = s
        .chars()
        .map(|c| {
            let c = c.to_ascii_lowercase();
            if c.is_ascii_lowercase() || c.is_ascii_digit() {
                c
            } else {
                '_'
            }
        })
        .collect();
    if out.is_empty() {
        out.push('x');
    }
    out
}

fn basename(path: &str) -> &str {
    Path::new(path)
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or(path)
}

fn path_digest8(path: &str) -> String {
    let mut h = Sha256::new();
    h.update(path.as_bytes());
    format!("{:x}", h.finalize())[..8].to_string()
}

/// Snapshot one repository: porcelain topology, git2 cross-check, per-live-
/// worktree fingerprints, same-branch conflict detection. Read-only.
/// Per-row failures degrade that row (visible `fingerprint_error`), never
/// the whole snapshot; only topology-level failures (worktree list, git2
/// open) abort.
pub fn snapshot_repo(project_id: &str, repo_path: &Path) -> Result<RepoSnapshot, SnapshotError> {
    let raw = run_git(repo_path, &["worktree", "list", "--porcelain", "-z"])?;
    let entries = parse_worktree_list_z(&raw);
    let conflicts: BTreeSet<String> = same_branch_conflicts(&entries).into_iter().collect();
    let check = git2_crosscheck(repo_path)?;

    let mut rows = Vec::with_capacity(entries.len());
    for entry in entries {
        let g2 = check.get(&entry.path);
        let git2_invalid = g2.is_some_and(|s| s.invalid);
        let stable_name = g2
            .map(|s| s.name.clone())
            .unwrap_or_else(|| basename(&entry.path).to_string());
        let worktree_id = format!(
            "wt_{}_{}",
            sanitize_id(&stable_name),
            path_digest8(&entry.path)
        );
        let live = !entry.bare
            && entry.prunable.is_none()
            && !git2_invalid
            && Path::new(&entry.path).is_dir();
        let (fingerprint, fingerprint_error) = if live {
            match fingerprint_worktree(Path::new(&entry.path)) {
                Ok(fp) => (Some(fp), None),
                Err(e) => (None, Some(e.to_string())),
            }
        } else {
            (None, None)
        };
        let same_branch_conflict = entry.branch.as_ref().is_some_and(|b| conflicts.contains(b));
        rows.push(WorktreeStatusRow {
            worktree_id,
            entry,
            fingerprint,
            fingerprint_error,
            same_branch_conflict,
            git2_invalid,
        });
    }
    Ok(RepoSnapshot {
        project_id: project_id.to_string(),
        rows,
    })
}

fn envelope(
    project_id: &str,
    seq: u64,
    ts: &str,
    kind: EventKind,
    payload: serde_json::Value,
) -> EventEnvelope {
    EventEnvelope {
        event_id: format!("evt_{}_{seq:04}", sanitize_id(project_id)),
        seq,
        ts: ts.to_string(),
        schema_version: EVENT_SCHEMA_VERSION.to_string(),
        kind,
        source: EventSource::Git,
        trust_state: TrustState::ObservedUnsigned,
        payload,
    }
}

/// Project a snapshot into contract envelopes: one WorktreeDiscovered per
/// worktree, one DiffSnapshot per dirty worktree. trust_state stays
/// observed_unsigned - identity is P2's job, not P1's.
pub fn to_events(snap: &RepoSnapshot, seq_start: u64, ts: &str) -> Vec<EventEnvelope> {
    let mut out = Vec::new();
    let mut seq = seq_start;
    for row in &snap.rows {
        let dirty = row.fingerprint.as_ref().is_some_and(|f| f.is_dirty());
        let mut payload = serde_json::json!({
            "project_id": snap.project_id,
            "worktree_id": row.worktree_id,
            "path": row.entry.path,
            "head": row.entry.head,
            "dirty": dirty,
            "bare": row.entry.bare,
            "detached": row.entry.detached,
            "locked": row.entry.locked.is_some(),
            "prunable": row.entry.prunable.is_some() || row.git2_invalid,
            "same_branch_conflict": row.same_branch_conflict,
        });
        if let Some(b) = &row.entry.branch {
            payload["branch"] =
                serde_json::Value::String(b.strip_prefix("refs/heads/").unwrap_or(b).to_string());
        }
        if let Some(r) = row.entry.locked.as_ref().filter(|r| !r.is_empty()) {
            payload["locked_reason"] = serde_json::Value::String(r.clone());
        }
        if let Some(r) = row.entry.prunable.as_ref().filter(|r| !r.is_empty()) {
            payload["prunable_reason"] = serde_json::Value::String(r.clone());
        }
        if let Some(e) = &row.fingerprint_error {
            payload["fingerprint_error"] = serde_json::Value::String(e.clone());
        }
        out.push(envelope(
            &snap.project_id,
            seq,
            ts,
            EventKind::WorktreeDiscovered,
            payload,
        ));
        seq += 1;

        if let Some(fp) = row.fingerprint.as_ref().filter(|f| f.is_dirty()) {
            out.push(envelope(
                &snap.project_id,
                seq,
                ts,
                EventKind::DiffSnapshot,
                serde_json::json!({
                    "worktree_id": row.worktree_id,
                    "diff_hash": fp.diff_hash,
                    "files_changed": fp.files_changed,
                    "insertions": fp.insertions,
                    "deletions": fp.deletions,
                    "binary_files": fp.binary_files,
                    "lfs_pointer_files": fp.lfs_pointer_files,
                    "untracked": fp.untracked,
                    "renamed": fp.renamed,
                    "submodules_dirty": fp.submodules_dirty,
                }),
            ));
            seq += 1;
        }
    }
    out
}

/// Contract `ts` format without a chrono dependency: civil-from-days
/// (Howard Hinnant's algorithm), UTC, second precision.
pub fn iso_from_unix(secs: u64) -> String {
    let days = (secs / 86_400) as i64;
    let rem = secs % 86_400;
    let (h, m, s) = (rem / 3600, (rem % 3600) / 60, rem % 60);
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z.rem_euclid(146_097);
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let month = if mp < 10 { mp + 3 } else { mp - 9 };
    let year = yoe + era * 400 + i64::from(month <= 2);
    format!("{year:04}-{month:02}-{d:02}T{h:02}:{m:02}:{s:02}Z")
}

pub fn utc_now_iso() -> String {
    let secs = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    iso_from_unix(secs)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::path::PathBuf;

    fn transcript(name: &str) -> Vec<u8> {
        let p = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../fixtures/cli_transcripts/git")
            .join(name);
        fs::read(&p).unwrap_or_else(|e| panic!("read {}: {e}", p.display()))
    }

    #[test]
    fn worktree_parse_list_z_transcript() {
        let entries = parse_worktree_list_z(&transcript("wt_list_porcelain_z.txt"));
        assert_eq!(entries.len(), 6, "origin + 5 linked worktrees");
        // Attribute order per entry is worktree -> HEAD -> branch|detached.
        assert_eq!(
            entries[0].branch.as_deref(),
            Some("refs/heads/main"),
            "main worktree first"
        );
        let detached: Vec<_> = entries.iter().filter(|e| e.detached).collect();
        assert_eq!(detached.len(), 1);
        assert!(detached[0].branch.is_none(), "detached has no branch line");
        let locked: Vec<_> = entries.iter().filter(|e| e.locked.is_some()).collect();
        assert_eq!(locked.len(), 1);
        assert_eq!(locked[0].locked.as_deref(), Some("testing lock"));
        let prunable: Vec<_> = entries.iter().filter(|e| e.prunable.is_some()).collect();
        assert_eq!(prunable.len(), 1);
        assert!(prunable[0]
            .prunable
            .as_deref()
            .unwrap()
            .contains("non-existent location"));
        assert!(entries.iter().all(|e| !e.head.is_empty()));
    }

    #[test]
    fn worktree_parse_list_bare_transcript() {
        let entries = parse_worktree_list_z(&transcript("wt_list_bare_z.txt"));
        assert_eq!(entries.len(), 2, "bare main entry + 1 linked worktree");
        assert!(entries[0].bare, "bare attribute parsed");
        assert!(
            entries[0].head.is_empty(),
            "bare entry carries no HEAD line"
        );
        assert!(entries[0].branch.is_none());
        assert!(!entries[1].bare);
        assert_eq!(entries[1].branch.as_deref(), Some("refs/heads/main"));
    }

    #[test]
    fn worktree_conflict_grouping_from_transcript() {
        let entries = parse_worktree_list_z(&transcript("wt_list_porcelain_z.txt"));
        let conflicts = same_branch_conflicts(&entries);
        assert_eq!(
            conflicts,
            vec!["refs/heads/feature".to_string()],
            "feature checked out twice via --force; detached entries excluded"
        );
    }

    #[test]
    fn worktree_parse_status_v2_transcript() {
        let st = parse_status_v2_z(&transcript("status_v2_z.txt"));
        assert_eq!(st.branch_head.as_deref(), Some("main"));
        assert!(st.branch_oid.is_some());
        // a.txt, bin.dat, lfs.bin, sub (type 1) + name2.txt (type 2 rename)
        assert_eq!(st.changed_paths.len(), 5);
        assert!(st.changed_paths.contains(&"name2.txt".to_string()));
        assert!(
            !st.changed_paths.contains(&"name1.txt".to_string()),
            "rename source is a separate -z token, not a record"
        );
        assert_eq!(st.renamed, 1);
        assert_eq!(st.submodules_dirty, 1, "sub carries S.M. flags");
        assert_eq!(st.untracked, vec!["newfile.txt".to_string()]);
        assert!(st.ignored.is_empty(), "normal mode never lists ignored");
    }

    #[test]
    fn worktree_parse_numstat_transcript() {
        // Captured with the production invocation `diff --numstat -z HEAD`,
        // so the staged pure rename appears as the real two-token form.
        let ns = parse_diff_numstat_z(&transcript("diff_numstat_z.txt"));
        assert_eq!(ns.len(), 5);
        let by_path: std::collections::BTreeMap<&str, &NumstatRecord> =
            ns.iter().map(|r| (r.path.as_str(), r)).collect();
        assert_eq!(by_path["a.txt"].insertions, Some(1));
        assert_eq!(by_path["bin.dat"].insertions, None, "binary == -\\t-");
        assert_eq!(by_path["bin.dat"].deletions, None);
        assert_eq!(
            by_path["lfs.bin"].insertions,
            Some(2),
            "LFS pointer diffs as 3-line text, NOT binary (sniffing required)"
        );
        assert_eq!(by_path["sub"].insertions, Some(0));
        assert_eq!(
            by_path["name2.txt"].insertions,
            Some(0),
            "rename two-token: empty path in stat token, src+dst follow"
        );
        assert!(!by_path.contains_key("name1.txt"), "src token is consumed");
    }

    #[test]
    fn worktree_parse_numstat_rename_synthetic() {
        // Same branch as above, synthetic bytes with a space-bearing path.
        let raw = b"3\t1\t\0old name.txt\0new name.txt\0-\t-\tblob.bin\0";
        let ns = parse_diff_numstat_z(raw);
        assert_eq!(ns.len(), 2);
        assert_eq!(ns[0].path, "new name.txt");
        assert_eq!(ns[0].insertions, Some(3));
        assert_eq!(ns[1].path, "blob.bin");
        assert_eq!(ns[1].insertions, None);
    }

    #[test]
    fn worktree_event_ts_helper_iso() {
        assert_eq!(iso_from_unix(0), "1970-01-01T00:00:00Z");
        // python3: datetime.fromtimestamp(1765324800, UTC) == 2025-12-10 00:00:00
        assert_eq!(iso_from_unix(1_765_324_800), "2025-12-10T00:00:00Z");
        assert_eq!(iso_from_unix(951_827_696), "2000-02-29T12:34:56Z");
    }

    #[test]
    fn worktree_id_sanitization() {
        assert_eq!(sanitize_id("Wt-Feature.2"), "wt_feature_2");
        assert_eq!(sanitize_id(""), "x");
        assert_eq!(path_digest8("/a/dup").len(), 8);
        assert_ne!(
            path_digest8("/a/dup"),
            path_digest8("/b/dup"),
            "same basename, different path => different digest"
        );
    }
}

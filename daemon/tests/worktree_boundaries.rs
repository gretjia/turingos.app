//! A1_02 six-boundary tests (R1_memo §1-§2) plus the S-stage critique
//! regressions (staged changes, bare repos, basename collisions, unborn
//! HEAD, diff_hash stability): every case is reproduced against a real git
//! repository built in a tempdir - the fixture IS the assertion. Read-only
//! discipline: the snapshot path never mutates a repo; all mutation here is
//! test setup via the git CLI.

mod common;

use common::{base_repo, git};
use turingosd::events::{EventEnvelope, EventKind};
use turingosd::snapshot::{snapshot_repo, to_events};

fn row<'a>(
    snap: &'a turingosd::snapshot::RepoSnapshot,
    suffix: &str,
) -> &'a turingosd::snapshot::WorktreeStatusRow {
    snap.rows
        .iter()
        .find(|r| r.entry.path.ends_with(suffix))
        .unwrap_or_else(|| panic!("no row for {suffix}"))
}

/// Boundary 5 (branch identity, conflict half): two worktrees on one branch
/// is impossible without --force (R1_memo §1.3) - the Radar must tolerate
/// and flag it, never hide it.
#[test]
fn worktree_same_branch_force_conflict_flagged() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = base_repo(tmp.path());
    git(&repo, &["worktree", "add", "-q", "../wt1", "-b", "feat"]);
    git(
        &repo,
        &["worktree", "add", "-q", "--force", "../wt2", "feat"],
    );

    let snap = snapshot_repo("p", &repo).unwrap();
    assert!(row(&snap, "wt1").same_branch_conflict);
    assert!(row(&snap, "wt2").same_branch_conflict);
    assert!(
        !row(&snap, "origin").same_branch_conflict,
        "main branch checked out once - no false positive"
    );
}

/// Boundary 5 (branch identity, detached half): detached worktrees carry no
/// branch line (R1_memo §1.4) and must never trip the same-branch detector.
#[test]
fn worktree_detached_identity_no_false_conflict() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = base_repo(tmp.path());
    git(&repo, &["worktree", "add", "-q", "--detach", "../d1"]);
    git(&repo, &["worktree", "add", "-q", "--detach", "../d2"]);

    let snap = snapshot_repo("p", &repo).unwrap();
    for suffix in ["d1", "d2"] {
        let r = row(&snap, suffix);
        assert!(r.entry.detached);
        assert!(r.entry.branch.is_none());
        assert!(
            !r.same_branch_conflict,
            "two detached worktrees at one commit are legal"
        );
    }
}

/// Boundary: prunable / gitdir dead link (R1_memo §1.2/§1.5). A deleted
/// worktree directory must surface as a visible orphan row, cross-checked
/// by git2 validate(), with no fingerprint attempt against the dead path.
#[test]
fn worktree_prunable_orphan_detected() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = base_repo(tmp.path());
    git(
        &repo,
        &["worktree", "add", "-q", "../gone", "-b", "gone-br"],
    );
    std::fs::remove_dir_all(tmp.path().join("gone")).unwrap();

    let snap = snapshot_repo("p", &repo).unwrap();
    let r = row(&snap, "gone");
    assert!(
        r.entry.prunable.is_some() || r.git2_invalid,
        "porcelain prunable reason or git2 validate() failure must flag the orphan"
    );
    assert!(r.fingerprint.is_none(), "no status run against a dead path");
    let ev = to_events(&snap, 0, "2026-06-10T00:00:00Z");
    let orphan = ev
        .iter()
        .find(|e| e.payload["path"].as_str().unwrap().ends_with("gone"))
        .expect("orphan still projected");
    assert_eq!(orphan.payload["prunable"], true);
}

/// Boundary: submodules never appear as worktree entries; the parent's
/// porcelain v2 S<c><m><u> field is the only (read-only) signal we surface
/// (R1_memo §2.b). No recursion, no fetch.
#[test]
fn worktree_submodule_dirty_s_flag() {
    let tmp = tempfile::tempdir().unwrap();
    let sub = tmp.path().join("sub");
    std::fs::create_dir(&sub).unwrap();
    git(&sub, &["init", "-q"]);
    std::fs::write(sub.join("s.txt"), "s\n").unwrap();
    git(&sub, &["add", "."]);
    git(&sub, &["commit", "-qm", "s"]);

    let repo = base_repo(tmp.path());
    git(&repo, &["submodule", "add", "-q", "../sub", "sub"]);
    git(&repo, &["commit", "-qm", "add submodule"]);
    std::fs::write(repo.join("sub/s.txt"), "s\nchanged\n").unwrap();

    let snap = snapshot_repo("p", &repo).unwrap();
    assert_eq!(
        snap.rows.len(),
        1,
        "submodule is NOT a worktree entry (R1_memo §2.b)"
    );
    let fp = snap.rows[0].fingerprint.as_ref().unwrap();
    assert_eq!(fp.submodules_dirty, 1);
    assert!(fp.is_dirty());
}

/// Boundary: git-lfs / binary (R1_memo §2.c). numstat marks true binaries
/// `-\t-` while an LFS pointer diffs as 3-line text - classification needs
/// content sniffing, and both must be counted distinctly.
#[test]
fn worktree_lfs_pointer_sniffed_vs_binary() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = base_repo(tmp.path());
    std::fs::write(repo.join("bin.dat"), b"BIN\x00\x01\x02DATA").unwrap();
    std::fs::write(
        repo.join("model.weights"),
        "version https://git-lfs.github.com/spec/v1\noid sha256:4d7a214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2393\nsize 12345\n",
    )
    .unwrap();
    git(&repo, &["add", "."]);
    git(&repo, &["commit", "-qm", "binaries"]);
    std::fs::write(repo.join("bin.dat"), b"BIN\x00\xff\xfeDATA2").unwrap();
    std::fs::write(
        repo.join("model.weights"),
        "version https://git-lfs.github.com/spec/v1\noid sha256:aaaa214614ab2935c943f9e0ff69d22eadbb8f32b1258daaa5e2ca24d17e2222\nsize 99\n",
    )
    .unwrap();

    let snap = snapshot_repo("p", &repo).unwrap();
    let fp = snap.rows[0].fingerprint.as_ref().unwrap();
    assert_eq!(fp.binary_files, 1, "bin.dat is -\\t- in numstat");
    assert_eq!(
        fp.lfs_pointer_files, 1,
        "model.weights sniffed as LFS pointer despite texty numstat"
    );
    assert_eq!(fp.files_changed, 2);
}

/// Boundary: untracked in normal mode (R1_memo §2.d) - `?` entries counted,
/// `.gitignore`d files invisible without --ignored.
#[test]
fn worktree_untracked_normal_mode_counted() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = base_repo(tmp.path());
    std::fs::write(repo.join(".gitignore"), "ignored.txt\n").unwrap();
    git(&repo, &["add", "."]);
    git(&repo, &["commit", "-qm", "gitignore"]);
    std::fs::write(repo.join("newfile.txt"), "untracked\n").unwrap();
    std::fs::write(repo.join("ignored.txt"), "invisible\n").unwrap();

    let snap = snapshot_repo("p", &repo).unwrap();
    let fp = snap.rows[0].fingerprint.as_ref().unwrap();
    assert_eq!(fp.untracked, 1, "newfile.txt only");
    assert!(fp.is_dirty(), "untracked alone must light the dirty bit");
    assert_eq!(fp.files_changed, 0);
    assert_eq!(fp.insertions, 0);
}

/// S-stage critique blocker regression: staged-only changes must be counted
/// in line stats. Plain `diff --numstat` (working tree vs index) silently
/// zeroed them; HEAD-relative numstat sees staged + unstaged.
#[test]
fn worktree_staged_changes_counted() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = base_repo(tmp.path());
    std::fs::write(
        repo.join("base.txt"),
        "base\nstaged-line-1\nstaged-line-2\n",
    )
    .unwrap();
    git(&repo, &["add", "base.txt"]);

    let snap = snapshot_repo("p", &repo).unwrap();
    let fp = snap.rows[0].fingerprint.as_ref().unwrap();
    assert_eq!(fp.files_changed, 1);
    assert_eq!(
        fp.insertions, 2,
        "fully staged edit must not report +0/-0 (S-stage blocker repro)"
    );
    assert!(fp.is_dirty());
}

/// S-stage critique blocker regression: a bare main entry must degrade to a
/// visible non-live row, never abort the snapshot (git status exits 128 in
/// a bare repo).
#[test]
fn worktree_bare_repo_tolerated() {
    let tmp = tempfile::tempdir().unwrap();
    let normal = base_repo(tmp.path());
    let bare = tmp.path().join("bare.git");
    git(
        tmp.path(),
        &[
            "clone",
            "-q",
            "--bare",
            normal.to_str().unwrap(),
            bare.to_str().unwrap(),
        ],
    );
    git(&bare, &["worktree", "add", "-q", "../bwt", "main"]);

    let snap = snapshot_repo("p", &bare).expect("bare repo must not abort the snapshot");
    let b = row(&snap, "bare.git");
    assert!(b.entry.bare);
    assert!(b.fingerprint.is_none(), "no status run inside a bare repo");
    assert!(b.fingerprint_error.is_none(), "non-live, not an error");
    let w = row(&snap, "bwt");
    assert!(
        w.fingerprint.is_some(),
        "linked worktree still fingerprinted"
    );
    let ev = to_events(&snap, 0, "2026-06-10T00:00:00Z");
    let bev = ev
        .iter()
        .find(|e| e.payload["bare"] == true)
        .expect("bare row projected");
    assert_eq!(bev.payload["dirty"], false);
}

/// S-stage critique blocker regression: two worktrees whose path basenames
/// collide must get distinct worktree_ids (projection merge key), and the
/// git2 cross-check lane must match rows by recorded path, not basename.
#[test]
fn worktree_basename_collision_ids_distinct() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = base_repo(tmp.path());
    std::fs::create_dir_all(tmp.path().join("a")).unwrap();
    std::fs::create_dir_all(tmp.path().join("b")).unwrap();
    git(&repo, &["worktree", "add", "-q", "../a/dup", "-b", "br-a"]);
    git(&repo, &["worktree", "add", "-q", "../b/dup", "-b", "br-b"]);

    let snap = snapshot_repo("p", &repo).unwrap();
    let ids: std::collections::BTreeSet<&str> =
        snap.rows.iter().map(|r| r.worktree_id.as_str()).collect();
    assert_eq!(
        ids.len(),
        snap.rows.len(),
        "worktree_id must be unique across basename collisions"
    );

    // git2 lane keyed by path: deleting b/dup (git2 internal name `dup1`)
    // must flag exactly that row as invalid.
    std::fs::remove_dir_all(tmp.path().join("b/dup")).unwrap();
    let snap2 = snapshot_repo("p", &repo).unwrap();
    let gone = snap2
        .rows
        .iter()
        .find(|r| r.entry.path.ends_with("b/dup"))
        .expect("registry still lists the deleted worktree");
    assert!(
        gone.git2_invalid || gone.entry.prunable.is_some(),
        "deleted worktree flagged"
    );
    assert!(
        gone.git2_invalid,
        "git2 cross-check lane must match by path even when basename != internal id"
    );
    let alive = snap2
        .rows
        .iter()
        .find(|r| r.entry.path.ends_with("a/dup"))
        .unwrap();
    assert!(!alive.git2_invalid, "surviving twin not falsely flagged");
}

/// S-stage critique regression: unborn HEAD (fresh repo, staged file, no
/// commit yet) must still fingerprint - `diff HEAD` exits 128 there, the
/// explicit branch uses --cached + worktree-vs-index instead.
#[test]
fn worktree_unborn_head_repo_fingerprinted() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = tmp.path().join("fresh");
    std::fs::create_dir(&repo).unwrap();
    git(&repo, &["init", "-q"]);
    std::fs::write(repo.join("first.txt"), "one\ntwo\n").unwrap();
    git(&repo, &["add", "first.txt"]);

    let snap = snapshot_repo("p", &repo).expect("unborn HEAD must not abort");
    let fp = snap.rows[0].fingerprint.as_ref().unwrap();
    assert_eq!(fp.files_changed, 1);
    assert_eq!(fp.insertions, 2, "staged-vs-empty counted via --cached");
}

/// S-stage critique risk regression: diff_hash must identify the dirty
/// state, not HEAD - an unrelated commit (branch.oid flip) with identical
/// dirty content must not change the hash.
#[test]
fn worktree_diff_hash_ignores_head_movement() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = base_repo(tmp.path());
    std::fs::write(repo.join("untracked.txt"), "u\n").unwrap();

    let h1 = snapshot_repo("p", &repo).unwrap().rows[0]
        .fingerprint
        .as_ref()
        .unwrap()
        .diff_hash
        .clone();
    git(&repo, &["commit", "-q", "--allow-empty", "-m", "noop"]);
    let h2 = snapshot_repo("p", &repo).unwrap().rows[0]
        .fingerprint
        .as_ref()
        .unwrap()
        .diff_hash
        .clone();
    assert_eq!(
        h1, h2,
        "no-op commit flipped diff_hash: branch headers are leaking into it"
    );
}

/// Contract conformance: emitted envelopes round-trip through the
/// deny_unknown_fields projection of contracts/event_stream.schema.json,
/// with strictly increasing seq and schema-legal event ids.
#[test]
fn worktree_events_conform_to_envelope() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = base_repo(tmp.path());
    git(&repo, &["worktree", "add", "-q", "../wt1", "-b", "feat"]);
    std::fs::write(tmp.path().join("wt1/extra.txt"), "x\n").unwrap();

    let snap = snapshot_repo("Demo.Project", &repo).unwrap();
    let events = to_events(&snap, 10, "2026-06-10T00:00:00Z");
    assert!(
        events.iter().any(|e| e.kind == EventKind::DiffSnapshot),
        "dirty wt1 must produce a DiffSnapshot"
    );
    assert_eq!(
        events
            .iter()
            .filter(|e| e.kind == EventKind::WorktreeDiscovered)
            .count(),
        2
    );
    let mut prev = 9u64;
    for ev in &events {
        assert!(ev.seq > prev, "seq strictly increasing");
        prev = ev.seq;
        assert!(ev.event_id.starts_with("evt_"));
        assert!(
            ev.event_id
                .chars()
                .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_'),
            "event_id ^evt_[a-z0-9_]+$: {}",
            ev.event_id
        );
        assert_eq!(ev.ts, "2026-06-10T00:00:00Z");
        // deny_unknown_fields round-trip == structural contract replay
        let js = serde_json::to_string(ev).unwrap();
        let back: EventEnvelope = serde_json::from_str(&js).unwrap();
        assert_eq!(back.seq, ev.seq);
    }
    let disc = events
        .iter()
        .find(|e| e.payload["path"].as_str().unwrap().ends_with("wt1"))
        .unwrap();
    assert_eq!(
        disc.payload["branch"], "feat",
        "short branch name projected"
    );
    assert_eq!(disc.payload["dirty"], true);
    assert!(
        disc.payload["worktree_id"]
            .as_str()
            .unwrap()
            .starts_with("wt_"),
        "stable id present"
    );
}

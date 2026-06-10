//! A1_06 integration tests: registry-driven multi-repo reconciliation with
//! per-project bucketed projections. Real git repos in tempdirs; the
//! registry file is mutated mid-test to exercise hot reload.

mod common;

use std::path::Path;

use common::{base_repo, git};
use turingosd::events::EventKind;
use turingosd::registry::{load_registry, RegistryRunner};
use turingosd::uds::EventHub;

fn write_registry(path: &Path, projects: &[(&str, Option<&Path>, Option<&str>)]) {
    let projects: Vec<serde_json::Value> = projects
        .iter()
        .map(|(id, p, remote)| {
            serde_json::json!({
                "project_id": id,
                "path": p.map(|p| p.to_string_lossy()),
                "remote": remote,
            })
        })
        .collect();
    let body = serde_json::json!({ "version": 1, "projects": projects });
    std::fs::write(path, serde_json::to_vec_pretty(&body).unwrap()).unwrap();
}

fn second_repo(root: &Path, name: &str) -> std::path::PathBuf {
    let repo = root.join(name);
    std::fs::create_dir(&repo).unwrap();
    git(&repo, &["init", "-q"]);
    std::fs::write(repo.join("base.txt"), "base\n").unwrap();
    git(&repo, &["add", "."]);
    git(&repo, &["commit", "-qm", "base"]);
    repo
}

#[test]
fn registry_parses_canonicalizes_and_rejects_garbage() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = base_repo(tmp.path());
    let link = tmp.path().join("link");
    std::os::unix::fs::symlink(&repo, &link).unwrap();
    let reg = tmp.path().join("projects.json");
    write_registry(&reg, &[("alpha", Some(&link), Some("github.com/x/alpha"))]);

    let entries = load_registry(&reg).unwrap();
    assert_eq!(entries.len(), 1);
    assert_eq!(
        entries[0].path.as_deref().unwrap(),
        repo.canonicalize().unwrap(),
        "symlinked path must canonicalize (R1_memo §2.a)"
    );

    std::fs::write(&reg, b"{ not json").unwrap();
    assert!(
        load_registry(&reg).is_err(),
        "corrupt registry is a visible error"
    );

    write_registry(&reg, &[("dup", None, None), ("dup", None, None)]);
    assert!(
        load_registry(&reg).is_err(),
        "duplicate project_id rejected"
    );
}

/// Two repos, drift in one: only its bucket moves; both buckets conserve
/// against a filtered refold of the shared log (双层守恒).
#[test]
fn registry_two_repos_isolated_buckets() {
    let tmp = tempfile::tempdir().unwrap();
    let alpha = base_repo(tmp.path());
    let beta = second_repo(tmp.path(), "beta");
    let reg = tmp.path().join("projects.json");
    write_registry(
        &reg,
        &[("alpha", Some(&alpha), None), ("beta", Some(&beta), None)],
    );

    let hub = EventHub::new("workspace");
    let mut runner = RegistryRunner::new(&reg);
    let s1 = runner.tick(&hub).unwrap();
    assert_eq!(s1.projects_local, 2);
    assert_eq!(s1.reconcile_errors, 0);

    // drift only in alpha: a same-branch --force conflict (anomaly)
    git(&alpha, &["worktree", "add", "-q", "../wt1", "-b", "feat"]);
    git(
        &alpha,
        &["worktree", "add", "-q", "--force", "../wt2", "feat"],
    );
    runner.tick(&hub).unwrap();

    let pa = hub.project_projection("alpha").expect("alpha bucket");
    let pb = hub.project_projection("beta").expect("beta bucket");
    assert_eq!(
        pa.anomalous_worktrees(),
        2,
        "alpha's conflict pair is anomalous"
    );
    assert_eq!(
        pb.anomalous_worktrees(),
        0,
        "beta untouched - no cross-bucket bleed"
    );

    // 双层守恒: every bucket == filtered refold; rollup == full refold
    for id in hub.project_ids() {
        assert_eq!(
            hub.project_projection(&id).unwrap(),
            hub.refold_project(&id),
            "bucket {id} diverged from filtered refold"
        );
    }
    assert_eq!(hub.projection(), hub.refold(), "global rollup conserved");
}

/// Hot reload: add beta mid-flight -> discovered without restart; remove
/// alpha -> its worktrees get WorktreeRemoved and its anomaly count drains.
#[test]
fn registry_hot_reload_adds_and_removes_projects() {
    let tmp = tempfile::tempdir().unwrap();
    let alpha = base_repo(tmp.path());
    let beta = second_repo(tmp.path(), "beta");
    let reg = tmp.path().join("projects.json");

    write_registry(&reg, &[("alpha", Some(&alpha), None)]);
    let hub = EventHub::new("workspace");
    let mut runner = RegistryRunner::new(&reg);
    runner.tick(&hub).unwrap();
    assert!(
        hub.project_projection("beta").is_none(),
        "beta not yet registered"
    );

    write_registry(
        &reg,
        &[("alpha", Some(&alpha), None), ("beta", Some(&beta), None)],
    );
    let s = runner.tick(&hub).unwrap();
    assert_eq!(s.projects_local, 2, "hot reload picked beta up");
    assert!(hub.project_projection("beta").is_some());

    // remove alpha: rows retire visibly
    write_registry(&reg, &[("beta", Some(&beta), None)]);
    runner.tick(&hub).unwrap();
    let (events, _) = hub.replay_and_subscribe();
    let retired: Vec<_> = events
        .iter()
        .filter(|e| {
            e.kind == EventKind::WorktreeRemoved
                && e.payload["project_id"] == "alpha"
                && e.payload["reason"] == "project unregistered"
        })
        .collect();
    assert!(
        !retired.is_empty(),
        "alpha's worktrees must retire with a visible reason"
    );
    assert_eq!(
        hub.refold_project("alpha").anomalous_worktrees(),
        0,
        "retired project's anomaly ledger drains"
    );
}

/// Remote-only entries (selected on GitHub, no local clone) are announced
/// as visible placeholders with local=false - the gray remote-only row.
#[test]
fn registry_remote_only_announced_not_reconciled() {
    let tmp = tempfile::tempdir().unwrap();
    let reg = tmp.path().join("projects.json");
    write_registry(&reg, &[("ghost", None, Some("github.com/x/ghost"))]);

    let hub = EventHub::new("workspace");
    let mut runner = RegistryRunner::new(&reg);
    let s = runner.tick(&hub).unwrap();
    assert_eq!(s.projects_remote_only, 1);
    assert_eq!(s.projects_local, 0);

    let (events, _) = hub.replay_and_subscribe();
    let reg_ev = events
        .iter()
        .find(|e| e.kind == EventKind::ProjectRegistered)
        .expect("remote-only project still announced");
    assert_eq!(reg_ev.payload["project_id"], "ghost");
    assert_eq!(reg_ev.payload["local"], false);
    assert_eq!(reg_ev.payload["remote"], "github.com/x/ghost");
    // announcement dedup: a second tick adds no new registration event
    runner.tick(&hub).unwrap();
    let (events2, _) = hub.replay_and_subscribe();
    assert_eq!(
        events2
            .iter()
            .filter(|e| e.kind == EventKind::ProjectRegistered)
            .count(),
        1,
        "unchanged entry must not re-announce every tick (log growth)"
    );
}

/// Corrupt registry mid-flight: the tick errors VISIBLY and the previous
/// generation keeps reconciling untouched on the next good read.
#[test]
fn registry_corrupt_reload_keeps_previous_generation() {
    let tmp = tempfile::tempdir().unwrap();
    let alpha = base_repo(tmp.path());
    let reg = tmp.path().join("projects.json");
    write_registry(&reg, &[("alpha", Some(&alpha), None)]);

    let hub = EventHub::new("workspace");
    let mut runner = RegistryRunner::new(&reg);
    runner.tick(&hub).unwrap();

    std::fs::write(&reg, b"{ broken").unwrap();
    assert!(
        runner.tick(&hub).is_err(),
        "corrupt reload is an error, not a wipe"
    );

    // restore and verify alpha kept its state (no spurious re-discovery)
    write_registry(&reg, &[("alpha", Some(&alpha), None)]);
    runner.tick(&hub).unwrap();
    let (events, _) = hub.replay_and_subscribe();
    assert_eq!(
        events
            .iter()
            .filter(|e| e.kind == EventKind::WorktreeRemoved)
            .count(),
        0,
        "no retire storm across the corrupt window"
    );
    assert_eq!(
        events
            .iter()
            .filter(|e| e.kind == EventKind::ProjectRegistered)
            .count(),
        1,
        "no duplicate announcement across the corrupt window"
    );
}

/// S-stage blocker regression: idle STEADY STATE across multiple projects.
/// Per-bucket conservation must hold after many all-idle ticks (the old
/// cross-project coalescing deleted other projects' markers from the log
/// while their buckets had folded them), and the idle log must stay
/// bounded at <= 1 trailing idle marker per project (no per-tick growth).
#[test]
fn registry_steady_state_idle_buckets_conserve() {
    let tmp = tempfile::tempdir().unwrap();
    let alpha = base_repo(tmp.path());
    let beta = second_repo(tmp.path(), "beta");
    let reg = tmp.path().join("projects.json");
    write_registry(
        &reg,
        &[("alpha", Some(&alpha), None), ("beta", Some(&beta), None)],
    );

    let hub = EventHub::new("workspace");
    let mut runner = RegistryRunner::new(&reg);
    runner.tick(&hub).unwrap(); // discovery
    for _ in 0..3 {
        runner.tick(&hub).unwrap(); // idle steady state
    }
    let (events_mid, _) = hub.replay_and_subscribe();
    for _ in 0..3 {
        runner.tick(&hub).unwrap();
    }
    let (events_end, _) = hub.replay_and_subscribe();
    assert_eq!(
        events_mid.len(),
        events_end.len(),
        "idle steady state must not grow the retained log"
    );

    for id in hub.project_ids() {
        assert_eq!(
            hub.project_projection(&id).unwrap(),
            hub.refold_project(&id),
            "bucket {id} broke conservation in idle steady state"
        );
    }
    assert_eq!(hub.projection(), hub.refold(), "global rollup conserved");

    // exactly one trailing idle marker per project
    let trailing_idle: Vec<_> = events_end
        .iter()
        .rev()
        .take_while(|e| {
            e.kind == EventKind::ReconciliationCompleted && e.payload["drift_found"] == 0
        })
        .map(|e| e.payload["project_id"].as_str().unwrap().to_string())
        .collect();
    let mut sorted = trailing_idle.clone();
    sorted.sort();
    sorted.dedup();
    assert_eq!(
        sorted.len(),
        trailing_idle.len(),
        "duplicate idle markers for one project in the trailing run: {trailing_idle:?}"
    );
    assert_eq!(sorted, vec!["alpha".to_string(), "beta".to_string()]);
}

/// S-stage blocker regression: same project_id repointed to a new clone
/// must rebind - the old binding retires (with visible removals + bucket
/// eviction) and the new path's worktrees are discovered.
#[test]
fn registry_path_repoint_rebinds_reconciler() {
    let tmp = tempfile::tempdir().unwrap();
    let alpha = base_repo(tmp.path());
    let beta = second_repo(tmp.path(), "beta");
    let reg = tmp.path().join("projects.json");

    write_registry(&reg, &[("proj", Some(&alpha), None)]);
    let hub = EventHub::new("workspace");
    let mut runner = RegistryRunner::new(&reg);
    runner.tick(&hub).unwrap();

    write_registry(&reg, &[("proj", Some(&beta), None)]);
    runner.tick(&hub).unwrap();

    let (events, _) = hub.replay_and_subscribe();
    let beta_canon = beta.canonicalize().unwrap();
    let discovered_beta = events.iter().any(|e| {
        e.kind == EventKind::WorktreeDiscovered
            && e.payload["project_id"] == "proj"
            && e.payload["path"]
                .as_str()
                .is_some_and(|p| p.starts_with(beta_canon.to_str().unwrap()))
    });
    assert!(discovered_beta, "repointed clone must be discovered");
    let retired_alpha = events.iter().any(|e| {
        e.kind == EventKind::WorktreeRemoved
            && e.payload["project_id"] == "proj"
            && e.payload["reason"] == "project unregistered"
    });
    assert!(retired_alpha, "old binding must retire visibly");
    assert_eq!(
        hub.project_projection("proj").unwrap(),
        hub.refold_project("proj"),
        "bucket conserves across the rebind"
    );
}

/// S-stage blocker regression: two project_ids on one canonical path are
/// rejected at load (path-derived worktree_ids would collide in the global
/// ledger, breaking rollup == Σ buckets and poisoning retire).
#[test]
fn registry_duplicate_path_rejected_even_via_symlink() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = base_repo(tmp.path());
    let link = tmp.path().join("alias");
    std::os::unix::fs::symlink(&repo, &link).unwrap();
    let reg = tmp.path().join("projects.json");
    write_registry(
        &reg,
        &[("ida", Some(&repo), None), ("idb", Some(&link), None)],
    );
    assert!(
        load_registry(&reg).is_err(),
        "symlink alias of the same clone must be rejected as duplicate path"
    );
}

/// S-stage blocker regression: removal evicts the bucket (no ghost card),
/// and re-registration rebuilds a conserved bucket from fresh events.
#[test]
fn registry_removal_evicts_bucket_and_rereg_conserves() {
    let tmp = tempfile::tempdir().unwrap();
    let alpha = base_repo(tmp.path());
    let reg = tmp.path().join("projects.json");
    write_registry(&reg, &[("alpha", Some(&alpha), None)]);

    let hub = EventHub::new("workspace");
    let mut runner = RegistryRunner::new(&reg);
    runner.tick(&hub).unwrap();
    assert!(hub.project_ids().contains(&"alpha".to_string()));

    write_registry(&reg, &[]);
    runner.tick(&hub).unwrap();
    assert!(
        !hub.project_ids().contains(&"alpha".to_string()),
        "removed project must not survive as a ghost bucket"
    );
    assert!(hub.project_projection("alpha").is_none());

    write_registry(&reg, &[("alpha", Some(&alpha), None)]);
    runner.tick(&hub).unwrap();
    assert!(hub.project_ids().contains(&"alpha".to_string()));
    assert_eq!(
        hub.project_projection("alpha").unwrap(),
        hub.refold_project("alpha"),
        "re-registered bucket conserves against the full filtered log"
    );
}

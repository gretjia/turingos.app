//! A1_03 integration tests: UDS subscription end-to-end (replay + live
//! push + 0600 + peer-cred), reconciliation drift lifecycle against a real
//! git repository, and hub-level projection conservation.

mod common;

use std::path::Path;
use std::sync::Arc;

use tokio::io::{AsyncBufReadExt, BufReader};
use tokio::net::UnixStream;

use common::{base_repo, git};
use turingosd::events::{EventEnvelope, EventKind, EventSource, TrustState};
use turingosd::uds::{bind_socket, serve, EventHub, PeerAuth, Reconciler, SameUid};

fn publish_simple(hub: &EventHub, kind: EventKind) -> EventEnvelope {
    hub.publish(
        kind,
        EventSource::Daemon,
        TrustState::ObservedUnsigned,
        serde_json::json!({}),
    )
}

async fn read_envelope(
    reader: &mut BufReader<UnixStream>,
    buf: &mut String,
) -> Option<EventEnvelope> {
    buf.clear();
    match reader.read_line(buf).await {
        Ok(0) => None,
        Ok(_) => Some(serde_json::from_str(buf).expect("JSONL line is an envelope")),
        Err(e) => panic!("read: {e}"),
    }
}

/// Replay-then-live: a subscriber gets the full retained log first, then
/// live pushes, seq strictly increasing across the boundary; socket is 0600.
#[tokio::test]
async fn uds_replay_then_live_push() {
    let tmp = tempfile::tempdir().unwrap();
    let sock = tmp.path().join("d.sock");
    let hub = EventHub::new("t");
    publish_simple(&hub, EventKind::AgentSessionStarted);
    publish_simple(&hub, EventKind::ProposalSubmitted);

    let listener = bind_socket(&sock).unwrap();
    use std::os::unix::fs::PermissionsExt;
    let mode = std::fs::metadata(&sock).unwrap().permissions().mode();
    assert_eq!(mode & 0o777, 0o600, "socket must be 0600");

    let server_hub = hub.clone();
    tokio::spawn(async move {
        let _ = serve(listener, server_hub, Arc::new(SameUid)).await;
    });

    let stream = UnixStream::connect(&sock).await.unwrap();
    let mut reader = BufReader::new(stream);
    let mut buf = String::new();

    let e0 = read_envelope(&mut reader, &mut buf).await.unwrap();
    let e1 = read_envelope(&mut reader, &mut buf).await.unwrap();
    assert_eq!((e0.seq, e1.seq), (0, 1), "replay in order");
    assert_eq!(e0.kind, EventKind::AgentSessionStarted);

    publish_simple(&hub, EventKind::ProposalAccepted);
    let e2 = read_envelope(&mut reader, &mut buf).await.unwrap();
    assert_eq!(e2.seq, 2, "live push follows replay with no gap/dup");
    assert_eq!(e2.kind, EventKind::ProposalAccepted);
    assert_eq!(e2.schema_version, "tos.app.event.v0");
}

/// Peer credentials on this platform: uid must match (SameUid PASS path)
/// and pid availability is pinned per-OS (R1_memo §5 UNVERIFIED #6: macOS
/// pid via peer cred - asserted here on real sockets, not assumed).
#[tokio::test]
async fn uds_peer_cred_uid_and_pid() {
    let tmp = tempfile::tempdir().unwrap();
    let sock = tmp.path().join("c.sock");
    let listener = bind_socket(&sock).unwrap();
    let accept = tokio::spawn(async move {
        let (stream, _) = listener.accept().await.unwrap();
        stream.peer_cred().unwrap()
    });
    let _client = UnixStream::connect(&sock).await.unwrap();
    let cred = accept.await.unwrap();

    // SAFETY: getuid(2) cannot fail.
    assert_eq!(cred.uid(), unsafe { libc::getuid() });
    assert!(SameUid.authorize(&cred).is_ok());
    #[cfg(any(target_os = "linux", target_os = "macos"))]
    assert!(
        cred.pid().is_some(),
        "peer pid expected on this platform (Linux SO_PEERCRED / macOS LOCAL_PEERPID)"
    );
}

/// Fail-closed: a denying policy must close the connection before any
/// event bytes flow.
#[tokio::test]
async fn uds_denied_peer_gets_closed() {
    struct DenyAll;
    impl PeerAuth for DenyAll {
        fn authorize(&self, _: &tokio::net::unix::UCred) -> Result<(), String> {
            Err("policy: deny-all".into())
        }
    }
    let tmp = tempfile::tempdir().unwrap();
    let sock = tmp.path().join("deny.sock");
    let hub = EventHub::new("t");
    publish_simple(&hub, EventKind::AgentSessionStarted);
    let listener = bind_socket(&sock).unwrap();
    tokio::spawn(async move {
        let _ = serve(listener, hub, Arc::new(DenyAll)).await;
    });

    let stream = UnixStream::connect(&sock).await.unwrap();
    let mut reader = BufReader::new(stream);
    let mut buf = String::new();
    let n = reader.read_line(&mut buf).await.unwrap();
    assert_eq!(n, 0, "denied peer must see EOF, never an event");
}

/// Reconciliation lifecycle on a real repo: first tick discovers everything,
/// a quiet tick reports zero drift, adding a worktree drifts by one,
/// removing it emits WorktreeRemoved. Every cycle closes with
/// ReconciliationCompleted carrying the registered method string.
#[test]
fn uds_reconciler_emits_drift_lifecycle() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = base_repo(tmp.path());
    let hub = EventHub::new("p");
    let mut recon = Reconciler::new(&repo);

    let s1 = recon.tick(&hub).unwrap();
    assert_eq!(s1.worktrees_seen, 1);
    assert_eq!(
        s1.drift_found, 1,
        "first sight of the main worktree is drift"
    );

    let s2 = recon.tick(&hub).unwrap();
    assert_eq!(s2.drift_found, 0, "quiet repo, quiet tick");

    git(&repo, &["worktree", "add", "-q", "../wt1", "-b", "feat"]);
    let s3 = recon.tick(&hub).unwrap();
    assert_eq!(s3.worktrees_seen, 2);
    assert_eq!(s3.drift_found, 1, "exactly the new worktree drifted");

    git(&repo, &["worktree", "remove", "../wt1"]);
    let s4 = recon.tick(&hub).unwrap();
    assert_eq!(s4.worktrees_seen, 1);
    assert_eq!(s4.drift_found, 1, "removal is drift too");

    let (events, _) = hub.replay_and_subscribe();
    assert_eq!(
        events
            .iter()
            .filter(|e| e.kind == EventKind::ReconciliationCompleted)
            .count(),
        4,
        "one marker per tick"
    );
    let removed: Vec<_> = events
        .iter()
        .filter(|e| e.kind == EventKind::WorktreeRemoved)
        .collect();
    assert_eq!(removed.len(), 1);
    assert!(removed[0].payload["path"]
        .as_str()
        .unwrap()
        .ends_with("wt1"));
    let recon_done = events
        .iter()
        .rfind(|e| e.kind == EventKind::ReconciliationCompleted)
        .unwrap();
    assert_eq!(recon_done.payload["method"], "git_worktree_list+fs");
    assert_eq!(recon_done.payload["drift_found"], 1);
    let mut prev = None;
    for e in &events {
        assert!(
            prev.is_none_or(|p| e.seq > p),
            "hub seq strictly increasing"
        );
        prev = Some(e.seq);
    }
}

/// Hub-level conservation: the resident projection equals a cold fold of the
/// retained log after arbitrary publishes (菜单栏三计数恒时可信的机器背书).
#[test]
fn uds_hub_projection_conserved() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = base_repo(tmp.path());
    let hub = EventHub::new("p");
    publish_simple(&hub, EventKind::AgentSessionStarted);
    publish_simple(&hub, EventKind::ProposalSubmitted);
    Reconciler::new(&repo).tick(&hub).unwrap();
    publish_simple(&hub, EventKind::AgentSessionEnded);

    assert_eq!(
        hub.projection(),
        hub.refold(),
        "incremental projection diverged from fold(log)"
    );
    let js = hub
        .projection()
        .to_contract_json(turingosd::projection::DeriveSource::Git);
    assert_eq!(js["state"]["active_sessions"], 0);
    assert_eq!(js["state"]["pending_proposals"], 1);
    assert_eq!(js["schema_version"], "tos.app.projection.v0");
    assert_eq!(js["derive_source"], "git");
}

/// S-stage critique regression: drift identity must be the full emitted
/// payload - a `git worktree lock` toggle (which the old hand-picked digest
/// ignored) is drift and must re-emit with locked=true + the reason.
#[test]
fn uds_lock_toggle_is_drift() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = base_repo(tmp.path());
    git(&repo, &["worktree", "add", "-q", "../wt1", "-b", "feat"]);
    let hub = EventHub::new("p");
    let mut recon = Reconciler::new(&repo);
    recon.tick(&hub).unwrap();

    git(
        &repo,
        &["worktree", "lock", "../wt1", "--reason", "frozen for audit"],
    );
    let s = recon.tick(&hub).unwrap();
    assert_eq!(s.drift_found, 1, "lock toggle must be drift");
    let (events, _) = hub.replay_and_subscribe();
    let latest = events
        .iter()
        .rfind(|e| e.kind == EventKind::WorktreeDiscovered)
        .unwrap();
    assert_eq!(latest.payload["locked"], true);
    assert_eq!(latest.payload["locked_reason"], "frozen for audit");

    git(&repo, &["worktree", "unlock", "../wt1"]);
    let s2 = recon.tick(&hub).unwrap();
    assert_eq!(s2.drift_found, 1, "unlock is drift too");
}

/// S-stage critique regression: an idle repo must not grow the retained log
/// by one marker per tick. Live subscribers still see every heartbeat;
/// the replay log coalesces consecutive idle markers; seq stays strictly
/// increasing and conservation holds across the compaction.
#[test]
fn uds_idle_markers_coalesce_in_replay() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = base_repo(tmp.path());
    let hub = EventHub::new("p");
    let mut recon = Reconciler::new(&repo);
    recon.tick(&hub).unwrap(); // discovery tick (drift marker retained)

    let (_, mut rx) = hub.replay_and_subscribe();
    for _ in 0..3 {
        recon.tick(&hub).unwrap(); // three idle heartbeats
    }
    let mut live_markers = 0;
    while let Ok(ev) = rx.try_recv() {
        if ev.kind == EventKind::ReconciliationCompleted {
            live_markers += 1;
        }
    }
    assert_eq!(live_markers, 3, "live stream keeps every heartbeat");

    let (events, _) = hub.replay_and_subscribe();
    let idle_markers: Vec<_> = events
        .iter()
        .filter(|e| e.kind == EventKind::ReconciliationCompleted && e.payload["drift_found"] == 0)
        .collect();
    assert_eq!(
        idle_markers.len(),
        1,
        "consecutive idle markers coalesce to the latest one in replay"
    );
    let mut prev = None;
    for e in &events {
        assert!(
            prev.is_none_or(|p| e.seq > p),
            "seq strictly increasing across compaction"
        );
        prev = Some(e.seq);
    }
    assert_eq!(
        hub.projection(),
        hub.refold(),
        "conservation must survive coalescing"
    );
}

/// The reconciler's payloads come from the same builders as snapshot
/// to_events - guard against drift by comparing one real row end-to-end.
#[test]
fn uds_reconciler_payload_matches_snapshot_shape() {
    let tmp = tempfile::tempdir().unwrap();
    let repo = base_repo(tmp.path());
    std::fs::write(repo.join("dirty.txt"), "x\n").unwrap();

    let hub = EventHub::new("p");
    Reconciler::new(&repo).tick(&hub).unwrap();
    let (events, _) = hub.replay_and_subscribe();
    let via_recon = events
        .iter()
        .find(|e| e.kind == EventKind::WorktreeDiscovered)
        .unwrap();

    let snap = turingosd::snapshot::snapshot_repo("p", Path::new(&repo)).unwrap();
    let via_snapshot = turingosd::snapshot::to_events(&snap, 0, "2026-06-10T00:00:00Z");
    let reference = via_snapshot
        .iter()
        .find(|e| e.kind == EventKind::WorktreeDiscovered)
        .unwrap();
    assert_eq!(
        via_recon.payload, reference.payload,
        "one payload builder, two emit paths - they must agree byte-for-byte"
    );
}

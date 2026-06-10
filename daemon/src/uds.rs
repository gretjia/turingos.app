//! A1_03: UDS JSONL event subscription server + reconciliation loop.
//!
//! ADR-005: GUI<->daemon IPC is event-subscription, not request-response.
//! Wire format = one contract envelope per line (JSONL), exactly the
//! fixture format - the SwiftUI shell consumes the same stream shape the
//! P0.5 renderer proved. Security posture (docs/THREAT_MODEL.md): socket
//! chmod 0600 + peer-cred same-uid check, fail-closed with a visible
//! stderr reason. A slow subscriber that lags the broadcast buffer is
//! disconnected (visible state - the UI shows gray "未对账" and reconnects
//! to get a fresh replay) rather than silently skipping events.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use tokio::io::AsyncWriteExt;
use tokio::net::unix::UCred;
use tokio::net::{UnixListener, UnixStream};
use tokio::sync::broadcast;

use crate::events::{EventEnvelope, EventKind, EventSource, TrustState};
use crate::projection::AggregateProjection;
use crate::snapshot::{
    diff_snapshot_payload, snapshot_repo, utc_now_iso, worktree_discovered_payload, SnapshotError,
};

/// Peer admission policy. Output domain is {PASS,FAIL}: Ok(()) or a visible
/// denial reason - never a silent default-allow (M2 fail-closed).
pub trait PeerAuth: Send + Sync + 'static {
    fn authorize(&self, cred: &UCred) -> Result<(), String>;
}

/// Same-uid policy: only the daemon owner's processes may subscribe.
/// uid/gid via peer credentials are reliable on both Linux (SO_PEERCRED)
/// and macOS (getpeereid) - R1_memo §5; pid availability is asserted in the
/// integration tests per platform.
pub struct SameUid;

impl PeerAuth for SameUid {
    fn authorize(&self, cred: &UCred) -> Result<(), String> {
        // SAFETY: getuid(2) cannot fail and has no preconditions.
        let me = unsafe { libc::getuid() };
        if cred.uid() == me {
            Ok(())
        } else {
            Err(format!("peer uid {} != daemon uid {me}", cred.uid()))
        }
    }
}

struct HubState {
    events: Vec<EventEnvelope>,
    projection: AggregateProjection,
    /// Per-project buckets (A1_06): an event lands in the bucket named by
    /// its payload.project_id (when present) AND in the global rollup -
    /// the compressed Global Workspace cards read buckets, the menubar
    /// Glance reads the rollup. Conservation holds per bucket against a
    /// filtered refold of the log.
    buckets: BTreeMap<String, AggregateProjection>,
    /// Monotonic seq, independent of events.len(): retained-log coalescing
    /// may drop an event, and a reused seq would break the strictly-
    /// increasing guarantee live subscribers rely on.
    next_seq: u64,
}

/// In-process retained event log + live broadcast + resident projection.
/// ADR-003: this is derived, disposable state (rebuildable by re-running
/// reconciliation from git); canonical truth stays in the upstream tape.
pub struct EventHub {
    project_id: String,
    state: Mutex<HubState>,
    tx: broadcast::Sender<EventEnvelope>,
}

impl EventHub {
    pub fn new(project_id: &str) -> Arc<Self> {
        let (tx, _) = broadcast::channel(1024);
        Arc::new(EventHub {
            project_id: project_id.to_string(),
            state: Mutex::new(HubState {
                events: Vec::new(),
                projection: AggregateProjection::default(),
                buckets: BTreeMap::new(),
                next_seq: 0,
            }),
            tx,
        })
    }

    pub fn project_id(&self) -> &str {
        &self.project_id
    }

    /// Append one event: seq assignment, projection fold step and broadcast
    /// all happen under the same lock, so `replay_and_subscribe` can never
    /// observe a gap or a duplicate.
    pub fn publish(
        &self,
        kind: EventKind,
        source: EventSource,
        trust_state: TrustState,
        payload: serde_json::Value,
    ) -> EventEnvelope {
        let mut st = self.state.lock().expect("hub lock");
        Self::publish_locked(
            &self.project_id,
            &self.tx,
            &mut st,
            kind,
            source,
            trust_state,
            payload,
        )
    }

    fn publish_locked(
        project_id: &str,
        tx: &broadcast::Sender<EventEnvelope>,
        st: &mut HubState,
        kind: EventKind,
        source: EventSource,
        trust_state: TrustState,
        payload: serde_json::Value,
    ) -> EventEnvelope {
        let seq = st.next_seq;
        st.next_seq += 1;
        let ev = EventEnvelope::new(
            project_id,
            seq,
            &utc_now_iso(),
            kind,
            source,
            trust_state,
            payload,
        );
        st.projection.apply(&ev);
        if let Some(pid) = event_project_id(&ev) {
            st.buckets.entry(pid.to_string()).or_default().apply(&ev);
        }
        st.events.push(ev.clone());
        let _ = tx.send(ev.clone()); // no subscribers yet is fine
        ev
    }

    /// ReconciliationCompleted markers: live subscribers receive every
    /// tick's marker (heartbeat), but consecutive idle markers (drift==0)
    /// are coalesced in the retained log - the previous idle marker is
    /// dropped before the new one is appended, so an idle repo does not
    /// grow the log by one event per tick forever (S-stage critique:
    /// unbounded growth). Coalescing only ever removes an event whose sole
    /// projection effect is as_of_seq, which the newer marker dominates -
    /// `projection == fold(log)` conservation is preserved, and seq stays
    /// strictly increasing because next_seq is independent of events.len().
    pub fn publish_reconciliation(&self, payload: serde_json::Value, idle: bool) -> EventEnvelope {
        let pid = payload
            .get("project_id")
            .and_then(|v| v.as_str())
            .map(str::to_owned);
        let mut st = self.state.lock().expect("hub lock");
        if idle {
            // Coalescing is scoped to THIS project's previous idle marker
            // within the trailing run of idle markers (S-stage A1_06
            // blocker: a cross-project pop deleted other projects' markers
            // from the log while their buckets had already folded them -
            // per-bucket conservation broke in idle steady state). The
            // trailing-run bound keeps the idle log at <= 1 marker per
            // project instead of growing per tick; removing a marker only
            // ever drops an event whose sole bucket effect (as_of_seq) is
            // dominated by the newer marker, so conservation survives.
            let mut found: Option<usize> = None;
            for i in (0..st.events.len()).rev() {
                let e = &st.events[i];
                let is_idle_marker = e.kind == EventKind::ReconciliationCompleted
                    && e.payload.get("drift_found").and_then(|v| v.as_u64()) == Some(0);
                if !is_idle_marker {
                    break;
                }
                if event_project_id(e) == pid.as_deref() {
                    found = Some(i);
                    break;
                }
            }
            if let Some(i) = found {
                st.events.remove(i);
            }
        }
        Self::publish_locked(
            &self.project_id,
            &self.tx,
            &mut st,
            EventKind::ReconciliationCompleted,
            EventSource::Daemon,
            TrustState::ObservedUnsigned,
            payload,
        )
    }

    /// FileChanged hints (A1_04): live stream keeps every pulse; the
    /// retained log keeps only the latest of consecutive hints - the same
    /// unbounded-growth hardening the idle reconciliation markers got.
    /// Hints are projection no-ops except as_of_seq (dominated by the newer
    /// hint), so `projection == fold(log)` conservation survives the pop.
    /// Source honesty (S-stage critique): fsevents only where the backend
    /// really is FSEvents (macOS); elsewhere the watch subsystem reports as
    /// daemon - the contract enum has no inotify value yet (registered
    /// contracts debt on the atom card).
    pub fn publish_hint(&self, payload: serde_json::Value) -> EventEnvelope {
        #[cfg(target_os = "macos")]
        let source = EventSource::Fsevents;
        #[cfg(not(target_os = "macos"))]
        let source = EventSource::Daemon;
        let mut st = self.state.lock().expect("hub lock");
        let last_is_hint = st
            .events
            .last()
            .is_some_and(|e| e.kind == EventKind::FileChanged);
        if last_is_hint {
            st.events.pop();
        }
        Self::publish_locked(
            &self.project_id,
            &self.tx,
            &mut st,
            EventKind::FileChanged,
            source,
            TrustState::ObservedUnsigned,
            payload,
        )
    }

    /// Atomic snapshot replay + live subscription (single lock - see
    /// `publish`).
    pub fn replay_and_subscribe(&self) -> (Vec<EventEnvelope>, broadcast::Receiver<EventEnvelope>) {
        let st = self.state.lock().expect("hub lock");
        (st.events.clone(), self.tx.subscribe())
    }

    pub fn projection(&self) -> AggregateProjection {
        self.state.lock().expect("hub lock").projection.clone()
    }

    /// Per-project bucket (compressed Global Workspace card data source).
    pub fn project_projection(&self, project_id: &str) -> Option<AggregateProjection> {
        self.state
            .lock()
            .expect("hub lock")
            .buckets
            .get(project_id)
            .cloned()
    }

    pub fn project_ids(&self) -> Vec<String> {
        self.state
            .lock()
            .expect("hub lock")
            .buckets
            .keys()
            .cloned()
            .collect()
    }

    /// Conservation reference for tests/audits: fold of the retained log.
    pub fn refold(&self) -> AggregateProjection {
        let st = self.state.lock().expect("hub lock");
        AggregateProjection::fold(&st.events)
    }

    /// Bucket conservation reference: fold of the log filtered to one
    /// project's events (same extractor as the bucket router - one helper,
    /// or the paired paths drift).
    pub fn refold_project(&self, project_id: &str) -> AggregateProjection {
        let st = self.state.lock().expect("hub lock");
        AggregateProjection::fold(
            st.events
                .iter()
                .filter(|e| event_project_id(e) == Some(project_id)),
        )
    }

    /// Evict a project's bucket (registry removal: "no longer care" must
    /// not leave a ghost card - S-stage A1_06 blocker). Call AFTER the
    /// retire events are published; history stays in the log, only the
    /// live bucket surface disappears.
    pub fn retire_project(&self, project_id: &str) {
        self.state
            .lock()
            .expect("hub lock")
            .buckets
            .remove(project_id);
    }
}

/// The one project-attribution extractor, shared by the bucket router, the
/// conservation refold and the idle-marker scoper (paired-path drift guard).
pub(crate) fn event_project_id(ev: &EventEnvelope) -> Option<&str> {
    ev.payload.get("project_id").and_then(|v| v.as_str())
}

/// Bind the subscription socket: remove a stale socket file from a previous
/// daemon run (the path is daemon-owned by contract), bind, chmod 0600.
///
/// The bind->chmod gap was flagged in S-stage critique (socket briefly
/// world-connectable under default umask). A umask(0o177) bracket was tried
/// and REJECTED by real test: umask is process-global, so any concurrent
/// thread (parallel tests) or freshly spawned git child inherits it and
/// creates untraversable 0600 directories - a worse hazard than the gap.
/// The gap itself is harmless: every accepted connection still passes the
/// peer-cred same-uid check before a single event byte flows (THREAT_MODEL
/// pairs 0600 with peer-cred precisely so neither lock stands alone), and
/// callers are expected to place the socket in a user-private directory.
pub fn bind_socket(path: &Path) -> std::io::Result<UnixListener> {
    if path.exists() {
        std::fs::remove_file(path)?;
    }
    let listener = UnixListener::bind(path)?;
    use std::os::unix::fs::PermissionsExt;
    std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600))?;
    Ok(listener)
}

/// Accept loop: peer-cred check first, then a per-client push task.
pub async fn serve(
    listener: UnixListener,
    hub: Arc<EventHub>,
    auth: Arc<dyn PeerAuth>,
) -> std::io::Result<()> {
    loop {
        let (stream, _) = listener.accept().await?;
        let cred = match stream.peer_cred() {
            Ok(c) => c,
            Err(e) => {
                eprintln!("uds: peer_cred unavailable, closing: {e}");
                continue;
            }
        };
        if let Err(reason) = auth.authorize(&cred) {
            eprintln!("uds: connection denied: {reason}");
            continue; // drop == close, fail-closed
        }
        let hub = hub.clone();
        tokio::spawn(async move {
            if let Err(e) = handle_client(stream, hub).await {
                eprintln!("uds: subscriber ended: {e}");
            }
        });
    }
}

async fn write_jsonl(stream: &mut UnixStream, ev: &EventEnvelope) -> std::io::Result<()> {
    let mut line = serde_json::to_vec(ev).expect("envelope serializes");
    line.push(b'\n');
    stream.write_all(&line).await
}

async fn handle_client(mut stream: UnixStream, hub: Arc<EventHub>) -> std::io::Result<()> {
    let (replay, mut rx) = hub.replay_and_subscribe();
    let mut last_seq = None;
    for ev in &replay {
        write_jsonl(&mut stream, ev).await?;
        last_seq = Some(ev.seq);
    }
    loop {
        match rx.recv().await {
            Ok(ev) => {
                if last_seq.is_some_and(|s| ev.seq <= s) {
                    continue; // belt-and-suspenders: replay already covered it
                }
                last_seq = Some(ev.seq);
                write_jsonl(&mut stream, &ev).await?;
            }
            Err(broadcast::error::RecvError::Lagged(n)) => {
                // Losing events silently would make the stream lie; close so
                // the client reconnects and gets a coherent replay.
                eprintln!("uds: subscriber lagged by {n} events, closing for fresh replay");
                return Ok(());
            }
            Err(broadcast::error::RecvError::Closed) => return Ok(()),
        }
    }
}

pub struct ReconStats {
    pub worktrees_seen: u64,
    pub drift_found: u64,
}

/// Periodic reconciliation (ADR-010): canonical discovery is always
/// `git worktree list` + filesystem, regardless of hooks. Each tick runs an
/// A1_02 snapshot, publishes only the drift against the previous tick, and
/// closes with a ReconciliationCompleted marker.
///
/// Drift identity IS the emitted WorktreeDiscovered payload itself: if any
/// field the UI would be told changes (locked toggling, reason/error text,
/// head, dirty stats), that is drift. A hand-picked digest struct was the
/// S-stage critique's blind-spot finding (locked changes went unreported) -
/// one source of truth instead of a second lossy projection of it.
pub struct Reconciler {
    project_id: String,
    repo_path: PathBuf,
    last: BTreeMap<String, (serde_json::Value, String)>, // worktree_id -> (payload, path)
}

impl Reconciler {
    /// project_id is the reconciler's own identity (A1_06: one hub serves
    /// many projects, so the hub's id no longer names the repo).
    pub fn new(project_id: &str, repo_path: &Path) -> Self {
        Reconciler {
            project_id: project_id.to_string(),
            repo_path: repo_path.to_path_buf(),
            last: BTreeMap::new(),
        }
    }

    /// The path this reconciler is bound to (registry repoint detection).
    pub fn repo_path(&self) -> &Path {
        &self.repo_path
    }

    /// Retire this project's rows: every last-known worktree gets a
    /// WorktreeRemoved (the bucket's anomaly ledger drains with them) -
    /// a project leaving the registry must not freeze as a ghost.
    pub fn retire(self, hub: &EventHub) {
        for (worktree_id, (_, path)) in self.last {
            hub.publish(
                EventKind::WorktreeRemoved,
                EventSource::Daemon,
                TrustState::ObservedUnsigned,
                serde_json::json!({
                    "project_id": self.project_id,
                    "worktree_id": worktree_id,
                    "path": path,
                    "reason": "project unregistered",
                }),
            );
        }
    }

    pub fn tick(&mut self, hub: &EventHub) -> Result<ReconStats, SnapshotError> {
        let snap = snapshot_repo(&self.project_id, &self.repo_path)?;
        let mut drift = 0u64;
        let mut current: BTreeMap<String, (serde_json::Value, String)> = BTreeMap::new();
        for row in &snap.rows {
            let payload = worktree_discovered_payload(&self.project_id, row);
            let changed = self
                .last
                .get(&row.worktree_id)
                .is_none_or(|(prev, _)| *prev != payload);
            if changed {
                drift += 1;
                hub.publish(
                    EventKind::WorktreeDiscovered,
                    EventSource::Git,
                    TrustState::ObservedUnsigned,
                    payload.clone(),
                );
                if let Some(dp) = diff_snapshot_payload(row) {
                    hub.publish(
                        EventKind::DiffSnapshot,
                        EventSource::Git,
                        TrustState::ObservedUnsigned,
                        dp,
                    );
                }
            }
            current.insert(row.worktree_id.clone(), (payload, row.entry.path.clone()));
        }
        for (gone_id, (_, path)) in self
            .last
            .iter()
            .filter(|(id, _)| !current.contains_key(*id))
        {
            drift += 1;
            hub.publish(
                EventKind::WorktreeRemoved,
                EventSource::Git,
                TrustState::ObservedUnsigned,
                serde_json::json!({
                    "project_id": self.project_id,
                    "worktree_id": gone_id,
                    "path": path,
                    "reason": "worktree gone",
                }),
            );
        }
        self.last = current;
        let stats = ReconStats {
            worktrees_seen: snap.rows.len() as u64,
            drift_found: drift,
        };
        hub.publish_reconciliation(
            serde_json::json!({
                "project_id": self.project_id,
                "worktrees_seen": stats.worktrees_seen,
                "drift_found": stats.drift_found,
                "method": "git_worktree_list+fs",
            }),
            stats.drift_found == 0,
        );
        Ok(stats)
    }
}

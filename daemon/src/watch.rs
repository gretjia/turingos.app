//! A1_04: fs-watch dirty signals (notify crate spike).
//!
//! R1_memo §2.f law: FSEvents/inotify are best-effort HINTS, never a log.
//! The watch callback only collects dirty paths; a debounce window (the UX
//! "breathing" parameter - 活动脉冲呼吸感) coalesces bursts into one signal;
//! all heavy work stays in the reconciliation loop, which remains the
//! canonical discovery lane (ADR-010) and keeps running periodically even
//! if watching fails - the degradation path changes no contract.
//!
//! `.git/` internals are filtered at the source (S-stage critique): git
//! bookkeeping (index refresh, commits, fetches) must not masquerade as a
//! user edit pulse - and the daemon's own reads must never feed back.
//! Empirically pinned: with `--no-optional-locks` the reconciler's git
//! invocations leave .git/index untouched (plain `git status` does write
//! it), so the filter guards against EXTERNAL git churn, not our own.
//! git-state changes (commits, checkouts) still surface through the
//! periodic reconciliation tick within 2s.
//!
//! Known spike limitations (registered on the atom card): only the repo
//! root is watched - linked worktrees outside it are covered by the
//! periodic tick alone.

use std::collections::BTreeSet;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{mpsc, Arc};
use std::time::{Duration, Instant};

use notify::{RecommendedWatcher, RecursiveMode, Watcher};

/// Debounce window default: 800ms (R1 design brief - the pulse must breathe,
/// not flicker; the value travels in the event payload as protocol metadata).
pub const DEFAULT_DEBOUNCE_MS: u64 = 800;

/// At most this many concrete paths are carried in one hint payload; the
/// rest is a count (the hint says "look", not "here is everything").
pub const MAX_SAMPLE_PATHS: usize = 8;

/// Bounded signal queue between the OS callback and the debouncer. Hints
/// are droppable by design (best-effort; the periodic tick is the safety
/// net), so overflow drops the signal and counts it visibly instead of
/// growing memory without bound (S-stage critique).
const SIGNAL_QUEUE_CAP: usize = 1024;

#[derive(Debug, Clone)]
pub struct WatchConfig {
    pub debounce: Duration,
}

impl Default for WatchConfig {
    fn default() -> Self {
        WatchConfig {
            debounce: Duration::from_millis(DEFAULT_DEBOUNCE_MS),
        }
    }
}

/// One debounced dirty signal: every fs path that fired within the window.
#[derive(Debug, Clone)]
pub struct DirtyBatch {
    pub paths: BTreeSet<PathBuf>,
    pub debounce_ms: u64,
    /// Signals dropped on queue overflow since the last batch - honesty
    /// counter, not an error (hints are best-effort).
    pub dropped_signals: u64,
}

impl DirtyBatch {
    /// FileChanged hint payload (contract envelope payload). hint_only=true
    /// is the law: the UI renders a blue pulse, never a green truth, from
    /// this (R1 brief: git 确认前不转 green).
    pub fn to_payload(&self, project_id: &str) -> serde_json::Value {
        let sample: Vec<String> = self
            .paths
            .iter()
            .take(MAX_SAMPLE_PATHS)
            .map(|p| p.to_string_lossy().to_string())
            .collect();
        serde_json::json!({
            "project_id": project_id,
            "hint_only": true,
            "debounce_ms": self.debounce_ms,
            "changed_paths": self.paths.len() as u64,
            "sample_paths": sample,
            "dropped_signals": self.dropped_signals,
        })
    }
}

/// Any path with a `.git` component is git bookkeeping, not a user edit.
fn is_git_internal(path: &Path) -> bool {
    path.components().any(|c| c.as_os_str() == ".git")
}

/// Live watcher handle: dropping it stops both the OS watcher and the
/// debouncer thread (channel disconnect ends the loop).
pub struct DirtyWatcher {
    watcher: Option<RecommendedWatcher>,
    debouncer: Option<std::thread::JoinHandle<()>>,
}

impl Drop for DirtyWatcher {
    fn drop(&mut self) {
        // Order is load-bearing: the watcher (which owns the channel sender
        // inside its callback) must die FIRST so the debouncer's recv()
        // disconnects and its thread exits - joining before that deadlocks
        // (found by real test: the first run hung exactly here).
        drop(self.watcher.take());
        if let Some(h) = self.debouncer.take() {
            let _ = h.join();
        }
    }
}

/// Start watching `root` recursively. `on_dirty` receives one debounced
/// batch per quiet-period; it runs on the debouncer thread, so it must be
/// cheap (publish a hint, poke the reconciler - no git work).
pub fn watch_dirty(
    root: &Path,
    cfg: WatchConfig,
    on_dirty: impl Fn(DirtyBatch) + Send + 'static,
) -> notify::Result<DirtyWatcher> {
    let (tx, rx) = mpsc::sync_channel::<Vec<PathBuf>>(SIGNAL_QUEUE_CAP);
    let dropped = Arc::new(AtomicU64::new(0));
    let dropped_in = dropped.clone();
    let mut watcher = notify::recommended_watcher(move |res: notify::Result<notify::Event>| {
        if let Ok(event) = res {
            // Access events are reads - not dirt. Everything else (create/
            // modify/remove/rename/unknown) is a hint worth debouncing.
            if matches!(event.kind, notify::EventKind::Access(_)) {
                return;
            }
            let paths: Vec<PathBuf> = event
                .paths
                .into_iter()
                .filter(|p| !is_git_internal(p))
                .collect();
            if paths.is_empty() {
                return;
            }
            if tx.try_send(paths).is_err() {
                // Queue full (or debouncer gone): drop, count, stay honest.
                dropped_in.fetch_add(1, Ordering::Relaxed);
            }
        }
    })?;
    watcher.watch(root, RecursiveMode::Recursive)?;

    let debounce = cfg.debounce;
    let debouncer = std::thread::spawn(move || {
        // Block for the first signal, then collect until the window closes.
        while let Ok(first) = rx.recv() {
            let mut paths: BTreeSet<PathBuf> = first.into_iter().collect();
            let window_end = Instant::now() + debounce;
            let mut disconnected = false;
            loop {
                let now = Instant::now();
                if now >= window_end {
                    break;
                }
                match rx.recv_timeout(window_end - now) {
                    Ok(more) => paths.extend(more),
                    Err(mpsc::RecvTimeoutError::Timeout) => break,
                    Err(mpsc::RecvTimeoutError::Disconnected) => {
                        disconnected = true;
                        break;
                    }
                }
            }
            on_dirty(DirtyBatch {
                paths,
                debounce_ms: debounce.as_millis() as u64,
                dropped_signals: dropped.swap(0, Ordering::Relaxed),
            });
            if disconnected {
                return;
            }
        }
    });

    Ok(DirtyWatcher {
        watcher: Some(watcher),
        debouncer: Some(debouncer),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::mpsc;
    use std::time::Duration;

    /// FSEvents arms asynchronously and never replays pre-arm events
    /// (kFSEventStreamEventIdSinceNow); a fixed pre-sleep is the documented
    /// flake footgun (S-stage critique). Instead: keep writing probe files
    /// until the first batch lands.
    fn write_until_first_batch(
        dir: &Path,
        rx: &mpsc::Receiver<DirtyBatch>,
        stem: &str,
    ) -> DirtyBatch {
        let deadline = Instant::now() + Duration::from_secs(15);
        let mut i = 0;
        loop {
            std::fs::write(dir.join(format!("{stem}{i}.txt")), "x\n").unwrap();
            i += 1;
            match rx.recv_timeout(Duration::from_millis(500)) {
                Ok(batch) => return batch,
                Err(mpsc::RecvTimeoutError::Timeout) => {
                    assert!(
                        Instant::now() < deadline,
                        "watcher never delivered a batch within 15s"
                    );
                }
                Err(e) => panic!("debouncer died: {e}"),
            }
        }
    }

    /// R1 UNVERIFIED #7 closure: the notify backend on THIS platform
    /// (macOS -> FSEvents, Linux -> inotify) really delivers a debounced
    /// signal for a real file write.
    #[test]
    fn watch_real_fs_event_arrives() {
        let tmp = tempfile::tempdir().unwrap();
        let (tx, rx) = mpsc::channel();
        let _w = watch_dirty(
            tmp.path(),
            WatchConfig {
                debounce: Duration::from_millis(200),
            },
            move |batch| {
                let _ = tx.send(batch);
            },
        )
        .expect("watcher starts on this platform");
        let batch = write_until_first_batch(tmp.path(), &rx, "dirty");
        assert!(!batch.paths.is_empty());
        assert!(
            batch
                .paths
                .iter()
                .any(|p| p.to_string_lossy().contains("dirty")),
            "the written file should be among the dirty paths: {:?}",
            batch.paths
        );
        assert_eq!(batch.debounce_ms, 200);
    }

    /// A burst of writes inside one window coalesces - the pulse breathes,
    /// it does not flicker.
    #[test]
    fn watch_debounce_coalesces_bursts() {
        let tmp = tempfile::tempdir().unwrap();
        let (tx, rx) = mpsc::channel();
        let _w = watch_dirty(
            tmp.path(),
            WatchConfig {
                debounce: Duration::from_millis(500),
            },
            move |batch| {
                let _ = tx.send(batch);
            },
        )
        .unwrap();
        // Arm first (the arming batch may contain only probe files), then
        // burst within one window.
        let _armed = write_until_first_batch(tmp.path(), &rx, "arm");
        for i in 0..20 {
            std::fs::write(tmp.path().join(format!("burst{i}.txt")), "x\n").unwrap();
        }
        let batch = rx
            .recv_timeout(Duration::from_secs(10))
            .expect("burst produces a signal");
        assert!(
            batch.paths.len() > 1,
            "window should have coalesced multiple paths, got {:?}",
            batch.paths
        );
    }

    /// S-stage critique regression: git bookkeeping is not a user edit -
    /// `.git/**` churn must produce no pulse at all.
    #[test]
    fn watch_git_internal_churn_filtered() {
        let tmp = tempfile::tempdir().unwrap();
        std::fs::create_dir(tmp.path().join(".git")).unwrap();
        let (tx, rx) = mpsc::channel();
        let _w = watch_dirty(
            tmp.path(),
            WatchConfig {
                debounce: Duration::from_millis(200),
            },
            move |batch| {
                let _ = tx.send(batch);
            },
        )
        .unwrap();
        let _armed = write_until_first_batch(tmp.path(), &rx, "arm");

        std::fs::write(tmp.path().join(".git/index"), "bookkeeping\n").unwrap();
        std::fs::write(tmp.path().join(".git/FETCH_HEAD"), "x\n").unwrap();
        match rx.recv_timeout(Duration::from_millis(1500)) {
            Err(mpsc::RecvTimeoutError::Timeout) => {} // correct: no pulse
            Ok(batch) => panic!(".git churn leaked into a dirty batch: {:?}", batch.paths),
            Err(e) => panic!("debouncer died: {e}"),
        }

        // and a real edit right after still pulses (filter, not blackout)
        std::fs::write(tmp.path().join("real.txt"), "edit\n").unwrap();
        let batch = rx
            .recv_timeout(Duration::from_secs(10))
            .expect("real edit still pulses");
        assert!(batch.paths.iter().all(|p| !is_git_internal(p)));
        assert!(batch
            .paths
            .iter()
            .any(|p| p.to_string_lossy().contains("real.txt")));
    }

    #[test]
    fn watch_hint_payload_shape() {
        let batch = DirtyBatch {
            paths: (0..12).map(|i| PathBuf::from(format!("/x/f{i}"))).collect(),
            debounce_ms: DEFAULT_DEBOUNCE_MS,
            dropped_signals: 3,
        };
        let p = batch.to_payload("demo");
        assert_eq!(p["hint_only"], true, "hints never claim git truth");
        assert_eq!(p["debounce_ms"], DEFAULT_DEBOUNCE_MS);
        assert_eq!(p["changed_paths"], 12);
        assert_eq!(p["dropped_signals"], 3, "overflow is visible, not silent");
        assert_eq!(
            p["sample_paths"].as_array().unwrap().len(),
            MAX_SAMPLE_PATHS,
            "payload carries a bounded sample, not the world"
        );
    }

    /// Degradation path: watching a missing root fails loudly at setup -
    /// callers fall back to periodic reconciliation, contract unchanged.
    #[test]
    fn watch_missing_root_fails_closed() {
        let err = watch_dirty(
            Path::new("/nonexistent/turingos/watch/root"),
            WatchConfig::default(),
            |_| {},
        );
        assert!(err.is_err(), "missing root must be a visible setup error");
    }

    /// Wire-level: a real fs write becomes a contract FileChanged envelope
    /// in the hub (hint_only=true), exactly as `serve` publishes it, and
    /// consecutive hints coalesce in the retained log.
    #[test]
    fn watch_hint_published_into_hub_conforms() {
        use crate::events::EventKind;
        let tmp = tempfile::tempdir().unwrap();
        let hub = crate::uds::EventHub::new("demo");
        let watch_hub = hub.clone();
        let _w = watch_dirty(
            tmp.path(),
            WatchConfig {
                debounce: Duration::from_millis(200),
            },
            move |batch| {
                let payload = batch.to_payload(watch_hub.project_id());
                watch_hub.publish_hint(payload);
            },
        )
        .unwrap();
        let deadline = Instant::now() + Duration::from_secs(15);
        let mut i = 0;
        loop {
            std::fs::write(tmp.path().join(format!("pulse{i}.txt")), "x\n").unwrap();
            i += 1;
            let (events, _) = hub.replay_and_subscribe();
            if let Some(ev) = events.iter().find(|e| e.kind == EventKind::FileChanged) {
                assert_eq!(ev.payload["hint_only"], true);
                assert_eq!(ev.payload["debounce_ms"], 200);
                assert!(ev.event_id.starts_with("evt_demo_"));
                // deny_unknown_fields round-trip == contract conformance
                let js = serde_json::to_string(ev).unwrap();
                let back: crate::events::EventEnvelope = serde_json::from_str(&js).unwrap();
                assert_eq!(back.seq, ev.seq);
                break;
            }
            assert!(
                Instant::now() < deadline,
                "FileChanged hint never reached the hub"
            );
            std::thread::sleep(Duration::from_millis(100));
        }
    }

    /// Retained-log coalescing for hints (same unbounded-growth hardening
    /// the idle reconciliation markers got): live stream keeps every pulse,
    /// replay keeps only the latest consecutive one.
    #[test]
    fn watch_hint_log_coalesces() {
        use crate::events::EventKind;
        let hub = crate::uds::EventHub::new("demo");
        let (_, mut rx) = hub.replay_and_subscribe();
        for i in 0..3 {
            hub.publish_hint(serde_json::json!({
                "project_id": "demo", "hint_only": true,
                "debounce_ms": 800u64, "changed_paths": 1u64,
                "sample_paths": [format!("f{i}")], "dropped_signals": 0u64,
            }));
        }
        let mut live = 0;
        while let Ok(ev) = rx.try_recv() {
            if ev.kind == EventKind::FileChanged {
                live += 1;
            }
        }
        assert_eq!(live, 3, "live subscribers see every pulse");
        let (events, _) = hub.replay_and_subscribe();
        let hints: Vec<_> = events
            .iter()
            .filter(|e| e.kind == EventKind::FileChanged)
            .collect();
        assert_eq!(hints.len(), 1, "replay keeps only the latest hint");
        assert_eq!(hints[0].payload["sample_paths"][0], "f2");
        assert_eq!(hub.projection(), hub.refold(), "conservation survives");
    }
}

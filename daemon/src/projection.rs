//! A1_03: resident aggregate projection - the menu-bar Glance three counts.
//!
//! UX reverse-shaping law (PLAN.md registry): the counts must be ALWAYS
//! trustworthy, so they are maintained incrementally on every event, never
//! recomputed on demand. ADR-003 keeps this honest: the projection is
//! derived, disposable state and a conservation test pins
//! `incremental apply == fold(all events)` - if they ever diverge, the
//! incremental path is lying and gate goes red.

use std::collections::BTreeMap;

use crate::events::{EventEnvelope, EventKind};

pub const PROJECTION_SCHEMA_VERSION: &str = "tos.app.projection.v0";

/// Glance counts + per-worktree anomaly ledger.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct AggregateProjection {
    /// AgentSessionStarted minus AgentSessionEnded (saturating).
    pub active_sessions: u64,
    /// ProposalSubmitted minus (Accepted + Rejected) (saturating).
    pub pending_proposals: u64,
    /// worktree_id -> latest anomaly verdict (prunable / same-branch
    /// conflict / fingerprint error). WorktreeRemoved retires the entry.
    anomalies: BTreeMap<String, bool>,
    /// Highest seq folded in so far (contract `as_of_seq`).
    pub as_of_seq: u64,
}

fn payload_flag(ev: &EventEnvelope, key: &str) -> bool {
    ev.payload
        .get(key)
        .and_then(|v| v.as_bool())
        .unwrap_or(false)
}

impl AggregateProjection {
    /// Incremental fold step. Total over EventKind: kinds without aggregate
    /// semantics still advance `as_of_seq`, so conservation covers them.
    pub fn apply(&mut self, ev: &EventEnvelope) {
        match ev.kind {
            EventKind::AgentSessionStarted => self.active_sessions += 1,
            EventKind::AgentSessionEnded => {
                self.active_sessions = self.active_sessions.saturating_sub(1)
            }
            EventKind::ProposalSubmitted => self.pending_proposals += 1,
            EventKind::ProposalAccepted | EventKind::ProposalRejected => {
                self.pending_proposals = self.pending_proposals.saturating_sub(1)
            }
            EventKind::WorktreeDiscovered => {
                if let Some(id) = ev.payload.get("worktree_id").and_then(|v| v.as_str()) {
                    let anomalous = payload_flag(ev, "prunable")
                        || payload_flag(ev, "same_branch_conflict")
                        || ev.payload.get("fingerprint_error").is_some();
                    self.anomalies.insert(id.to_string(), anomalous);
                }
            }
            EventKind::WorktreeRemoved => {
                if let Some(id) = ev.payload.get("worktree_id").and_then(|v| v.as_str()) {
                    self.anomalies.remove(id);
                }
            }
            _ => {}
        }
        self.as_of_seq = self.as_of_seq.max(ev.seq);
    }

    /// Full recompute - the conservation reference (`view ==
    /// derive_from_tape(tape)`).
    pub fn fold<'a>(events: impl IntoIterator<Item = &'a EventEnvelope>) -> Self {
        let mut p = AggregateProjection::default();
        for ev in events {
            p.apply(ev);
        }
        p
    }

    pub fn anomalous_worktrees(&self) -> u64 {
        self.anomalies.values().filter(|v| **v).count() as u64
    }

    /// Contract-shaped JSON (contracts/projection.schema.json): the three
    /// ownership fields are mandatory - a projection without an owner and a
    /// rebuild path is not allowed to exist (ADR-003). derive_source is the
    /// CALLER's truth (S-stage critique: a hardcoded value was a lie waiting
    /// to happen) and the rebuild_command is derived from it so the pair
    /// can never disagree.
    pub fn to_contract_json(&self, derive_source: DeriveSource) -> serde_json::Value {
        serde_json::json!({
            "projection_id": "prj_glance_counts",
            "schema_version": PROJECTION_SCHEMA_VERSION,
            "derive_source": derive_source.as_str(),
            "rebuild_command": derive_source.rebuild_command(),
            "as_of_seq": self.as_of_seq,
            "state": {
                "active_sessions": self.active_sessions,
                "pending_proposals": self.pending_proposals,
                "anomalous_worktrees": self.anomalous_worktrees(),
            }
        })
    }
}

/// contracts/projection.schema.json derive_source enum, with the honest
/// rebuild path for each source. The live daemon hub is `Git` while every
/// retained event originates from git reconciliation (P1); when P5 wires
/// hook/appserver sources through the upstream tape it must switch to
/// `Chaintape` - the enum forces that decision to be explicit per call site.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DeriveSource {
    Chaintape,
    Git,
    FixtureEventStream,
}

impl DeriveSource {
    pub fn as_str(self) -> &'static str {
        match self {
            DeriveSource::Chaintape => "chaintape",
            DeriveSource::Git => "git",
            DeriveSource::FixtureEventStream => "fixture_event_stream",
        }
    }

    /// An executable, truthful rebuild path per source - no flags that do
    /// not exist, no claims of durability the daemon does not have.
    pub fn rebuild_command(self) -> &'static str {
        match self {
            DeriveSource::Chaintape => "replay the upstream ChainTape (P5+ wiring)",
            DeriveSource::Git => {
                "restart `turingosd serve <repo-path> <socket-path>` - reconciliation re-derives all state from git"
            }
            DeriveSource::FixtureEventStream => {
                "AggregateProjection::fold over fixtures/event_streams/*.jsonl"
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::events::{EventSource, TrustState};
    use std::fs;
    use std::path::PathBuf;

    fn ev(seq: u64, kind: EventKind, payload: serde_json::Value) -> EventEnvelope {
        EventEnvelope::new(
            "t",
            seq,
            "2026-06-10T00:00:00Z",
            kind,
            EventSource::Daemon,
            TrustState::ObservedUnsigned,
            payload,
        )
    }

    #[test]
    fn projection_counts_sessions_and_proposals() {
        let events = vec![
            ev(0, EventKind::AgentSessionStarted, serde_json::json!({})),
            ev(1, EventKind::AgentSessionStarted, serde_json::json!({})),
            ev(2, EventKind::ProposalSubmitted, serde_json::json!({})),
            ev(3, EventKind::AgentSessionEnded, serde_json::json!({})),
            ev(4, EventKind::ProposalRejected, serde_json::json!({})),
        ];
        let p = AggregateProjection::fold(&events);
        assert_eq!(p.active_sessions, 1);
        assert_eq!(
            p.pending_proposals, 0,
            "rejection drains pending (拒绝也是状态)"
        );
        assert_eq!(p.as_of_seq, 4);
    }

    #[test]
    fn projection_anomaly_ledger_tracks_latest_verdict() {
        let events = vec![
            ev(
                0,
                EventKind::WorktreeDiscovered,
                serde_json::json!({"worktree_id":"wt_a_1","same_branch_conflict":true}),
            ),
            ev(
                1,
                EventKind::WorktreeDiscovered,
                serde_json::json!({"worktree_id":"wt_b_2","prunable":false,"same_branch_conflict":false}),
            ),
            // latest verdict wins: wt_a_1 conflict resolved
            ev(
                2,
                EventKind::WorktreeDiscovered,
                serde_json::json!({"worktree_id":"wt_a_1","same_branch_conflict":false}),
            ),
            ev(
                3,
                EventKind::WorktreeDiscovered,
                serde_json::json!({"worktree_id":"wt_c_3","fingerprint_error":"index locked"}),
            ),
        ];
        let p = AggregateProjection::fold(&events);
        assert_eq!(p.anomalous_worktrees(), 1, "only wt_c_3 still anomalous");
        let mut p2 = p.clone();
        p2.apply(&ev(
            4,
            EventKind::WorktreeRemoved,
            serde_json::json!({"worktree_id":"wt_c_3"}),
        ));
        assert_eq!(p2.anomalous_worktrees(), 0, "removal retires the entry");
    }

    /// Conservation over synthetic stream: incremental == fold-from-scratch
    /// at every prefix (not just the end - mid-stream divergence must fail).
    #[test]
    fn projection_conservation_incremental_equals_fold() {
        let kinds = [
            EventKind::AgentSessionStarted,
            EventKind::ProposalSubmitted,
            EventKind::WorktreeDiscovered,
            EventKind::AgentSessionEnded,
            EventKind::ProposalAccepted,
            EventKind::WorktreeRemoved,
            EventKind::AgentSessionStarted,
            EventKind::DiffSnapshot,
        ];
        let events: Vec<EventEnvelope> = kinds
            .iter()
            .enumerate()
            .map(|(i, k)| {
                ev(
                    i as u64,
                    *k,
                    serde_json::json!({"worktree_id": format!("wt_x_{}", i % 2), "prunable": i % 3 == 0}),
                )
            })
            .collect();
        let mut incremental = AggregateProjection::default();
        for (i, e) in events.iter().enumerate() {
            incremental.apply(e);
            assert_eq!(
                incremental,
                AggregateProjection::fold(&events[..=i]),
                "conservation broke at prefix {i}"
            );
        }
    }

    /// Conservation over every committed fixture stream (real repo law data).
    #[test]
    fn projection_conservation_over_fixtures() {
        let dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../fixtures/event_streams");
        let mut checked = 0;
        for entry in fs::read_dir(dir).expect("fixtures dir") {
            let path = entry.expect("entry").path();
            if path.extension().is_none_or(|x| x != "jsonl") {
                continue;
            }
            let body = fs::read_to_string(&path).expect("read fixture");
            let events: Vec<EventEnvelope> = body
                .lines()
                .filter(|l| !l.trim().is_empty())
                .map(|l| serde_json::from_str(l).expect("envelope"))
                .collect();
            let mut incremental = AggregateProjection::default();
            for e in &events {
                incremental.apply(e);
            }
            assert_eq!(
                incremental,
                AggregateProjection::fold(&events),
                "{}",
                path.display()
            );
            checked += 1;
        }
        assert!(checked >= 4, "expected the committed fixture streams");
    }

    #[test]
    fn projection_contract_json_shape() {
        let p = AggregateProjection::fold(&[ev(
            7,
            EventKind::AgentSessionStarted,
            serde_json::json!({}),
        )]);
        let js = p.to_contract_json(DeriveSource::Git);
        assert!(js["projection_id"].as_str().unwrap().starts_with("prj_"));
        assert_eq!(js["schema_version"], PROJECTION_SCHEMA_VERSION);
        assert_eq!(js["derive_source"], "git");
        let rebuild = js["rebuild_command"].as_str().unwrap();
        assert!(
            rebuild.contains("turingosd serve <repo-path> <socket-path>"),
            "rebuild_command must name a real invocation, not a fictional flag"
        );
        assert!(!rebuild.contains("--replay"), "no flags that do not exist");
        assert_eq!(js["as_of_seq"], 7);
        assert_eq!(js["state"]["active_sessions"], 1);

        let js2 = p.to_contract_json(DeriveSource::FixtureEventStream);
        assert_eq!(js2["derive_source"], "fixture_event_stream");
        assert!(js2["rebuild_command"]
            .as_str()
            .unwrap()
            .contains("fixtures/event_streams"));
    }

    /// External gold standard (S-stage critique: incremental==fold is the
    /// same apply() twice and can never fail). Here the expected counts are
    /// tallied straight off the raw fixture JSON with hand-written logic
    /// that shares zero code with AggregateProjection::apply.
    #[test]
    fn projection_fixture_counts_match_independent_tally() {
        let dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../fixtures/event_streams");
        let mut checked = 0;
        for entry in fs::read_dir(dir).expect("fixtures dir") {
            let path = entry.expect("entry").path();
            if path.extension().is_none_or(|x| x != "jsonl") {
                continue;
            }
            let body = fs::read_to_string(&path).expect("read fixture");
            let raw: Vec<serde_json::Value> = body
                .lines()
                .filter(|l| !l.trim().is_empty())
                .map(|l| serde_json::from_str(l).expect("json line"))
                .collect();
            // Independent reference: raw string matching, explicit running
            // tallies, no EventEnvelope/EventKind types involved.
            let (mut sessions, mut proposals) = (0i64, 0i64);
            for v in &raw {
                match v["kind"].as_str().unwrap() {
                    "AgentSessionStarted" => sessions += 1,
                    "AgentSessionEnded" => sessions = (sessions - 1).max(0),
                    "ProposalSubmitted" => proposals += 1,
                    "ProposalAccepted" | "ProposalRejected" => proposals = (proposals - 1).max(0),
                    _ => {}
                }
            }
            let events: Vec<EventEnvelope> = body
                .lines()
                .filter(|l| !l.trim().is_empty())
                .map(|l| serde_json::from_str(l).expect("envelope"))
                .collect();
            let p = AggregateProjection::fold(&events);
            assert_eq!(
                p.active_sessions,
                sessions as u64,
                "{}: active_sessions vs independent tally",
                path.display()
            );
            assert_eq!(
                p.pending_proposals,
                proposals as u64,
                "{}: pending_proposals vs independent tally",
                path.display()
            );
            checked += 1;
        }
        assert!(checked >= 4, "expected the committed fixture streams");
    }
}

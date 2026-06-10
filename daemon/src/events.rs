//! Event envelope mirroring contracts/event_stream.schema.json (tos.app.event.v0).
//! The JSON schema is the law; this struct is its Rust projection. Contract
//! conformance is enforced by tests that replay every committed fixture.

use serde::{Deserialize, Serialize};

pub const EVENT_SCHEMA_VERSION: &str = "tos.app.event.v0";

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EventEnvelope {
    pub event_id: String,
    pub seq: u64,
    pub ts: String,
    pub schema_version: String,
    pub kind: EventKind,
    pub source: EventSource,
    pub trust_state: TrustState,
    pub payload: serde_json::Value,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum EventKind {
    ProjectRegistered,
    WorktreeDiscovered,
    WorktreeRemoved,
    FileChanged,
    DiffSnapshot,
    ProposalCandidate,
    ProposalSubmitted,
    ProposalRejected,
    ProposalAccepted,
    PredicateResult,
    VetoVerdict,
    AgentManifestRegistered,
    AgentSessionStarted,
    AgentSessionEnded,
    SignatureVerified,
    SignatureRejected,
    RatificationProposed,
    RatificationCeremonyOpened,
    RatificationSigned,
    RatificationTagCreated,
    MarketTxObserved,
    ReconciliationCompleted,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EventSource {
    Git,
    Fsevents,
    ClaudeHook,
    CodexAppserver,
    Human,
    Daemon,
    Fixture,
}

/// ActorTrustState - the single trust vocabulary (docs/TRUST_STATES.md).
/// Machine source of truth is contracts/event_stream.schema.json; changes
/// must touch both and pass shipgate.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TrustState {
    ObservedUnsigned,
    ManifestMissing,
    ManifestRegistered,
    SignatureValid,
    SignatureInvalid,
    SignerUnregistered,
    SignerRevoked,
    CapabilityMissing,
    HumanAdopted,
    HumanRootSigned,
    LegacyPreRule,
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::path::PathBuf;

    fn fixtures_dir() -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../fixtures/event_streams")
    }

    /// Repo law replayed in Rust: every committed fixture line must
    /// deserialize into the envelope with strictly increasing seq and the
    /// pinned schema_version. If this fails, either the contract drifted or
    /// this projection did - both are gate-red conditions.
    #[test]
    fn fixtures_conform_to_envelope() {
        let mut files: Vec<_> = fs::read_dir(fixtures_dir())
            .expect("fixtures dir")
            .map(|e| e.expect("entry").path())
            .filter(|p| p.extension().is_some_and(|x| x == "jsonl"))
            .collect();
        files.sort();
        assert!(!files.is_empty(), "no fixtures found - repo law missing");
        for file in files {
            let body = fs::read_to_string(&file).expect("read fixture");
            let mut prev_seq: Option<u64> = None;
            for (n, line) in body.lines().enumerate() {
                if line.trim().is_empty() {
                    continue;
                }
                let ev: EventEnvelope = serde_json::from_str(line)
                    .unwrap_or_else(|e| panic!("{}:{} bad envelope: {e}", file.display(), n + 1));
                assert_eq!(
                    ev.schema_version,
                    EVENT_SCHEMA_VERSION,
                    "{}",
                    file.display()
                );
                if let Some(p) = prev_seq {
                    assert!(
                        ev.seq > p,
                        "{}: seq not strictly increasing",
                        file.display()
                    );
                }
                prev_seq = Some(ev.seq);
            }
        }
    }

    #[test]
    fn trust_state_round_trips_snake_case() {
        let js = "\"human_root_signed\"";
        let t: TrustState = serde_json::from_str(js).unwrap();
        assert_eq!(t, TrustState::HumanRootSigned);
        assert_eq!(serde_json::to_string(&t).unwrap(), js);
    }
}

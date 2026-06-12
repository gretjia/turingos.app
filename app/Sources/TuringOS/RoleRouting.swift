// RoleRouting.swift — A1_22: Role-to-provider routing table (§5.6).
//
// Constitutional anchor: WHITEPAPER.md §5.6 "role-as-routing: judgment clarity
// determines model routing — this is not a cost preference but a consequence of
// verification asymmetry."
//
// BOUNDARY: PURE DATA — no network, no Keychain, no tape, no gating logic.
// This table is CONFIGURATION, not POLICY. It expresses preferred provider kinds
// per role; ModelGateway selects the first available provider from the list.
// Zero gating or release decisions live here — those belong to the Predicate Gate.
//
// Terminology (§13.7):
//   openai_compatible  — OpenAI Chat Completions format (OpenAI / xAI / Gemini beta /
//                        compatible hosters); worker/veto fast throughput.
//   anthropic_messages — Anthropic Messages API; meta/architect — strongest, never downgraded.
//   apple_fm_local     — Apple Foundation Models local session (P1.9 lane); facilitator /
//                        gardener — privacy-preserving, on-device, low-latency.
//
// Role routing table (§5.6 judgment-clarity tiers):
//
//   facilitator  → [appleFMLocal, openaiCompatible]
//     Thin, fast, rule-first. On-device FM preferred; fall back to compatible API.
//
//   meta         → [anthropicMessages, openaiCompatible]
//     Strongest model, NEVER downgraded. Anthropic native preferred (I8-conscious
//     Anthropic system-prompt + multi-turn context best served by Messages API).
//
//   worker       → [openaiCompatible, anthropicMessages]
//     Batch, throughput-oriented. OpenAI-compatible fastest for parallelism;
//     Anthropic fallback when higher output quality needed.
//
//   veto         → [openaiCompatible, anthropicMessages]
//     Rule engine first; LLM only for ambiguous cases. Fast turnaround over
//     raw output quality.
//
//   architect    → [anthropicMessages, openaiCompatible]
//     Open-ended design, expert domain, non-reversible consequence work.
//     Matches meta routing (never downgraded for architect-class decisions).
//
//   gardener     → [appleFMLocal, anthropicMessages]
//     Skill library curation — privacy-preserving local preferred;
//     Anthropic for complex restructuring.

import Foundation

// MARK: - ProviderKind

/// Provider kind enum for role routing. Matches MetaAIProviderKind plus local extension.
///
/// NOTE: MetaAIProviderKind uses "native" for Apple FM; RoleRouting uses "appleFMLocal"
/// as the domain-specific name. The mapping from appleFMLocal → .native is in ModelGateway.
public enum ProviderKind: String, Codable, CaseIterable, Sendable, Equatable {
    case appleFMLocal     = "apple_fm_local"
    case openaiCompatible = "openai_compatible"
    case anthropicMessages = "anthropic_messages"
}

// MARK: - RoleRouting

/// Pure lookup table mapping ModelRole → ordered list of preferred ProviderKind.
///
/// "Ordered" means preferred first; callers should attempt providers left-to-right
/// and fall back when a provider is unavailable (no credential or offline).
///
/// This table is CONFIGURATION, not POLICY:
///   - It expresses runtime preference, not a gating decision.
///   - Adding a new role requires updating the table and the exhaustive switch below.
///   - Changing the order is a configuration change, not a constitutional change.
///   - CaseIterable on ModelRole + the exhaustive switch ensures all roles are covered.
public enum RoleRouting {

    /// Returns the ordered preferred provider list for the given role.
    /// All ModelRole cases must be covered (enforced by exhaustive switch;
    /// compile error if a new case is added without updating this table).
    public static func preferredProviders(for role: ModelRole) -> [ProviderKind] {
        switch role {
        case .facilitator:
            // §5.6: judgment-clarity A — rule-first, thin, on-device preferred.
            return [.appleFMLocal, .openaiCompatible]
        case .meta:
            // §5.6: judgment-clarity C — strongest model, never downgraded.
            return [.anthropicMessages, .openaiCompatible]
        case .worker:
            // §5.6: judgment-clarity B — throughput, parallel execution.
            return [.openaiCompatible, .anthropicMessages]
        case .veto:
            // §5.6: deterministic rule engine first; LLM for ambiguous cases only.
            return [.openaiCompatible, .anthropicMessages]
        case .architect:
            // §5.6: judgment-clarity C — open-ended expert domain, non-reversible.
            return [.anthropicMessages, .openaiCompatible]
        case .gardener:
            // §5.6: skill library curation — privacy-preserving local, expert fallback.
            return [.appleFMLocal, .anthropicMessages]
        }
    }

    /// Returns the full routing table as a dictionary (role → provider list).
    /// Useful for inspection, audit, and test assertions.
    public static var fullTable: [ModelRole: [ProviderKind]] {
        Dictionary(uniqueKeysWithValues: ModelRole.allCases.map { role in
            (role, preferredProviders(for: role))
        })
    }
}

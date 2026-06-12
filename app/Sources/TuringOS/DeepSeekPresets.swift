// DeepSeekPresets.swift — A1_31: DeepSeek model presets for facilitator/meta roles.
//
// Constitutional anchors:
//   - docs/01_KERNEL_CONTRACTS.md I9 — the API key NEVER appears in code,
//     tape, logs, or projections. Only the credential SCOPE descriptor lives
//     here; the key value sits in the Keychain (KeychainStore, service =
//     credentialScope, account = "api_key") and flows only into the
//     transport Authorization header.
//   - WHITEPAPER.md §5.6 — role-as-routing; user ruling 2026-06-12:
//     Facilitator AI = deepseek-v4-flash (thinking disabled),
//     Meta AI = deepseek-v4-pro (thinking enabled), same API key.
//
// PURE DATA — no network, no Keychain access, no tape. CONFIGURATION, not
// POLICY: zero gating decisions live here.
//
// verified_external_facts (verified_on 2026-06-12, atom card A1_31):
//   - Models deepseek-v4-flash / deepseek-v4-pro — probe-verified with a real
//     key (FLASH_OK no reasoning / PRO_OK has reasoning_content).
//   - Thinking parameter wire shape: {"thinking":{"type":"enabled"|"disabled"}}.
//   - OpenAI-compatible base https://api.deepseek.com (POST /chat/completions).
//   - deepseek-chat / deepseek-reasoner are DEPRECATED effective 2026-07-24 —
//     do not reintroduce them.
//   Source: https://api-docs.deepseek.com/zh-cn/ + /guides/thinking_mode
//   (WebFetch) + live double probe.

import Foundation

// MARK: - DeepSeekPresets

/// Role → DeepSeek model preset lookup (A1_31 user ruling, 2026-06-12).
///
/// Only facilitator and meta have DeepSeek presets; every other role returns
/// nil — NO CLAIM is made for roles the ruling did not cover.
public enum DeepSeekPresets {

    /// Keychain credential scope for the (single, shared) DeepSeek API key.
    /// Usage: KeychainStore.load(service: credentialScope, account: "api_key").
    /// I9: the key VALUE never appears in code — scope descriptor only.
    public static let credentialScope = "deepseek-api"

    /// OpenAI-compatible chat completions endpoint (verified 2026-06-12).
    public static let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!

    /// Returns the DeepSeek preset for `role`, or nil when the role has no
    /// DeepSeek ruling (worker/veto/architect/gardener — no claim).
    public static func config(for role: ModelRole) -> (model: String, thinking: ThinkingMode, endpoint: URL)? {
        switch role {
        case .facilitator:
            // User ruling 2026-06-12: thin/fast lane, thinking off.
            return ("deepseek-v4-flash", .disabled, endpoint)
        case .meta:
            // User ruling 2026-06-12: strongest lane, thinking on.
            return ("deepseek-v4-pro", .enabled, endpoint)
        case .worker, .veto, .architect, .gardener:
            // No ruling for these roles — no claim.
            return nil
        }
    }
}

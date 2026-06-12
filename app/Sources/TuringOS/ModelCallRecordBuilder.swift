// ModelCallRecordBuilder.swift — A1_22: Build ModelCallRecord from call data.
//
// Constitutional anchor: docs/01_KERNEL_CONTRACTS.md I8 + I9.
// I8: every ModelCall must enter tape; privacy_mode=redacted → replay_degraded=true.
// I9: credentials never in tape payload; only credential_scope_hash may appear.
//
// This builder covers ALL 14 required keys in contracts/model_call.schema.json:
//   schema_version, call_id, provider, model, role, privacy_mode,
//   input_record, output_record, latency_ms, cost, token_usage, policy,
//   project_id, replay_degraded.
//
// Content hash format: "sha256:<hex>" (pattern ^sha256:[0-9a-f]{8,64}$).
// CryptoKit is used for sha256; the prefix is prepended per schema pattern.
//
// privacy_mode logic:
//   .full     → input/output_record { mode:"full", content:<text>, content_hash:<sha256> }
//               replay_degraded = false
//   .redacted → input/output_record { mode:"hash", content_hash:<sha256> }  (NO "content" key)
//               replay_degraded = true

import Foundation
import CryptoKit

// MARK: - ContentRecord

/// Wire-safe input or output record for a ModelCall tape entry.
///
/// Encodes as `{ "mode": "...", "content_hash": "sha256:..." }` (hash mode)
/// or `{ "content": "...", "content_hash": "sha256:...", "mode": "full" }` (full mode).
/// The "content" key MUST be absent for hash mode (I8: redacted never pretends to replay).
public struct ContentRecord: Encodable, Sendable, Equatable {
    public let mode: String          // "full" or "hash"
    public let contentHash: String   // "sha256:<hex>"
    public let content: String?      // present only for mode=="full"

    public init(mode: String, contentHash: String, content: String?) {
        self.mode        = mode
        self.contentHash = contentHash
        self.content     = content
    }

    enum CodingKeys: String, CodingKey {
        case mode
        case contentHash = "content_hash"
        case content
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(contentHash, forKey: .contentHash)
        // CRITICAL: "content" key is only emitted when present (mode=="full").
        // For hash mode the key must be absent — not null, absent.
        if let c = content {
            try container.encode(c, forKey: .content)
        }
    }
}

// MARK: - ModelCallRecord

/// Tape record for a single model call.
/// JSON encoding must cover all 14 required keys from model_call.schema.json.
public struct ModelCallRecord: Encodable, Sendable, Equatable {
    // Required keys (14 total):
    public let schemaVersion: String        // const "tos.app.model_call.v0"
    public let callId: String
    public let provider: String
    public let model: String
    public let role: ModelRole
    public let privacyMode: PrivacyMode
    public let inputRecord: ContentRecord
    public let outputRecord: ContentRecord
    public let latencyMs: Int
    public let cost: CostRecord
    public let tokenUsage: TokenUsageRecord
    public let policy: PolicyRecord
    public let projectId: String
    public let replayDegraded: Bool

    // Optional:
    public let workOrderId: String?

    enum CodingKeys: String, CodingKey {
        case schemaVersion  = "schema_version"
        case callId         = "call_id"
        case provider
        case model
        case role
        case privacyMode    = "privacy_mode"
        case inputRecord    = "input_record"
        case outputRecord   = "output_record"
        case latencyMs      = "latency_ms"
        case cost
        case tokenUsage     = "token_usage"
        case policy
        case projectId      = "project_id"
        case replayDegraded = "replay_degraded"
        case workOrderId    = "work_order_id"
    }
}

// MARK: - Supporting record types

/// Cost breakdown for budget accounting (model_call.schema.json "cost": object).
public struct CostRecord: Encodable, Sendable, Equatable {
    public let inputTokensUsd: Double
    public let outputTokensUsd: Double
    public let totalUsd: Double

    public init(inputTokensUsd: Double, outputTokensUsd: Double, totalUsd: Double) {
        self.inputTokensUsd  = inputTokensUsd
        self.outputTokensUsd = outputTokensUsd
        self.totalUsd        = totalUsd
    }

    enum CodingKeys: String, CodingKey {
        case inputTokensUsd  = "input_tokens_usd"
        case outputTokensUsd = "output_tokens_usd"
        case totalUsd        = "total_usd"
    }
}

/// Token counts (model_call.schema.json "token_usage": object).
public struct TokenUsageRecord: Encodable, Sendable, Equatable {
    public let input: Int
    public let output: Int
    public let total: Int

    public init(input: Int, output: Int) {
        self.input  = input
        self.output = output
        self.total  = input + output
    }
}

/// Policy snapshot at call time (model_call.schema.json "policy": object).
public struct PolicyRecord: Encodable, Sendable, Equatable {
    public let maxTokens: Int?
    public let temperature: Double?

    public init(maxTokens: Int?, temperature: Double?) {
        self.maxTokens   = maxTokens
        self.temperature = temperature
    }

    enum CodingKeys: String, CodingKey {
        case maxTokens   = "max_tokens"
        case temperature
    }
}

// MARK: - ModelCallRecordBuilder

/// Pure builder — no network, no tape, no Keychain.
///
/// Constructs a ModelCallRecord covering all 14 schema required keys.
/// sha256 is computed via CryptoKit; prefix "sha256:" is prepended per schema pattern.
public enum ModelCallRecordBuilder {

    // MARK: - Public build entry point

    /// Build a tape record for one model call.
    ///
    /// - Parameters:
    ///   - callId:       Unique call identifier (e.g. UUID string).
    ///   - provider:     Provider string (e.g. "anthropic", "openai").
    ///   - model:        Model identifier (e.g. "claude-sonnet-4-6").
    ///   - role:         Agent role (facilitator/meta/worker/veto/architect/gardener).
    ///   - privacyMode:  .full or .redacted (I8).
    ///   - input:        The raw input text sent to the model.
    ///   - output:       The raw output text returned by the model.
    ///   - latencyMs:    Round-trip latency in milliseconds.
    ///   - cost:         Total USD cost (nil → 0.0 for all cost fields).
    ///   - tokenUsage:   Input/output token counts.
    ///   - policy:       Request policy (maxTokens, temperature).
    ///   - projectId:    Project identifier.
    ///   - workOrderId:  Optional work order identifier.
    public static func build(
        callId: String,
        provider: String,
        model: String,
        role: ModelRole,
        privacyMode: PrivacyMode,
        input: String,
        output: String,
        latencyMs: Int,
        cost: Double?,
        tokenUsage: TokenUsage,
        policy: GatewayRequest,
        projectId: String,
        workOrderId: String? = nil
    ) -> ModelCallRecord {
        let inputHash  = sha256Prefixed(input)
        let outputHash = sha256Prefixed(output)

        let inputRecord: ContentRecord
        let outputRecord: ContentRecord
        let replayDegraded: Bool

        switch privacyMode {
        case .full:
            inputRecord    = ContentRecord(mode: "full", contentHash: inputHash, content: input)
            outputRecord   = ContentRecord(mode: "full", contentHash: outputHash, content: output)
            replayDegraded = false
        case .redacted:
            // CRITICAL: content key must be absent (I8 redaction honesty).
            inputRecord    = ContentRecord(mode: "hash", contentHash: inputHash, content: nil)
            outputRecord   = ContentRecord(mode: "hash", contentHash: outputHash, content: nil)
            replayDegraded = true   // honest acknowledgement — this segment cannot be replayed
        }

        let totalUsd        = cost ?? 0.0
        // Split 40/60 input/output as a reasonable placeholder when provider
        // doesn't return itemized cost. Budget accounting uses totalUsd anyway.
        let inputUsd  = totalUsd * 0.4
        let outputUsd = totalUsd * 0.6

        return ModelCallRecord(
            schemaVersion: "tos.app.model_call.v0",
            callId:        callId,
            provider:      provider,
            model:         model,
            role:          role,
            privacyMode:   privacyMode,
            inputRecord:   inputRecord,
            outputRecord:  outputRecord,
            latencyMs:     latencyMs,
            cost:          CostRecord(
                               inputTokensUsd:  inputUsd,
                               outputTokensUsd: outputUsd,
                               totalUsd:        totalUsd
                           ),
            tokenUsage:    TokenUsageRecord(
                               input:  tokenUsage.inputTokens,
                               output: tokenUsage.outputTokens
                           ),
            policy:        PolicyRecord(
                               maxTokens:   policy.maxTokens,
                               temperature: policy.temperature
                           ),
            projectId:     projectId,
            replayDegraded: replayDegraded,
            workOrderId:   workOrderId
        )
    }

    // MARK: - Internal sha256

    /// Returns "sha256:<lowercased hex>" for the UTF-8 encoding of `text`.
    /// Prefix matches the schema pattern ^sha256:[0-9a-f]{8,64}$.
    static func sha256Prefixed(_ text: String) -> String {
        let data   = Data(text.utf8)
        let digest = SHA256.hash(data: data)
        let hex    = digest.map { String(format: "%02x", $0) }.joined()
        return "sha256:\(hex)"
    }
}

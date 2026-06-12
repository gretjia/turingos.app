// ModelGatewayTypes.swift — A1_22: Model Gateway adapter layer — core types.
//
// Constitutional anchors:
//   - docs/01_KERNEL_CONTRACTS.md I8 — every ModelCall must enter tape
//   - docs/01_KERNEL_CONTRACTS.md I9 — credentials never logged or in prompt
//   - WHITEPAPER.md §13.7 — Model Gateway bottom-whitebox pipe
//   - contracts/model_call.schema.json — 14 required keys
//
// BOUNDARY: pure value types — no network, no Keychain access, no tape I/O.
// All I/O lives in ModelGateway.swift (transport + tape) and
// ModelCallRecordBuilder.swift (record construction).
//
// FAIL-CLOSED invariant: without a TapeSink, live calls are refused with
// GatewayError.tapeUnavailable. "Ceremony unavailable = unavailable."
// This mirrors SpecStatus having no ratified case: the system stays dark
// rather than emitting unrecorded traffic.

import Foundation

// MARK: - ModelRole

/// Agent role enum matching contracts/model_call.schema.json "role" property.
///
/// Maps to WHITEPAPER.md §5.6 judgment-clarity routing table:
///   - facilitator: Facilitator AI — thin, fast, rule-first.
///   - meta:        Meta AI        — strongest model, never downgraded.
///   - worker:      Worker AI      — batch, throughput-oriented.
///   - veto:        Veto-AI        — rule engine + LLM interpreter, {PASS,VETO}.
///   - architect:   ArchitectAI    — open-ended design, expert domain.
///   - gardener:    GardenerAI     — skill library evolution & curation.
public enum ModelRole: String, Codable, CaseIterable, Sendable, Equatable {
    case facilitator = "facilitator"
    case meta        = "meta"
    case worker      = "worker"
    case veto        = "veto"
    case architect   = "architect"
    case gardener    = "gardener"
}

// MARK: - GatewayMessage

/// A single message in a model conversation. Role mirrors OpenAI/Anthropic conventions.
public struct GatewayMessage: Codable, Sendable, Equatable {
    /// Message role — matches both OpenAI ("user"/"assistant"/"system") and
    /// Anthropic ("user"/"assistant") conventions. System messages are
    /// extracted into the top-level system field by AnthropicMessagesCodec.
    public enum Role: String, Codable, Sendable, Equatable {
        case system    = "system"
        case user      = "user"
        case assistant = "assistant"
    }

    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role    = role
        self.content = content
    }
}

// MARK: - ThinkingMode

/// Thinking-mode switch for providers that expose an explicit reasoning toggle
/// (A1_31: DeepSeek `{"thinking":{"type":"enabled"|"disabled"}}` wire shape,
/// verified_on 2026-06-12 against api-docs.deepseek.com + live probe).
///
/// nil on GatewayRequest = field absent from the wire (backward compatible —
/// contracts evolution rule 2: adding an optional field never changes the
/// encoding of existing requests).
public enum ThinkingMode: String, Codable, Sendable {
    case enabled  = "enabled"
    case disabled = "disabled"
}

// MARK: - GatewayRequest

/// A model call request passed to the gateway. Provider-agnostic.
///
/// The gateway's codec layer translates this into the provider wire format.
/// No credentials, no tape references here — those live in the gateway only.
public struct GatewayRequest: Sendable, Equatable {
    /// The agent role initiating this call (routes model selection per §5.6).
    public let role: ModelRole
    /// Conversation messages in chronological order.
    public let messages: [GatewayMessage]
    /// Maximum tokens to generate (provider default if nil).
    public let maxTokens: Int?
    /// Sampling temperature (provider default if nil).
    public let temperature: Double?
    /// Provider thinking-mode toggle (A1_31). nil = absent from the wire —
    /// existing request encodings stay byte-identical.
    public var thinkingMode: ThinkingMode?

    public init(
        role: ModelRole,
        messages: [GatewayMessage],
        maxTokens: Int? = nil,
        temperature: Double? = nil,
        thinkingMode: ThinkingMode? = nil
    ) {
        self.role         = role
        self.messages     = messages
        self.maxTokens    = maxTokens
        self.temperature  = temperature
        self.thinkingMode = thinkingMode
    }
}

// MARK: - TokenUsage

/// Token consumption for a single call.
public struct TokenUsage: Codable, Sendable, Equatable {
    public let inputTokens: Int
    public let outputTokens: Int

    public var total: Int { inputTokens + outputTokens }

    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens  = inputTokens
        self.outputTokens = outputTokens
    }

    enum CodingKeys: String, CodingKey {
        case inputTokens  = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - GatewayResponse

/// A successful response from a model call.
public struct GatewayResponse: Sendable, Equatable {
    /// The generated text content from the model.
    public let content: String
    /// Stop reason returned by the provider (e.g. "stop", "end_turn", "max_tokens").
    public let finishReason: String
    /// Token counts for cost and budget accounting (I8: mandatory even when zero).
    public let usage: TokenUsage
    /// Round-trip latency in milliseconds.
    public let latencyMs: Int
    /// Total USD cost (nil if provider doesn't return pricing).
    public let cost: Double?

    public init(
        content: String,
        finishReason: String,
        usage: TokenUsage,
        latencyMs: Int,
        cost: Double? = nil
    ) {
        self.content      = content
        self.finishReason = finishReason
        self.usage        = usage
        self.latencyMs    = latencyMs
        self.cost         = cost
    }
}

// MARK: - PrivacyMode

/// Input/output redaction mode for tape recording (contracts/model_call.schema.json).
///
/// - full:     Record complete input and output text + sha256 hash.
///             replay_degraded = false.
/// - redacted: Record sha256 hash only — content key absent from tape.
///             replay_degraded = true (honest acknowledgement per I8).
public enum PrivacyMode: String, Codable, Sendable, Equatable {
    case full     = "full"
    case redacted = "redacted"
}

// MARK: - GatewayError

/// Typed errors returned by ModelGateway.send(_:).
///
/// .tapeUnavailable is the fail-closed sentinel: the gateway refuses to emit
/// unrecorded model traffic. Transport is never touched when tape is absent.
public enum GatewayError: Error, Sendable, Equatable {
    /// No TapeSink was provided at gateway init — FAIL-CLOSED (I8).
    case tapeUnavailable
    /// Required credential is missing from the Keychain (I9).
    case credentialUnavailable(scope: String)
    /// The provider returned an error or an unparseable response.
    case providerError(String)
    /// The codec could not encode the request or decode the response.
    case codecError(String)
}

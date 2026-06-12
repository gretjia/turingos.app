// ModelGateway.swift — A1_22: Model Gateway adapter layer — live wire orchestration.
//
// Constitutional anchors:
//   - docs/01_KERNEL_CONTRACTS.md I8 — every ModelCall must enter tape;
//     without tape sink the gateway is FAIL-CLOSED (refuses all calls).
//   - docs/01_KERNEL_CONTRACTS.md I9 — credentials NEVER logged or in prompt;
//     credential value only flows through network layer, never into any
//     observable state (tape, View IR, logs).
//   - WHITEPAPER.md §13.7 — Model Gateway = bottom-whitebox pipe (tool layer);
//     ZERO release/gating decisions live here — those are the Predicate Gate.
//
// FAIL-CLOSED invariant: ModelGateway(tapeSink: nil).send(...) always throws
// .tapeUnavailable WITHOUT touching transport. This is the same "ceremony
// unavailable = unavailable" pattern as SpecStatus having no ratified case.
//
// Record-then-return: the tape record is appended BEFORE the response is
// returned to the caller. An unrecorded response never escapes the gateway.
//
// UPSTREAM_CONTRACT: TapeSink and ModelTransport have no implementation here.
// TapeSink arrives with the P1.9 runtime lane (daemon integration).
// ModelTransport is injected; only MockTransport is used in tests (zero network).

import Foundation

// MARK: - TapeSink protocol

/// Tape sink receiving ModelCallRecord entries.
///
/// UPSTREAM_CONTRACT: The live implementation (ChainTape append) is provided
/// by the P1.9 daemon integration lane and imported at that point.
/// This protocol is the stable contract surface; implementors must guarantee
/// append is durable (written to disk) before returning without error.
///
/// Reference: docs/01_KERNEL_CONTRACTS.md I8, UPSTREAM_CONTRACT.md rule 2.
public protocol TapeSink: Sendable {
    /// Append a model call record to the tape.
    /// Throws if the write fails (disk full, permission denied, etc.).
    func append(_ record: ModelCallRecord) throws
}

// MARK: - ModelTransport protocol

/// Abstracts the HTTP POST used for provider API calls.
///
/// Live implementation uses URLSession. Tests inject MockTransport.
/// Credentials are applied by the implementation (as an Authorization header)
/// and MUST NOT appear in any observable state — only `url`, `headers` (minus
/// secret values), and `body` shape matter for the codec golden tests.
public protocol ModelTransport: Sendable {
    /// Post `body` to `url` with `headers`, return the response body.
    func post(url: URL, headers: [String: String], body: Data) async throws -> Data
}

// MARK: - ModelGateway

/// Bottom-whitebox model call gateway.
///
/// Responsibilities (all, nothing else):
///   1. FAIL-CLOSED on absent tape sink (first guard in send).
///   2. Resolve credential scope via KeychainStore (I9: value used only in transport header).
///   3. Encode request via the appropriate codec.
///   4. Execute transport.post (not called when tape absent).
///   5. Decode response.
///   6. Build ModelCallRecord and append to tape BEFORE returning.
///   7. Return GatewayResponse.
///
/// NOT a responsibility:
///   - Route/gating decisions (Predicate Gate).
///   - Cost approval (Budget Gate).
///   - Role authorization (Capability Registry).
///   - Any UI state update.
public final class ModelGateway: Sendable {

    private let tapeSink: TapeSink?
    private let transport: ModelTransport
    private let keychainStore: KeychainStore
    private let projectId: String

    /// Designated initialiser.
    ///
    /// - Parameters:
    ///   - tapeSink:      The tape sink. If nil, ALL calls throw .tapeUnavailable (I8).
    ///   - transport:     HTTP transport (inject MockTransport in tests; LiveURLSessionTransport in prod).
    ///   - keychainStore: Keychain access for credential resolution (I9).
    ///   - projectId:     Project identifier stamped on every tape record.
    public init(
        tapeSink: TapeSink?,
        transport: ModelTransport,
        keychainStore: KeychainStore = .shared,
        projectId: String = "proj_unknown"
    ) {
        self.tapeSink      = tapeSink
        self.transport     = transport
        self.keychainStore = keychainStore
        self.projectId     = projectId
    }

    // MARK: - Send

    /// Execute a model call.
    ///
    /// FAIL-CLOSED contract: the FIRST statement is the tape guard.
    /// Transport is never invoked if tapeSink is nil.
    ///
    /// - Parameters:
    ///   - request:      Provider-agnostic request.
    ///   - config:       Provider endpoint + credential scope config.
    ///   - model:        Model identifier string.
    ///   - privacyMode:  .full or .redacted (I8).
    ///   - callId:       Unique call ID (caller supplies for idempotency; defaults to UUID).
    ///   - workOrderId:  Optional work-order identifier for cost attribution.
    public func send(
        _ request: GatewayRequest,
        config: MetaAIConfig,
        model: String,
        privacyMode: PrivacyMode = .full,
        callId: String = UUID().uuidString,
        workOrderId: String? = nil
    ) async throws -> GatewayResponse {
        // ── FAIL-CLOSED GUARD (I8) ───────────────────────────────────────────
        // This is the FIRST statement. tapeSink nil = unavailable = refuse.
        guard let sink = tapeSink else {
            throw GatewayError.tapeUnavailable
        }
        // ── Credential resolution (I9) ────────────────────────────────────────
        // The secret value is used ONLY to build the Authorization header
        // inside the transport layer. It is NEVER recorded in tape, logs,
        // or any observable state.
        let credential: String
        do {
            credential = try keychainStore.load(
                service: config.credentialScope,
                account: "api_key"
            )
        } catch {
            throw GatewayError.credentialUnavailable(scope: config.credentialScope)
        }

        // ── Endpoint resolution ───────────────────────────────────────────────
        let endpoint = providerEndpoint(config: config)

        // ── Encode request ────────────────────────────────────────────────────
        let requestBody: Data
        do {
            requestBody = try encodeRequest(request, model: model, config: config)
        } catch let e as GatewayError {
            throw e
        } catch {
            throw GatewayError.codecError("encode: \(error)")
        }

        // ── Network call ──────────────────────────────────────────────────────
        let started = Date()
        let responseData: Data
        do {
            responseData = try await transport.post(
                url: endpoint,
                headers: authHeaders(credential: credential, config: config),
                body: requestBody
            )
        } catch let e as GatewayError {
            throw e
        } catch {
            throw GatewayError.providerError("\(error)")
        }
        let latencyMs = Int(Date().timeIntervalSince(started) * 1000)

        // ── Decode response ───────────────────────────────────────────────────
        let response: GatewayResponse
        do {
            response = try decodeResponse(responseData, latencyMs: latencyMs, config: config)
        } catch let e as GatewayError {
            throw e
        } catch {
            throw GatewayError.codecError("decode: \(error)")
        }

        // ── Build tape record ─────────────────────────────────────────────────
        // The flat input text is the concatenation of all message contents
        // (for hash/redaction purposes; the wire JSON already carries structure).
        let inputText = request.messages.map(\.content).joined(separator: "\n")
        let record = ModelCallRecordBuilder.build(
            callId:       callId,
            provider:     providerString(config: config),
            model:        model,
            role:         request.role,
            privacyMode:  privacyMode,
            input:        inputText,
            output:       response.content,
            latencyMs:    latencyMs,
            cost:         response.cost,
            tokenUsage:   response.usage,
            policy:       request,
            projectId:    projectId,
            workOrderId:  workOrderId
        )

        // ── Append to tape BEFORE returning (I8: record-then-return) ─────────
        do {
            try sink.append(record)
        } catch {
            // Tape write failure → surface as providerError so the caller
            // knows the response should NOT be acted upon (unrecorded traffic).
            throw GatewayError.providerError("tape write failed: \(error)")
        }

        return response
    }

    // MARK: - Internal helpers

    private func providerEndpoint(config: MetaAIConfig) -> URL {
        if let url = config.endpointURL { return url }
        switch config.providerKind {
        case .openaiCompatible:
            return URL(string: "https://api.openai.com/v1/chat/completions")!
        case .anthropicMessages:
            return URL(string: "https://api.anthropic.com/v1/messages")!
        case .native:
            // Apple FM local — no remote endpoint needed (FM session handles this).
            return URL(string: "http://localhost:0/fm/local")!
        }
    }

    private func authHeaders(credential: String, config: MetaAIConfig) -> [String: String] {
        // I9: credential value appears ONLY here, in the in-memory request header.
        switch config.providerKind {
        case .openaiCompatible, .native:
            return ["Authorization": "Bearer \(credential)", "Content-Type": "application/json"]
        case .anthropicMessages:
            return ["x-api-key": credential, "anthropic-version": "2023-06-01",
                    "Content-Type": "application/json"]
        }
    }

    private func encodeRequest(_ request: GatewayRequest, model: String, config: MetaAIConfig) throws -> Data {
        switch config.providerKind {
        case .openaiCompatible, .native:
            return try OpenAIChatCompletionsCodec.encodeRequest(request, model: model)
        case .anthropicMessages:
            return try AnthropicMessagesCodec.encodeRequest(request, model: model)
        }
    }

    private func decodeResponse(_ data: Data, latencyMs: Int, config: MetaAIConfig) throws -> GatewayResponse {
        switch config.providerKind {
        case .openaiCompatible, .native:
            return try OpenAIChatCompletionsCodec.decodeResponse(data, latencyMs: latencyMs)
        case .anthropicMessages:
            return try AnthropicMessagesCodec.decodeResponse(data, latencyMs: latencyMs)
        }
    }

    private func providerString(config: MetaAIConfig) -> String {
        switch config.providerKind {
        case .openaiCompatible:  return "openai_compatible"
        case .anthropicMessages: return "anthropic_messages"
        case .native:            return "apple_fm_local"
        }
    }
}

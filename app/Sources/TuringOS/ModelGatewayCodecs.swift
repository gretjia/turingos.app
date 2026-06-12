// ModelGatewayCodecs.swift — A1_22: Provider wire-format encoders/decoders.
//
// Constitutional anchor: WHITEPAPER.md §13.7 "three API format adapters:
// OpenAI Chat Completions (de facto standard) / Anthropic Messages (native) /
// Apple FM local (placeholder)".
//
// BOUNDARY: pure encode/decode — NO network calls, NO Keychain, NO tape.
// All I/O is Data <-> GatewayRequest / GatewayResponse.
//
// Encoding convention: sortedKeys throughout for reproducible golden fixtures.

import Foundation

// MARK: - OpenAIChatCompletionsCodec

/// Wire codec for the OpenAI Chat Completions API.
///
/// Endpoint: POST /v1/chat/completions
/// Wire shape (request):
///   { "model": "...", "messages": [{"role": "...", "content": "..."}],
///     "max_tokens"?: Int, "temperature"?: Double }
/// Wire shape (response, extracts choices[0]):
///   { "choices": [{ "message": { "content": "..." }, "finish_reason": "..." }],
///     "usage": { "prompt_tokens": Int, "completion_tokens": Int } }
///
/// Both OpenAI and OpenAI-compatible providers (xAI, Gemini beta, hosted models)
/// speak this format (WHITEPAPER.md §13.7, FEASIBILITY Part IV-2).
public enum OpenAIChatCompletionsCodec {

    // MARK: Encode

    /// Encodes a GatewayRequest to the OpenAI Chat Completions wire JSON.
    /// Uses sortedKeys for deterministic golden-fixture comparison.
    public static func encodeRequest(_ request: GatewayRequest, model: String) throws -> Data {
        var body: [String: Any] = [
            "model": model,
            "messages": request.messages.map { msg in
                ["role": msg.role.rawValue, "content": msg.content]
            }
        ]
        if let maxTokens = request.maxTokens {
            body["max_tokens"] = maxTokens
        }
        if let temperature = request.temperature {
            body["temperature"] = temperature
        }
        // sortedKeys requires NSMutableDictionary-compatible input; use JSONSerialization
        // with .sortedKeys option for consistent byte output.
        return try JSONSerialization.data(
            withJSONObject: sortedJSONObject(body),
            options: [.sortedKeys]
        )
    }

    // MARK: Decode

    /// Decodes the OpenAI Chat Completions response JSON into a GatewayResponse.
    /// Reads choices[0].message.content, choices[0].finish_reason,
    /// usage.prompt_tokens, usage.completion_tokens.
    public static func decodeResponse(_ data: Data, latencyMs: Int) throws -> GatewayResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GatewayError.codecError("Response is not a JSON object")
        }
        guard let choices = json["choices"] as? [[String: Any]],
              let first = choices.first else {
            throw GatewayError.codecError("Missing or empty choices array")
        }
        guard let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw GatewayError.codecError("Missing choices[0].message.content")
        }
        let finishReason = first["finish_reason"] as? String ?? "unknown"
        let usage = json["usage"] as? [String: Any]
        let promptTokens     = usage?["prompt_tokens"]     as? Int ?? 0
        let completionTokens = usage?["completion_tokens"] as? Int ?? 0

        return GatewayResponse(
            content:      content,
            finishReason: finishReason,
            usage:        TokenUsage(inputTokens: promptTokens, outputTokens: completionTokens),
            latencyMs:    latencyMs
        )
    }
}

// MARK: - AnthropicMessagesCodec

/// Wire codec for the Anthropic Messages API.
///
/// Endpoint: POST /v1/messages
/// Wire shape (request):
///   { "model": "...", "max_tokens": Int (REQUIRED),
///     "system"?: "...", "messages": [{"role": "user"|"assistant", "content": "..."}] }
/// Wire shape (response, extracts content[0]):
///   { "content": [{ "text": "..." }], "stop_reason": "...",
///     "usage": { "input_tokens": Int, "output_tokens": Int } }
///
/// Notes:
///   - max_tokens is ALWAYS required by this API; defaults to 4096 if absent from GatewayRequest.
///   - System messages are extracted from the messages array and placed in the top-level "system" field.
///   - Only "user" and "assistant" roles appear in the messages array; "system" is filtered out.
public enum AnthropicMessagesCodec {

    /// Default max_tokens when GatewayRequest.maxTokens is nil.
    /// Anthropic requires this field — omitting it is a 400 error.
    static let defaultMaxTokens = 4096

    // MARK: Encode

    /// Encodes a GatewayRequest to the Anthropic Messages API wire JSON.
    /// Uses sortedKeys for deterministic golden-fixture comparison.
    public static func encodeRequest(_ request: GatewayRequest, model: String) throws -> Data {
        // Extract system prompt (Anthropic places this at top level, not in messages).
        let systemContent = request.messages
            .filter { $0.role == .system }
            .map(\.content)
            .joined(separator: "\n")

        // Only user/assistant messages go in the messages array.
        let conversationMessages = request.messages
            .filter { $0.role != .system }
            .map { msg in ["role": msg.role.rawValue, "content": msg.content] }

        var body: [String: Any] = [
            "model":      model,
            "max_tokens": request.maxTokens ?? defaultMaxTokens,
            "messages":   conversationMessages
        ]
        if !systemContent.isEmpty {
            body["system"] = systemContent
        }
        if let temperature = request.temperature {
            body["temperature"] = temperature
        }
        return try JSONSerialization.data(
            withJSONObject: sortedJSONObject(body),
            options: [.sortedKeys]
        )
    }

    // MARK: Decode

    /// Decodes the Anthropic Messages API response JSON into a GatewayResponse.
    /// Reads content[0].text, stop_reason, usage.input_tokens, usage.output_tokens.
    public static func decodeResponse(_ data: Data, latencyMs: Int) throws -> GatewayResponse {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GatewayError.codecError("Response is not a JSON object")
        }
        guard let contentArray = json["content"] as? [[String: Any]],
              let first = contentArray.first,
              let text = first["text"] as? String else {
            throw GatewayError.codecError("Missing or empty content[0].text")
        }
        let stopReason = json["stop_reason"] as? String ?? "unknown"
        let usage = json["usage"] as? [String: Any]
        let inputTokens  = usage?["input_tokens"]  as? Int ?? 0
        let outputTokens = usage?["output_tokens"] as? Int ?? 0

        return GatewayResponse(
            content:      text,
            finishReason: stopReason,
            usage:        TokenUsage(inputTokens: inputTokens, outputTokens: outputTokens),
            latencyMs:    latencyMs
        )
    }
}

// MARK: - AppleFMLocalCodec

/// Placeholder wire codec for Apple Foundation Models local inference.
///
/// Real FM session wiring arrives with the P1.9 runtime lane (live
/// FoundationModels.framework session; structure only here).
/// When the FM session is available this codec will be replaced with the
/// real request/response bridge using Apple's framework session API.
///
/// UPSTREAM_CONTRACT: This placeholder satisfies the adapter slot defined
/// in ModelGateway. Its presence allows RoleRouting.swift to list
/// .appleFMLocal as a preferred provider for facilitator/gardener roles
/// without a live wire dependency.
public enum AppleFMLocalCodec {

    /// Placeholder request container.
    /// Real implementation will wrap FoundationModels.GenerationRequest.
    public struct FMRequest: Sendable {
        public let prompt: String
        public let maxTokens: Int?
        public init(prompt: String, maxTokens: Int? = nil) {
            self.prompt    = prompt
            self.maxTokens = maxTokens
        }
    }

    /// Placeholder response container.
    /// Real implementation will unwrap FoundationModels.GenerationResponse.
    public struct FMResponse: Sendable {
        public let text: String
        public init(text: String) { self.text = text }
    }

    /// Convert GatewayRequest to FMRequest placeholder.
    public static func encodeRequest(_ request: GatewayRequest) -> FMRequest {
        // Flatten messages to a single prompt string for the FM session placeholder.
        let prompt = request.messages
            .map { "\($0.role.rawValue): \($0.content)" }
            .joined(separator: "\n")
        return FMRequest(prompt: prompt, maxTokens: request.maxTokens)
    }

    /// Convert FMResponse placeholder to GatewayResponse.
    public static func decodeResponse(_ response: FMResponse, latencyMs: Int) -> GatewayResponse {
        GatewayResponse(
            content:      response.text,
            finishReason: "end_turn",
            usage:        TokenUsage(inputTokens: 0, outputTokens: 0),
            latencyMs:    latencyMs
        )
    }
}

// MARK: - Helpers

/// Recursively sort dictionary keys for deterministic JSONSerialization output.
///
/// JSONSerialization.Options.sortedKeys sorts top-level keys only in some
/// versions; this helper ensures nested dicts are sorted too, giving
/// byte-identical output for golden fixture comparison.
private func sortedJSONObject(_ value: Any) -> Any {
    if let dict = value as? [String: Any] {
        return Dictionary(
            uniqueKeysWithValues: dict.map { ($0.key, sortedJSONObject($0.value)) }
        ) as [String: Any]
    } else if let array = value as? [Any] {
        return array.map { sortedJSONObject($0) }
    }
    return value
}

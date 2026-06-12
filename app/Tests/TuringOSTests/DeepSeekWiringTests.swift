// DeepSeekWiringTests.swift — A1_31: DeepSeek live wiring tests.
//
// Atom card predicate mapping (specs/atoms/A1_31_deepseek_live_wiring.md):
//
//   P1 "golden：flash+disabled 与 pro+enabled 两种请求体字节断言；
//       thinkingMode=nil → 请求体无 thinking 键"
//     1. testGoldenFlashDisabledThinkingShape
//           — encode (.disabled, "deepseek-v4-flash") → thinking == {"type":"disabled"};
//             encode twice → byte-identical (sortedKeys stability)
//     2. testGoldenProEnabledThinkingShape
//           — encode (.enabled, "deepseek-v4-pro") → thinking == {"type":"enabled"};
//             encode twice → byte-identical
//     3. testBackwardCompatNilThinkingModeOmitsKey
//           — thinkingMode nil → parsed request JSON has NO "thinking" key
//     4. testDecodeToleratesReasoningContent
//           — response with choices[0].message.reasoning_content decodes without
//             throwing; content extraction unchanged (PRO_OK probe shape)
//
//   P2 "FileTapeSink append 产物逐键覆盖 model_call.schema.json 全部 14 required；
//       append-only（二次 append 不重写首行）"
//     5. testFileTapeSinkRecordCoversAllSchemaRequiredKeys
//           — append one record to a temp-dir sink → read line back → every
//             required[] key from the REAL contracts/model_call.schema.json present
//     6. testFileTapeSinkAppendOnly
//           — two appends → exactly 2 lines; first-line bytes captured after
//             append #1 are unchanged after append #2
//
//   P3 "无 TapeSink ⇒ send() 必抛 tapeUnavailable（A1_22 负控不回归）；测试零网络"
//     7. testFailClosedNoTapeThroughDeepSeekPath
//           — ModelGateway(tapeSink: nil) + DeepSeek config + thinkingMode .enabled
//             → throws .tapeUnavailable; MockTransport invocations == 0
//
//   P4 "key 零泄漏负控" + preset shape
//     8. testPresetsRoleMapping
//           — facilitator == (deepseek-v4-flash, .disabled), meta == (deepseek-v4-pro,
//             .enabled), worker/veto/architect/gardener nil
//     9. testCredentialScopeIsDescriptorNotKey
//           — credentialScope == "deepseek-api"; does not contain the secret-key
//             prefix (prefix is constructed at runtime so this file itself stays
//             clean under the key-leak grep)
//    10. testEndpointURL
//           — endpoint == https://api.deepseek.com/chat/completions
//
// BOUNDARY: zero network — LiveURLSessionTransport and URLSession are NEVER
// constructed here (A1_22 zero-network discipline; MockTransport injected).
// NO real API key appears anywhere in this file.

import Foundation
import XCTest
@testable import TuringOS

// MARK: - Test helpers

private extension DeepSeekWiringTests {
    static var repoRoot: URL {
        // app/Tests/TuringOSTests/DeepSeekWiringTests.swift → repo root
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // TuringOSTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // app
            .deletingLastPathComponent() // repo root
    }

    static var schemaURL: URL {
        repoRoot.appendingPathComponent("contracts/model_call.schema.json")
    }

    /// Single-user-message request used across the encoding tests.
    func deepSeekRequest(thinkingMode: ThinkingMode?, role: ModelRole) -> GatewayRequest {
        GatewayRequest(
            role: role,
            messages: [
                GatewayMessage(role: .user, content: "ping")
            ],
            maxTokens: 64,
            temperature: 0.0,
            thinkingMode: thinkingMode
        )
    }

    /// A representative ModelCallRecord built via the production builder
    /// (same pattern as ModelGatewayTests.testModelCallRecordCovers14RequiredKeys).
    func sampleRecord(callId: String) -> ModelCallRecord {
        let request = deepSeekRequest(thinkingMode: .disabled, role: .facilitator)
        return ModelCallRecordBuilder.build(
            callId:      callId,
            provider:    "openai_compatible",
            model:       "deepseek-v4-flash",
            role:        .facilitator,
            privacyMode: .full,
            input:       "ping",
            output:      "pong",
            latencyMs:   42,
            cost:        0.0001,
            tokenUsage:  TokenUsage(inputTokens: 3, outputTokens: 2),
            policy:      request,
            projectId:   "proj_test"
        )
    }

    /// Fresh temp-dir tape file URL (unique per test invocation).
    func tempTapeURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("DeepSeekWiringTests-\(UUID().uuidString)")
            .appendingPathComponent("model_calls.jsonl")
    }
}

// MARK: - Test class

final class DeepSeekWiringTests: XCTestCase {

    // MARK: - Test 1: golden flash + disabled thinking shape

    func testGoldenFlashDisabledThinkingShape() throws {
        let request = deepSeekRequest(thinkingMode: .disabled, role: .facilitator)
        let encoded = try OpenAIChatCompletionsCodec.encodeRequest(request, model: "deepseek-v4-flash")

        let dict = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        XCTAssertEqual(dict["model"] as? String, "deepseek-v4-flash")

        let thinking = dict["thinking"] as? [String: Any]
        XCTAssertNotNil(thinking, "thinkingMode .disabled must emit a 'thinking' object")
        XCTAssertEqual(thinking?["type"] as? String, "disabled",
                       "flash lane wire shape must be {\"thinking\":{\"type\":\"disabled\"}}")
        XCTAssertEqual(thinking?.count, 1,
                       "thinking object must contain exactly the 'type' key")

        // sortedKeys stability: encoding the same request twice must be byte-identical.
        let encodedAgain = try OpenAIChatCompletionsCodec.encodeRequest(request, model: "deepseek-v4-flash")
        XCTAssertEqual(encoded, encodedAgain,
                       "encodeRequest must be deterministic (sortedKeys golden stability)")
    }

    // MARK: - Test 2: golden pro + enabled thinking shape

    func testGoldenProEnabledThinkingShape() throws {
        let request = deepSeekRequest(thinkingMode: .enabled, role: .meta)
        let encoded = try OpenAIChatCompletionsCodec.encodeRequest(request, model: "deepseek-v4-pro")

        let dict = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        XCTAssertEqual(dict["model"] as? String, "deepseek-v4-pro")

        let thinking = dict["thinking"] as? [String: Any]
        XCTAssertNotNil(thinking, "thinkingMode .enabled must emit a 'thinking' object")
        XCTAssertEqual(thinking?["type"] as? String, "enabled",
                       "pro lane wire shape must be {\"thinking\":{\"type\":\"enabled\"}}")
        XCTAssertEqual(thinking?.count, 1,
                       "thinking object must contain exactly the 'type' key")

        // sortedKeys stability.
        let encodedAgain = try OpenAIChatCompletionsCodec.encodeRequest(request, model: "deepseek-v4-pro")
        XCTAssertEqual(encoded, encodedAgain,
                       "encodeRequest must be deterministic (sortedKeys golden stability)")
    }

    // MARK: - Test 3: backward compat — nil thinkingMode omits the key

    func testBackwardCompatNilThinkingModeOmitsKey() throws {
        let request = deepSeekRequest(thinkingMode: nil, role: .worker)
        let encoded = try OpenAIChatCompletionsCodec.encodeRequest(request, model: "gpt-4o")

        let dict = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        XCTAssertNil(dict["thinking"],
                     "thinkingMode nil must leave the 'thinking' key ABSENT from the wire " +
                     "(contracts evolution rule 2: pre-A1_31 encodings stay byte-identical)")
    }

    // MARK: - Test 4: decode tolerates reasoning_content (PRO_OK probe shape)

    func testDecodeToleratesReasoningContent() throws {
        // Inline fixture mirroring the 2026-06-12 deepseek-v4-pro probe shape:
        // thinking output arrives in message.reasoning_content alongside content.
        let responseJSON = """
        {
          "choices": [{
            "message": {
              "role": "assistant",
              "content": "x",
              "reasoning_content": "thought..."
            },
            "finish_reason": "stop"
          }],
          "usage": {"prompt_tokens": 7, "completion_tokens": 3}
        }
        """.data(using: .utf8)!

        // Must NOT throw — reasoning_content is tolerated (ignored).
        let response = try OpenAIChatCompletionsCodec.decodeResponse(responseJSON, latencyMs: 250)

        XCTAssertEqual(response.content, "x",
                       "content extraction must be unchanged by reasoning_content presence")
        XCTAssertEqual(response.finishReason, "stop")
        XCTAssertEqual(response.usage.inputTokens, 7)
        XCTAssertEqual(response.usage.outputTokens, 3)
        XCTAssertEqual(response.latencyMs, 250)
    }

    // MARK: - Test 5: FileTapeSink record covers all schema required keys

    func testFileTapeSinkRecordCoversAllSchemaRequiredKeys() throws {
        // Load the REAL contracts schema at runtime (same pattern as
        // ModelGatewayTests.testModelCallRecordCovers14RequiredKeys).
        let schemaData = try Data(contentsOf: Self.schemaURL)
        let schemaJSON = try JSONSerialization.jsonObject(with: schemaData) as! [String: Any]
        let schemaRequired = schemaJSON["required"] as! [String]
        XCTAssertEqual(schemaRequired.count, 14,
                       "contracts/model_call.schema.json must have exactly 14 required keys")

        // Append one record through the production sink into a temp dir.
        let tapeURL = tempTapeURL()
        defer { try? FileManager.default.removeItem(at: tapeURL.deletingLastPathComponent()) }
        let sink = FileTapeSink(fileURL: tapeURL)
        try sink.append(sampleRecord(callId: "deepseek_tape_001"))

        // Read the JSONL line back and parse it.
        let contents = try String(contentsOf: tapeURL, encoding: .utf8)
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 1, "one append must produce exactly one JSONL line")

        let lineData = Data(lines[0].utf8)
        let dict = try JSONSerialization.jsonObject(with: lineData) as! [String: Any]

        // EVERY schema required key must be present in the on-disk record.
        for key in schemaRequired {
            XCTAssertNotNil(dict[key],
                            "FileTapeSink line must contain schema required key '\(key)'")
        }

        // Spot-check identity fields survived the round trip.
        XCTAssertEqual(dict["schema_version"] as? String, "tos.app.model_call.v0")
        XCTAssertEqual(dict["call_id"] as? String, "deepseek_tape_001")
        XCTAssertEqual(dict["model"] as? String, "deepseek-v4-flash")
        XCTAssertEqual(dict["role"] as? String, "facilitator")
    }

    // MARK: - Test 6: FileTapeSink append-only (first line immutable)

    func testFileTapeSinkAppendOnly() throws {
        let tapeURL = tempTapeURL()
        defer { try? FileManager.default.removeItem(at: tapeURL.deletingLastPathComponent()) }
        let sink = FileTapeSink(fileURL: tapeURL)

        // Append #1 — capture the exact bytes of the file (== first line).
        try sink.append(sampleRecord(callId: "append_only_first"))
        let firstLineBytes = try Data(contentsOf: tapeURL)

        // Append #2 — file must grow; earlier bytes must be untouched.
        try sink.append(sampleRecord(callId: "append_only_second"))
        let afterSecond = try Data(contentsOf: tapeURL)

        let contents = String(data: afterSecond, encoding: .utf8)!
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines.count, 2, "two appends must produce exactly 2 JSONL lines")

        XCTAssertEqual(afterSecond.prefix(firstLineBytes.count), firstLineBytes,
                       "APPEND-ONLY: append #2 must not rewrite the first line's bytes")

        // The two lines carry the two distinct call ids in append order.
        let first  = try JSONSerialization.jsonObject(with: Data(lines[0].utf8)) as! [String: Any]
        let second = try JSONSerialization.jsonObject(with: Data(lines[1].utf8)) as! [String: Any]
        XCTAssertEqual(first["call_id"]  as? String, "append_only_first")
        XCTAssertEqual(second["call_id"] as? String, "append_only_second")
    }

    // MARK: - Test 7: I8 fail-closed regression through the DeepSeek path

    func testFailClosedNoTapeThroughDeepSeekPath() async throws {
        let transport = MockTransport()
        let gateway = ModelGateway(
            tapeSink: nil,  // FAIL-CLOSED (I8)
            transport: transport,
            keychainStore: KeychainStore(),
            projectId: "proj_test"
        )

        guard let preset = DeepSeekPresets.config(for: .facilitator) else {
            XCTFail("facilitator must have a DeepSeek preset")
            return
        }
        let config = MetaAIConfig(
            providerKind: .openaiCompatible,
            endpointURL: preset.endpoint,
            credentialScope: DeepSeekPresets.credentialScope,
            displayName: "DeepSeek Test"
        )

        var request = deepSeekRequest(thinkingMode: nil, role: .facilitator)
        request.thinkingMode = preset.thinking == .disabled ? .disabled : .enabled

        do {
            _ = try await gateway.send(request, config: config, model: preset.model)
            XCTFail("Expected .tapeUnavailable to be thrown (A1_22 I8 negative control)")
        } catch GatewayError.tapeUnavailable {
            // Expected — fail-closed holds through the new DeepSeek wiring.
        } catch {
            XCTFail("Expected GatewayError.tapeUnavailable, got \(error)")
        }

        // Zero network: transport must NEVER be touched when tape is absent.
        XCTAssertEqual(transport.invocationCount, 0,
                       "transport.post must NOT be called when tapeSink is nil (fail-closed)")
    }

    // MARK: - Test 8: preset role mapping (user ruling 2026-06-12)

    func testPresetsRoleMapping() {
        // Facilitator → flash, thinking disabled.
        let facilitator = DeepSeekPresets.config(for: .facilitator)
        XCTAssertNotNil(facilitator, "facilitator must have a DeepSeek preset")
        XCTAssertEqual(facilitator?.model, "deepseek-v4-flash")
        XCTAssertEqual(facilitator?.thinking, .disabled)
        XCTAssertEqual(facilitator?.endpoint, DeepSeekPresets.endpoint)

        // Meta → pro, thinking enabled.
        let meta = DeepSeekPresets.config(for: .meta)
        XCTAssertNotNil(meta, "meta must have a DeepSeek preset")
        XCTAssertEqual(meta?.model, "deepseek-v4-pro")
        XCTAssertEqual(meta?.thinking, .enabled)
        XCTAssertEqual(meta?.endpoint, DeepSeekPresets.endpoint)

        // Roles without a ruling → nil (no claim).
        XCTAssertNil(DeepSeekPresets.config(for: .worker),    "worker has no DeepSeek ruling")
        XCTAssertNil(DeepSeekPresets.config(for: .veto),      "veto has no DeepSeek ruling")
        XCTAssertNil(DeepSeekPresets.config(for: .architect), "architect has no DeepSeek ruling")
        XCTAssertNil(DeepSeekPresets.config(for: .gardener),  "gardener has no DeepSeek ruling")
    }

    // MARK: - Test 9: credential scope is a descriptor, never a key (I9)

    func testCredentialScopeIsDescriptorNotKey() {
        XCTAssertEqual(DeepSeekPresets.credentialScope, "deepseek-api")

        // I9 negative control: the scope must not look like a secret key value.
        // The prefix is assembled at runtime so this source file itself stays
        // clean under the repo-wide key-leak grep.
        let secretKeyPrefix = "sk" + "-"
        XCTAssertFalse(DeepSeekPresets.credentialScope.contains(secretKeyPrefix),
                       "credentialScope is a Keychain descriptor — never a key value (I9)")
    }

    // MARK: - Test 10: endpoint URL (verified 2026-06-12)

    func testEndpointURL() {
        XCTAssertEqual(DeepSeekPresets.endpoint.absoluteString,
                       "https://api.deepseek.com/chat/completions",
                       "OpenAI-compatible chat completions endpoint (verified_on 2026-06-12)")
        XCTAssertEqual(DeepSeekPresets.endpoint.scheme, "https")
        XCTAssertEqual(DeepSeekPresets.endpoint.host, "api.deepseek.com")
    }
}

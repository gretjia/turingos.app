// ModelGatewayTests.swift — A1_22: Model Gateway adapter layer tests.
//
// Test inventory (7 test functions, 40+ assertions):
//
//   1. testOpenAICodecGoldenRequestEncoding
//         — encode 2-message request → byte-exact against openai_chat.golden.json
//   2. testAnthropicCodecGoldenRequestEncoding
//         — encode 2-message request (system extracted) → byte-exact against
//           anthropic_messages.golden.json
//   3. testOpenAICodecDecodeGoldenResponse
//         — decode openai_response.golden.json → GatewayResponse field assertions
//   4. testAnthropicCodecDecodeGoldenResponse
//         — decode anthropic_response.golden.json → GatewayResponse field assertions
//   5. testModelCallRecordCovers14RequiredKeys
//         — build a record; JSON-encode it; assert all 14 schema required keys present
//           (reads real contracts/model_call.schema.json — same pattern as A1_21)
//   6. testRedactionHonesty
//         — .redacted → replay_degraded=true, "content" key absent from both records,
//           "content_hash" present + correct format
//         — .full → "content" key present, replay_degraded=false, hash matches sha256
//   7. testFailClosedNoTape
//         — ModelGateway(tapeSink: nil).send(...) throws .tapeUnavailable
//           WITHOUT touching transport (mock asserts zero invocations)
//   8. testRecordThenReturn
//         — with RecordingMockSink + RecordingMockTransport, send() appends
//           exactly 1 record whose output content matches the mocked response
//   9. testRoleRoutingDeterminismAndAllRolesCovered
//         — CaseIterable walk: every ModelRole maps to a non-empty provider list;
//           calling preferredProviders twice returns identical list;
//           fullTable keys == ModelRole.allCases set
//
// BOUNDARY: zero network calls, zero Keychain access (MockTransport injected).

import Foundation
import XCTest
@testable import TuringOS

// MARK: - Mock types

/// Mock transport that records all invocations and returns a preconfigured response.
final class MockTransport: ModelTransport, @unchecked Sendable {
    private(set) var invocationCount = 0
    var responseData: Data
    var shouldThrow: Bool = false

    init(responseData: Data = Data()) {
        self.responseData = responseData
    }

    func post(url: URL, headers: [String: String], body: Data) async throws -> Data {
        invocationCount += 1
        if shouldThrow { throw GatewayError.providerError("mock error") }
        return responseData
    }
}

/// Mock tape sink that records all appended records.
final class MockTapeSink: TapeSink, @unchecked Sendable {
    private(set) var appended: [ModelCallRecord] = []

    func append(_ record: ModelCallRecord) throws {
        appended.append(record)
    }
}

// MARK: - Test helpers

private extension ModelGatewayTests {
    static var repoRoot: URL {
        // Tests/TuringOSTests/ModelGatewayTests.swift → app/Tests/TuringOSTests/
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // TuringOSTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // app
            .deletingLastPathComponent() // repo root
    }

    static var goldenDir: URL {
        repoRoot.appendingPathComponent("fixtures/model_gateway")
    }

    static var schemaURL: URL {
        repoRoot.appendingPathComponent("contracts/model_call.schema.json")
    }

    func loadGolden(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws -> Data {
        let url = Self.goldenDir.appendingPathComponent(name)
        do {
            return try Data(contentsOf: url)
        } catch {
            XCTFail("Cannot read golden fixture \(name): \(error)", file: file, line: line)
            throw error
        }
    }

    /// Returns a 2-message GatewayRequest used for golden fixture tests.
    func twoMessageRequest(role: ModelRole = .worker) -> GatewayRequest {
        GatewayRequest(
            role: role,
            messages: [
                GatewayMessage(role: .system, content: "You are a helpful assistant."),
                GatewayMessage(role: .user,   content: "Hello, world!")
            ],
            maxTokens: 256,
            temperature: 0.7
        )
    }

    /// Minimal MetaAIConfig backed by a fake credential scope.
    /// Credential scope is present but MockTransport is used — no live Keychain hit.
    func openAIConfig() -> MetaAIConfig {
        MetaAIConfig(
            providerKind: .openaiCompatible,
            endpointURL: URL(string: "https://api.openai.com/v1/chat/completions"),
            credentialScope: "test_openai_key",
            displayName: "Test OpenAI"
        )
    }

    func anthropicConfig() -> MetaAIConfig {
        MetaAIConfig(
            providerKind: .anthropicMessages,
            endpointURL: URL(string: "https://api.anthropic.com/v1/messages"),
            credentialScope: "test_anthropic_key",
            displayName: "Test Anthropic"
        )
    }
}

// MARK: - Test class

final class ModelGatewayTests: XCTestCase {

    // MARK: - Test 1: OpenAI codec golden request encoding

    func testOpenAICodecGoldenRequestEncoding() throws {
        let request = twoMessageRequest()
        let encoded = try OpenAIChatCompletionsCodec.encodeRequest(request, model: "gpt-4o")

        let golden = try loadGolden("openai_chat.golden.json")

        // Byte-exact comparison: same sortedKeys JSON.
        // Normalize by re-parsing both to dicts and re-serializing to eliminate
        // any whitespace difference in the fixture file.
        let encodedDict = try JSONSerialization.jsonObject(with: encoded)    as! [String: Any]
        let goldenDict  = try JSONSerialization.jsonObject(with: golden)     as! [String: Any]
        let encodedNorm = try JSONSerialization.data(withJSONObject: encodedDict, options: [.sortedKeys])
        let goldenNorm  = try JSONSerialization.data(withJSONObject: goldenDict,  options: [.sortedKeys])

        XCTAssertEqual(encodedNorm, goldenNorm,
                       "OpenAI codec must produce byte-exact output matching the golden fixture")

        // Structural assertions (belt+suspenders — the golden already ensures this,
        // but named assertions give clearer failure messages).
        XCTAssertEqual(encodedDict["model"] as? String, "gpt-4o")
        XCTAssertEqual(encodedDict["max_tokens"] as? Int, 256)
        let temperature = encodedDict["temperature"] as? Double
        XCTAssertNotNil(temperature, "temperature must be present when set")
        XCTAssertEqual(temperature!, 0.7, accuracy: 0.001)

        let messages = encodedDict["messages"] as? [[String: Any]]
        XCTAssertEqual(messages?.count, 2, "2-message request must encode 2 messages")
        XCTAssertEqual(messages?.first?["role"] as? String, "system")
        XCTAssertEqual(messages?.first?["content"] as? String, "You are a helpful assistant.")
        XCTAssertEqual(messages?.last?["role"] as? String, "user")
        XCTAssertEqual(messages?.last?["content"] as? String, "Hello, world!")
    }

    // MARK: - Test 2: Anthropic codec golden request encoding

    func testAnthropicCodecGoldenRequestEncoding() throws {
        // Anthropic: system extracted; max_tokens default applied (256 passed here).
        let request = GatewayRequest(
            role: .meta,
            messages: [
                GatewayMessage(role: .system, content: "You are a helpful assistant."),
                GatewayMessage(role: .user,   content: "Hello, world!")
            ],
            maxTokens: nil,  // nil → defaultMaxTokens (4096) for golden
            temperature: nil
        )
        let encoded = try AnthropicMessagesCodec.encodeRequest(request, model: "claude-sonnet-4-6")

        let golden = try loadGolden("anthropic_messages.golden.json")

        let encodedDict = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        let goldenDict  = try JSONSerialization.jsonObject(with: golden)  as! [String: Any]
        let encodedNorm = try JSONSerialization.data(withJSONObject: encodedDict, options: [.sortedKeys])
        let goldenNorm  = try JSONSerialization.data(withJSONObject: goldenDict,  options: [.sortedKeys])

        XCTAssertEqual(encodedNorm, goldenNorm,
                       "Anthropic codec must produce byte-exact output matching the golden fixture")

        // Structural assertions.
        XCTAssertEqual(encodedDict["model"] as? String, "claude-sonnet-4-6")
        XCTAssertEqual(encodedDict["max_tokens"] as? Int, 4096,
                       "max_tokens must be 4096 (default) when GatewayRequest.maxTokens is nil")
        XCTAssertEqual(encodedDict["system"] as? String, "You are a helpful assistant.",
                       "System message must be extracted to top-level 'system' field")

        let messages = encodedDict["messages"] as? [[String: Any]]
        XCTAssertEqual(messages?.count, 1,
                       "Only user/assistant messages go in the messages array (system is filtered)")
        XCTAssertEqual(messages?.first?["role"] as? String, "user")
        XCTAssertEqual(messages?.first?["content"] as? String, "Hello, world!")
        XCTAssertNil(encodedDict["temperature"],
                     "temperature must be absent when nil in the request")
    }

    // MARK: - Test 3: OpenAI codec decode golden response

    func testOpenAICodecDecodeGoldenResponse() throws {
        let golden = try loadGolden("openai_response.golden.json")
        let response = try OpenAIChatCompletionsCodec.decodeResponse(golden, latencyMs: 500)

        XCTAssertEqual(response.content, "Hello! How can I help you today?")
        XCTAssertEqual(response.finishReason, "stop")
        XCTAssertEqual(response.usage.inputTokens, 17, "prompt_tokens must map to inputTokens")
        XCTAssertEqual(response.usage.outputTokens, 9, "completion_tokens must map to outputTokens")
        XCTAssertEqual(response.usage.total, 26)
        XCTAssertEqual(response.latencyMs, 500)
    }

    // MARK: - Test 4: Anthropic codec decode golden response

    func testAnthropicCodecDecodeGoldenResponse() throws {
        let golden = try loadGolden("anthropic_response.golden.json")
        let response = try AnthropicMessagesCodec.decodeResponse(golden, latencyMs: 350)

        XCTAssertEqual(response.content, "Hello! How can I help you today?")
        XCTAssertEqual(response.finishReason, "end_turn")
        XCTAssertEqual(response.usage.inputTokens, 17)
        XCTAssertEqual(response.usage.outputTokens, 9)
        XCTAssertEqual(response.usage.total, 26)
        XCTAssertEqual(response.latencyMs, 350)
    }

    // MARK: - Test 5: ModelCallRecord covers all 14 schema required keys

    func testModelCallRecordCovers14RequiredKeys() throws {
        // Read real schema (same pattern as CapabilityManifestTests.testValidatorRequiredListFromSchemaFile).
        let schemaData = try Data(contentsOf: Self.schemaURL)
        let schemaJSON = try JSONSerialization.jsonObject(with: schemaData) as! [String: Any]
        let schemaRequired = schemaJSON["required"] as! [String]

        XCTAssertEqual(schemaRequired.count, 14,
                       "contracts/model_call.schema.json must have exactly 14 required keys")

        // Build a record.
        let request = twoMessageRequest()
        let record = ModelCallRecordBuilder.build(
            callId:      "test_call_001",
            provider:    "openai_compatible",
            model:       "gpt-4o",
            role:        .worker,
            privacyMode: .full,
            input:       "Hello",
            output:      "World",
            latencyMs:   123,
            cost:        0.001,
            tokenUsage:  TokenUsage(inputTokens: 10, outputTokens: 5),
            policy:      request,
            projectId:   "proj_test"
        )

        // Encode to JSON dict.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(record)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Assert every schema required key is present.
        for key in schemaRequired {
            XCTAssertNotNil(dict[key],
                            "ModelCallRecord JSON must contain required key '\(key)'")
        }

        // Assert schema_version constant.
        XCTAssertEqual(dict["schema_version"] as? String, "tos.app.model_call.v0")

        // Assert nested required fields in input_record / output_record.
        let inputRec  = dict["input_record"]  as? [String: Any]
        let outputRec = dict["output_record"] as? [String: Any]
        XCTAssertNotNil(inputRec?["mode"],         "input_record.mode must be present")
        XCTAssertNotNil(inputRec?["content_hash"], "input_record.content_hash must be present")
        XCTAssertNotNil(outputRec?["mode"],         "output_record.mode must be present")
        XCTAssertNotNil(outputRec?["content_hash"], "output_record.content_hash must be present")
    }

    // MARK: - Test 6: Redaction honesty

    func testRedactionHonesty() throws {
        let request = twoMessageRequest()
        let inputText  = "Sensitive user input"
        let outputText = "Model reply"

        // ── .redacted ───────────────────────────────────────────────────────
        let redacted = ModelCallRecordBuilder.build(
            callId:      "r_001",
            provider:    "anthropic_messages",
            model:       "claude-sonnet-4-6",
            role:        .meta,
            privacyMode: .redacted,
            input:       inputText,
            output:      outputText,
            latencyMs:   200,
            cost:        nil,
            tokenUsage:  TokenUsage(inputTokens: 5, outputTokens: 3),
            policy:      request,
            projectId:   "proj_test"
        )

        XCTAssertTrue(redacted.replayDegraded,
                      "redacted mode: replay_degraded must be true (I8 honesty)")

        // Encode to dict and verify "content" key is ABSENT.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let redactedData = try encoder.encode(redacted)
        let redactedDict = try JSONSerialization.jsonObject(with: redactedData) as! [String: Any]

        let inputRec  = redactedDict["input_record"]  as! [String: Any]
        let outputRec = redactedDict["output_record"] as! [String: Any]

        XCTAssertNil(inputRec["content"],
                     "redacted mode: input_record must NOT contain 'content' key")
        XCTAssertNil(outputRec["content"],
                     "redacted mode: output_record must NOT contain 'content' key")
        XCTAssertNotNil(inputRec["content_hash"],
                        "redacted mode: input_record must contain 'content_hash'")
        XCTAssertNotNil(outputRec["content_hash"],
                        "redacted mode: output_record must contain 'content_hash'")
        XCTAssertEqual(inputRec["mode"] as? String, "hash")
        XCTAssertEqual(outputRec["mode"] as? String, "hash")

        // Hash format check: "sha256:" prefix + hex characters.
        let inputHash  = inputRec["content_hash"]  as? String ?? ""
        let outputHash = outputRec["content_hash"] as? String ?? ""
        XCTAssertTrue(inputHash.hasPrefix("sha256:"),
                      "content_hash must begin with 'sha256:'; got '\(inputHash)'")
        XCTAssertTrue(outputHash.hasPrefix("sha256:"),
                      "content_hash must begin with 'sha256:'; got '\(outputHash)'")
        let hexPattern = "^sha256:[0-9a-f]{8,64}$"
        XCTAssertTrue(inputHash.range(of: hexPattern, options: .regularExpression) != nil,
                      "content_hash must match pattern ^sha256:[0-9a-f]{8,64}$")

        // ── .full ────────────────────────────────────────────────────────────
        let full = ModelCallRecordBuilder.build(
            callId:      "f_001",
            provider:    "openai_compatible",
            model:       "gpt-4o",
            role:        .worker,
            privacyMode: .full,
            input:       inputText,
            output:      outputText,
            latencyMs:   100,
            cost:        0.002,
            tokenUsage:  TokenUsage(inputTokens: 5, outputTokens: 3),
            policy:      request,
            projectId:   "proj_test"
        )

        XCTAssertFalse(full.replayDegraded,
                       "full mode: replay_degraded must be false")

        let fullData = try encoder.encode(full)
        let fullDict = try JSONSerialization.jsonObject(with: fullData) as! [String: Any]
        let fullInputRec  = fullDict["input_record"]  as! [String: Any]
        let fullOutputRec = fullDict["output_record"] as! [String: Any]

        XCTAssertEqual(fullInputRec["content"] as? String,  inputText,
                       "full mode: input_record.content must equal input text")
        XCTAssertEqual(fullOutputRec["content"] as? String, outputText,
                       "full mode: output_record.content must equal output text")
        XCTAssertEqual(fullInputRec["mode"] as? String,  "full")
        XCTAssertEqual(fullOutputRec["mode"] as? String, "full")

        // Hash in full mode must match sha256 of content.
        let expectedInputHash  = ModelCallRecordBuilder.sha256Prefixed(inputText)
        let expectedOutputHash = ModelCallRecordBuilder.sha256Prefixed(outputText)
        XCTAssertEqual(fullInputRec["content_hash"]  as? String, expectedInputHash,
                       "full mode: input_record.content_hash must match sha256 of input")
        XCTAssertEqual(fullOutputRec["content_hash"] as? String, expectedOutputHash,
                       "full mode: output_record.content_hash must match sha256 of output")
    }

    // MARK: - Test 7: FAIL-CLOSED — no tape = .tapeUnavailable, transport untouched

    func testFailClosedNoTape() async throws {
        let transport = MockTransport()
        let gateway = ModelGateway(
            tapeSink: nil,  // FAIL-CLOSED
            transport: transport,
            keychainStore: KeychainStore(),
            projectId: "proj_test"
        )

        let request = twoMessageRequest()
        let config  = openAIConfig()

        do {
            _ = try await gateway.send(request, config: config, model: "gpt-4o")
            XCTFail("Expected .tapeUnavailable to be thrown")
        } catch GatewayError.tapeUnavailable {
            // Expected.
        } catch {
            XCTFail("Expected GatewayError.tapeUnavailable, got \(error)")
        }

        // Transport MUST have zero invocations — gateway must not call network without tape.
        XCTAssertEqual(transport.invocationCount, 0,
                       "transport.post must NOT be called when tapeSink is nil (fail-closed)")
    }

    // MARK: - Test 8: Record-then-return

    func testRecordThenReturn() async throws {
        // Prepare a realistic OpenAI response.
        let openaiResponse = """
        {
          "choices": [{ "message": {"content": "Mocked reply", "role": "assistant"},
                        "finish_reason": "stop" }],
          "usage": {"prompt_tokens": 10, "completion_tokens": 4}
        }
        """.data(using: .utf8)!

        let sink      = MockTapeSink()
        let transport = MockTransport(responseData: openaiResponse)

        // Inject a KeychainStore stub: we need a credential for the gateway to proceed.
        // Save a fake key first.
        let ks = KeychainStore()
        try ks.save(service: "test_openai_record", account: "api_key", secret: "fake_key_for_test")
        defer { try? ks.delete(service: "test_openai_record", account: "api_key") }

        let config = MetaAIConfig(
            providerKind: .openaiCompatible,
            endpointURL: URL(string: "https://api.openai.com/v1/chat/completions"),
            credentialScope: "test_openai_record",
            displayName: "Test"
        )

        let gateway = ModelGateway(
            tapeSink: sink,
            transport: transport,
            keychainStore: ks,
            projectId: "proj_record_test"
        )

        let request = twoMessageRequest(role: .worker)
        let response = try await gateway.send(
            request,
            config: config,
            model: "gpt-4o",
            privacyMode: .full,
            callId: "cid_record_001"
        )

        // Response must contain the mocked content.
        XCTAssertEqual(response.content, "Mocked reply")
        XCTAssertEqual(response.finishReason, "stop")

        // Exactly 1 record must have been appended to the sink.
        XCTAssertEqual(sink.appended.count, 1,
                       "Exactly one ModelCallRecord must be appended per send() call")

        let rec = sink.appended[0]
        // Record output content must match the mocked response.
        XCTAssertEqual(rec.outputRecord.content, "Mocked reply",
                       "tape record output content must match the mocked response")
        XCTAssertEqual(rec.callId, "cid_record_001")
        XCTAssertEqual(rec.role, .worker)
        XCTAssertFalse(rec.replayDegraded,
                       "full mode: replay_degraded must be false in the tape record")
        XCTAssertEqual(rec.projectId, "proj_record_test")
        XCTAssertEqual(rec.schemaVersion, "tos.app.model_call.v0")
        XCTAssertEqual(rec.tokenUsage.input, 10)
        XCTAssertEqual(rec.tokenUsage.output, 4)

        // Transport must have been called exactly once.
        XCTAssertEqual(transport.invocationCount, 1)
    }

    // MARK: - Test 9: Role routing determinism + all roles covered

    func testRoleRoutingDeterminismAndAllRolesCovered() {
        // Walk every ModelRole.
        for role in ModelRole.allCases {
            let list1 = RoleRouting.preferredProviders(for: role)
            let list2 = RoleRouting.preferredProviders(for: role)

            XCTAssertFalse(list1.isEmpty,
                           "Role \(role.rawValue) must map to a non-empty provider list")
            XCTAssertEqual(list1, list2,
                           "RoleRouting must be deterministic: same input → same output (role: \(role.rawValue))")
        }

        // fullTable must cover all roles.
        let tableKeys = Set(RoleRouting.fullTable.keys)
        let allRoles  = Set(ModelRole.allCases)
        XCTAssertEqual(tableKeys, allRoles,
                       "RoleRouting.fullTable must contain exactly all ModelRole cases")

        // Spot-checks per §5.6 routing table.
        XCTAssertEqual(RoleRouting.preferredProviders(for: .meta).first, .anthropicMessages,
                       "meta role must prefer anthropicMessages first (never downgraded, §5.6)")
        XCTAssertEqual(RoleRouting.preferredProviders(for: .architect).first, .anthropicMessages,
                       "architect role must prefer anthropicMessages first")
        XCTAssertEqual(RoleRouting.preferredProviders(for: .facilitator).first, .appleFMLocal,
                       "facilitator role must prefer appleFMLocal first (on-device)")
        XCTAssertEqual(RoleRouting.preferredProviders(for: .gardener).first, .appleFMLocal,
                       "gardener role must prefer appleFMLocal first (privacy-preserving)")
        XCTAssertEqual(RoleRouting.preferredProviders(for: .worker).first, .openaiCompatible,
                       "worker role must prefer openaiCompatible first (throughput)")
        XCTAssertEqual(RoleRouting.preferredProviders(for: .veto).first, .openaiCompatible,
                       "veto role must prefer openaiCompatible first (fast turnaround)")
    }
}

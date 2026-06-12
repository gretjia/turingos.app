// FacilitatorDialogueTests.swift — A1_34: live Facilitator dialogue tests.
//
// Atom card predicate mapping (specs/atoms/A1_34_facilitator_live_dialogue.md):
//
//   P1 "确定性路由命中 → 零 gateway 调用"
//     1. testDeterministicRouteHitZeroGatewayInvocations
//           — "meta 设置" / "早" / "立项 x" through the view-model with a live
//             dialogue injected → transport invocation count == 0, no task.
//
//   P2 "未命中 + 可用 → golden 请求 + summary_card + model_call derive_source"
//     2. testUnknownInputSendsGoldenDeepSeekRequest
//           — unknown input → transport received DeepSeekPresets.endpoint,
//             body model deepseek-v4-flash, thinking {"type":"disabled"},
//             messages[1].content == user text (DeepSeekWiringTests golden style);
//             projection replaced with the facilitator_reply document.
//     3. testSuccessReplyDocShape
//           — respond() success → kind facilitator_reply, body == mocked
//             content, deriveSource contains the model_call entry.
//
//   P3 "未命中 + gateway 抛错 → escape hatch + 确定性错误行"
//     4. testGatewayErrorFallbackDoc
//           — provider error AND no-key paths → kind facilitator_unavailable,
//             body is one of the FIXED reason strings (no secrets, no scope,
//             no upstream error text), intent_suggestions block present.
//     7. testFailureDocDeterminismByteEqual
//           — same failure twice → byte-identical sortedKeys encodings.
//
//   P4 "测试零网络；模型文本结构上仅进 summary_card body"
//     5. testReasoningContentToleratedContentOnly
//           — mock JSON with reasoning_content → content extracted only.
//     6. testRedLineOnlyInertBlockTypes
//           — success (markup-bearing content) + failure docs contain NO block
//             type other than summary_card / intent_suggestions.
//     8. testTapeRecordAppendedToInMemorySink
//           — success → exactly 1 record in the in-memory sink (model/role/
//             project stamped); FileTapeSink is NEVER constructed in tests.
//
// BOUNDARY: zero network — the live transport type is NEVER constructed here
// (A1_22 discipline; CapturingTransport injected). No real API key appears
// anywhere in this file.

import Foundation
import XCTest
@testable import TuringOS

// MARK: - Capturing transport

/// Mock transport recording url + body per invocation (headers deliberately
/// NOT recorded — the Authorization value never lands in test state, I9).
final class FacilitatorCapturingTransport: ModelTransport, @unchecked Sendable {
    struct Capture {
        let url: URL
        let body: Data
    }

    private(set) var captures: [Capture] = []
    var invocationCount: Int { captures.count }
    var responseData: Data
    var errorToThrow: GatewayError?

    init(responseData: Data = Data(), errorToThrow: GatewayError? = nil) {
        self.responseData = responseData
        self.errorToThrow = errorToThrow
    }

    func post(url: URL, headers: [String: String], body: Data) async throws -> Data {
        captures.append(Capture(url: url, body: body))
        if let errorToThrow { throw errorToThrow }
        return responseData
    }
}

// MARK: - Test helpers

private extension FacilitatorDialogueTests {

    static let mockedReply = "已收到。建议先查看项目列表。"

    /// The four FIXED fallback reason strings (golden copy — must stay in
    /// sync with FacilitatorDialogue.fallbackReason by breaking loudly here).
    static let fixedReasons: Set<String> = [
        "磁带记录不可用（无记录不通话）",
        "未配置 API Key（请输入「meta 设置」保存密钥）",
        "模型服务暂时不可达",
        "模型响应解析失败",
    ]

    func successResponseJSON(content: String = FacilitatorDialogueTests.mockedReply) -> Data {
        let payload: [String: Any] = [
            "choices": [[
                "message": ["role": "assistant", "content": content],
                "finish_reason": "stop"
            ]],
            "usage": ["prompt_tokens": 20, "completion_tokens": 12]
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    /// Build a dialogue on a Mock gateway: in-memory sink + capturing
    /// transport + a unique fake-key Keychain scope (cleaned up on teardown).
    /// `saveKey: false` leaves the scope empty → credentialUnavailable path.
    func makeDialogue(
        transport: FacilitatorCapturingTransport,
        sink: MockTapeSink = MockTapeSink(),
        saveKey: Bool = true
    ) throws -> FacilitatorDialogue {
        let scope = "facilitator-test-\(UUID().uuidString)"
        let ks = KeychainStore()
        if saveKey {
            try ks.save(service: scope, account: "api_key", secret: "fake_facilitator_key_value")
            addTeardownBlock { try? ks.delete(service: scope, account: "api_key") }
        }
        let gateway = ModelGateway(
            tapeSink: sink,
            transport: transport,
            keychainStore: ks,
            projectId: "proj_test"
        )
        return FacilitatorDialogue(gateway: gateway, credentialScope: scope)
    }
}

// MARK: - Test class

final class FacilitatorDialogueTests: XCTestCase {

    // MARK: - Test 1: deterministic route hit → zero gateway invocations

    @MainActor
    func testDeterministicRouteHitZeroGatewayInvocations() async throws {
        let transport = FacilitatorCapturingTransport(responseData: successResponseJSON())
        let dialogue = try makeDialogue(transport: transport)
        let vm = OrbViewModel(probe: MockFacilitatorProbe(.apiBacked), dialogue: dialogue)
        vm.resolveRuntime()

        // Deterministic hits: config / morning ritual / wizard entry.
        vm.send(.inputSubmitted(text: "meta 设置"))
        XCTAssertNil(vm.dialogueTask, "设置 hit must not spawn a dialogue task")
        vm.send(.inputSubmitted(text: "早"))
        XCTAssertNil(vm.dialogueTask, "早 hit must not spawn a dialogue task")
        vm.send(.inputSubmitted(text: "立项 proj_a134"))
        XCTAssertNil(vm.dialogueTask, "立项 wizard entry must not spawn a dialogue task")
        // A1_34 verifier finding: menu ⌘R submits "ci 检查" and menu
        // .connectRepo submits "连接仓库" — both MUST be deterministic
        // routes (atom card predicate 1 names ci explicitly).
        vm.send(.inputSubmitted(text: "ci 检查"))
        XCTAssertNil(vm.dialogueTask, "ci 检查 must route deterministically, never to the model")
        vm.send(.inputSubmitted(text: "连接仓库"))
        XCTAssertNil(vm.dialogueTask, "连接仓库 must route deterministically, never to the model")

        XCTAssertEqual(transport.invocationCount, 0,
                       "deterministic route hits must NEVER touch the gateway (predicate 1)")
    }

    // MARK: - Test 2: unknown input → golden DeepSeek request + projection swap

    @MainActor
    func testUnknownInputSendsGoldenDeepSeekRequest() async throws {
        let transport = FacilitatorCapturingTransport(responseData: successResponseJSON())
        let dialogue = try makeDialogue(transport: transport)
        let vm = OrbViewModel(probe: MockFacilitatorProbe(.apiBacked), dialogue: dialogue)
        vm.resolveRuntime()

        let userText = "帮我看看现在的整体情况"
        vm.send(.inputSubmitted(text: userText))

        // IMMEDIATE synchronous projection = the escape hatch (suggestions
        // show instantly; the async reply replaces it later).
        XCTAssertEqual(vm.currentProjection?.kind, "general",
                       "escape hatch must be projected synchronously before the reply")
        XCTAssertTrue(vm.currentProjection?.blocks.contains {
            if case .intentSuggestions = $0 { return true }
            return false
        } ?? false, "immediate projection must carry intent_suggestions")

        // Await the view-model's async dialogue task.
        XCTAssertNotNil(vm.dialogueTask, "unknown input + dialogue available must spawn the task")
        await vm.dialogueTask?.value

        // Golden wire assertions (DeepSeekWiringTests style).
        XCTAssertEqual(transport.captures.count, 1, "exactly one gateway call")
        let capture = try XCTUnwrap(transport.captures.first)
        XCTAssertEqual(capture.url, DeepSeekPresets.endpoint,
                       "request must hit the DeepSeek chat completions endpoint")

        let body = try JSONSerialization.jsonObject(with: capture.body) as! [String: Any]
        XCTAssertEqual(body["model"] as? String, "deepseek-v4-flash")
        XCTAssertEqual(body["max_tokens"] as? Int, 512)

        let thinking = body["thinking"] as? [String: Any]
        XCTAssertEqual(thinking?["type"] as? String, "disabled",
                       "facilitator lane wire shape must be {\"thinking\":{\"type\":\"disabled\"}}")

        let messages = body["messages"] as? [[String: Any]]
        XCTAssertEqual(messages?.count, 2, "system + user message")
        XCTAssertEqual(messages?[0]["role"] as? String, "system")
        XCTAssertEqual(messages?[1]["role"] as? String, "user")
        XCTAssertEqual(messages?[1]["content"] as? String, userText,
                       "user message content must be the raw input text")

        // Projection replaced with the facilitator reply.
        XCTAssertEqual(vm.currentProjection?.kind, "facilitator_reply",
                       "async reply must replace the projection on arrival")
    }

    // MARK: - Test 3: success → facilitator_reply doc shape

    func testSuccessReplyDocShape() async throws {
        let transport = FacilitatorCapturingTransport(responseData: successResponseJSON())
        let dialogue = try makeDialogue(transport: transport)

        let doc = await dialogue.respond(to: "随便聊聊")

        XCTAssertEqual(doc.kind, "facilitator_reply")
        XCTAssertEqual(doc.deriveSource, ["user_input", "model_call:facilitator:deepseek-v4-flash"],
                       "derive_source must carry user_input + the model_call reference")
        XCTAssertEqual(doc.blocks.count, 1)
        guard case .summaryCard(let card) = doc.blocks.first else {
            XCTFail("facilitator_reply must contain exactly one summary_card")
            return
        }
        XCTAssertEqual(card.title, "Facilitator")
        XCTAssertEqual(card.body, Self.mockedReply,
                       "summary_card body must equal the mocked response content")
    }

    // MARK: - Test 4: gateway errors → deterministic fallback (both paths)

    func testGatewayErrorFallbackDoc() async throws {
        // I9 negative-control prefix assembled at runtime (keeps this file
        // clean under the repo-wide key-leak grep).
        let secretKeyPrefix = "sk" + "-"

        // ── Path 1: provider error (transport throws), key present ─────────
        let throwingTransport = FacilitatorCapturingTransport(
            errorToThrow: .providerError("HTTP 500: upstream detail that must never surface")
        )
        let dialogue = try makeDialogue(transport: throwingTransport)
        let doc = await dialogue.respond(to: "你好")

        XCTAssertEqual(doc.kind, "facilitator_unavailable")
        guard case .summaryCard(let card) = doc.blocks.first else {
            XCTFail("fallback doc must lead with a summary_card")
            return
        }
        XCTAssertEqual(card.title, "Facilitator 暂不可用")
        XCTAssertEqual(card.body, "模型服务暂时不可达",
                       "providerError must map to the FIXED reason string")
        XCTAssertTrue(Self.fixedReasons.contains(card.body),
                      "body must be one of the fixed deterministic strings")
        XCTAssertFalse(card.body.contains("HTTP 500"),
                       "upstream error text must never surface in the IR")
        XCTAssertFalse(card.body.contains(secretKeyPrefix),
                       "no secret-key-shaped values in the fallback body")
        XCTAssertTrue(doc.blocks.contains {
            if case .intentSuggestions = $0 { return true }
            return false
        }, "fallback doc must include the intent_suggestions escape hatch")

        // ── Path 2: no key saved → credentialUnavailable ────────────────────
        let unusedTransport = FacilitatorCapturingTransport()
        let noKeyDialogue = try makeDialogue(transport: unusedTransport, saveKey: false)
        let noKeyDoc = await noKeyDialogue.respond(to: "你好")

        XCTAssertEqual(noKeyDoc.kind, "facilitator_unavailable")
        guard case .summaryCard(let noKeyCard) = noKeyDoc.blocks.first else {
            XCTFail("no-key fallback doc must lead with a summary_card")
            return
        }
        XCTAssertEqual(noKeyCard.body, "未配置 API Key（请输入「meta 设置」保存密钥）",
                       "credentialUnavailable must map to the FIXED reason string")
        XCTAssertFalse(noKeyCard.body.contains("facilitator-test-"),
                       "the credential scope value must never surface in the IR")
        XCTAssertEqual(unusedTransport.invocationCount, 0,
                       "no key → transport never touched")
        XCTAssertTrue(noKeyDoc.blocks.contains {
            if case .intentSuggestions = $0 { return true }
            return false
        }, "no-key fallback must include the intent_suggestions escape hatch")
    }

    // MARK: - Test 5: reasoning_content tolerated — content extracted only

    func testReasoningContentToleratedContentOnly() async throws {
        let payload: [String: Any] = [
            "choices": [[
                "message": [
                    "role": "assistant",
                    "content": "正文回答",
                    "reasoning_content": "内部推理过程不得外泄"
                ],
                "finish_reason": "stop"
            ]],
            "usage": ["prompt_tokens": 9, "completion_tokens": 4]
        ]
        let transport = FacilitatorCapturingTransport(
            responseData: try JSONSerialization.data(withJSONObject: payload)
        )
        let dialogue = try makeDialogue(transport: transport)

        let doc = await dialogue.respond(to: "随便问问")

        XCTAssertEqual(doc.kind, "facilitator_reply")
        guard case .summaryCard(let card) = doc.blocks.first else {
            XCTFail("reply must be a summary_card")
            return
        }
        XCTAssertEqual(card.body, "正文回答",
                       "only message.content reaches the card body")
        XCTAssertFalse(card.body.contains("内部推理过程不得外泄"),
                       "reasoning_content must never reach the projection")
    }

    // MARK: - Test 6: red line — only inert block types, even for hostile text

    func testRedLineOnlyInertBlockTypes() async throws {
        // Hostile model output: markup + script. RED LINE 1 — it may only
        // exist as an UNINTERPRETED string inside a summary_card body.
        let hostile = "<script>alert('pwn')</script><div onclick=\"x()\">点我</div>"
        let transport = FacilitatorCapturingTransport(
            responseData: successResponseJSON(content: hostile)
        )
        let dialogue = try makeDialogue(transport: transport)
        let successDoc = await dialogue.respond(to: "试试注入")

        let failTransport = FacilitatorCapturingTransport(errorToThrow: .codecError("bad json"))
        let failDialogue = try makeDialogue(transport: failTransport)
        let failureDoc = await failDialogue.respond(to: "试试注入")

        for (label, doc) in [("success", successDoc), ("failure", failureDoc)] {
            for block in doc.blocks {
                switch block {
                case .summaryCard, .intentSuggestions:
                    continue // the ONLY two permitted (inert) block types
                default:
                    XCTFail("red line 1 violated: \(label) doc contains a non-inert block: \(block)")
                }
            }
        }

        // The hostile text survives verbatim as a STRING in the body —
        // structurally incapable of reaching an executable surface.
        guard case .summaryCard(let card) = successDoc.blocks.first else {
            XCTFail("success doc must lead with a summary_card")
            return
        }
        XCTAssertEqual(card.body, hostile,
                       "model text is stored verbatim as a string, never interpreted")
    }

    // MARK: - Test 7: failure doc determinism — twice, byte-equal

    func testFailureDocDeterminismByteEqual() async throws {
        let transport = FacilitatorCapturingTransport()
        let noKeyDialogue = try makeDialogue(transport: transport, saveKey: false)

        let doc1 = await noKeyDialogue.respond(to: "同一输入")
        let doc2 = await noKeyDialogue.respond(to: "同一输入")

        XCTAssertEqual(doc1, doc2, "same failure must produce the identical document")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data1 = try encoder.encode(doc1)
        let data2 = try encoder.encode(doc2)
        XCTAssertEqual(data1, data2,
                       "failure doc must be byte-identical across calls (sortedKeys)")
        XCTAssertEqual(transport.invocationCount, 0,
                       "credential failure short-circuits before transport")
    }

    // MARK: - Test 8: I8 — success call lands in the in-memory recording sink

    func testTapeRecordAppendedToInMemorySink() async throws {
        let sink = MockTapeSink()
        let transport = FacilitatorCapturingTransport(responseData: successResponseJSON())
        let dialogue = try makeDialogue(transport: transport, sink: sink)

        let doc = await dialogue.respond(to: "记录这次调用")
        XCTAssertEqual(doc.kind, "facilitator_reply")

        // Exactly one record, stamped with the facilitator lane identity —
        // recorded through the IN-MEMORY sink (FileTapeSink is never
        // constructed in this test target).
        XCTAssertEqual(sink.appended.count, 1, "one send → one tape record (I8)")
        let record = try XCTUnwrap(sink.appended.first)
        XCTAssertEqual(record.model, "deepseek-v4-flash")
        XCTAssertEqual(record.role, .facilitator)
        XCTAssertEqual(record.projectId, "proj_test")
        XCTAssertEqual(record.outputRecord.content, Self.mockedReply,
                       "tape output content must match the mocked reply")
    }
}

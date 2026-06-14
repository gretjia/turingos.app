// MetaDraftingTests.swift — A1_35: Meta drafting + budget/approval routes.
//
// Atom card predicate mapping (specs/atoms/A1_35_meta_drafting_and_projection_routes.md):
//
//   P1 "Meta golden：起草意图 + wizard 活跃 → 请求体 model==deepseek-v4-pro 且
//       thinking enabled 且上下文含已答步骤；wizard 状态前后逐字节不变（红线 4）"
//     1. testGoldenMetaDraftRequest
//     2. testRedLine4WizardSessionUnmutated
//
//   P2 "起草意图但 wizard 不活跃 → 确定性提示卡（先立项），零 gateway 调用"
//     3. testDraftIntentWithoutWizardDeterministicNotice
//     8. testRequiresWizardNoticeDeterminismByteEqual
//
//   P3 "预算/批准意图 → 确定性投影 ×2 字节一致，零 gateway 调用（负控）；
//       approval 卡含 approval_request 块"
//     5. testBudgetIntentDeterministicProjectionZeroCall
//     6. testApprovalIntentDeterministicProjectionZeroCall
//
//   P1 failure lane + injection seam:
//     4. testMetaGatewayErrorFixedStringFallback
//     7. testA134DeterministicRoutesNegativeControlStillZeroCall
//     9. testNilDefaultWiringNoMetaServiceUnlessInjected
//
// BOUNDARY: zero network — the live transport type is NEVER constructed here
// (A1_22 discipline; FacilitatorCapturingTransport reused). No real API key
// appears anywhere in this file. MetaDrafting.production() is NEVER called
// (it would construct FileTapeSink + the live session transport).

import Foundation
import XCTest
@testable import TuringOS

// MARK: - Test helpers

private extension MetaDraftingTests {

    static let mockedProposal = "建议：非目标可写「不做移动端」；DoD 可写「shipgate 全绿」。"

    func successResponseJSON(content: String = MetaDraftingTests.mockedProposal) -> Data {
        let payload: [String: Any] = [
            "choices": [[
                "message": ["role": "assistant", "content": content],
                "finish_reason": "stop"
            ]],
            "usage": ["prompt_tokens": 40, "completion_tokens": 25]
        ]
        return try! JSONSerialization.data(withJSONObject: payload)
    }

    /// Build a MetaDrafting on a Mock gateway: in-memory sink + capturing
    /// transport + a unique fake-key Keychain scope (cleaned up on teardown).
    /// `saveKey: false` leaves the scope empty → credentialUnavailable path.
    func makeMeta(
        transport: FacilitatorCapturingTransport,
        sink: MockTapeSink = MockTapeSink(),
        saveKey: Bool = true
    ) throws -> MetaDrafting {
        let scope = "meta-test-\(UUID().uuidString)"
        let ks = KeychainStore()
        if saveKey {
            try ks.save(service: scope, account: "api_key", secret: "fake_meta_key_value")
            addTeardownBlock { try? ks.delete(service: scope, account: "api_key") }
        }
        let gateway = ModelGateway(
            tapeSink: sink,
            transport: transport,
            keychainStore: ks,
            projectId: "proj_test"
        )
        return MetaDrafting(gateway: gateway, credentialScope: scope)
    }

    /// Sorted-keys canonical bytes for byte-identity assertions.
    func canonicalBytes(_ doc: ViewIRDocument?) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(XCTUnwrap(doc))
    }
}

// MARK: - Test class

final class MetaDraftingTests: XCTestCase {

    // MARK: - Test 1: golden — wizard active + drafting ask → v4-pro, thinking on

    @MainActor
    func testGoldenMetaDraftRequest() async throws {
        let transport = FacilitatorCapturingTransport(responseData: successResponseJSON())
        let meta = try makeMeta(transport: transport)
        let vm = OrbViewModel(probe: MockFacilitatorProbe(.apiBacked), metaDrafting: meta)
        vm.resolveRuntime()

        // Start a wizard and answer step 0 (goals) so the context is non-empty.
        vm.send(.inputSubmitted(text: "立项 proj_meta35"))
        let answeredText = "目标：跑通 Meta 提案链路（A1_35）"
        vm.send(.inputSubmitted(text: answeredText))

        let userAsk = "帮我写 剩下的"
        vm.send(.inputSubmitted(text: userAsk))

        // Deterministic placeholder shown IMMEDIATELY (rules first, §5.6).
        XCTAssertEqual(vm.currentProjection?.kind, "meta_drafting_in_progress",
                       "起草中… placeholder must be projected synchronously")
        XCTAssertNotNil(vm.metaTask, "drafting ask + wizard active must spawn the meta task")
        await vm.metaTask?.value

        // Golden wire assertions (DeepSeekWiringTests style).
        XCTAssertEqual(transport.captures.count, 1, "exactly one gateway call")
        let capture = try XCTUnwrap(transport.captures.first)
        XCTAssertEqual(capture.url, DeepSeekPresets.endpoint)

        let body = try JSONSerialization.jsonObject(with: capture.body) as! [String: Any]
        XCTAssertEqual(body["model"] as? String, "deepseek-v4-pro",
                       "meta lane is deepseek-v4-pro (user ruling 2026-06-12)")
        XCTAssertEqual(body["max_tokens"] as? Int, 4096)

        let thinking = body["thinking"] as? [String: Any]
        XCTAssertEqual(thinking?["type"] as? String, "enabled",
                       "meta lane wire shape must be {\"thinking\":{\"type\":\"enabled\"}}")

        let messages = body["messages"] as? [[String: Any]]
        XCTAssertEqual(messages?.count, 2, "system + user message")
        XCTAssertEqual(messages?[0]["role"] as? String, "system")
        XCTAssertEqual(messages?[0]["content"] as? String, MetaDrafting.systemPrompt)
        let userContent = try XCTUnwrap(messages?[1]["content"] as? String)
        XCTAssertTrue(userContent.contains(answeredText),
                      "drafting context must contain the answered step's text")
        XCTAssertTrue(userContent.contains(userAsk),
                      "drafting context must carry the user's ask")
        XCTAssertTrue(userContent.contains("proj_meta35"),
                      "drafting context must name the wizard's project")

        // Projection replaced with the proposal document.
        XCTAssertEqual(vm.currentProjection?.kind, "meta_draft_proposal")
        XCTAssertEqual(vm.currentProjection?.deriveSource,
                       ["user_input", "wizard:proj_meta35", "model_call:meta:deepseek-v4-pro"])
        guard case .summaryCard(let card) = vm.currentProjection?.blocks.first else {
            XCTFail("proposal must lead with a summary_card")
            return
        }
        XCTAssertEqual(card.title, "Meta AI 起草建议（提案，未写入）")
        XCTAssertEqual(card.body, Self.mockedProposal,
                       "model text lands ONLY in the summary_card body string (red line 1)")
    }

    // MARK: - Test 2: RED LINE 4 — wizard session byte-identical before/after

    @MainActor
    func testRedLine4WizardSessionUnmutated() async throws {
        let transport = FacilitatorCapturingTransport(responseData: successResponseJSON())
        let meta = try makeMeta(transport: transport)
        let vm = OrbViewModel(probe: MockFacilitatorProbe(.apiBacked), metaDrafting: meta)
        vm.resolveRuntime()

        vm.send(.inputSubmitted(text: "立项 proj_redline4"))
        vm.send(.inputSubmitted(text: "目标 A"))
        vm.send(.inputSubmitted(text: "非目标 B"))

        let before = try XCTUnwrap(vm.wizardSession)

        vm.send(.inputSubmitted(text: "帮我写 验收谓词"))
        // Immediately after dispatch: session untouched (ask was NOT consumed
        // as a wizard answer).
        XCTAssertEqual(vm.wizardSession, before,
                       "drafting ask must never advance or mutate the wizard session")

        await vm.metaTask?.value
        // After the async proposal replaced the projection: still untouched.
        let after = try XCTUnwrap(vm.wizardSession)
        XCTAssertEqual(after, before, "red line 4: proposal only — zero session writes")
        XCTAssertEqual(after.stepIndex, before.stepIndex)
        XCTAssertEqual(after.answers, before.answers)
        XCTAssertEqual(after.finished, before.finished)
        XCTAssertEqual(after.projectId, before.projectId)
        XCTAssertEqual(vm.currentProjection?.kind, "meta_draft_proposal")
    }

    // MARK: - Test 3: no wizard → requires-wizard notice, zero gateway

    @MainActor
    func testDraftIntentWithoutWizardDeterministicNotice() throws {
        let transport = FacilitatorCapturingTransport(responseData: successResponseJSON())
        let meta = try makeMeta(transport: transport)
        let vm = OrbViewModel(probe: MockFacilitatorProbe(.apiBacked), metaDrafting: meta)
        vm.resolveRuntime()

        vm.send(.inputSubmitted(text: "帮我 draft 一份立项材料"))

        XCTAssertEqual(vm.currentProjection?.kind, "meta_draft_requires_wizard")
        guard case .summaryCard(let card) = vm.currentProjection?.blocks.first else {
            XCTFail("notice must be a summary_card")
            return
        }
        XCTAssertEqual(card.body, "先用 ⌘N 或「立项」开始一个草案，再让 Meta 起草。")
        XCTAssertNil(vm.metaTask, "no wizard → no meta task")
        XCTAssertEqual(transport.invocationCount, 0,
                       "no wizard → the gateway is NEVER touched (predicate 2)")
    }

    // MARK: - Test 4: gateway errors → deterministic meta_unavailable fixed strings

    func testMetaGatewayErrorFixedStringFallback() async throws {
        let session = WizardSession(projectId: "proj_err", stepIndex: 1,
                                    answers: [.goals: "G1"])

        // ── Path 1: provider error (transport throws), key present ─────────
        let throwingTransport = FacilitatorCapturingTransport(
            errorToThrow: .providerError("HTTP 503: upstream detail that must never surface")
        )
        let meta = try makeMeta(transport: throwingTransport)
        let doc = await meta.draft(for: session, userAsk: "帮我写")

        XCTAssertEqual(doc.kind, "meta_unavailable")
        guard case .summaryCard(let card) = doc.blocks.first else {
            XCTFail("fallback doc must lead with a summary_card")
            return
        }
        XCTAssertEqual(card.title, "Meta AI 暂不可用")
        XCTAssertEqual(card.body, "模型服务暂时不可达",
                       "providerError must map to the FIXED reason string")
        XCTAssertFalse(card.body.contains("HTTP 503"),
                       "upstream error text must never surface in the IR")

        // ── Path 2: no key saved → credentialUnavailable, transport untouched ──
        let unusedTransport = FacilitatorCapturingTransport()
        let noKeyMeta = try makeMeta(transport: unusedTransport, saveKey: false)
        let noKeyDoc = await noKeyMeta.draft(for: session, userAsk: "帮我写")

        XCTAssertEqual(noKeyDoc.kind, "meta_unavailable")
        guard case .summaryCard(let noKeyCard) = noKeyDoc.blocks.first else {
            XCTFail("no-key fallback doc must lead with a summary_card")
            return
        }
        XCTAssertEqual(noKeyCard.body, "未配置 API Key（请输入「meta 设置」保存密钥）")
        XCTAssertFalse(noKeyCard.body.contains("meta-test-"),
                       "the credential scope value must never surface in the IR")
        XCTAssertEqual(unusedTransport.invocationCount, 0,
                       "no key → transport never touched")
    }

    // MARK: - Test 5: 预算 intent → deterministic budget_draft, zero gateway

    @MainActor
    func testBudgetIntentDeterministicProjectionZeroCall() async throws {
        let transport = FacilitatorCapturingTransport(responseData: successResponseJSON())
        let meta = try makeMeta(transport: transport)
        let vm = OrbViewModel(probe: MockFacilitatorProbe(.apiBacked), metaDrafting: meta)
        vm.resolveRuntime()

        // No wizard → placeholder project.
        vm.send(.inputSubmitted(text: "预算"))
        let doc1 = try XCTUnwrap(vm.currentProjection)
        XCTAssertEqual(doc1.kind, "budget_draft")
        XCTAssertTrue(doc1.deriveSource.contains("project:proj_default"))
        XCTAssertTrue(doc1.deriveSource.contains("spec:sha256:draft"))

        vm.send(.inputSubmitted(text: "预算"))
        let doc2 = try XCTUnwrap(vm.currentProjection)
        XCTAssertEqual(try canonicalBytes(doc1), try canonicalBytes(doc2),
                       "预算 projection must be byte-identical across calls (determinism ×2)")

        // Active wizard → its projectId flows into the contract.
        vm.send(.inputSubmitted(text: "立项 proj_fin35"))
        let sessionBefore = try XCTUnwrap(vm.wizardSession)
        vm.send(.inputSubmitted(text: "budget 看一眼"))
        let wizardDoc = try XCTUnwrap(vm.currentProjection)
        XCTAssertEqual(wizardDoc.kind, "budget_draft")
        XCTAssertTrue(wizardDoc.deriveSource.contains("project:proj_fin35"),
                      "active wizard supplies the projectId")
        XCTAssertEqual(vm.wizardSession, sessionBefore,
                       "budget intent must not be consumed as a wizard answer")

        XCTAssertNil(vm.metaTask)
        XCTAssertEqual(transport.invocationCount, 0,
                       "budget route is deterministic — ZERO model (predicate 3)")
    }

    // MARK: - Test 6: 批准 intent → approval_request block, deterministic ×2

    @MainActor
    func testApprovalIntentDeterministicProjectionZeroCall() async throws {
        let transport = FacilitatorCapturingTransport(responseData: successResponseJSON())
        let meta = try makeMeta(transport: transport)
        let vm = OrbViewModel(probe: MockFacilitatorProbe(.apiBacked), metaDrafting: meta)
        vm.resolveRuntime()

        vm.send(.inputSubmitted(text: "批准"))
        let doc1 = try XCTUnwrap(vm.currentProjection)
        XCTAssertEqual(doc1.kind, "approval_draft_demo")
        XCTAssertEqual(doc1.deriveSource, ["approval_draft:demo"])

        // approval_request block present, referencing the built draft.
        let approvalBlocks = doc1.blocks.compactMap { block -> ApprovalRequestPayload? in
            if case .approvalRequest(let payload) = block { return payload }
            return nil
        }
        XCTAssertEqual(approvalBlocks.count, 1, "approval card must contain one approval_request block")
        XCTAssertTrue(try XCTUnwrap(approvalBlocks.first).envelopeRef.hasPrefix("env_"),
                      "envelope_ref must come from the deterministic builder draft")

        vm.send(.inputSubmitted(text: "审批"))
        let doc2 = try XCTUnwrap(vm.currentProjection)
        XCTAssertEqual(try canonicalBytes(doc1), try canonicalBytes(doc2),
                       "fixed nonce/expiry → byte-identical approval demo (determinism ×2)")

        vm.send(.inputSubmitted(text: "show approval"))
        XCTAssertEqual(vm.currentProjection?.kind, "approval_draft_demo")

        XCTAssertNil(vm.metaTask)
        XCTAssertEqual(transport.invocationCount, 0,
                       "approval route is deterministic — ZERO model, zero signing (predicate 3)")
    }

    // MARK: - Test 7: A1_34 deterministic-route negative control rerun

    @MainActor
    func testA134DeterministicRoutesNegativeControlStillZeroCall() throws {
        let transport = FacilitatorCapturingTransport(responseData: successResponseJSON())
        let meta = try makeMeta(transport: transport)
        let vm = OrbViewModel(probe: MockFacilitatorProbe(.apiBacked), metaDrafting: meta)
        vm.resolveRuntime()

        // The A1_34 deterministic set, now with a live meta service injected:
        // none of these may reach ANY gateway.
        for text in ["meta 设置", "早", "项目", "ci 检查", "连接仓库"] {
            vm.send(.inputSubmitted(text: text))
            XCTAssertNil(vm.metaTask, "\(text) must not spawn a meta task")
            XCTAssertNil(vm.dialogueTask, "\(text) must not spawn a dialogue task")
        }
        XCTAssertEqual(transport.invocationCount, 0,
                       "deterministic route hits must NEVER touch the gateway (A1_34 control)")
    }

    // MARK: - Test 8: requires-wizard notice determinism ×2 byte-equal

    @MainActor
    func testRequiresWizardNoticeDeterminismByteEqual() throws {
        let transport = FacilitatorCapturingTransport()
        let meta = try makeMeta(transport: transport)
        let vm = OrbViewModel(probe: MockFacilitatorProbe(.apiBacked), metaDrafting: meta)
        vm.resolveRuntime()

        vm.send(.inputSubmitted(text: "起草"))
        let doc1 = try XCTUnwrap(vm.currentProjection)
        vm.send(.inputSubmitted(text: "起草"))
        let doc2 = try XCTUnwrap(vm.currentProjection)

        XCTAssertEqual(doc1.kind, "meta_draft_requires_wizard")
        XCTAssertEqual(try canonicalBytes(doc1), try canonicalBytes(doc2),
                       "requires-wizard notice must be byte-identical across calls")
        XCTAssertEqual(transport.invocationCount, 0)
    }

    // MARK: - Test 9: nil-default wiring — no meta service unless injected

    @MainActor
    func testNilDefaultWiringNoMetaServiceUnlessInjected() throws {
        // Default construction (every pre-A1_35 call site): metaDrafting nil.
        let vm = OrbViewModel(probe: MockFacilitatorProbe(.apiBacked))
        vm.resolveRuntime()

        vm.send(.inputSubmitted(text: "立项 proj_nilwire"))
        let before = try XCTUnwrap(vm.wizardSession)

        vm.send(.inputSubmitted(text: "帮我写 目标"))

        XCTAssertNil(vm.metaTask, "nil service → no task, no spinner lie")
        XCTAssertEqual(vm.currentProjection?.kind, "meta_unavailable",
                       "nil service → deterministic fail-visible card")
        guard case .summaryCard(let card) = vm.currentProjection?.blocks.first else {
            XCTFail("unavailable doc must lead with a summary_card")
            return
        }
        XCTAssertEqual(card.body, "Meta 服务未接线（仅生产入口注入）")
        XCTAssertEqual(vm.wizardSession, before,
                       "red line 4 holds on the nil-service path too")
    }

    // MARK: - A1_41: worktree-task proposal lane ("与 Meta AI 沟通")

    @MainActor
    func testProposeWorktreeTaskGolden() async throws {
        let transport = FacilitatorCapturingTransport(
            responseData: successResponseJSON(
                content: "提议：在 main 上新开 worktree 修复 X；基分支 main；新分支 fix/x"))
        let meta = try makeMeta(transport: transport)
        let research = WorktreeResearchContext(
            currentBranch: "main",
            branches: ["main", "feat/auth"],
            recentCommits: ["abc123 wire CI", "def456 init"],
            dirty: false)

        let doc = await meta.proposeWorktreeTask(
            research: research, projectId: "turingos_app",
            userAsk: "建议一个小型可测试的 worktree")

        // Golden wire assertions.
        XCTAssertEqual(transport.captures.count, 1, "exactly one gateway call")
        let body = try JSONSerialization.jsonObject(
            with: XCTUnwrap(transport.captures.first).body) as! [String: Any]
        XCTAssertEqual(body["model"] as? String, "deepseek-v4-pro")
        let thinking = body["thinking"] as? [String: Any]
        XCTAssertEqual(thinking?["type"] as? String, "enabled")
        let messages = body["messages"] as? [[String: Any]]
        XCTAssertEqual(messages?[0]["content"] as? String, MetaDrafting.worktreeSystemPrompt)
        let userContent = try XCTUnwrap(messages?[1]["content"] as? String)
        XCTAssertTrue(userContent.contains("当前分支：main"), "git research current branch in context")
        XCTAssertTrue(userContent.contains("feat/auth"), "branches in context")
        XCTAssertTrue(userContent.contains("wire CI"), "recent commits in context")
        XCTAssertTrue(userContent.contains("建议一个小型可测试的 worktree"), "user ask carried")

        // Projection (red line 1: model text only in the card body).
        XCTAssertEqual(doc.kind, "meta_worktree_proposal")
        XCTAssertEqual(doc.deriveSource,
                       ["user_input", "git_research:turingos_app", "model_call:meta:deepseek-v4-pro"])
        guard case .summaryCard(let card) = doc.blocks.first else {
            XCTFail("proposal must lead with a summary_card"); return
        }
        XCTAssertEqual(card.title, "Meta AI worktree 提议（提案，未执行）")
        XCTAssertTrue(card.body.contains("基分支 main"), "model proposal text in the card body")
    }

    @MainActor
    func testProposeWorktreeTaskGatewayErrorFallback() async throws {
        // No key saved → credentialUnavailable → deterministic fail-visible doc.
        let transport = FacilitatorCapturingTransport(responseData: successResponseJSON())
        let meta = try makeMeta(transport: transport, saveKey: false)
        let research = WorktreeResearchContext(
            currentBranch: "main", branches: ["main"], recentCommits: [], dirty: false)
        let doc = await meta.proposeWorktreeTask(research: research, projectId: "p", userAsk: "x")
        XCTAssertEqual(doc.kind, "meta_unavailable")
    }
}

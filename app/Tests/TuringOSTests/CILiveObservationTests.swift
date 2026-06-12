// CILiveObservationTests.swift — A1_36 predicate coverage.
// P1: provider nil → immediate CIUnavailableNotice (deterministic ×2), no task
// P2: provider with PR → placeholder first, async replacement with
//     CIStatusProjection (derive_source carries pr number); no PR → honest notice
// P3: CI path zero gateway calls; observation runs off the MainActor

import XCTest
@testable import TuringOS

/// Mock observation source — pure data, zero process spawning.
private struct MockObservationSource: RepoObservationSource {
    var prs: [PRSummary]
    var checks: [CheckRunSummary]
    var deriveSourceTag: String { "mock:repo:test" }

    func headSHA(branch: String?) throws -> String { "abc123def456" }
    func openPRs() throws -> [PRSummary] { prs }
    func checkRuns(prNumber: Int) throws -> [CheckRunSummary] { checks }
    func branchProtectionSnapshot(owner: String, repo: String) throws -> String { "{}" }
    func workflowFilesHash(commit: String) throws -> String { "sha256:wf" }
    func mergeBase(ref1: String, ref2: String) throws -> String { "base789" }
}

@MainActor
final class CILiveObservationTests: XCTestCase {

    // MARK: - P1: nil provider

    func testNilProviderImmediateUnavailableNoticeNoTask() {
        let vm = OrbViewModel(probe: MockFacilitatorProbe(.apiBacked))
        vm.resolveRuntime()
        vm.send(.inputSubmitted(text: "ci 检查"))
        XCTAssertNil(vm.ciTask, "nil provider must not spawn an observation task")
        XCTAssertEqual(vm.currentProjection, CIUnavailableNotice.make())
    }

    func testNilProviderNoticeDeterministicX2() {
        let a = CIUnavailableNotice.make()
        let b = CIUnavailableNotice.make()
        XCTAssertEqual(a, b)
    }

    // MARK: - P2: provider paths

    func testProviderWithPRPlaceholderThenStatusProjection() async {
        let source = MockObservationSource(
            prs: [PRSummary(number: 42, headRefName: "feat/x", title: "T", url: "u")],
            checks: [CheckRunSummary(id: "c1", name: "tests", conclusion: "success", runnerType: "github_actions")]
        )
        let vm = OrbViewModel(
            probe: MockFacilitatorProbe(.apiBacked),
            ciObservationProvider: { source }
        )
        vm.resolveRuntime()
        vm.send(.inputSubmitted(text: "ci 检查"))

        // Placeholder shows immediately (synchronous).
        XCTAssertEqual(vm.currentProjection?.kind, "ci_checking")
        XCTAssertNotNil(vm.ciTask)

        await vm.ciTask?.value
        // Replaced with the real status projection carrying the PR number.
        XCTAssertNotEqual(vm.currentProjection?.kind, "ci_checking")
        XCTAssertTrue(vm.currentProjection?.deriveSource.contains(where: { $0.contains("pr:42") }) == true,
            "derive_source must reference the observed PR: \(String(describing: vm.currentProjection?.deriveSource))")
    }

    func testProviderNoPRHonestNotice() async {
        let source = MockObservationSource(prs: [], checks: [])
        let vm = OrbViewModel(
            probe: MockFacilitatorProbe(.apiBacked),
            ciObservationProvider: { source }
        )
        vm.resolveRuntime()
        vm.send(.inputSubmitted(text: "检查"))
        await vm.ciTask?.value
        // Honest degraded notice (no open PR), not a crash, not a model call.
        XCTAssertTrue(vm.currentProjection?.blocks.contains(where: {
            if case .summaryCard = $0 { return true }; return false
        }) == true)
    }

    // MARK: - P3: zero gateway + placeholder determinism

    func testCIPathZeroGatewayInvocations() async throws {
        // Live dialogue injected — CI intent still must never reach it.
        let transport = FacilitatorCapturingTransport(responseData: Data("{}".utf8))
        let sink = MockTapeSink()
        let gateway = ModelGateway(
            tapeSink: sink, transport: transport,
            keychainStore: .shared, projectId: "p"
        )
        let dialogue = FacilitatorDialogue(gateway: gateway, credentialScope: "test-scope-ci36")
        let source = MockObservationSource(prs: [], checks: [])
        let vm = OrbViewModel(
            probe: MockFacilitatorProbe(.apiBacked),
            dialogue: dialogue,
            ciObservationProvider: { source }
        )
        vm.resolveRuntime()
        vm.send(.inputSubmitted(text: "ci 检查"))
        await vm.ciTask?.value
        XCTAssertEqual(transport.invocationCount, 0,
            "CI path must NEVER touch the model gateway")
        XCTAssertNil(vm.dialogueTask)
    }

    func testCheckingPlaceholderDeterministicX2() {
        XCTAssertEqual(TemplateProjections.ciCheckingNotice(),
                       TemplateProjections.ciCheckingNotice())
    }
}

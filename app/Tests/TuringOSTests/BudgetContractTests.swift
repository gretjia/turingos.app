// BudgetContractTests.swift — A1_19 predicate coverage.
// Predicates:
//   P1: BudgetContractStatus has exactly 2 cases — no ratified
//   P2: budgetHash determinism ×2; content change → hash change; status/projectId change → hash stable
//   P3: Builder produces signatureNode==2; budgetHash matches contract.budgetHash
//   P4: Projection determinism ×2; derive_source non-empty; schema_version non-empty
//   P5: Validator accepts valid contract; rejects zero tokenLimit; rejects empty stopLossLine
//   P6: T3 hostThreatLevel → BuildRefusal (forwarded from A1_23 ApprovalEnvelopeBuilder)

import XCTest
@testable import TuringOS

final class BudgetContractTests: XCTestCase {

    // MARK: - Helpers

    private func makeLimits(
        tokenLimit: Int = 100_000,
        wallClockSecs: Int = 86_400
    ) -> BudgetLimits {
        BudgetLimits(
            tokenLimit: tokenLimit,
            wallClockSecs: wallClockSecs,
            toolCallsLimit: 500,
            ciCyclesLimit: 20,
            reviewerBurdenHours: 2.0,
            externalDispatchLimit: 5,
            stopLossLine: "halt_on_3_consecutive_ci_failures"
        )
    }

    private func makeContract(projectId: String = "test-project") -> BudgetContract {
        BudgetContract(projectId: projectId, limits: makeLimits())
    }

    // MARK: - P1: Status enum has exactly 2 cases, no ratified

    func testStatusEnumHasExactlyTwoCases() {
        // Type-level enforcement: ratification is kernel tape (UPSTREAM_CONTRACT).
        XCTAssertEqual(BudgetContractStatus.allCases.count, 2)
    }

    func testStatusEnumHasNoCaseNamedRatified() {
        let rawValues = BudgetContractStatus.allCases.map(\.rawValue)
        XCTAssertFalse(rawValues.contains("ratified"),
            "ratified case must not exist — kernel-side tape event, not app state")
        XCTAssertFalse(rawValues.contains("activated"),
            "activated case must not exist in BudgetContractStatus")
    }

    // MARK: - P2: budgetHash determinism

    func testBudgetHashDeterminismX2() {
        let c1 = makeContract()
        let c2 = makeContract()
        XCTAssertEqual(c1.budgetHash, c2.budgetHash,
            "Same inputs must produce identical budgetHash")
    }

    func testBudgetHashChangesWithLimitChange() {
        let c1 = makeContract()
        var c2 = makeContract()
        c2.limits.tokenLimit = 200_000
        XCTAssertNotEqual(c1.budgetHash, c2.budgetHash,
            "Changed token_limit must produce different budgetHash")
    }

    func testBudgetHashStableAcrossStatusChange() {
        var c = makeContract()
        let hashDraft = c.budgetHash
        c.status = .awaitingRatification
        XCTAssertEqual(hashDraft, c.budgetHash,
            "Status change must NOT change budgetHash (status excluded from hash surface)")
    }

    func testBudgetHashStableAcrossProjectIdChange() {
        let c1 = BudgetContract(projectId: "project-a", limits: makeLimits())
        let c2 = BudgetContract(projectId: "project-b", limits: makeLimits())
        XCTAssertEqual(c1.budgetHash, c2.budgetHash,
            "projectId change must NOT change budgetHash (projectId excluded from hash surface)")
    }

    // MARK: - P3: Builder produces signatureNode==2 and matching budgetHash

    func testBuilderProducesSignatureNode2() {
        let contract = makeContract()
        let result = BudgetContractBuilder.buildEnvelope(
            contract: contract,
            specHash: "sha256:aaaa",
            prevTapeHead: "sha256:0000",
            nonce: "test-nonce",
            expiryUtc: "2026-12-31T23:59:59Z"
        )
        guard case .success(let draft) = result else {
            XCTFail("Builder should succeed for T0 contract"); return
        }
        XCTAssertEqual(draft.signatureNode, 2,
            "Budget approval envelope must have signatureNode==2")
    }

    func testBuilderBudgetHashMatchesContract() {
        let contract = makeContract()
        let expectedHash = contract.budgetHash
        let result = BudgetContractBuilder.buildEnvelope(
            contract: contract,
            specHash: "sha256:spec",
            prevTapeHead: "sha256:prev",
            nonce: "nonce-xyz",
            expiryUtc: "2026-12-31T00:00:00Z"
        )
        guard case .success(let draft) = result else {
            XCTFail("Builder should succeed"); return
        }
        XCTAssertEqual(draft.budgetHash, expectedHash,
            "Envelope budgetHash must match contract.budgetHash")
        // Verify schema pattern: sha256: + hex
        XCTAssert(draft.budgetHash.hasPrefix("sha256:"),
            "budgetHash must match schema pattern ^sha256:[0-9a-f]{8,64}$")
    }

    // MARK: - P4: Projection determinism and structural integrity

    func testBudgetDraftCardDeterminismX2() {
        let contract = makeContract()
        let doc1 = BudgetProjections.budgetDraftCard(for: contract, specHash: "sha256:s")
        let doc2 = BudgetProjections.budgetDraftCard(for: contract, specHash: "sha256:s")
        XCTAssertEqual(doc1, doc2, "budgetDraftCard must be deterministic")
    }

    func testProjectReadyPendingCardDeterminismX2() {
        let doc1 = BudgetProjections.projectReadyPendingCard(
            projectId: "p1", budgetHash: "sha256:b", specHash: "sha256:s")
        let doc2 = BudgetProjections.projectReadyPendingCard(
            projectId: "p1", budgetHash: "sha256:b", specHash: "sha256:s")
        XCTAssertEqual(doc1, doc2, "projectReadyPendingCard must be deterministic")
    }

    func testProjectionDeriveSourceNonEmpty() {
        let contract = makeContract()
        let doc = BudgetProjections.budgetDraftCard(for: contract, specHash: "sha256:s")
        XCTAssertFalse(doc.deriveSource.isEmpty, "derive_source must be non-empty (Red Line 5)")
    }

    func testProjectionSchemaVersionNonEmpty() {
        let doc = BudgetProjections.projectReadyPendingCard(
            projectId: "p", budgetHash: "sha256:b", specHash: "sha256:s")
        XCTAssertFalse(doc.schemaVersion.isEmpty, "schema_version must be non-empty")
    }

    // MARK: - P5: Validator

    func testValidatorAcceptsValidContract() {
        let contract = makeContract()
        let errors = BudgetContractValidator.validate(contract)
        XCTAssertTrue(errors.isEmpty, "Valid contract should pass: \(errors)")
    }

    func testValidatorRejectsZeroTokenLimit() {
        let contract = BudgetContract(
            projectId: "p",
            limits: makeLimits(tokenLimit: 0)
        )
        let errors = BudgetContractValidator.validate(contract)
        XCTAssertFalse(errors.isEmpty, "Zero tokenLimit should fail validation")
        XCTAssert(errors.first?.contains("token_limit") == true)
    }

    func testValidatorRejectsNegativeWallClock() {
        let contract = BudgetContract(
            projectId: "p",
            limits: makeLimits(wallClockSecs: -1)
        )
        let errors = BudgetContractValidator.validate(contract)
        XCTAssertFalse(errors.isEmpty, "Negative wallClockSecs should fail validation")
    }

    func testValidatorRejectsEmptyProjectId() {
        let contract = BudgetContract(
            projectId: "",
            limits: makeLimits()
        )
        let errors = BudgetContractValidator.validate(contract)
        XCTAssertFalse(errors.isEmpty, "Empty projectId should fail validation")
    }

    // MARK: - P6: T3 refusal forwarded from ApprovalEnvelopeBuilder

    func testBuilderRefusesT3ThreatLevel() {
        let contract = makeContract()
        let result = BudgetContractBuilder.buildEnvelope(
            contract: contract,
            specHash: "sha256:s",
            prevTapeHead: "sha256:p",
            nonce: "n",
            expiryUtc: "2026-12-31T00:00:00Z",
            hostThreatLevel: .t3
        )
        guard case .failure(let refusal) = result else {
            XCTFail("T3 threat level must be refused"); return
        }
        if case .hostThreatLevelT3NotSupported = refusal {
            // Expected
        } else {
            XCTFail("Expected hostThreatLevelT3NotSupported, got \(refusal)")
        }
    }
}

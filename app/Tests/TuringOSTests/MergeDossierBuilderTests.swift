// A1_45: MergeDossier — schema conformance, R1 route law, PASS-only, ci_evidence.

import Foundation
import XCTest
@testable import TuringOS

final class MergeDossierBuilderTests: XCTestCase {
    private static var schemaURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // TuringOSTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // app
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("contracts/merge_dossier.schema.json")
    }

    private func passResult(target: String = "feat/x") -> PredicateResult {
        PredicateResult(
            predicateId: "prd_swift_build_deadbeef",
            verdict: .pass,
            evidenceHash: "sha256:" + String(repeating: "a", count: 64),
            target: target)
    }

    private func buildSample(provenance: MergeDossier.ProvenanceLevel = .partial) throws -> MergeDossier {
        try MergeDossierBuilder.build(
            predicate: passResult(),
            projectId: "turingos_app",
            worktreeBranch: "feat/x",
            commitSha: "c0ffee123456",
            mergeBase: "ba5eba11",
            changedFiles: ["app/Sources/TuringOS/Foo.swift"],
            provenance: provenance)
    }

    func testSchemaRequiredKeysPresent() throws {
        let schema = try JSONSerialization.jsonObject(with: Data(contentsOf: Self.schemaURL)) as! [String: Any]
        let required = schema["required"] as! [String]
        let ciRequired = ((schema["properties"] as! [String: Any])["ci_evidence"] as! [String: Any])["required"] as! [String]

        let dossier = try buildSample()
        let encoded = try JSONEncoder().encode(dossier)
        let obj = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]

        for key in required {
            XCTAssertNotNil(obj[key], "encoded MergeDossier must carry required key '\(key)'")
        }
        let ci = try XCTUnwrap(obj["ci_evidence"] as? [String: Any])
        for key in ciRequired {
            XCTAssertNotNil(ci[key], "ci_evidence must carry required key '\(key)'")
        }
        XCTAssertEqual(obj["schema_version"] as? String, "tos.app.merge_dossier.v0")
    }

    func testPartialProvenanceRoutesToSignature5() throws {
        let dossier = try buildSample(provenance: .partial)
        XCTAssertEqual(dossier.approvalRoute, .signature5,
                       "R1: PARTIAL provenance MUST route to signature_5, never autonomy_contract")
        XCTAssertTrue(MergeDossierBuilder.verdictSentence(dossier).contains("签名#5"))
    }

    func testFullProvenanceMayAutonomy() throws {
        let dossier = try buildSample(provenance: .full)
        XCTAssertEqual(dossier.approvalRoute, .autonomyContract,
                       "only locally-verified FULL provenance may use autonomy_contract")
    }

    func testNoDossierOnFail() {
        let fail = PredicateResult(
            predicateId: "prd_x_dead", verdict: .fail,
            evidenceHash: "sha256:" + String(repeating: "b", count: 64), target: "feat/x")
        XCTAssertThrowsError(try MergeDossierBuilder.build(
            predicate: fail, projectId: "p", worktreeBranch: "feat/x",
            commitSha: "c", mergeBase: "m", changedFiles: [])) { err in
            XCTAssertEqual(err as? MergeDossierError, .predicateNotPassing(verdict: "FAIL"),
                           "FAIL ⇒ no dossier (failure-certificate path)")
        }
    }

    func testCiEvidenceReusesPredicate() throws {
        let dossier = try buildSample()
        XCTAssertEqual(dossier.ciEvidence.conclusion, "PASS")
        XCTAssertEqual(dossier.ciEvidence.workflowFileHash, "sha256:" + String(repeating: "a", count: 64))
        XCTAssertNotNil(dossier.ciEvidence.workflowFileHash.range(
            of: "^sha256:[0-9a-f]{8,64}$", options: .regularExpression))
        XCTAssertTrue(dossier.ciEvidence.checkRunIds.contains("prd_swift_build_deadbeef"))
        XCTAssertTrue(dossier.receipts.contains("prd_swift_build_deadbeef"))
    }
}

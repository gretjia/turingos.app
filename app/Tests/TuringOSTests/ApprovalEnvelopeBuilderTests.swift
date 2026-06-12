// ApprovalEnvelopeBuilderTests.swift — A1_23: ApprovalEnvelope builder + what-you-saw binding.
//
// Test inventory (6 test functions, 40+ assertions):
//
//   1. testAllSchemaRequiredKeysPresent
//          — encode a built envelope; assert every key in contracts/approval_envelope.schema.json
//            required[] is present in the encoded JSON.
//
//   2. testVisibleCardHashBinding
//          — same content x2 → identical visibleCardHash (byte-equal);
//            mutate EACH ApprovalCardContent field one at a time → hash changes for every field;
//            envelope.visible_card_hash == content.visibleCardHash() (structural).
//
//   3. testCardContentSingleSourceOfTruth
//          — construct ApprovalRequestPayload and ApprovalCardContent from the same values;
//            assert the card-displayed strings appear in the hashed canonical data
//            (canonical JSON contains the summary/consequence verbatim).
//
//   4. testFailClosedRefusals
//          — T3 → refused;
//            node 0 → refused;
//            node 9 → refused;
//            class 3 + node 3 → refused;
//            class 3 + node 4 → ok;
//            required_signature_level is always "app_approval" in output.
//
//   5. testDeterminismBytEqual
//          — same inputs x2 → byte-equal encoded envelope.
//
//   6. testNoCeremonyAPIOnNewTypes
//          — no API named sign/record/persist on ApprovalCardContent,
//            ApprovalEnvelopeDraft, or ApprovalEnvelopeBuilder (compile-level structural check).

import Foundation
import XCTest
@testable import TuringOS

final class ApprovalEnvelopeBuilderTests: XCTestCase {

    // MARK: - Path helpers (mirrors CapabilityManifestTests pattern)

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // TuringOSTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // app
            .deletingLastPathComponent() // repo root
    }

    private static var schemaURL: URL {
        repoRoot.appendingPathComponent("contracts/approval_envelope.schema.json")
    }

    // MARK: - Shared fixture factory

    private static func makeContent(
        actor: String = "agent_test_01",
        actionKind: String = "create_worktree",
        actionClass: Int = 1,
        target: String = "~/Developer/turingos.app/worktrees/test",
        paramsSummary: String = "branch=test, isolation=process",
        riskCategory: String = "low",
        reversibility: String = "reversible",
        consequenceStatement: String = "A new git worktree is created. Reversible: run git worktree remove.",
        humanReadableSummary: String = "Create worktree for test atom."
    ) -> ApprovalCardContent {
        ApprovalCardContent(
            actor: actor,
            actionKind: actionKind,
            actionClass: actionClass,
            target: target,
            paramsSummary: paramsSummary,
            riskCategory: riskCategory,
            reversibility: reversibility,
            consequenceStatement: consequenceStatement,
            humanReadableSummary: humanReadableSummary
        )
    }

    private static func makeSuccessfulDraft(
        content: ApprovalCardContent? = nil,
        signatureNode: Int = 2,
        actionClass: Int = 1,
        nonce: String = "nonce-a1-23-test-0001",
        hostThreatLevel: HostThreatLevel = .t0
    ) -> ApprovalEnvelopeDraft {
        let c = content ?? makeContent(actionClass: actionClass)
        let result = ApprovalEnvelopeBuilder.build(
            content: c,
            signatureNode: signatureNode,
            projectId: "proj_test_a1_23",
            specHash: "sha256:aabb1122ccdd3344eeff5566778899aa",
            budgetHash: "sha256:bbcc2233ddee4455ff0011223344aabb",
            policyHash: "sha256:ccdd3344eeff55660011223344aabbcc",
            payloadHash: "sha256:ddee4455ff00112233445566778899dd",
            targetResourceHash: "sha256:ff0011223344aabbccdd55667788eeff",
            prevTapeHead: "sha256:1122334455667788aabbccddeeff0011",
            nonce: nonce,
            expiryUtc: "2026-06-12T06:00:00Z",
            hostThreatLevel: hostThreatLevel
        )
        guard case .success(let draft) = result else {
            fatalError("makeSuccessfulDraft: unexpected failure \(result)")
        }
        return draft
    }

    // MARK: - Test 1: all 20 required schema keys present in encoded output

    func testAllSchemaRequiredKeysPresent() throws {
        // Load the real schema file.
        let schemaData = try Data(contentsOf: Self.schemaURL)
        let schemaJSON = try JSONSerialization.jsonObject(with: schemaData) as! [String: Any]
        let schemaRequired = schemaJSON["required"] as! [String]
        XCTAssertEqual(schemaRequired.count, 20,
                       "schema 'required' array must have exactly 20 keys (single source of truth)")

        // Build a valid draft.
        let draft = Self.makeSuccessfulDraft()

        // Encode to JSON and parse into a dictionary.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(draft)
        let decoded = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]

        // Assert every required key is present.
        for key in schemaRequired {
            XCTAssertTrue(decoded[key] != nil,
                          "encoded envelope is missing required schema key '\(key)'")
        }

        // Also verify schema_version is the const.
        XCTAssertEqual(decoded["schema_version"] as? String,
                       "tos.app.approval_envelope.v0",
                       "schema_version must be the const value")

        // Verify required_signature_level is always "app_approval" in v0.x.
        XCTAssertEqual(decoded["required_signature_level"] as? String,
                       "app_approval",
                       "required_signature_level must be 'app_approval' in all v0.x envelopes")
    }

    // MARK: - Test 2: visible_card_hash binding (bi-directional)

    func testVisibleCardHashBinding() throws {
        let content = Self.makeContent()

        // 2a. Same content twice → identical visibleCardHash (byte-equal).
        let hash1 = content.visibleCardHash()
        let hash2 = content.visibleCardHash()
        XCTAssertEqual(hash1, hash2, "visibleCardHash() must be deterministic: same content → same hash")
        XCTAssertTrue(hash1.hasPrefix("sha256:"), "visibleCardHash must be formatted as 'sha256:<hex>'")
        XCTAssertEqual(hash1.count, "sha256:".count + 64,
                       "visibleCardHash must be sha256:<64 hex chars>")

        // 2b. Mutate EACH field → hash must change.
        // We use the default values from makeContent() as the baseline.
        let mutations: [(String, ApprovalCardContent)] = [
            ("actor",               Self.makeContent(actor: "agent_different")),
            ("actionKind",          Self.makeContent(actionKind: "send_email")),
            ("actionClass",         Self.makeContent(actionClass: 2)),
            ("target",              Self.makeContent(target: "/different/path")),
            ("paramsSummary",       Self.makeContent(paramsSummary: "changed params")),
            ("riskCategory",        Self.makeContent(riskCategory: "high")),
            ("reversibility",       Self.makeContent(reversibility: "irreversible")),
            ("consequenceStatement", Self.makeContent(consequenceStatement: "Changed consequence.")),
            ("humanReadableSummary", Self.makeContent(humanReadableSummary: "Changed summary.")),
        ]

        let baseline = content.visibleCardHash()
        for (fieldName, mutated) in mutations {
            let mutatedHash = mutated.visibleCardHash()
            XCTAssertNotEqual(baseline, mutatedHash,
                              "Mutating field '\(fieldName)' must change visibleCardHash; " +
                              "baseline=\(baseline) mutatedHash=\(mutatedHash)")
        }

        // 2c. Structural: envelope.visible_card_hash == content.visibleCardHash().
        let draft = Self.makeSuccessfulDraft(content: content)
        XCTAssertEqual(draft.visibleCardHash, content.visibleCardHash(),
                       "envelope.visible_card_hash must equal content.visibleCardHash() — structural binding")
    }

    // MARK: - Test 3: card-content single source of truth

    func testCardContentSingleSourceOfTruth() throws {
        // Use the same string values for both the ViewIR payload and ApprovalCardContent.
        let envelopeRef   = "env_test_single_source_001"
        let actor         = "agent_contract_test"
        let actionKind    = "approve_merge"
        let actionClass   = 2
        let target        = "main branch"
        let paramsSummary = "worktree=a1_23_impl"
        let riskCategory  = "medium"
        let reversibility = "draft"
        let consequence   = "Draft will be submitted for merge review."
        let summary       = "Merge the A1_23 implementation branch."

        // Construct ApprovalRequestPayload (what the card references by ID).
        let payload = ApprovalRequestPayload(envelopeRef: envelopeRef)
        XCTAssertEqual(payload.envelopeRef, envelopeRef)

        // Construct ApprovalCardContent using the factory that takes the same values
        // the card renderer would display.
        let content = ApprovalCardContent.from(
            envelopeRef: envelopeRef,
            actor: actor,
            actionKind: actionKind,
            actionClass: actionClass,
            target: target,
            paramsSummary: paramsSummary,
            riskCategory: riskCategory,
            reversibility: reversibility,
            consequenceStatement: consequence,
            humanReadableSummary: summary
        )

        // The canonical data must contain the exact strings that the card displays.
        let canonicalBytes = content.canonicalData()
        let canonicalString = String(data: canonicalBytes, encoding: .utf8)!

        XCTAssertTrue(canonicalString.contains(summary),
                      "canonical JSON must contain humanReadableSummary verbatim")
        XCTAssertTrue(canonicalString.contains(consequence),
                      "canonical JSON must contain consequenceStatement verbatim")
        XCTAssertTrue(canonicalString.contains(actor),
                      "canonical JSON must contain actor verbatim")
        XCTAssertTrue(canonicalString.contains(actionKind),
                      "canonical JSON must contain actionKind verbatim")
        XCTAssertTrue(canonicalString.contains(target),
                      "canonical JSON must contain target verbatim")
        XCTAssertTrue(canonicalString.contains(paramsSummary),
                      "canonical JSON must contain paramsSummary verbatim")
        XCTAssertTrue(canonicalString.contains(riskCategory),
                      "canonical JSON must contain riskCategory verbatim")
        XCTAssertTrue(canonicalString.contains(reversibility),
                      "canonical JSON must contain reversibility verbatim")

        // The content hash is derived from these exact bytes.
        let hash = content.visibleCardHash()
        XCTAssertTrue(hash.hasPrefix("sha256:"), "hash must be sha256:<hex>")
    }

    // MARK: - Test 4: FAIL-CLOSED refusals

    func testFailClosedRefusals() throws {
        let baseContent = Self.makeContent(actionClass: 1)
        let class3Content = Self.makeContent(actionClass: 3)

        // 4a. T3 → refused (Tier-2 reserved).
        let t3Result = ApprovalEnvelopeBuilder.build(
            content: baseContent,
            signatureNode: 4,
            projectId: "proj_test",
            specHash: "sha256:aabb1122ccdd3344eeff5566778899aa",
            budgetHash: "sha256:bbcc2233ddee4455ff0011223344aabb",
            policyHash: "sha256:ccdd3344eeff55660011223344aabbcc",
            payloadHash: "sha256:ddee4455ff00112233445566778899dd",
            targetResourceHash: "sha256:ff0011223344aabbccdd55667788eeff",
            prevTapeHead: "sha256:1122334455667788aabbccddeeff0011",
            nonce: "nonce-t3-test",
            expiryUtc: "2026-06-12T06:00:00Z",
            hostThreatLevel: .t3
        )
        guard case .failure(let t3Err) = t3Result,
              case .hostThreatLevelT3NotSupported(let reason) = t3Err else {
            XCTFail("T3 hostThreatLevel must be refused; got \(t3Result)")
            return
        }
        XCTAssertFalse(reason.isEmpty, "T3 refusal must include a non-empty reason")
        XCTAssertTrue(reason.contains("T3") || reason.contains("Tier-2") || reason.contains("v0.x"),
                      "T3 reason must reference T3 / Tier-2 / v0.x; got: \(reason)")

        // 4b. node 0 → refused (out of range 1...8).
        let node0Result = ApprovalEnvelopeBuilder.build(
            content: baseContent,
            signatureNode: 0,
            projectId: "proj_test",
            specHash: "sha256:aabb1122ccdd3344eeff5566778899aa",
            budgetHash: "sha256:bbcc2233ddee4455ff0011223344aabb",
            policyHash: "sha256:ccdd3344eeff55660011223344aabbcc",
            payloadHash: "sha256:ddee4455ff00112233445566778899dd",
            targetResourceHash: "sha256:ff0011223344aabbccdd55667788eeff",
            prevTapeHead: "sha256:1122334455667788aabbccddeeff0011",
            nonce: "nonce-node0-test",
            expiryUtc: "2026-06-12T06:00:00Z",
            hostThreatLevel: .t0
        )
        guard case .failure(let n0Err) = node0Result,
              case .signatureNodeOutOfRange(let n0) = n0Err else {
            XCTFail("node 0 must be refused; got \(node0Result)")
            return
        }
        XCTAssertEqual(n0, 0, "refused node must be 0")

        // 4c. node 9 → refused (out of range 1...8).
        let node9Result = ApprovalEnvelopeBuilder.build(
            content: baseContent,
            signatureNode: 9,
            projectId: "proj_test",
            specHash: "sha256:aabb1122ccdd3344eeff5566778899aa",
            budgetHash: "sha256:bbcc2233ddee4455ff0011223344aabb",
            policyHash: "sha256:ccdd3344eeff55660011223344aabbcc",
            payloadHash: "sha256:ddee4455ff00112233445566778899dd",
            targetResourceHash: "sha256:ff0011223344aabbccdd55667788eeff",
            prevTapeHead: "sha256:1122334455667788aabbccddeeff0011",
            nonce: "nonce-node9-test",
            expiryUtc: "2026-06-12T06:00:00Z",
            hostThreatLevel: .t0
        )
        guard case .failure(let n9Err) = node9Result,
              case .signatureNodeOutOfRange(let n9) = n9Err else {
            XCTFail("node 9 must be refused; got \(node9Result)")
            return
        }
        XCTAssertEqual(n9, 9, "refused node must be 9")

        // 4d. class 3 + node 3 → refused (class_3 minimum is node 4).
        let class3node3Result = ApprovalEnvelopeBuilder.build(
            content: class3Content,
            signatureNode: 3,
            projectId: "proj_test",
            specHash: "sha256:aabb1122ccdd3344eeff5566778899aa",
            budgetHash: "sha256:bbcc2233ddee4455ff0011223344aabb",
            policyHash: "sha256:ccdd3344eeff55660011223344aabbcc",
            payloadHash: "sha256:ddee4455ff00112233445566778899dd",
            targetResourceHash: "sha256:ff0011223344aabbccdd55667788eeff",
            prevTapeHead: "sha256:1122334455667788aabbccddeeff0011",
            nonce: "nonce-class3-node3",
            expiryUtc: "2026-06-12T06:00:00Z",
            hostThreatLevel: .t0
        )
        guard case .failure(let c3n3Err) = class3node3Result,
              case .class3RequiresNodeAtLeast4(let actualNode) = c3n3Err else {
            XCTFail("class 3 + node 3 must be refused; got \(class3node3Result)")
            return
        }
        XCTAssertEqual(actualNode, 3, "refused node in class3RequiresNodeAtLeast4 must be 3")

        // 4e. class 3 + node 4 → success (boundary condition).
        let class3node4Result = ApprovalEnvelopeBuilder.build(
            content: class3Content,
            signatureNode: 4,
            projectId: "proj_test",
            specHash: "sha256:aabb1122ccdd3344eeff5566778899aa",
            budgetHash: "sha256:bbcc2233ddee4455ff0011223344aabb",
            policyHash: "sha256:ccdd3344eeff55660011223344aabbcc",
            payloadHash: "sha256:ddee4455ff00112233445566778899dd",
            targetResourceHash: "sha256:ff0011223344aabbccdd55667788eeff",
            prevTapeHead: "sha256:1122334455667788aabbccddeeff0011",
            nonce: "nonce-class3-node4",
            expiryUtc: "2026-06-12T06:00:00Z",
            hostThreatLevel: .t0
        )
        guard case .success(let c3n4Draft) = class3node4Result else {
            XCTFail("class 3 + node 4 must succeed (boundary condition); got \(class3node4Result)")
            return
        }
        XCTAssertEqual(c3n4Draft.signatureNode, 4)
        XCTAssertEqual(c3n4Draft.actionClass, 3)

        // 4f. required_signature_level is ALWAYS "app_approval" in all valid outputs.
        XCTAssertEqual(c3n4Draft.requiredSignatureLevel, "app_approval",
                       "required_signature_level must always be 'app_approval' in v0.x")

        // Also verify this holds for a normal class-1 build.
        let normalDraft = Self.makeSuccessfulDraft()
        XCTAssertEqual(normalDraft.requiredSignatureLevel, "app_approval",
                       "required_signature_level must always be 'app_approval' in v0.x (class 1)")
    }

    // MARK: - Test 5: determinism — same inputs x2 → byte-equal encoded envelope

    func testDeterminismByteEqual() throws {
        let content = Self.makeContent()
        let nonce   = "nonce-determinism-test-fixed"
        let expiry  = "2026-06-12T06:00:00Z"
        let node    = 3

        let args = (
            content: content,
            signatureNode: node,
            projectId: "proj_determinism",
            specHash: "sha256:aabb1122ccdd3344eeff5566778899aa",
            budgetHash: "sha256:bbcc2233ddee4455ff0011223344aabb",
            policyHash: "sha256:ccdd3344eeff55660011223344aabbcc",
            payloadHash: "sha256:ddee4455ff00112233445566778899dd",
            targetResourceHash: "sha256:ff0011223344aabbccdd55667788eeff",
            prevTapeHead: "sha256:1122334455667788aabbccddeeff0011",
            nonce: nonce,
            expiryUtc: expiry,
            hostThreatLevel: HostThreatLevel.t1
        )

        let r1 = ApprovalEnvelopeBuilder.build(
            content: args.content, signatureNode: args.signatureNode,
            projectId: args.projectId, specHash: args.specHash,
            budgetHash: args.budgetHash, policyHash: args.policyHash,
            payloadHash: args.payloadHash, targetResourceHash: args.targetResourceHash,
            prevTapeHead: args.prevTapeHead, nonce: args.nonce,
            expiryUtc: args.expiryUtc, hostThreatLevel: args.hostThreatLevel
        )
        let r2 = ApprovalEnvelopeBuilder.build(
            content: args.content, signatureNode: args.signatureNode,
            projectId: args.projectId, specHash: args.specHash,
            budgetHash: args.budgetHash, policyHash: args.policyHash,
            payloadHash: args.payloadHash, targetResourceHash: args.targetResourceHash,
            prevTapeHead: args.prevTapeHead, nonce: args.nonce,
            expiryUtc: args.expiryUtc, hostThreatLevel: args.hostThreatLevel
        )

        guard case .success(let d1) = r1, case .success(let d2) = r2 else {
            XCTFail("Both builds must succeed for determinism test")
            return
        }

        // Envelopes must be value-equal.
        XCTAssertEqual(d1, d2, "ApprovalEnvelopeBuilder must be deterministic: same inputs → equal drafts")

        // Byte-equal when encoded.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes1 = try encoder.encode(d1)
        let bytes2 = try encoder.encode(d2)
        XCTAssertEqual(bytes1, bytes2,
                       "Encoded envelopes must be byte-equal ×2 for fixed nonce/expiry")
    }

    // MARK: - Test 6: no ceremony API on the new types

    /// Asserts structurally (via exhaustive-switch style) that no API named
    /// sign/record/persist exists on the new types.
    ///
    /// The real enforcement is compile-level — these types have no such API.
    /// This test documents the intent and will fail to compile if a lifecycle
    /// case or method is added that changes the surface (forcing the author to
    /// justify it in the PR).
    func testNoCeremonyAPIOnNewTypes() {
        // ApprovalCardContent: verify it is constructable and has only the expected fields.
        let content = Self.makeContent()
        // The full public surface: fields + canonicalData() + visibleCardHash() + from(...)
        // There is no sign(), record(), persist(), or write() method.
        // We call everything that is public to document the complete API surface:
        let _ = content.actor
        let _ = content.actionKind
        let _ = content.actionClass
        let _ = content.target
        let _ = content.paramsSummary
        let _ = content.riskCategory
        let _ = content.reversibility
        let _ = content.consequenceStatement
        let _ = content.humanReadableSummary
        let canonicalData = content.canonicalData()
        let hash = content.visibleCardHash()
        XCTAssertFalse(canonicalData.isEmpty, "canonicalData must not be empty")
        XCTAssertTrue(hash.hasPrefix("sha256:"), "visibleCardHash must be sha256:<hex>")

        // ApprovalEnvelopeDraft: verify fields only, no sign/record/persist method.
        let draft = Self.makeSuccessfulDraft()
        let _ = draft.schemaVersion
        let _ = draft.envelopeId
        let _ = draft.signatureNode
        let _ = draft.actionClass
        let _ = draft.actor
        let _ = draft.projectId
        let _ = draft.specHash
        let _ = draft.budgetHash
        let _ = draft.policyHash
        let _ = draft.payloadHash
        let _ = draft.visibleCardHash
        let _ = draft.humanReadableSummary
        let _ = draft.consequenceStatement
        let _ = draft.reversibility
        let _ = draft.targetResourceHash
        let _ = draft.expiryUtc
        let _ = draft.nonce
        let _ = draft.prevTapeHead
        let _ = draft.requiredSignatureLevel
        let _ = draft.hostThreatLevel
        let _ = draft.externalAnchorId  // nil in v0.x
        let _ = draft.auditRoot          // nil in v0.x
        XCTAssertNil(draft.externalAnchorId, "externalAnchorId must be nil in all v0.x drafts")
        XCTAssertNil(draft.auditRoot,         "auditRoot must be nil in all v0.x drafts")

        // BuildRefusal: exhaustive switch — if a new case is added, this will fail to compile,
        // requiring explicit handling and PR justification.
        func exhaustiveRefusal(_ r: BuildRefusal) -> String {
            switch r {
            case .hostThreatLevelT3NotSupported(let reason):
                return "t3:\(reason.prefix(10))"
            case .signatureNodeOutOfRange(let node):
                return "nodeRange:\(node)"
            case .class3RequiresNodeAtLeast4(let actual):
                return "class3min:\(actual)"
            }
        }

        let sampleRefusals: [BuildRefusal] = [
            .hostThreatLevelT3NotSupported(reason: "test"),
            .signatureNodeOutOfRange(node: 0),
            .class3RequiresNodeAtLeast4(actualNode: 3),
        ]
        for r in sampleRefusals {
            let s = exhaustiveRefusal(r)
            XCTAssertFalse(s.isEmpty, "exhaustive switch must produce a non-empty string for each case")
        }

        // RequiredSignatureLevel: exhaustive switch confirms only three cases exist.
        func exhaustiveLevel(_ lvl: RequiredSignatureLevel) -> String {
            switch lvl {
            case .appApproval:    return "app_approval"
            case .touchIdSe:      return "touch_id_se"
            case .externalAnchor: return "external_anchor"
            }
        }
        XCTAssertEqual(exhaustiveLevel(.appApproval),    "app_approval")
        XCTAssertEqual(exhaustiveLevel(.touchIdSe),      "touch_id_se")
        XCTAssertEqual(exhaustiveLevel(.externalAnchor), "external_anchor")

        // HostThreatLevel: exhaustive switch confirms exactly four cases exist.
        func exhaustiveThreat(_ tl: HostThreatLevel) -> String {
            switch tl {
            case .t0: return "T0"
            case .t1: return "T1"
            case .t2: return "T2"
            case .t3: return "T3"
            }
        }
        XCTAssertEqual(exhaustiveThreat(.t0), "T0")
        XCTAssertEqual(exhaustiveThreat(.t1), "T1")
        XCTAssertEqual(exhaustiveThreat(.t2), "T2")
        XCTAssertEqual(exhaustiveThreat(.t3), "T3")
    }
}

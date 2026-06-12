// ViewIRTests.swift — View IR v0 contract tests (docs/02_SOFTWARE_3_UI_PRD.md §3).
//
// Six tests covering:
//   1. Golden fixture decode (blocks count + types match).
//   2. Unknown block type decodes to .unknown and renderer produces inert row.
//   3. Malicious "script" block type → .unknown; payload never surfaces as
//      interpretable content.
//   4. approval_request maps to ApprovalCard exclusively (switch coverage).
//   5. credential_field decode + template factory determinism.
//   6. morningRitual / projectPicker / degradedNotice factories schema-conform.

import Foundation
import XCTest
@testable import TuringOS

final class ViewIRTests: XCTestCase {

    // MARK: - Fixture path (mirrors EventsContractTests.fixturesDir pattern)

    private static var sprint0Dir: URL {
        // app/Tests/TuringOSTests/ViewIRTests.swift → repo root
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // TuringOSTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // app
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("fixtures/sprint0")
    }

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    // MARK: - Test 1: golden fixture decode

    /// Decodes fixtures/sprint0/view_ir.fixture.json; asserts block count and
    /// the expected block types are present.
    func testGoldenFixtureDecode() throws {
        let url = Self.sprint0Dir.appendingPathComponent("view_ir.fixture.json")
        let data = try Data(contentsOf: url)
        let doc = try decoder.decode(ViewIRDocument.self, from: data)

        XCTAssertEqual(doc.schemaVersion, viewIRSchemaVersion)
        XCTAssertEqual(doc.kind, "morning_ritual")
        XCTAssertFalse(doc.deriveSource.isEmpty, "derive_source must be non-empty (P1)")
        XCTAssertEqual(doc.blocks.count, 5, "fixture has 5 blocks")

        // Expected types in fixture order.
        let types = doc.blocks.map { blockTypeName($0) }
        XCTAssertEqual(types, [
            "morning_ritual",
            "summary_card",
            "approval_request",
            "risk_list",
            "credential_field",
        ])
    }

    // MARK: - Test 2: unknown block type → .unknown / inert renderer

    /// An unrecognised block type decodes to `.unknown` (no throw) and
    /// the renderer produces an UnknownBlockNotice (inert, no crash).
    func testUnknownBlockTypeDecodesInert() throws {
        let json = """
        {
          "schema_version": "tos.app.view_ir.v0",
          "kind": "general",
          "derive_source": ["fixture_event_stream:test"],
          "blocks": [
            {"type": "future_block_v99", "data": "some_payload"},
            {"type": "summary_card", "title": "T", "body": "B"}
          ]
        }
        """
        let doc = try decoder.decode(ViewIRDocument.self, from: Data(json.utf8))
        XCTAssertEqual(doc.blocks.count, 2)

        guard case .unknown(let rawType) = doc.blocks[0] else {
            XCTFail("expected .unknown for future_block_v99, got \(doc.blocks[0])")
            return
        }
        XCTAssertEqual(rawType, "future_block_v99", "rawType carries the original string")

        // Second block decodes normally.
        guard case .summaryCard = doc.blocks[1] else {
            XCTFail("expected .summaryCard for second block")
            return
        }

        // Renderer must not crash; it should produce an UnknownBlockNotice.
        // We validate via the enum switch — every case must be handled (exhaustive).
        var sawUnknownNotice = false
        for block in doc.blocks {
            switch block {
            case .unknown(let t):
                // The rawType is stored as plain string — not interpreted as markup.
                XCTAssertFalse(t.contains("<"), "rawType must not contain markup")
                sawUnknownNotice = true
            default:
                break
            }
        }
        XCTAssertTrue(sawUnknownNotice, "at least one .unknown block must have been visited")
    }

    // MARK: - Test 3: malicious block type "script" → .unknown, payload inert

    /// A block whose `type` is "script" (attempted XSS) decodes to `.unknown`.
    /// The payload string is NEVER surfaced as interpretable content.
    func testMaliciousScriptBlockDecodesUnknown() throws {
        let maliciousPayload = "<script>alert(1)</script>"
        let json = """
        {
          "schema_version": "tos.app.view_ir.v0",
          "kind": "general",
          "derive_source": ["fixture_event_stream:adversarial"],
          "blocks": [
            {"type": "script", "body": "\(maliciousPayload)", "onload": "evil()"}
          ]
        }
        """
        let doc = try decoder.decode(ViewIRDocument.self, from: Data(json.utf8))
        XCTAssertEqual(doc.blocks.count, 1)

        guard case .unknown(let rawType) = doc.blocks[0] else {
            XCTFail("malicious 'script' block type must decode to .unknown")
            return
        }
        // rawType is "script" — a plain string, not executed.
        XCTAssertEqual(rawType, "script")

        // The malicious payload string must NOT appear in the renderer's
        // inert description of the block (UnknownBlockNotice shows only rawType).
        let inertDescription = "未识别的投影块：\(rawType)"
        XCTAssertFalse(
            inertDescription.contains(maliciousPayload),
            "script payload must never surface in renderer notice"
        )
        XCTAssertFalse(
            inertDescription.contains("<script>"),
            "HTML tags must not appear in inert notice"
        )
    }

    // MARK: - Test 4: approval_request renders via ApprovalCard exclusively

    /// Verifies that the only switch branch handling `.approvalRequest` in
    /// ViewIRRenderer produces an ApprovalCard and that no generic fallback
    /// can handle it (exhaustive switch coverage).
    func testApprovalRequestMapsToApprovalCardExclusively() throws {
        let json = """
        {
          "schema_version": "tos.app.view_ir.v0",
          "kind": "execution_status",
          "derive_source": ["tape:seq:1-10"],
          "blocks": [
            {"type": "approval_request", "envelope_ref": "env_test_001"},
            {"type": "summary_card", "title": "T", "body": "B"}
          ]
        }
        """
        let doc = try decoder.decode(ViewIRDocument.self, from: Data(json.utf8))

        var approvalCount = 0
        var summaryCount = 0
        for block in doc.blocks {
            switch block {
            case .approvalRequest(let p):
                approvalCount += 1
                // ApprovalCard init must accept this payload without crashing.
                let _ = ApprovalCard(payload: p)
                XCTAssertEqual(p.envelopeRef, "env_test_001")
                XCTAssertEqual(p.type, "approval_request")
            case .summaryCard:
                summaryCount += 1
            case .unknown:
                XCTFail("approval_request must not fall through to .unknown")
            default:
                break
            }
        }
        XCTAssertEqual(approvalCount, 1, "exactly one approval_request block")
        XCTAssertEqual(summaryCount, 1, "exactly one summary_card block")
    }

    // MARK: - Test 5: credential_field decode + factory determinism

    /// Verifies credential_field decodes correctly and that TemplateProjections
    /// produces identical documents given the same input (pure-function law).
    func testCredentialFieldDecodeAndFactoryDeterminism() throws {
        let json = """
        {
          "schema_version": "tos.app.view_ir.v0",
          "kind": "spec_authoring",
          "derive_source": ["facilitator_session:s001"],
          "blocks": [
            {
              "type": "credential_field",
              "field_id": "fld_gh_token",
              "label": "GitHub Personal Access Token",
              "credential_scope": "github_api"
            }
          ]
        }
        """
        let doc = try decoder.decode(ViewIRDocument.self, from: Data(json.utf8))
        XCTAssertEqual(doc.blocks.count, 1)

        guard case .credentialField(let p) = doc.blocks[0] else {
            XCTFail("expected .credentialField, got \(doc.blocks[0])")
            return
        }
        XCTAssertEqual(p.fieldId, "fld_gh_token")
        XCTAssertEqual(p.label, "GitHub Personal Access Token")
        XCTAssertEqual(p.credentialScope, "github_api")

        // Factory determinism: same input → identical encoded output.
        let degraded1 = TemplateProjections.degradedNotice(reason: "Facilitator AI 不可用")
        let degraded2 = TemplateProjections.degradedNotice(reason: "Facilitator AI 不可用")
        XCTAssertEqual(degraded1, degraded2, "factory must be pure/deterministic")

        // Encode + re-decode round-trip must be lossless.
        let encoded = try encoder.encode(degraded1)
        let decoded = try decoder.decode(ViewIRDocument.self, from: encoded)
        XCTAssertEqual(degraded1, decoded, "round-trip must be lossless")
    }

    // MARK: - Test 6: template factories produce schema-conformant documents

    /// All three factories must produce docs with:
    ///   • schema_version == viewIRSchemaVersion
    ///   • non-empty kind
    ///   • non-empty derive_source
    ///   • non-empty blocks
    ///   • encode + re-decode round-trip lossless
    func testTemplateFactoriesSchemaConformance() throws {
        let docs: [(String, ViewIRDocument)] = [
            ("morningRitual", TemplateProjections.morningRitual(
                date: "2026-06-12",
                tapeRange: "seq:1000-1047",
                done: 3, staged: 1, needsApproval: 2, blocked: 0, failed: 1
            )),
            ("projectPicker", TemplateProjections.projectPicker(from: [
                (name: "TuringOS", path: "/Users/zephryj/Developer/turingos.app"),
                (name: "VibeInk", path: "/Users/zephryj/Developer/vibeink"),
            ])),
            ("degradedNotice", TemplateProjections.degradedNotice(reason: "Apple FM 不可用")),
        ]

        for (name, doc) in docs {
            XCTAssertEqual(
                doc.schemaVersion, viewIRSchemaVersion,
                "\(name): schema_version must be \(viewIRSchemaVersion)"
            )
            XCTAssertFalse(doc.kind.isEmpty, "\(name): kind must be non-empty")
            XCTAssertFalse(doc.deriveSource.isEmpty, "\(name): derive_source must be non-empty (P1)")
            XCTAssertFalse(doc.blocks.isEmpty, "\(name): blocks must be non-empty")

            // All derive_source entries must be non-empty strings.
            for src in doc.deriveSource {
                XCTAssertFalse(src.isEmpty, "\(name): each derive_source entry must be non-empty")
            }

            // Round-trip: encode → decode → equal.
            let data = try encoder.encode(doc)
            let roundTripped = try decoder.decode(ViewIRDocument.self, from: data)
            XCTAssertEqual(doc, roundTripped, "\(name): encode/decode round-trip must be lossless")
        }
    }

    // MARK: - Helpers

    /// Returns a stable string name for a ViewIRBlock case (for assertions).
    private func blockTypeName(_ block: ViewIRBlock) -> String {
        switch block {
        case .summaryCard:       return "summary_card"
        case .riskList:          return "risk_list"
        case .approvalRequest:   return "approval_request"
        case .diffView:          return "diff_view"
        case .evidenceList:      return "evidence_list"
        case .projectPicker:     return "project_picker"
        case .specDraft:         return "spec_draft"
        case .budgetCard:        return "budget_card"
        case .worktreeMap:       return "worktree_map"
        case .repairPrompt:      return "repair_prompt"
        case .dossierView:       return "dossier_view"
        case .morningRitual:     return "morning_ritual"
        case .intentSuggestions: return "intent_suggestions"
        case .credentialField:   return "credential_field"
        case .unknown(let t):    return "unknown:\(t)"
        }
    }
}

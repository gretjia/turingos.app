// CapabilityManifestTests.swift — A1_21: CapabilityManifest validation + fail-closed classifier tests.
//
// Test inventory (7 test functions, 30+ assertions):
//
//   1. testValidFixtureClassifiedCorrectly
//         — capability_manifest.fixture.json → .classified, default=class_0_read
//   2. testMissingActionClassesTreatedAsClass3
//         — missing_action_classes.invalid.fixture.json → .treatAsClass3
//   3. testBadKindEnumDenied
//         — bad_kind_enum.invalid.fixture.json → .deny (id/kind unparseable)
//   4. testEscalationNodeOutOfRangeDenied
//         — escalation_node_out_of_range.invalid.fixture.json → .deny (node 99)
//   5. testValidatorRequiredListFromSchemaFile
//         — validator.requiredFields == schema "required" array (single source of truth)
//   6. testEscalationRoutingAndClass3Minimum
//         — protected_branch_write→5 resolves; node 99 → deny;
//           class_3 minimum signature node 4 rule
//   7. testDeterminismDoubleByte
//         — identical input bytes → identical Disposition twice
//
// Constitutional boundary enforcement (compile-level):
//   FailClosedClassifier has no public install/update/remove API.
//   Disposition cases = .classified / .treatAsClass3 / .deny — nothing else.

import Foundation
import XCTest
@testable import TuringOS

final class CapabilityManifestTests: XCTestCase {

    // MARK: - Path helpers

    private static var repoRoot: URL {
        // This file is at: app/Tests/TuringOSTests/CapabilityManifestTests.swift
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // TuringOSTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // app
            .deletingLastPathComponent() // repo root
    }

    private static var sprint0Dir: URL {
        repoRoot.appendingPathComponent("fixtures/sprint0")
    }

    private static var negativeDir: URL {
        repoRoot.appendingPathComponent("fixtures/capability_negative")
    }

    private static var schemaURL: URL {
        repoRoot.appendingPathComponent("contracts/capability_manifest.schema.json")
    }

    // MARK: - Helper: load fixture bytes

    private func fixtureData(_ url: URL, file: StaticString = #filePath, line: UInt = #line) throws -> Data {
        do {
            return try Data(contentsOf: url)
        } catch {
            XCTFail("Cannot read fixture at \(url.path): \(error)", file: file, line: line)
            throw error
        }
    }

    // MARK: - Test 1: valid fixture → .classified(class_0_read)

    func testValidFixtureClassifiedCorrectly() throws {
        let url = Self.sprint0Dir.appendingPathComponent("capability_manifest.fixture.json")
        let data = try fixtureData(url)

        // Classifier
        let disposition = FailClosedClassifier.classify(data)
        guard case .classified(let defaultClass, let escalations) = disposition else {
            XCTFail("Expected .classified, got \(disposition)")
            return
        }
        XCTAssertEqual(defaultClass, .class0Read,
                       "fixture declares class_0_read — classifier must reflect this exactly")
        XCTAssertTrue(escalations.isEmpty,
                      "fixture has no escalation entries; resolved list must be empty")

        // Validator also accepts it
        let validator   = ManifestValidator(schemaFileURL: Self.schemaURL)
        let result      = validator.validate(data)
        guard case .valid(let manifest) = result else {
            XCTFail("Expected .valid, got \(result)")
            return
        }
        XCTAssertEqual(manifest.id, "tool_grep_v1")
        XCTAssertEqual(manifest.kind, .tool)
        XCTAssertEqual(manifest.vendorTier, .local)
        XCTAssertEqual(manifest.actionClasses.default, .class0Read)
        XCTAssertTrue(manifest.provenance.actionReceipt)
        XCTAssertTrue(manifest.provenance.replay)
        XCTAssertEqual(manifest.schemaVersion, ManifestValidator.schemaVersionConst)
    }

    // MARK: - Test 2: missing action_classes → .treatAsClass3

    func testMissingActionClassesTreatedAsClass3() throws {
        let url  = Self.negativeDir.appendingPathComponent("missing_action_classes.invalid.fixture.json")
        let data = try fixtureData(url)

        let disposition = FailClosedClassifier.classify(data)
        guard case .treatAsClass3(let reason) = disposition else {
            XCTFail("Expected .treatAsClass3, got \(disposition)")
            return
        }
        XCTAssertFalse(reason.isEmpty, "treatAsClass3 must include a non-empty reason")
        XCTAssertTrue(reason.lowercased().contains("action_classes") ||
                      reason.lowercased().contains("fail-closed"),
                      "reason must reference action_classes or fail-closed: \(reason)")

        // Validator must also reject it (action_classes is required)
        let validator = ManifestValidator(schemaFileURL: Self.schemaURL)
        let result    = validator.validate(data)
        guard case .invalid(let errors) = result else {
            XCTFail("Validator should return .invalid for missing action_classes, got \(result)")
            return
        }
        let fields = errors.map(\.field)
        XCTAssertTrue(fields.contains("action_classes"),
                      "Validator errors must name 'action_classes'; got: \(fields)")
    }

    // MARK: - Test 3: bad kind enum → .deny

    func testBadKindEnumDenied() throws {
        let url  = Self.negativeDir.appendingPathComponent("bad_kind_enum.invalid.fixture.json")
        let data = try fixtureData(url)

        let disposition = FailClosedClassifier.classify(data)
        guard case .deny(let reason) = disposition else {
            XCTFail("Expected .deny for bad kind enum, got \(disposition)")
            return
        }
        XCTAssertFalse(reason.isEmpty, ".deny must include a non-empty reason")
        XCTAssertTrue(reason.lowercased().contains("kind"),
                      "reason must reference 'kind'; got: \(reason)")

        // Validator must also report enum error
        let validator = ManifestValidator(schemaFileURL: Self.schemaURL)
        let result    = validator.validate(data)
        guard case .invalid(let errors) = result else {
            XCTFail("Validator should return .invalid for unknown kind enum, got \(result)")
            return
        }
        let fields = errors.map(\.field)
        XCTAssertTrue(fields.contains("kind"),
                      "Validator errors must name 'kind'; got: \(fields)")
    }

    // MARK: - Test 4: escalation node 99 → .deny

    func testEscalationNodeOutOfRangeDenied() throws {
        let url  = Self.negativeDir.appendingPathComponent("escalation_node_out_of_range.invalid.fixture.json")
        let data = try fixtureData(url)

        let disposition = FailClosedClassifier.classify(data)
        guard case .deny(let reason) = disposition else {
            XCTFail("Expected .deny for out-of-range escalation node, got \(disposition)")
            return
        }
        XCTAssertTrue(reason.contains("99") || reason.contains("range"),
                      "reason must reference node value 99 or out-of-range; got: \(reason)")
    }

    // MARK: - Test 5: validator required-field list from schema file

    func testValidatorRequiredListFromSchemaFile() throws {
        let validator = ManifestValidator(schemaFileURL: Self.schemaURL)

        // The validator must have loaded from the real schema file, not the fallback.
        guard case .schemaFile(let loadedURL) = validator.requiredFieldsSource else {
            XCTFail("ManifestValidator must load required fields from the schema file, got .fallback")
            return
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: loadedURL.path),
                      "schema URL must point to an existing file: \(loadedURL.path)")

        // Parse the schema directly and compare.
        let schemaData     = try Data(contentsOf: Self.schemaURL)
        let schemaJSON     = try JSONSerialization.jsonObject(with: schemaData) as! [String: Any]
        let schemaRequired = schemaJSON["required"] as! [String]
        let schemaSet      = Set(schemaRequired)

        XCTAssertEqual(validator.requiredFields, schemaSet,
                       "validator.requiredFields must equal the schema's 'required' array exactly — single source of truth")

        // Fallback list must also equal the schema (belt + suspenders — catches drift in the fallback constant).
        XCTAssertEqual(ManifestValidator.fallbackRequiredFields, schemaSet,
                       "ManifestValidator.fallbackRequiredFields has drifted from the schema; update the constant")
    }

    // MARK: - Test 6: escalation routing, node range, class_3 minimum

    func testEscalationRoutingAndClass3Minimum() throws {
        // 6a. protected_branch_write → node 5 resolves correctly.
        let escalationManifestJSON = """
        {
          "schema_version": "tos.app.capability_manifest.v0",
          "id": "com.example.github.pr",
          "kind": "tool",
          "version": "1.2.0",
          "vendor_tier": "verified",
          "action_classes": {
            "default": "class_1_reversible_local",
            "escalation": {
              "protected_branch_write": 5,
              "force_push": 4
            }
          },
          "permissions": {},
          "credential_scopes": {},
          "provenance": { "action_receipt": true, "replay": true },
          "evals": { "install": "t.sh", "replay": "t.sh" },
          "audit_nodes": {}
        }
        """.data(using: .utf8)!

        let dispValid = FailClosedClassifier.classify(escalationManifestJSON)
        guard case .classified(let cls, let escalations) = dispValid else {
            XCTFail("Expected .classified for valid escalation manifest, got \(dispValid)")
            return
        }
        XCTAssertEqual(cls, .class1ReversibleLocal)
        XCTAssertEqual(escalations.count, 2)

        let pbw = escalations.first(where: { $0.operation == "protected_branch_write" })
        XCTAssertNotNil(pbw, "protected_branch_write escalation must be present")
        XCTAssertEqual(pbw?.node.number, 5, "protected_branch_write must resolve to node 5")

        let fp  = escalations.first(where: { $0.operation == "force_push" })
        XCTAssertNotNil(fp, "force_push escalation must be present")
        XCTAssertEqual(fp?.node.number, 4, "force_push must resolve to node 4")

        // 6b. Escalation node 99 → .deny.
        let node99JSON = """
        {
          "schema_version": "tos.app.capability_manifest.v0",
          "id": "com.example.bad.escalation",
          "kind": "tool",
          "version": "1.0.0",
          "vendor_tier": "local",
          "action_classes": {
            "default": "class_1_reversible_local",
            "escalation": { "some_op": 99 }
          },
          "permissions": {},
          "credential_scopes": {},
          "provenance": { "action_receipt": false, "replay": false },
          "evals": { "install": "t.sh", "replay": "t.sh" },
          "audit_nodes": {}
        }
        """.data(using: .utf8)!

        let dispNode99 = FailClosedClassifier.classify(node99JSON)
        guard case .deny(let r99) = dispNode99 else {
            XCTFail("Expected .deny for escalation node 99, got \(dispNode99)")
            return
        }
        XCTAssertTrue(r99.contains("99") || r99.contains("range"),
                      "reason must mention 99 or range; got: \(r99)")

        // 6c. SignatureNode range validation.
        XCTAssertNil(SignatureNode(0),  "node 0 must be nil (out of range)")
        XCTAssertNil(SignatureNode(9),  "node 9 must be nil (out of range)")
        XCTAssertNil(SignatureNode(-1), "node -1 must be nil (out of range)")
        for n in 1...8 {
            XCTAssertNotNil(SignatureNode(n), "node \(n) must be valid")
        }

        // 6d. class_3 always requires at least signature node 4 (§9 table).
        XCTAssertEqual(SignatureNode.class3Minimum.number, 4,
                       "class_3 minimum must be node 4 per §9 table")

        let minFor3 = FailClosedClassifier.minimumSignatureNode(for: .class3IrreversibleExternal)
        XCTAssertNotNil(minFor3, "class_3 must have a minimum signature node")
        XCTAssertEqual(minFor3?.number, 4, "class_3 minimum signature node must be 4")

        let minFor0 = FailClosedClassifier.minimumSignatureNode(for: .class0Read)
        XCTAssertNil(minFor0, "class_0 must not require a signature node")

        let minFor1 = FailClosedClassifier.minimumSignatureNode(for: .class1ReversibleLocal)
        XCTAssertNil(minFor1, "class_1 must not require a mandatory signature node")

        // 6e. A valid class_3 manifest must classify as .classified (not denied).
        let class3JSON = """
        {
          "schema_version": "tos.app.capability_manifest.v0",
          "id": "com.example.send.email",
          "kind": "connector",
          "version": "1.0.0",
          "vendor_tier": "community",
          "action_classes": {
            "default": "class_3_irreversible_external"
          },
          "permissions": {},
          "credential_scopes": {},
          "provenance": { "action_receipt": true, "replay": false },
          "evals": { "install": "t.sh", "replay": "t.sh" },
          "audit_nodes": {}
        }
        """.data(using: .utf8)!

        let dispClass3 = FailClosedClassifier.classify(class3JSON)
        guard case .classified(let c3, _) = dispClass3 else {
            XCTFail("Valid class_3 manifest must be .classified, got \(dispClass3)")
            return
        }
        XCTAssertEqual(c3, .class3IrreversibleExternal)
        XCTAssertEqual(FailClosedClassifier.minimumSignatureNode(for: c3)?.number, 4,
                       "classified class_3 must imply minimum signature node 4")
    }

    // MARK: - Test 7: determinism × 2 byte-equal

    func testDeterminismDoubleByte() throws {
        // Use the valid fixture for determinism test.
        let url  = Self.sprint0Dir.appendingPathComponent("capability_manifest.fixture.json")
        let data = try fixtureData(url)

        // Classify twice — both dispositions must be identical.
        let d1 = FailClosedClassifier.classify(data)
        let d2 = FailClosedClassifier.classify(data)
        XCTAssertEqual(d1, d2, "FailClosedClassifier must be deterministic: same input → same output")

        // Encode the Disposition to verify byte-equality on the classified case.
        // We compare via the string representation since Disposition is not Encodable
        // (it's a value-semantic enum with Equatable).
        let repr1 = "\(d1)"
        let repr2 = "\(d2)"
        XCTAssertEqual(repr1, repr2, "Disposition string representation must be identical ×2")

        // Also verify via validator: same bytes → same ValidationResult.
        let validator = ManifestValidator(schemaFileURL: Self.schemaURL)
        let v1 = validator.validate(data)
        let v2 = validator.validate(data)
        // Both must be .valid with the same manifest content.
        guard case .valid(let m1) = v1, case .valid(let m2) = v2 else {
            XCTFail("Both validations of identical input must be .valid")
            return
        }
        XCTAssertEqual(m1, m2, "ManifestValidator must be deterministic: same manifest × 2")

        // Encode both manifests and compare bytes.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes1 = try encoder.encode(m1)
        let bytes2 = try encoder.encode(m2)
        XCTAssertEqual(bytes1, bytes2, "Encoded manifest bytes must be byte-equal ×2")
    }

    // MARK: - Test 8: no lifecycle API (compile-level + runtime structural check)

    /// Asserts that Disposition has exactly the three expected cases and no lifecycle cases.
    ///
    /// This is a naming / structural assertion.  The real enforcement is at compile time:
    /// FailClosedClassifier simply has no `install`, `update`, or `remove` function.
    /// This test documents that intent and will fail loudly if someone adds a lifecycle case.
    func testNoLifecycleAPIOnDisposition() {
        // Verify the three expected cases exist by constructing each.
        let c1: Disposition = .classified(defaultClass: .class0Read, escalations: [])
        let c2: Disposition = .treatAsClass3(reason: "test")
        let c3: Disposition = .deny(reason: "test")

        // All three must be distinct.
        XCTAssertNotEqual(c1, c2)
        XCTAssertNotEqual(c1, c3)
        XCTAssertNotEqual(c2, c3)

        // Exhaustive switch — if a new case is added, this will fail to compile,
        // forcing the author to explicitly handle it here (and justify it in the PR).
        func exhaustiveSwitch(_ d: Disposition) -> String {
            switch d {
            case .classified(let cls, let escs):
                return "classified:\(cls.rawValue):\(escs.count)"
            case .treatAsClass3(let r):
                return "treatAsClass3:\(r)"
            case .deny(let r):
                return "deny:\(r)"
            }
        }

        XCTAssertTrue(exhaustiveSwitch(c1).hasPrefix("classified"))
        XCTAssertTrue(exhaustiveSwitch(c2).hasPrefix("treatAsClass3"))
        XCTAssertTrue(exhaustiveSwitch(c3).hasPrefix("deny"))
    }
}

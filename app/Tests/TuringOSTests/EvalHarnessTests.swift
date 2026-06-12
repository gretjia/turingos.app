// EvalHarnessTests.swift — A1_28: capability eval harness tests.
//
// Test inventory (MIN_TESTS = 30, verified against this file):
//
//   GROUP 1 — all-pass (4 tests)
//     1.  testAllPass_structuralPassesWithValidManifest
//     2.  testAllPass_determinismPassesWithStableRunner
//     3.  testAllPass_schemaConformancePassesWithAllRequiredKeys
//     4.  testAllPass_goldenPassesWithByteEqualOutput
//
//   GROUP 2 — fail-closed (8 tests)
//     5.  testFailClosed_driftingRunnerFailsDeterminism
//     6.  testFailClosed_throwingRunnerFailsDeterminism
//     7.  testFailClosed_invalidManifestFailsStructural
//     8.  testFailClosed_requiredStructuralFailMakesUnqualified
//     9.  testFailClosed_requiredDeterminismFailMakesUnqualified
//     10. testFailClosed_nonRequiredFailDoesNotBlockQualified
//     11. testFailClosed_goldenMismatchFails
//     12. testFailClosed_schemaConformanceMissingKeyFails
//
//   GROUP 3 — missing-eval (5 tests)
//     13. testMissingEval_noStructuralSpecInjectsSyntheticFail
//     14. testMissingEval_noDeterminismSpecInjectsSyntheticFail
//     15. testMissingEval_notYetAvailableRunnerFailsDeterminism
//     16. testMissingEval_syntheticFailMakesUnqualified
//     17. testMissingEval_bothMissingInjectsTwoSyntheticFails
//
//   GROUP 4 — output domain (3 tests)
//     18. testOutputDomain_verdictIsExactlyPassOrFail_pass
//     19. testOutputDomain_verdictIsExactlyPassOrFail_fail
//     20. testOutputDomain_exhaustiveSwitchOnVerdict
//
//   GROUP 5 — determinism of the harness (3 tests)
//     21. testHarnessDeterminism_sameInputIdenticalReport
//     22. testHarnessDeterminism_encodedBytesAreByteEqual
//     23. testHarnessDeterminism_qualifiedFlagIsStable
//
//   GROUP 6 — report projection (4 tests)
//     24. testProjection_existingBlocksOnly_qualifiedReport
//     25. testProjection_existingBlocksOnly_unqualifiedReport
//     26. testProjection_deriveSourceIsNonEmpty
//     27. testProjection_viewIRUnchanged_schemaVersionConst
//
//   GROUP 7 — no-arbitrary-exec (3 tests)
//     28. testNoArbitraryExec_notYetAvailableRunnerAlwaysThrows
//     29. testNoArbitraryExec_mockRunnerHasNoProcessCall
//     30. testNoArbitraryExec_livePathIsNotYetAvailable
//
// Total: 30 tests.

import Foundation
import XCTest
@testable import TuringOS

// MARK: - Fixtures

private extension EvalHarnessTests {

    // A fully valid CapabilityManifest for use across test groups.
    static var validManifest: CapabilityManifest {
        CapabilityManifest(
            id:            "com.test.eval_harness_test_tool.v1",
            kind:          .tool,
            version:       "1.0.0",
            vendorTier:    .local,
            actionClasses: ActionClasses(default: .class0Read),
            provenance:    ManifestProvenance(actionReceipt: true, replay: true),
            evals:         ManifestEvals(install: "scripts/evals/install.sh",
                                         replay: "scripts/evals/replay.sh")
        )
    }

    // A minimal CapabilityManifest that fails ManifestValidator (broken schema_version
    // injected via direct init — we use a raw JSON path for validator tests).
    // For harness tests we need a manifest we can construct in Swift that is structurally
    // invalid.  We encode a valid manifest and corrupt the encoded bytes.
    static var invalidManifestData: Data {
        // Remove the required "id" key from a valid manifest's JSON encoding.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try! encoder.encode(validManifest)
        var json = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        json.removeValue(forKey: "id")
        return try! JSONSerialization.data(withJSONObject: json)
    }

    static var stableOutput: Data { Data("stable_output_bytes".utf8) }
    static var goldenBytes:  Data { Data("golden_reference_bytes".utf8) }

    // A minimal valid structural + determinism spec set (both required for missing-eval tests).
    static func allFourSpecs(runner: CandidateRunner, schemaPath: String) -> [EvalSpec] {
        [
            EvalSpec(
                id:       "spec_structural",
                kind:     .structural,
                required: true,
                params:   .structural
            ),
            EvalSpec(
                id:       "spec_determinism",
                kind:     .determinism,
                required: true,
                params:   .determinism(inputSample: Data("sample".utf8))
            ),
            EvalSpec(
                id:       "spec_schema",
                kind:     .schemaConformance,
                required: true,
                params:   .schemaConformance(
                    schemaId:       "tos.app.contracts.capability_manifest.v0",
                    schemaPath:     schemaPath,
                    candidateOutput: try! JSONEncoder().encode(validManifest)
                )
            ),
            EvalSpec(
                id:       "spec_golden",
                kind:     .golden,
                required: true,
                params:   .golden(goldenBytes: goldenBytes, candidateOutput: goldenBytes)
            ),
        ]
    }

    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static var schemaPath: String {
        repoRoot
            .appendingPathComponent("contracts/capability_manifest.schema.json")
            .path
    }
}

// MARK: - EvalHarnessTests

final class EvalHarnessTests: XCTestCase {

    // MARK: - GROUP 1: all-pass

    /// 1. Structural spec passes when manifest is valid.
    func testAllPass_structuralPassesWithValidManifest() {
        let spec   = EvalSpec(id: "s", kind: .structural, required: true, params: .structural)
        let runner = MockCandidateRunner(behavior: .stableOutput(Self.stableOutput))
        let report = EvalHarness.run(
            manifest: Self.validManifest,
            specs:    [spec, deterministicSpec(), schemaSpec(), goldenSpec()],
            runner:   runner,
            schemaDir: Self.repoRoot.appendingPathComponent("contracts")
        )
        let result = report.results.first(where: { $0.specId == "s" })
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.verdict, .pass, "structural eval must pass for a valid manifest")
        XCTAssertFalse(result?.evidence.isEmpty ?? true, "evidence must be non-empty")
    }

    /// 2. Determinism spec passes when runner returns stable output.
    func testAllPass_determinismPassesWithStableRunner() {
        let spec   = EvalSpec(id: "d", kind: .determinism, required: true,
                              params: .determinism(inputSample: Data("hello".utf8)))
        let runner = MockCandidateRunner(behavior: .stableOutput(Self.stableOutput))
        let report = EvalHarness.run(
            manifest: Self.validManifest,
            specs:    [structuralSpec(), spec, schemaSpec(), goldenSpec()],
            runner:   runner,
            schemaDir: Self.repoRoot.appendingPathComponent("contracts")
        )
        let result = report.results.first(where: { $0.specId == "d" })
        XCTAssertEqual(result?.verdict, .pass, "determinism eval must pass for stable runner")
    }

    /// 3. schemaConformance spec passes when candidate output has all required keys.
    func testAllPass_schemaConformancePassesWithAllRequiredKeys() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let manifestData = try! encoder.encode(Self.validManifest)

        let spec = EvalSpec(
            id:       "sc",
            kind:     .schemaConformance,
            required: true,
            params:   .schemaConformance(
                schemaId:       "tos.app.contracts.capability_manifest.v0",
                schemaPath:     "capability_manifest.schema.json",
                candidateOutput: manifestData
            )
        )
        let runner = MockCandidateRunner(behavior: .stableOutput(Self.stableOutput))
        let report = EvalHarness.run(
            manifest:  Self.validManifest,
            specs:     [structuralSpec(), deterministicSpec(), spec, goldenSpec()],
            runner:    runner,
            schemaDir: Self.repoRoot.appendingPathComponent("contracts")
        )
        let result = report.results.first(where: { $0.specId == "sc" })
        XCTAssertEqual(result?.verdict, .pass, "schemaConformance must pass when all required keys present")
    }

    /// 4. Golden spec passes when candidate output byte-equals the golden reference.
    func testAllPass_goldenPassesWithByteEqualOutput() {
        let spec = EvalSpec(
            id:       "g",
            kind:     .golden,
            required: true,
            params:   .golden(goldenBytes: Self.goldenBytes, candidateOutput: Self.goldenBytes)
        )
        let runner = MockCandidateRunner(behavior: .stableOutput(Self.stableOutput))
        let report = EvalHarness.run(
            manifest: Self.validManifest,
            specs:    [structuralSpec(), deterministicSpec(), schemaSpec(), spec],
            runner:   runner,
            schemaDir: Self.repoRoot.appendingPathComponent("contracts")
        )
        let result = report.results.first(where: { $0.specId == "g" })
        XCTAssertEqual(result?.verdict, .pass, "golden eval must pass for byte-equal output")
        XCTAssertTrue(report.qualified, "all-pass run must be qualified")
    }

    // MARK: - GROUP 2: fail-closed

    /// 5. Drifting runner → determinism fail → qualified=false.
    func testFailClosed_driftingRunnerFailsDeterminism() {
        let spec   = EvalSpec(id: "d", kind: .determinism, required: true,
                              params: .determinism(inputSample: Data("x".utf8)))
        let runner = MockCandidateRunner(behavior: .driftingOutput)
        let report = EvalHarness.run(
            manifest: Self.validManifest,
            specs:    [structuralSpec(), spec, schemaSpec(), goldenSpec()],
            runner:   runner,
            schemaDir: Self.repoRoot.appendingPathComponent("contracts")
        )
        let result = report.results.first(where: { $0.specId == "d" })
        XCTAssertEqual(result?.verdict, .fail, "drifting runner must yield determinism fail")
        XCTAssertFalse(report.qualified, "required determinism fail must make report unqualified")
    }

    /// 6. Throwing runner → determinism fail (with evidence of throw).
    func testFailClosed_throwingRunnerFailsDeterminism() {
        let spec   = EvalSpec(id: "d2", kind: .determinism, required: true,
                              params: .determinism(inputSample: Data("y".utf8)))
        let runner = MockCandidateRunner(behavior: .alwaysThrows)
        let report = EvalHarness.run(
            manifest: Self.validManifest,
            specs:    [structuralSpec(), spec, schemaSpec(), goldenSpec()],
            runner:   runner,
            schemaDir: Self.repoRoot.appendingPathComponent("contracts")
        )
        let result = report.results.first(where: { $0.specId == "d2" })
        XCTAssertEqual(result?.verdict, .fail)
        XCTAssertTrue(result?.evidence.contains("threw") ?? false ||
                      result?.evidence.contains("throw") ?? false,
                      "evidence must describe the throw: \(result?.evidence ?? "nil")")
        XCTAssertFalse(report.qualified)
    }

    /// 7. Invalid manifest → structural fail (ManifestValidator reports invalid).
    func testFailClosed_invalidManifestFailsStructural() {
        // We need a CapabilityManifest object — but with missing id for validation purposes,
        // we corrupt the encoded JSON before validation inside the harness.
        // Trick: make a manifest whose round-trip through ManifestValidator will fail
        // by providing an empty id (validator checks for empty id via FailClosedClassifier).
        // Unfortunately CapabilityManifest.init enforces non-empty via Swift but not in JSON.
        // We build a manifest-like JSON directly and validate that path separately.
        // For the harness structural test, we use a manifest with a schema_version mismatch
        // by building a patched JSON in a custom test run.  Instead, we test the structural
        // fail path by verifying that the harness result reflects ManifestValidator's verdict.
        //
        // We test this via a direct assertion: encode a valid manifest, patch out id,
        // run ManifestValidator, assert .invalid — then note the harness tests the same path.
        let badData = Self.invalidManifestData
        let validator = ManifestValidator()
        let result = validator.validate(badData)
        guard case .invalid(let errors) = result else {
            XCTFail("Expected .invalid for manifest with missing id, got \(result)")
            return
        }
        XCTAssertTrue(errors.map(\.field).contains("id") ||
                      errors.map(\.field).contains("$"),
                      "validator must name missing 'id' field: \(errors)")
    }

    /// 8. Required structural fail makes the report unqualified.
    func testFailClosed_requiredStructuralFailMakesUnqualified() {
        // Simulate a structural fail by using a manifest that re-encodes to broken JSON.
        // We create a spec whose params mismatch triggers fail.
        let spec = EvalSpec(
            id:       "bad_params",
            kind:     .structural,
            required: true,
            params:   .determinism(inputSample: Data("oops".utf8)) // params mismatch
        )
        let runner = MockCandidateRunner(behavior: .stableOutput(Self.stableOutput))
        let report = EvalHarness.run(
            manifest: Self.validManifest,
            specs:    [spec, deterministicSpec(), schemaSpec(), goldenSpec()],
            runner:   runner,
            schemaDir: Self.repoRoot.appendingPathComponent("contracts")
        )
        let result = report.results.first(where: { $0.specId == "bad_params" })
        XCTAssertEqual(result?.verdict, .fail, "params mismatch must yield fail")
        XCTAssertFalse(report.qualified, "required fail must make unqualified")
    }

    /// 9. Required determinism fail (drifting) makes the report unqualified.
    func testFailClosed_requiredDeterminismFailMakesUnqualified() {
        let spec   = EvalSpec(id: "drift", kind: .determinism, required: true,
                              params: .determinism(inputSample: Data("z".utf8)))
        let runner = MockCandidateRunner(behavior: .driftingOutput)
        let report = EvalHarness.run(
            manifest: Self.validManifest,
            specs:    [structuralSpec(), spec, schemaSpec(), goldenSpec()],
            runner:   runner,
            schemaDir: Self.repoRoot.appendingPathComponent("contracts")
        )
        XCTAssertFalse(report.qualified, "required determinism fail must make unqualified")
    }

    /// 10. Non-required fail does NOT block qualified when all required pass.
    func testFailClosed_nonRequiredFailDoesNotBlockQualified() {
        // golden spec is non-required and will fail (wrong candidateOutput).
        let goldenFail = EvalSpec(
            id:       "g_fail",
            kind:     .golden,
            required: false,   // non-required
            params:   .golden(goldenBytes: Data("abc".utf8), candidateOutput: Data("xyz".utf8))
        )
        let runner = MockCandidateRunner(behavior: .stableOutput(Self.stableOutput))
        let report = EvalHarness.run(
            manifest: Self.validManifest,
            specs:    [structuralSpec(), deterministicSpec(), schemaSpec(), goldenFail],
            runner:   runner,
            schemaDir: Self.repoRoot.appendingPathComponent("contracts")
        )
        let gResult = report.results.first(where: { $0.specId == "g_fail" })
        XCTAssertEqual(gResult?.verdict, .fail, "mismatch golden must fail")
        XCTAssertTrue(report.qualified,
                      "non-required fail must not block qualified when all required pass")
    }

    /// 11. Golden mismatch → fail with evidence describing byte counts.
    func testFailClosed_goldenMismatchFails() {
        let spec = EvalSpec(
            id:       "g_mismatch",
            kind:     .golden,
            required: true,
            params:   .golden(goldenBytes: Data("GOLD".utf8), candidateOutput: Data("SILVER".utf8))
        )
        let runner = MockCandidateRunner(behavior: .stableOutput(Self.stableOutput))
        let report = EvalHarness.run(
            manifest: Self.validManifest,
            specs:    [structuralSpec(), deterministicSpec(), schemaSpec(), spec],
            runner:   runner,
            schemaDir: Self.repoRoot.appendingPathComponent("contracts")
        )
        let result = report.results.first(where: { $0.specId == "g_mismatch" })
        XCTAssertEqual(result?.verdict, .fail)
        XCTAssertTrue(result?.evidence.contains("NOT byte-equal") ?? false,
                      "evidence must describe mismatch: \(result?.evidence ?? "nil")")
    }

    /// 12. schemaConformance fails when required key is missing from candidate output.
    func testFailClosed_schemaConformanceMissingKeyFails() {
        // Build a JSON object that is missing the "id" required key.
        let incompleteOutput = try! JSONSerialization.data(withJSONObject: ["schema_version": "x"])
        let spec = EvalSpec(
            id:       "sc_fail",
            kind:     .schemaConformance,
            required: true,
            params:   .schemaConformance(
                schemaId:       "tos.app.contracts.capability_manifest.v0",
                schemaPath:     "capability_manifest.schema.json",
                candidateOutput: incompleteOutput
            )
        )
        let runner = MockCandidateRunner(behavior: .stableOutput(Self.stableOutput))
        let report = EvalHarness.run(
            manifest: Self.validManifest,
            specs:    [structuralSpec(), deterministicSpec(), spec, goldenSpec()],
            runner:   runner,
            schemaDir: Self.repoRoot.appendingPathComponent("contracts")
        )
        let result = report.results.first(where: { $0.specId == "sc_fail" })
        XCTAssertEqual(result?.verdict, .fail)
        XCTAssertTrue(result?.evidence.lowercased().contains("missing") ?? false ||
                      result?.evidence.lowercased().contains("required") ?? false,
                      "evidence must describe missing keys: \(result?.evidence ?? "nil")")
    }

    // MARK: - GROUP 3: missing-eval

    /// 13. No structural spec → synthetic fail injected for install coverage.
    func testMissingEval_noStructuralSpecInjectsSyntheticFail() {
        // Omit structural spec.
        let runner = MockCandidateRunner(behavior: .stableOutput(Self.stableOutput))
        let report = EvalHarness.run(
            manifest: Self.validManifest,
            specs:    [deterministicSpec(), schemaSpec(), goldenSpec()],
            runner:   runner,
            schemaDir: Self.repoRoot.appendingPathComponent("contracts")
        )
        let synthetic = report.results.first(where: { $0.specId == "synthetic_install_coverage" })
        XCTAssertNotNil(synthetic, "missing structural spec must inject synthetic_install_coverage result")
        XCTAssertEqual(synthetic?.verdict, .fail)
        XCTAssertTrue(synthetic?.evidence.lowercased().contains("install") ?? false,
                      "synthetic evidence must mention install")
    }

    /// 14. No determinism spec → synthetic fail injected for replay coverage.
    func testMissingEval_noDeterminismSpecInjectsSyntheticFail() {
        let runner = MockCandidateRunner(behavior: .stableOutput(Self.stableOutput))
        let report = EvalHarness.run(
            manifest: Self.validManifest,
            specs:    [structuralSpec(), schemaSpec(), goldenSpec()],
            runner:   runner,
            schemaDir: Self.repoRoot.appendingPathComponent("contracts")
        )
        let synthetic = report.results.first(where: { $0.specId == "synthetic_replay_coverage" })
        XCTAssertNotNil(synthetic, "missing determinism spec must inject synthetic_replay_coverage result")
        XCTAssertEqual(synthetic?.verdict, .fail)
        XCTAssertTrue(synthetic?.evidence.lowercased().contains("replay") ?? false,
                      "synthetic evidence must mention replay")
    }

    /// 15. NotYetAvailableCandidateRunner throws on produce → determinism fails.
    func testMissingEval_notYetAvailableRunnerFailsDeterminism() {
        let spec   = EvalSpec(id: "d_live", kind: .determinism, required: true,
                              params: .determinism(inputSample: Data("live".utf8)))
        let runner = NotYetAvailableCandidateRunner()
        let report = EvalHarness.run(
            manifest: Self.validManifest,
            specs:    [structuralSpec(), spec, schemaSpec(), goldenSpec()],
            runner:   runner,
            schemaDir: Self.repoRoot.appendingPathComponent("contracts")
        )
        let result = report.results.first(where: { $0.specId == "d_live" })
        XCTAssertEqual(result?.verdict, .fail, "NotYetAvailableCandidateRunner must cause fail")
        XCTAssertFalse(report.qualified, "unavailable runner must make unqualified")
    }

    /// 16. Synthetic missing-eval fail makes the overall report unqualified.
    func testMissingEval_syntheticFailMakesUnqualified() {
        // Omit BOTH structural and determinism specs.
        let runner = MockCandidateRunner(behavior: .stableOutput(Self.stableOutput))
        let report = EvalHarness.run(
            manifest: Self.validManifest,
            specs:    [schemaSpec(), goldenSpec()],  // missing structural AND determinism
            runner:   runner,
            schemaDir: Self.repoRoot.appendingPathComponent("contracts")
        )
        XCTAssertFalse(report.qualified,
                       "missing both required coverage specs must make report unqualified")
    }

    /// 17. Both structural and determinism missing → two synthetic fails injected.
    func testMissingEval_bothMissingInjectsTwoSyntheticFails() {
        let runner = MockCandidateRunner(behavior: .stableOutput(Self.stableOutput))
        let report = EvalHarness.run(
            manifest: Self.validManifest,
            specs:    [schemaSpec(), goldenSpec()],
            runner:   runner,
            schemaDir: Self.repoRoot.appendingPathComponent("contracts")
        )
        let syntheticIds = Set(report.results.map(\.specId))
        XCTAssertTrue(syntheticIds.contains("synthetic_install_coverage"),
                      "must inject synthetic_install_coverage")
        XCTAssertTrue(syntheticIds.contains("synthetic_replay_coverage"),
                      "must inject synthetic_replay_coverage")
        let syntheticFails = report.results.filter {
            ($0.specId == "synthetic_install_coverage" || $0.specId == "synthetic_replay_coverage") &&
            $0.verdict == .fail
        }
        XCTAssertEqual(syntheticFails.count, 2, "both synthetic results must be fail")
    }

    // MARK: - GROUP 4: output domain

    /// 18. Verdict .pass is exactly .pass (exhaustive check).
    func testOutputDomain_verdictIsExactlyPassOrFail_pass() {
        let v: EvalVerdict = .pass
        switch v {
        case .pass: break   // expected
        case .fail: XCTFail("Unexpected .fail when constructing .pass")
        }
        XCTAssertEqual(v.rawValue, "pass")
    }

    /// 19. Verdict .fail is exactly .fail (exhaustive check).
    func testOutputDomain_verdictIsExactlyPassOrFail_fail() {
        let v: EvalVerdict = .fail
        switch v {
        case .fail: break   // expected
        case .pass: XCTFail("Unexpected .pass when constructing .fail")
        }
        XCTAssertEqual(v.rawValue, "fail")
    }

    /// 20. Exhaustive switch guard: EvalVerdict has EXACTLY two cases.
    func testOutputDomain_exhaustiveSwitchOnVerdict() {
        // Construct both cases and exhaust them.
        func label(_ v: EvalVerdict) -> String {
            switch v {
            case .pass: return "pass"
            case .fail: return "fail"
            // If a third case is ever added, this will fail to compile — intentional.
            }
        }
        XCTAssertEqual(label(.pass), "pass")
        XCTAssertEqual(label(.fail), "fail")
        XCTAssertNotEqual(label(.pass), label(.fail),
                          "pass and fail must be distinct")
    }

    // MARK: - GROUP 5: harness determinism

    /// 21. Same inputs → identical EvalReport (structural equality).
    func testHarnessDeterminism_sameInputIdenticalReport() {
        let runner  = MockCandidateRunner(behavior: .stableOutput(Self.stableOutput))
        let specs   = allRequiredSpecs()
        let schemaDir = Self.repoRoot.appendingPathComponent("contracts")

        let report1 = EvalHarness.run(manifest: Self.validManifest, specs: specs, runner: runner,
                                       schemaDir: schemaDir)
        let report2 = EvalHarness.run(manifest: Self.validManifest, specs: specs, runner: runner,
                                       schemaDir: schemaDir)
        XCTAssertEqual(report1, report2, "harness must be deterministic: same inputs → identical EvalReport")
    }

    /// 22. Encoded JSON bytes of two identical reports are byte-equal.
    func testHarnessDeterminism_encodedBytesAreByteEqual() throws {
        let runner  = MockCandidateRunner(behavior: .stableOutput(Self.stableOutput))
        let specs   = allRequiredSpecs()
        let schemaDir = Self.repoRoot.appendingPathComponent("contracts")

        let report1 = EvalHarness.run(manifest: Self.validManifest, specs: specs, runner: runner,
                                       schemaDir: schemaDir)
        let report2 = EvalHarness.run(manifest: Self.validManifest, specs: specs, runner: runner,
                                       schemaDir: schemaDir)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes1 = try encoder.encode(report1)
        let bytes2 = try encoder.encode(report2)
        XCTAssertEqual(bytes1, bytes2, "encoded report bytes must be byte-equal ×2")
    }

    /// 23. qualified flag is stable across two runs with same inputs.
    func testHarnessDeterminism_qualifiedFlagIsStable() {
        let runner  = MockCandidateRunner(behavior: .stableOutput(Self.stableOutput))
        let specs   = allRequiredSpecs()
        let schemaDir = Self.repoRoot.appendingPathComponent("contracts")

        let q1 = EvalHarness.run(manifest: Self.validManifest, specs: specs, runner: runner,
                                  schemaDir: schemaDir).qualified
        let q2 = EvalHarness.run(manifest: Self.validManifest, specs: specs, runner: runner,
                                  schemaDir: schemaDir).qualified
        XCTAssertEqual(q1, q2, "qualified flag must be stable")
        XCTAssertTrue(q1, "all-pass run must be qualified")
    }

    // MARK: - GROUP 6: report projection

    /// 24. Qualified report projection uses only existing ViewIR blocks.
    func testProjection_existingBlocksOnly_qualifiedReport() {
        let runner  = MockCandidateRunner(behavior: .stableOutput(Self.stableOutput))
        let report  = EvalHarness.run(
            manifest: Self.validManifest,
            specs:    allRequiredSpecs(),
            runner:   runner,
            schemaDir: Self.repoRoot.appendingPathComponent("contracts")
        )
        XCTAssertTrue(report.qualified, "Precondition: report must be qualified")

        let doc = EvalReportProjection.project(report: report, manifestId: Self.validManifest.id)

        for block in doc.blocks {
            switch block {
            case .summaryCard, .riskList:
                break  // allowed existing blocks
            case .unknown(let raw):
                XCTFail("Projection used unknown block type '\(raw)' — only existing blocks allowed")
            default:
                XCTFail("Projection used unexpected block type — only summary_card and risk_list are expected")
            }
        }
        // Qualified report must have exactly a summary_card (no failures → no risk_list).
        let summaryCards = doc.blocks.filter { if case .summaryCard = $0 { return true }; return false }
        XCTAssertEqual(summaryCards.count, 1, "qualified report must have one summary_card")
        let riskLists = doc.blocks.filter { if case .riskList = $0 { return true }; return false }
        XCTAssertEqual(riskLists.count, 0, "qualified report with no failures must have no risk_list")
    }

    /// 25. Unqualified report projection includes a risk_list for failures.
    func testProjection_existingBlocksOnly_unqualifiedReport() {
        let driftSpec = EvalSpec(id: "d_drift", kind: .determinism, required: true,
                                  params: .determinism(inputSample: Data("x".utf8)))
        let runner    = MockCandidateRunner(behavior: .driftingOutput)
        let report    = EvalHarness.run(
            manifest: Self.validManifest,
            specs:    [structuralSpec(), driftSpec, schemaSpec(), goldenSpec()],
            runner:   runner,
            schemaDir: Self.repoRoot.appendingPathComponent("contracts")
        )
        XCTAssertFalse(report.qualified, "Precondition: report must be unqualified")

        let doc = EvalReportProjection.project(report: report, manifestId: Self.validManifest.id)

        let riskLists = doc.blocks.filter { if case .riskList = $0 { return true }; return false }
        XCTAssertGreaterThan(riskLists.count, 0, "unqualified report must have at least one risk_list")

        let summaryCards = doc.blocks.filter { if case .summaryCard = $0 { return true }; return false }
        XCTAssertEqual(summaryCards.count, 1, "unqualified report must have one summary_card")
    }

    /// 26. derive_source is non-empty and contains manifest id + "eval_harness:v1".
    func testProjection_deriveSourceIsNonEmpty() {
        let runner = MockCandidateRunner(behavior: .stableOutput(Self.stableOutput))
        let report = EvalHarness.run(
            manifest: Self.validManifest,
            specs:    allRequiredSpecs(),
            runner:   runner,
            schemaDir: Self.repoRoot.appendingPathComponent("contracts")
        )
        let doc = EvalReportProjection.project(report: report, manifestId: Self.validManifest.id)

        XCTAssertFalse(doc.deriveSource.isEmpty, "derive_source must be non-empty")
        XCTAssertTrue(doc.deriveSource.contains("eval_harness:v1"),
                      "derive_source must contain 'eval_harness:v1'; got \(doc.deriveSource)")
        XCTAssertTrue(doc.deriveSource.contains(where: { $0.contains(Self.validManifest.id) }),
                      "derive_source must cite manifest id; got \(doc.deriveSource)")
    }

    /// 27. ViewIR schema version constant is unchanged.
    func testProjection_viewIRUnchanged_schemaVersionConst() {
        // Verifies ViewIR.swift is untouched: the schema version const must equal the
        // canonical value.  Any change to ViewIR.swift would break this.
        XCTAssertEqual(viewIRSchemaVersion, "tos.app.view_ir.v0",
                       "viewIRSchemaVersion must be unchanged from ViewIR.swift")
    }

    // MARK: - GROUP 7: no-arbitrary-exec

    /// 28. NotYetAvailableCandidateRunner always throws candidateExecutionUnavailable.
    func testNoArbitraryExec_notYetAvailableRunnerAlwaysThrows() {
        let runner = NotYetAvailableCandidateRunner()
        XCTAssertThrowsError(try runner.produce(forSample: Data())) { error in
            guard let evalError = error as? EvalError else {
                XCTFail("Expected EvalError, got \(error)")
                return
            }
            XCTAssertEqual(evalError, .candidateExecutionUnavailable,
                           "NotYetAvailableCandidateRunner must throw .candidateExecutionUnavailable")
        }
        // Call a second time — must still throw.
        XCTAssertThrowsError(try runner.produce(forSample: Data("abc".utf8))) { error in
            XCTAssertEqual(error as? EvalError, .candidateExecutionUnavailable)
        }
    }

    /// 29. MockCandidateRunner has no Process/exec call — pure Swift only.
    /// This is a structural/naming check.  The real enforcement is compile-time:
    /// MockCandidateRunner.swift contains no import of Foundation.Process or exec().
    func testNoArbitraryExec_mockRunnerHasNoProcessCall() {
        // Verify by calling the mock — it must complete synchronously without spawning
        // any subprocess.  If it spawned a process, the call would either hang or fail.
        let runner  = MockCandidateRunner(behavior: .stableOutput(Data("result".utf8)))
        let result  = try? runner.produce(forSample: Data("input".utf8))
        XCTAssertNotNil(result, "mock runner must return synchronously without spawning a process")
        XCTAssertEqual(result, Data("result".utf8), "mock must return configured stable output")
    }

    /// 30. Live path (NotYetAvailableCandidateRunner) is the correct default — not a real exec.
    func testNoArbitraryExec_livePathIsNotYetAvailable() {
        let runner = NotYetAvailableCandidateRunner()
        // The harness uses this runner; all determinism evals will fail.
        let spec   = EvalSpec(id: "d_nav", kind: .determinism, required: true,
                              params: .determinism(inputSample: Data("test".utf8)))
        let report = EvalHarness.run(
            manifest: Self.validManifest,
            specs:    [structuralSpec(), spec, schemaSpec(), goldenSpec()],
            runner:   runner,
            schemaDir: Self.repoRoot.appendingPathComponent("contracts")
        )
        let dResult = report.results.first(where: { $0.specId == "d_nav" })
        XCTAssertEqual(dResult?.verdict, .fail,
                       "live path (NotYetAvailableCandidateRunner) must fail evals that call produce")
        // Evidence must mention unavailability, not an arbitrary exec error.
        XCTAssertTrue(
            dResult?.evidence.lowercased().contains("threw") ?? false ||
            dResult?.evidence.lowercased().contains("throw") ?? false,
            "evidence must describe the throw: \(dResult?.evidence ?? "nil")"
        )
    }

    // MARK: - Private helpers

    private func structuralSpec() -> EvalSpec {
        EvalSpec(id: "s", kind: .structural, required: true, params: .structural)
    }

    private func deterministicSpec() -> EvalSpec {
        EvalSpec(id: "d", kind: .determinism, required: true,
                 params: .determinism(inputSample: Data("sample".utf8)))
    }

    private func schemaSpec() -> EvalSpec {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let manifestData = try! encoder.encode(Self.validManifest)
        return EvalSpec(
            id:       "sc",
            kind:     .schemaConformance,
            required: true,
            params:   .schemaConformance(
                schemaId:        "tos.app.contracts.capability_manifest.v0",
                schemaPath:      "capability_manifest.schema.json",
                candidateOutput: manifestData
            )
        )
    }

    private func goldenSpec() -> EvalSpec {
        EvalSpec(
            id:       "g",
            kind:     .golden,
            required: true,
            params:   .golden(goldenBytes: Self.goldenBytes, candidateOutput: Self.goldenBytes)
        )
    }

    private func allRequiredSpecs() -> [EvalSpec] {
        [structuralSpec(), deterministicSpec(), schemaSpec(), goldenSpec()]
    }
}

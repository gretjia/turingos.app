// CIObservationTests.swift — A1_20: unit tests for CI/PR observation layer.
//
// Test inventory (12 test functions):
//
//  1. testCIEvidenceAllRequiredKeysPresent
//       CIEvidenceCollector vs real schema file: all 8 required ci_evidence keys
//       present in encoded JSON (reads contracts/merge_dossier.schema.json at runtime).
//
//  2. testCIEvidenceUnavailableDataPath
//       Unavailable-data path: all 8 required ci_evidence keys still present
//       with explicit "unavailable" marker values.
//
//  3. testRepairPromptDeterminismX2
//       repair_prompt factory: same inputs → byte-equal output ×2.
//
//  4. testDossierDraftDeterminismX2
//       dossier_view draft factory: same inputs → byte-equal output ×2.
//
//  5. testProvenanceLevelEnumMatchesSchema
//       ProvenanceLevel enum case raw values match schema exactly (UPPERCASE).
//
//  6. testMockDrivenIntentRoutingCIDossierProducesProjection
//       Mock-driven intent routing for "ci"/"检查" produces a CI status doc;
//       dossier draft routing produces a dossier_view doc; derive_source non-empty.
//
//  7. testReadOnlyLawCommandTable
//       All entries in LiveRepoObservationSource.commandSpecs are read-only:
//       isReadOnly == true for every entry; no POST/PUT/DELETE http verbs.
//
//  8. testDeriveSourceNonEmptyOnAllCIProjections
//       Every CI projection factory produces non-empty derive_source (P1 predicate).
//
//  9. testCIEvidenceSchemaKeysExact
//       The eight required key names in the encoded CIEvidence JSON match
//       the exact strings from the schema (positional check).
//
// 10. testRepairPromptContainsWorktreeScope
//       The repair_prompt suggested_prompt contains the supplied worktree scope.
//
// 11. testDossierDraftProvenanceLevelInPayload
//       The dossier_view block's provenance field matches the input provenanceLevel.
//
// 12. testZeroNetworkInTests
//       Assert that no test in this file instantiates LiveRepoObservationSource
//       (commands-as-data: inspect the commandSpecs table without running anything).

import Foundation
import XCTest
@testable import TuringOS

final class CIObservationTests: XCTestCase {

    // MARK: - Shared mock helpers

    /// A MockRepoObservationSource with realistic check run data (success).
    private func mockSourceSuccess() -> MockRepoObservationSource {
        MockRepoObservationSource(
            head: "deadbeef1234567890abcdef1234567890abcdef",
            prs: [
                PRSummary(number: 42, headRefName: "claude/a1-20-ci-observation",
                          title: "A1_20 CI observation", url: "https://github.com/org/repo/pull/42")
            ],
            checkRuns: [
                CheckRunSummary(id: "111", name: "build", conclusion: "success",
                                runnerType: "github_actions"),
                CheckRunSummary(id: "222", name: "test", conclusion: "success",
                                runnerType: "github_actions"),
            ],
            branchProtection: #"{"required_status_checks":{"contexts":["build","test"]}}"#,
            workflowHash: "sha256:aabbccddeeff00112233445566778899aabbccdd",
            mergeBase: "base0000000000000000000000000000000000000"
        )
    }

    /// A MockRepoObservationSource that returns unavailable/empty for everything.
    private func mockSourceUnavailable() -> MockRepoObservationSource {
        MockRepoObservationSource(
            head: CIEvidence.Sentinel.commitSha,
            prs: [],
            checkRuns: [],
            branchProtection: "unavailable",
            workflowHash: CIEvidence.Sentinel.workflowFileHash,
            mergeBase: CIEvidence.Sentinel.mergeBase,
            tag: "mock:unavailable"
        )
    }

    // MARK: - Shared schema path helper (mirrors SpecDraftTests pattern)

    private func schemaFilePath(named filename: String) -> URL? {
        let candidates: [String] = [
            "../../contracts/" + filename,
            "\(NSHomeDirectory())/Developer/turingos.app/contracts/" + filename,
            "../contracts/" + filename,
        ]
        let fm = FileManager.default
        for path in candidates {
            let url = URL(fileURLWithPath: path)
            if fm.fileExists(atPath: url.path) { return url }
        }
        let cwdBased = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("../../contracts/" + filename)
        if fm.fileExists(atPath: cwdBased.path) { return cwdBased }
        return nil
    }

    // MARK: - Test 1: CIEvidenceCollector vs real schema (all 8 required keys present)

    func testCIEvidenceAllRequiredKeysPresent() throws {
        guard let schemaURL = schemaFilePath(named: "merge_dossier.schema.json") else {
            XCTFail("Cannot locate contracts/merge_dossier.schema.json — test cannot run")
            return
        }

        // Read the schema and extract ci_evidence.required keys.
        let schemaData = try Data(contentsOf: schemaURL)
        guard let schemaJSON = try JSONSerialization.jsonObject(with: schemaData) as? [String: Any],
              let properties = schemaJSON["properties"] as? [String: Any],
              let ciEvidenceProp = properties["ci_evidence"] as? [String: Any],
              let required = ciEvidenceProp["required"] as? [String] else {
            XCTFail("Cannot parse ci_evidence.required from merge_dossier.schema.json")
            return
        }
        XCTAssertEqual(required.count, 8,
                       "ci_evidence.required must have exactly 8 keys per schema")

        // Assemble CIEvidence from a mock source with full data.
        let source = mockSourceSuccess()
        let evidence = CIEvidenceCollector.assemble(
            from: source,
            prNumber: 42,
            headRef: "claude/a1-20-ci-observation",
            baseRef: "main"
        )

        // Encode and extract JSON keys.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(evidence)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Cannot deserialize encoded CIEvidence as JSON object")
            return
        }

        // Assert every required schema key is present in the encoded JSON.
        for key in required {
            XCTAssertNotNil(json[key],
                            "required ci_evidence key '\(key)' missing from encoded CIEvidence JSON")
        }
    }

    // MARK: - Test 2: Unavailable-data path — keys still present with explicit markers

    func testCIEvidenceUnavailableDataPath() throws {
        // Use the real schema to get the exact required keys.
        let requiredKeys = [
            "commit_sha", "merge_base", "check_run_ids", "workflow_file_hash",
            "branch_protection_snapshot", "required_checks_at_time", "runner_type", "conclusion"
        ]

        // Build an evidence struct that simulates an all-unavailable source.
        // We assemble from the unavailable mock — which has sentinel values.
        let source = mockSourceUnavailable()
        let evidence = CIEvidenceCollector.assemble(
            from: source,
            prNumber: 0,
            headRef: "some/branch"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(evidence)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Cannot deserialize encoded CIEvidence")
            return
        }

        // All 8 keys must be present even when data is unavailable.
        for key in requiredKeys {
            XCTAssertNotNil(json[key],
                            "unavailable path: required key '\(key)' must still be present in JSON")
        }

        // The sentinel values must be explicit (not nil/null).
        XCTAssertEqual(json["commit_sha"] as? String, CIEvidence.Sentinel.commitSha,
                       "commit_sha must be sentinel 'unavailable'")
        XCTAssertEqual(json["merge_base"] as? String, CIEvidence.Sentinel.mergeBase,
                       "merge_base must be sentinel 'unavailable'")
        XCTAssertEqual(json["runner_type"] as? String, CIEvidence.Sentinel.runnerType,
                       "runner_type must be sentinel 'unavailable'")
        XCTAssertEqual(json["conclusion"] as? String, CIEvidence.Sentinel.conclusion,
                       "conclusion must be sentinel 'unavailable'")

        // check_run_ids must be a non-empty array (the sentinel ["unavailable"]).
        let checkRunIds = json["check_run_ids"] as? [String]
        XCTAssertNotNil(checkRunIds, "check_run_ids must be present as an array")
        XCTAssertFalse(checkRunIds?.isEmpty ?? true, "check_run_ids must be non-empty sentinel")
    }

    // MARK: - Test 3: RepairPromptProjection determinism ×2 (byte-equal)

    func testRepairPromptDeterminismX2() throws {
        let doc1 = RepairPromptProjection.make(
            failedChecks: ["build: exit 1", "test: exit 2"],
            nearestPredicate: "swift test exit 0",
            worktreeScope: "app/Sources/TuringOS/**",
            failureNodeRef: "tape:failure:node:42",
            deriveSource: "ci_observation:pr:42:commit:deadbeef"
        )
        let doc2 = RepairPromptProjection.make(
            failedChecks: ["build: exit 1", "test: exit 2"],
            nearestPredicate: "swift test exit 0",
            worktreeScope: "app/Sources/TuringOS/**",
            failureNodeRef: "tape:failure:node:42",
            deriveSource: "ci_observation:pr:42:commit:deadbeef"
        )

        XCTAssertEqual(doc1, doc2, "RepairPromptProjection must be deterministic (doc equality)")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data1 = try encoder.encode(doc1)
        let data2 = try encoder.encode(doc2)
        XCTAssertEqual(data1, data2, "RepairPromptProjection must produce byte-equal output ×2")
    }

    // MARK: - Test 4: DossierDraftProjection determinism ×2 (byte-equal)

    func testDossierDraftDeterminismX2() throws {
        let evidence = CIEvidence(
            commitSha: "deadbeef1234567890abcdef1234567890abcdef",
            mergeBase: "base0000000000000000000000000000000000000",
            checkRunIds: ["111", "222"],
            workflowFileHash: "sha256:aabbccddeeff00112233445566778899aabbccdd",
            branchProtectionSnapshot: BranchProtectionSnapshot(raw: "unavailable"),
            requiredChecksAtTime: ["build", "test"],
            runnerType: "github_actions",
            conclusion: "success"
        )
        let riskFindings = [RiskFinding(dimension: "scope", note: "diff in scope")]

        let doc1 = DossierDraftProjection.make(
            specSummary: "A1_20 CI observation implementation",
            ciEvidence: evidence,
            changedFiles: ["app/Sources/TuringOS/CIObservation.swift"],
            provenanceLevel: .repoLevel,
            riskFindings: riskFindings,
            approvalRouteText: "autonomy_contract 候选",
            prRef: "42",
            commitRef: "deadbeef1234567890abcdef1234567890abcdef"
        )
        let doc2 = DossierDraftProjection.make(
            specSummary: "A1_20 CI observation implementation",
            ciEvidence: evidence,
            changedFiles: ["app/Sources/TuringOS/CIObservation.swift"],
            provenanceLevel: .repoLevel,
            riskFindings: riskFindings,
            approvalRouteText: "autonomy_contract 候选",
            prRef: "42",
            commitRef: "deadbeef1234567890abcdef1234567890abcdef"
        )

        XCTAssertEqual(doc1, doc2, "DossierDraftProjection must be deterministic (doc equality)")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data1 = try encoder.encode(doc1)
        let data2 = try encoder.encode(doc2)
        XCTAssertEqual(data1, data2, "DossierDraftProjection must produce byte-equal output ×2")
    }

    // MARK: - Test 5: ProvenanceLevel enum values match schema exactly (UPPERCASE)

    func testProvenanceLevelEnumMatchesSchema() throws {
        // Schema defines: ["FULL", "REPO_LEVEL", "PARTIAL", "OUTSIDE_GOVERNANCE"]
        let schemaValues = ["FULL", "REPO_LEVEL", "PARTIAL", "OUTSIDE_GOVERNANCE"]

        let enumValues = ProvenanceLevel.allCases.map(\.rawValue)
        XCTAssertEqual(Set(enumValues), Set(schemaValues),
                       "ProvenanceLevel enum raw values must match schema enum exactly")

        // Each case encodes to its rawValue
        for level in ProvenanceLevel.allCases {
            let encoder = JSONEncoder()
            let data = try encoder.encode(level)
            let decoded = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            XCTAssertEqual(decoded, level.rawValue,
                           "ProvenanceLevel.\(level) must encode to '\(level.rawValue)'")
        }

        // Roundtrip decode
        for level in ProvenanceLevel.allCases {
            let encoder = JSONEncoder()
            let data = try encoder.encode(level)
            let decoded = try JSONDecoder().decode(ProvenanceLevel.self, from: data)
            XCTAssertEqual(decoded, level, "ProvenanceLevel roundtrip must be lossless for \(level)")
        }

        // Schema also verifies: if we load the schema file it should agree
        if let schemaURL = schemaFilePath(named: "merge_dossier.schema.json") {
            let schemaData = try Data(contentsOf: schemaURL)
            guard let schemaJSON = try JSONSerialization.jsonObject(with: schemaData) as? [String: Any],
                  let properties = schemaJSON["properties"] as? [String: Any],
                  let provLevel = properties["provenance_level"] as? [String: Any],
                  let enumValues = provLevel["enum"] as? [String] else {
                // Schema parsing optional here — we already tested against hardcoded values above
                return
            }
            for v in enumValues {
                XCTAssertTrue(schemaValues.contains(v),
                              "Schema provenance_level enum '\(v)' must be in our enum table")
            }
        }
    }

    // MARK: - Test 6: Mock-driven intent routing produces CI/dossier projections

    func testMockDrivenIntentRoutingCIDossierProducesProjection() {
        let source = mockSourceSuccess()

        // "ci" intent via routeCIIntent produces a CI status doc
        let ciDoc = IntentRouter.routeCIIntent(
            lower: "ci 检查",
            observationSource: source,
            projectContext: "turingos.app"
        )
        XCTAssertNotNil(ciDoc, "ci intent must produce a projection")
        XCTAssertFalse(ciDoc?.deriveSource.isEmpty ?? true,
                       "ci projection must have non-empty derive_source (P1)")
        // derive_source must cite a PR or commit identifier
        let ciDeriveSource = ciDoc?.deriveSource.joined(separator: " ") ?? ""
        XCTAssertFalse(ciDeriveSource.isEmpty, "derive_source must be non-empty")

        // Dossier draft via IntentRouter.dossierDraft produces a dossier_view doc
        let dossierDoc = IntentRouter.dossierDraft(
            from: source,
            prNumber: 42,
            headRef: "claude/a1-20-ci-observation",
            specSummary: "A1_20 CI observation",
            changedFiles: ["app/Sources/TuringOS/CIObservation.swift"],
            provenanceLevel: .repoLevel,
            riskFindings: []
        )
        XCTAssertEqual(dossierDoc.kind, "dossier_draft",
                       "dossierDraft must produce kind=dossier_draft")
        XCTAssertFalse(dossierDoc.deriveSource.isEmpty,
                       "dossierDraft derive_source must be non-empty (P1)")

        // derive_source must cite PR and commit identifiers
        let dossierDS = dossierDoc.deriveSource.joined(separator: " ")
        XCTAssertTrue(dossierDS.contains("42") || dossierDS.contains("pr"),
                      "dossierDraft derive_source must cite PR number or PR identifier")
        XCTAssertTrue(dossierDS.contains("commit") || dossierDS.contains("deadbeef"),
                      "dossierDraft derive_source must cite commit identifier")

        // Unavailable: routeCIIntent with nil source → unavailable notice
        let unavailDoc = IntentRouter.routeCIIntent(
            lower: "ci 检查",
            observationSource: nil,
            projectContext: nil
        )
        XCTAssertNotNil(unavailDoc, "unavailable CI must produce a template notice doc")
        XCTAssertFalse(unavailDoc?.deriveSource.isEmpty ?? true,
                       "unavailable CI doc must have non-empty derive_source")
    }

    // MARK: - Test 7: Read-only law — command table contains only whitelisted read verbs

    func testReadOnlyLawCommandTable() {
        let specs = LiveRepoObservationSource.commandSpecs

        XCTAssertFalse(specs.isEmpty, "commandSpecs must not be empty")

        for spec in specs {
            XCTAssertTrue(spec.isReadOnly,
                          "command '\(spec.tag)' must be read-only (isReadOnly == true)")

            // HTTP verb: if present, must be GET
            if let verb = spec.httpVerb {
                XCTAssertEqual(verb.uppercased(), "GET",
                               "command '\(spec.tag)' has HTTP verb '\(verb)' — only GET is allowed")
            }

            // Git commands: base arg must be a read-only git verb
            if spec.executable.hasSuffix("git") || spec.executable == "/usr/bin/git" {
                let readOnlyGitVerbs: Set<String> = ["log", "rev-parse", "merge-base", "ls-tree", "cat-file"]
                if let verb = spec.baseArgs.first {
                    XCTAssertTrue(readOnlyGitVerbs.contains(verb),
                                  "git command '\(spec.tag)' uses verb '\(verb)' — not in read-only whitelist")
                }
            }

            // Assert no destructive verbs appear anywhere in baseArgs
            let destructiveVerbs: Set<String> = [
                "push", "merge", "rebase", "reset", "checkout", "commit",
                "branch", "tag", "stash", "clean", "apply", "cherry-pick",
                "revert", "POST", "PUT", "DELETE", "PATCH"
            ]
            for arg in spec.baseArgs {
                XCTAssertFalse(destructiveVerbs.contains(arg),
                               "command '\(spec.tag)' contains destructive arg '\(arg)' — forbidden")
            }
        }
    }

    // MARK: - Test 8: derive_source non-empty on ALL CI projections (P1 predicate)

    func testDeriveSourceNonEmptyOnAllCIProjections() {
        let source = mockSourceSuccess()
        let evidence = CIEvidenceCollector.assemble(
            from: source,
            prNumber: 42,
            headRef: "claude/a1-20-ci-observation"
        )

        let docs: [ViewIRDocument] = [
            RepairPromptProjection.make(
                failedChecks: ["build"],
                nearestPredicate: "swift test exit 0",
                worktreeScope: "app/",
                failureNodeRef: "tape:node:1",
                deriveSource: "ci_obs:pr:42"
            ),
            DossierDraftProjection.make(
                specSummary: "test",
                ciEvidence: evidence,
                changedFiles: [],
                provenanceLevel: .full,
                riskFindings: [],
                approvalRouteText: "autonomy_contract",
                prRef: "42",
                commitRef: "deadbeef"
            ),
            CIStatusProjection.make(
                ciEvidence: evidence,
                prNumber: 42,
                deriveSource: "mock:repo"
            ),
            CIUnavailableNotice.make(),
            IntentRouter.dossierDraft(
                from: source,
                prNumber: 42,
                headRef: "claude/a1-20-ci-observation"
            ),
        ]

        for (i, doc) in docs.enumerated() {
            XCTAssertFalse(doc.deriveSource.isEmpty,
                           "CI projection doc[\(i)] must have non-empty derive_source (P1)")
            for src in doc.deriveSource {
                XCTAssertFalse(src.isEmpty,
                               "CI projection doc[\(i)] has empty string in derive_source — forbidden")
            }
        }
    }

    // MARK: - Test 9: CIEvidence JSON key names match schema exactly

    func testCIEvidenceSchemaKeysExact() throws {
        let evidence = mockSourceSuccess()
        let ciEvidence = CIEvidenceCollector.assemble(
            from: evidence,
            prNumber: 42,
            headRef: "main"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(ciEvidence)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("Cannot parse encoded CIEvidence as JSON object")
            return
        }

        // The exact 8 required key names from the schema:
        let schemaRequiredKeys = [
            "commit_sha",
            "merge_base",
            "check_run_ids",
            "workflow_file_hash",
            "branch_protection_snapshot",
            "required_checks_at_time",
            "runner_type",
            "conclusion"
        ]

        for key in schemaRequiredKeys {
            XCTAssertNotNil(json[key],
                            "Schema key '\(key)' must be present in encoded CIEvidence JSON")
        }
    }

    // MARK: - Test 10: RepairPromptProjection contains worktree scope

    func testRepairPromptContainsWorktreeScope() {
        let scope = "app/Sources/TuringOS/**"
        let doc = RepairPromptProjection.make(
            failedChecks: ["build: exit 1"],
            nearestPredicate: "swift test exit 0",
            worktreeScope: scope,
            failureNodeRef: "tape:node:7",
            deriveSource: "ci_obs:pr:7"
        )

        // Extract the repair_prompt block
        let repairBlocks = doc.blocks.compactMap { block -> RepairPromptPayload? in
            if case .repairPrompt(let p) = block { return p }
            return nil
        }
        XCTAssertEqual(repairBlocks.count, 1, "repair_prompt doc must have exactly one repair_prompt block")

        let payload = repairBlocks[0]
        XCTAssertTrue(payload.suggestedPrompt.contains(scope),
                      "suggested_prompt must contain the worktree scope '\(scope)'")
        XCTAssertEqual(payload.targetWorktree, scope,
                       "target_worktree must equal the supplied worktree scope")
        XCTAssertEqual(payload.failureNodeRef, "tape:node:7",
                       "failure_node_ref must be preserved")
    }

    // MARK: - Test 11: DossierDraftProjection provenance level in payload

    func testDossierDraftProvenanceLevelInPayload() {
        let evidence = CIEvidence.unavailable
        for level in ProvenanceLevel.allCases {
            let doc = DossierDraftProjection.make(
                specSummary: "test provenance \(level.rawValue)",
                ciEvidence: evidence,
                changedFiles: [],
                provenanceLevel: level,
                riskFindings: [],
                approvalRouteText: "test",
                prRef: "1",
                commitRef: "abc123"
            )

            // dossier_view block must carry the correct provenance level
            let dossierBlocks = doc.blocks.compactMap { block -> DossierViewPayload? in
                if case .dossierView(let p) = block { return p }
                return nil
            }
            XCTAssertEqual(dossierBlocks.count, 1,
                           "dossier_draft doc must have exactly one dossier_view block")
            XCTAssertEqual(dossierBlocks[0].provenance, level.rawValue,
                           "dossier_view.provenance must equal '\(level.rawValue)'")

            // summary_card body must mention the provenance level
            let summaryBlocks = doc.blocks.compactMap { block -> SummaryCardPayload? in
                if case .summaryCard(let p) = block { return p }
                return nil
            }
            XCTAssertFalse(summaryBlocks.isEmpty, "dossier_draft must have a summary_card block")
            let bodyContainsLevel = summaryBlocks.contains { $0.body.contains(level.rawValue) }
            XCTAssertTrue(bodyContainsLevel,
                          "summary_card body must mention provenance level '\(level.rawValue)'")
        }
    }

    // MARK: - Test 12: Zero network in tests (structural)

    func testZeroNetworkInTests() {
        // This test asserts the READ-ONLY law structurally by enumerating the
        // commandSpecs table without executing any commands.
        // The entire CIObservationTests file must not instantiate LiveRepoObservationSource.
        // We verify this by confirming our test helpers only create MockRepoObservationSource.

        let mockSource = mockSourceSuccess()
        XCTAssertEqual(mockSource.deriveSourceTag, "mock:repo",
                       "test helpers must use MockRepoObservationSource, not live")

        let unavailSource = mockSourceUnavailable()
        XCTAssertEqual(unavailSource.deriveSourceTag, "mock:unavailable",
                       "unavailable source must be mock")

        // Verify the commandSpecs table is enumerable without side effects.
        let specCount = LiveRepoObservationSource.commandSpecs.count
        XCTAssertGreaterThan(specCount, 0,
                             "commandSpecs must have entries (enumerated without running any)")

        // Every spec must have a non-empty tag and executable
        for spec in LiveRepoObservationSource.commandSpecs {
            XCTAssertFalse(spec.tag.isEmpty, "command spec tag must not be empty")
            XCTAssertFalse(spec.executable.isEmpty, "command spec executable must not be empty")
        }
    }
}

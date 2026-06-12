// SpecDraftTests.swift — A1_18: Init Spec drafting unit tests.
//
// Test inventory (6 test functions per spec, plus fixture fixture):
//
//   1. testWizardReducerFullWalk               — full walk → SpecPackage; deterministic ×2
//   2. testRetroInitPrefill                    — prefill from mock catalog item
//   3. testSpecHashDeterminism                 — same content ×2 equal; status change no-op;
//                                               content change different hash
//   4. testSpecStatusNoCaseRatified            — CaseIterable: exactly {draft, awaitingRatification};
//                                               store roundtrip preserves draft status
//   5. testWorkOrderPackageBuilderSchemaKeys   — mechanical: every schema required key present
//                                               in encoded WorkOrderPackage JSON
//   6. testNoRatifiedInEncoding                — encoding of SpecPackage never contains "ratified"

import Foundation
import XCTest
@testable import TuringOS

final class SpecDraftTests: XCTestCase {

    // MARK: - Helpers

    /// Run the wizard reducer through all steps with a provided answer per step.
    /// Returns (session, package).
    private func runFullWizard(
        projectId: String = "test_proj",
        answers: [WizardStep.Field: String]? = nil
    ) -> (WizardSession, SpecPackage) {
        let defaultAnswers: [WizardStep.Field: String] = [
            .goals:                    "完成 Init Spec 模型\n支持 Retro-Init 路径",
            .nonGoals:                 "不做 UI 渲染\n不处理支付",
            .currentState:             "代码库刚初始化，无现有债务。",
            .definitionOfDone:         "所有测试通过\nbuild_app.sh exit 0",
            .acceptancePredicates:     "swift test exit 0\ngrep specHash in JSON",
            .dataScope:                "app/Sources/TuringOS/**\napp/Tests/TuringOSTests/**",
            .toolPermissions:          "swift build\nswift test",
            .ciRules:                  "CI must pass on main",
            .initialWorktreePlan:      "wt_spec_draft: branch claude/a1-18-init-spec-drafting",
            .risks:                    "runtime 未 import，ratification 不可用",
            .budgetSuggestion:         "100k tokens, $2 USD",
            .externalDelegationPolicy: "不外派，全 internal Worker。",
        ]
        let used = answers ?? defaultAnswers

        var session = WizardSession(projectId: projectId)

        // Walk through every step in order.
        for step in SpecDraftReducer.steps {
            guard step.field != .review else { break }
            let answer = used[step.field] ?? "placeholder answer"
            session = SpecDraftReducer.reduce(session: session, event: .submitAnswer(answer))
        }
        // Now on review step — confirm.
        session = SpecDraftReducer.reduce(session: session, event: .confirmReview)

        guard let pkg = SpecDraftReducer.buildPackage(from: session) else {
            XCTFail("buildPackage returned nil on finished session")
            // Return a minimal package to continue tests
            return (session, SpecPackage(projectId: projectId))
        }
        return (session, pkg)
    }

    // MARK: - Test 1: full wizard walk → SpecPackage; deterministic ×2

    func testWizardReducerFullWalk() {
        let (session1, pkg1) = runFullWizard(projectId: "proj_full_walk")
        XCTAssertTrue(session1.finished, "session must be finished after confirmReview")
        XCTAssertEqual(pkg1.status, .draft, "built package must have status=draft")
        XCTAssertEqual(pkg1.projectId, "proj_full_walk")

        // All content fields must be non-empty (our defaults provide all answers).
        XCTAssertFalse(pkg1.goals.isEmpty,                 "goals must not be empty")
        XCTAssertFalse(pkg1.nonGoals.isEmpty,              "nonGoals must not be empty")
        XCTAssertFalse(pkg1.currentState.isEmpty,          "currentState must not be empty")
        XCTAssertFalse(pkg1.definitionOfDone.isEmpty,      "definitionOfDone must not be empty")
        XCTAssertFalse(pkg1.acceptancePredicates.isEmpty,  "acceptancePredicates must not be empty")
        XCTAssertFalse(pkg1.dataScope.isEmpty,             "dataScope must not be empty")
        XCTAssertFalse(pkg1.toolPermissions.isEmpty,       "toolPermissions must not be empty")
        XCTAssertFalse(pkg1.ciRules.isEmpty,               "ciRules must not be empty")
        XCTAssertFalse(pkg1.initialWorktreePlan.isEmpty,   "initialWorktreePlan must not be empty")
        XCTAssertFalse(pkg1.risks.isEmpty,                 "risks must not be empty")
        XCTAssertFalse(pkg1.budgetSuggestion.isEmpty,      "budgetSuggestion must not be empty")
        XCTAssertFalse(pkg1.externalDelegationPolicy.isEmpty, "externalDelegationPolicy must not be empty")

        // Determinism: same answers → identical package.
        let (_, pkg2) = runFullWizard(projectId: "proj_full_walk")
        XCTAssertEqual(pkg1, pkg2, "same wizard answers must produce identical SpecPackage (determinism)")

        // Encode both — bytes must be identical.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data1 = try! encoder.encode(pkg1)
        let data2 = try! encoder.encode(pkg2)
        XCTAssertEqual(data1, data2, "encoded bytes must be identical (determinism ×2)")
    }

    // MARK: - Test 2: Retro-Init prefill correctness from mock catalog item

    func testRetroInitPrefill() {
        let session = SpecDraftReducer.prefill(
            projectId: "proj_retro",
            name: "RetroProject",
            path: "/Users/dev/retro_project",
            currentBranch: "main"
        )

        XCTAssertEqual(session.projectId, "proj_retro")
        XCTAssertFalse(session.finished, "prefilled session must not be finished (user still needs to complete it)")
        XCTAssertEqual(session.stepIndex, 0, "prefilled session starts at step 0")

        // goals prefilled
        let goals = session.answers[.goals]
        XCTAssertNotNil(goals, "goals must be prefilled in Retro-Init")
        XCTAssertFalse(goals!.isEmpty, "goals answer must not be empty")

        // currentState must include path, branch, and knownDebt placeholder
        let currentState = session.answers[.currentState]
        XCTAssertNotNil(currentState, "currentState must be prefilled in Retro-Init")
        XCTAssertTrue(currentState!.contains("/Users/dev/retro_project"),
                      "currentState must contain the project path")
        XCTAssertTrue(currentState!.contains("main"),
                      "currentState must contain the current branch")
        XCTAssertTrue(currentState!.contains("RetroProject"),
                      "currentState must contain the project name")
        // knownDebt placeholder must be present
        XCTAssertTrue(currentState!.contains("已知债务") || currentState!.contains("known"),
                      "currentState must contain known debt placeholder")

        // Verify the session is usable: run it forward with a submitAnswer.
        var s = session
        s = SpecDraftReducer.reduce(session: s, event: .submitAnswer("新目标"))
        // After submit, stepIndex advances (from 0).
        XCTAssertEqual(s.stepIndex, 1, "step advances after submitAnswer")
        XCTAssertEqual(s.answers[.goals], "新目标", "goals answer updated by submitAnswer")
    }

    // MARK: - Test 3: specHash determinism

    func testSpecHashDeterminism() {
        let pkg = SpecPackage(
            projectId: "proj_hash_test",
            goals: ["目标 A", "目标 B"],
            nonGoals: ["不做 X"],
            currentState: "初始状态",
            definitionOfDone: ["DoD 1"],
            acceptancePredicates: ["exit 0"],
            dataScope: ["src/**"],
            toolPermissions: ["swift build"],
            ciRules: ["CI pass"],
            initialWorktreePlan: ["wt_main"],
            risks: ["风险 1"],
            budgetSuggestion: "50k tokens",
            externalDelegationPolicy: "内部",
            status: .draft
        )

        // Same content × 2 → equal hash.
        let hash1 = pkg.specHash
        let hash2 = pkg.specHash
        XCTAssertEqual(hash1, hash2, "same content → same hash (idempotent)")
        XCTAssertTrue(hash1.hasPrefix("sha256:"), "hash must have sha256: prefix")

        // Status change does NOT change hash.
        var pkgWaiting = pkg
        pkgWaiting.status = .awaitingRatification
        XCTAssertEqual(pkg.specHash, pkgWaiting.specHash,
                       "status change must NOT change specHash (status excluded from hash)")

        // Content change DOES change hash.
        var pkgChanged = pkg
        pkgChanged.goals = ["完全不同的目标"]
        XCTAssertNotEqual(pkg.specHash, pkgChanged.specHash,
                          "content change MUST change specHash")

        // Another content field change.
        var pkgChanged2 = pkg
        pkgChanged2.budgetSuggestion = "完全不同的预算"
        XCTAssertNotEqual(pkg.specHash, pkgChanged2.specHash,
                          "budgetSuggestion change MUST change specHash")
    }

    // MARK: - Test 4: SpecStatus has no ratified case; store roundtrip preserves draft

    func testSpecStatusNoCaseRatified() throws {
        // CaseIterable reflection: exactly two cases exist.
        let allCases = SpecStatus.allCases
        XCTAssertEqual(allCases.count, 2,
                       "SpecStatus must have exactly 2 cases: draft + awaitingRatification")

        let caseNames = Set(allCases.map(\.rawValue))
        XCTAssertTrue(caseNames.contains("draft"),
                      "SpecStatus must have 'draft' case")
        XCTAssertTrue(caseNames.contains("awaiting_ratification"),
                      "SpecStatus must have 'awaiting_ratification' case")
        XCTAssertFalse(caseNames.contains("ratified"),
                       "SpecStatus must NOT have 'ratified' case (constitutional boundary)")

        // Store roundtrip: save a draft, reload, status must still be .draft.
        let projectId = "test_roundtrip_\(UUID().uuidString.prefix(8))"
        let pkg = SpecPackage(
            projectId: projectId,
            goals: ["テスト"],
            status: .draft
        )

        // Use a temp directory to avoid polluting app support.
        // We override the store's URL by directly writing/reading from a temp location.
        // Since SpecDraftStore uses Workspace.supportDir we use the real store but
        // clean up afterward.
        defer { try? SpecDraftStore.delete(projectId: projectId) }

        let savedURL = try SpecDraftStore.save(pkg)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path),
                      "saved file must exist")

        let loaded = try SpecDraftStore.load(projectId: projectId)
        XCTAssertNotNil(loaded, "load must return a SpecPackage")
        XCTAssertEqual(loaded!.status, .draft, "roundtrip must preserve draft status")
        XCTAssertEqual(loaded!.projectId, projectId, "roundtrip must preserve projectId")
        XCTAssertEqual(loaded!.goals, pkg.goals, "roundtrip must preserve goals")
        XCTAssertEqual(loaded!.specHash, pkg.specHash, "roundtrip must preserve specHash")

        // Envelope must carry the three-piece declaration.
        let envelope = try SpecDraftStore.loadEnvelope(projectId: projectId)
        XCTAssertNotNil(envelope, "envelope must be loadable")
        XCTAssertEqual(envelope!.schemaVersion, "tos.app.spec_draft.v0",
                       "envelope schema_version must be tos.app.spec_draft.v0")
        XCTAssertFalse(envelope!.deriveSource.isEmpty,
                       "envelope derive_source must not be empty")
        XCTAssertFalse(envelope!.rebuildCommand.isEmpty,
                       "envelope rebuild_command must not be empty")

        // The stored JSON must never contain the string "ratified".
        let fileData = try Data(contentsOf: savedURL)
        let fileJSON = String(data: fileData, encoding: .utf8) ?? ""
        XCTAssertFalse(fileJSON.contains("ratified"),
                       "stored JSON must never contain 'ratified' (constitutional boundary)")
    }

    // MARK: - Test 5: WorkOrderPackageBuilder vs real schema file (mechanical)

    func testWorkOrderPackageBuilderSchemaKeys() throws {
        // Locate contracts/work_order_package.schema.json relative to the repo.
        // Existing tests (e.g. EventsContractTests) load fixtures from the repo
        // by searching from the package root upward — we replicate that pattern.
        let schemaPath = schemaFilePath(named: "work_order_package.schema.json")
        guard let schemaURL = schemaPath else {
            // If the schema file cannot be found in this environment, log and skip.
            // The file MUST be present for this test to be meaningful — if it's
            // missing, something is wrong with the repo layout, so we fail.
            XCTFail("Cannot locate contracts/work_order_package.schema.json in repo — test cannot run")
            return
        }

        // Read the schema and extract "required" keys.
        let schemaData = try Data(contentsOf: schemaURL)
        guard let schemaJSON = try JSONSerialization.jsonObject(with: schemaData) as? [String: Any],
              let required = schemaJSON["required"] as? [String] else {
            XCTFail("Cannot parse 'required' from schema JSON")
            return
        }
        XCTAssertFalse(required.isEmpty, "schema required keys must not be empty")

        // Build a sample WorkOrderPackage and encode it.
        let spec = SpecPackage(
            projectId: "proj_schema_test",
            goals: ["test"],
            definitionOfDone: ["exit 0"],
            acceptancePredicates: ["swift test exit 0"],
            status: .draft
        )
        let pkg = WorkOrderPackageBuilder.build(
            from: spec,
            objective: "Test schema key coverage",
            worktreeScope: "app/",
            allowedFiles: ["app/Sources/**"],
            forbiddenFiles: ["runtime/**"],
            expectedOutputs: ["SpecPackage.swift"],
            budgetSlice: BudgetSlice(description: "test budget", tokenBudget: 1000),
            provenanceRequirement: .full,
            prompt: "Build it."
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let pkgData = try encoder.encode(pkg)
        guard let pkgJSON = try JSONSerialization.jsonObject(with: pkgData) as? [String: Any] else {
            XCTFail("Cannot deserialize encoded WorkOrderPackage as JSON object")
            return
        }

        // Assert every required schema key is present in the encoded JSON.
        for key in required {
            XCTAssertNotNil(pkgJSON[key],
                            "required schema key '\(key)' missing from encoded WorkOrderPackage")
        }

        // Also assert schema_version constant value.
        XCTAssertEqual(pkgJSON["schema_version"] as? String,
                       "tos.app.work_order_package.v0",
                       "schema_version must be 'tos.app.work_order_package.v0'")

        // provenance_requirement must be one of the enum values.
        let prov = pkgJSON["provenance_requirement"] as? String
        XCTAssertTrue(prov == "full" || prov == "partial_with_human_confirm",
                      "provenance_requirement must be 'full' or 'partial_with_human_confirm'")
    }

    // MARK: - Test 6: encoding never contains "ratified"

    func testNoRatifiedInEncoding() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        // Draft status.
        // Note: projectId must NOT contain "ratified" as a substring or the check below
        // would be a false positive (the projectId itself would appear in the JSON value).
        let draft = SpecPackage(projectId: "proj_encoding_check", status: .draft)
        let draftData = try encoder.encode(draft)
        let draftJSON = String(data: draftData, encoding: .utf8) ?? ""
        XCTAssertFalse(draftJSON.contains("ratified"),
                       "draft SpecPackage JSON must never contain 'ratified'")

        // awaitingRatification status (its raw value is "awaiting_ratification", not "ratified").
        var waiting = draft
        waiting.status = .awaitingRatification
        let waitingData = try encoder.encode(waiting)
        let waitingJSON = String(data: waitingData, encoding: .utf8) ?? ""
        XCTAssertFalse(waitingJSON.contains("\"ratified\""),
                       "awaitingRatification SpecPackage JSON must not contain bare 'ratified' string")
        XCTAssertTrue(waitingJSON.contains("awaiting_ratification"),
                      "awaitingRatification must encode as 'awaiting_ratification'")

        // WorkOrderPackage encoding.
        let pkg = WorkOrderPackageBuilder.build(
            from: draft,
            objective: "test",
            worktreeScope: "app/",
            allowedFiles: ["app/**"],
            forbiddenFiles: [],
            expectedOutputs: ["out.json"],
            budgetSlice: BudgetSlice(description: "t"),
            provenanceRequirement: .full,
            prompt: "go"
        )
        let pkgData = try encoder.encode(pkg)
        let pkgJSON = String(data: pkgData, encoding: .utf8) ?? ""
        XCTAssertFalse(pkgJSON.contains("\"ratified\""),
                       "WorkOrderPackage JSON must never contain bare 'ratified' string")

        // SpecStatus.allCases encoded values must not include "ratified".
        for status in SpecStatus.allCases {
            let raw = status.rawValue
            XCTAssertFalse(raw == "ratified",
                           "SpecStatus case '\(raw)' must not equal 'ratified' (constitutional boundary)")
        }
    }

    // MARK: - Helpers

    /// Locate a file under contracts/ by searching from known candidate roots.
    /// Mirrors the pattern used by EventsContractTests.
    private func schemaFilePath(named filename: String) -> URL? {
        // Try common roots: package dir, parent dirs, and known repo layout.
        let candidates: [String] = [
            // When running `swift test` from app/, the working dir is app/
            "../../contracts/" + filename,
            // Absolute home-directory path (CI / local)
            "\(NSHomeDirectory())/Developer/turingos.app/contracts/" + filename,
            // Sibling to package root
            "../contracts/" + filename,
        ]
        let fm = FileManager.default
        for path in candidates {
            let url = URL(fileURLWithPath: path)
            if fm.fileExists(atPath: url.path) {
                return url
            }
        }
        // Also try from Bundle (for Xcode test runner)
        // The schema is not embedded in the bundle, but try cwd-relative.
        let cwdBased = URL(fileURLWithPath: fm.currentDirectoryPath)
            .appendingPathComponent("../../contracts/" + filename)
        if fm.fileExists(atPath: cwdBased.path) { return cwdBased }

        return nil
    }
}

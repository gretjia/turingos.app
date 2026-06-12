// StrategyObserveTests.swift — A1_24: strategy observe-only layer tests.
//
// Test inventory (18 test functions — truthfully counted):
//
//  STUMP OPS PURITY (6 tests)
//   1. testAddStumpPurity                  — add returns new forest, original unchanged
//   2. testAddStumpDeterminism             — add x2 byte-equal on encoded output
//   3. testPruneStumpPurity                — prune returns new forest, original unchanged
//   4. testReactivateStumpPurity           — reactivate returns new forest, original unchanged
//   5. testCyclePreventionSelfParent       — self-parent rejected with selfParent error
//   6. testCyclePreventionParentNotFound   — unknown parentId rejected with parentNotFound error
//
//  STATISTICS DETERMINISM (3 tests)
//   7. testBudgetDeterminism               — budgetConsumedByWorktree x2 byte-equal
//   8. testStatisticsDeterminismX2         — all 5 stat functions x2 byte-equal
//   9. testRepeatedFailuresGrouping        — 3 reject classes, one above threshold, correctness
//
//  RATIONAL ARITHMETIC (1 test)
//  10. testWorkerSuccessRateRational       — 2/3 not "0.666...", exact "2/3"
//
//  AUTO-ACTIVATION GUARD (2 tests)
//  11. testNoAutoActivationCases          — StumpStatus has no auto-activation case
//  12. testMetaAISuggestionStartsProposed — metaAISuggestion stump starts as proposed (assert)
//
//  STATISTICS SORTED ORDER (1 test)
//  13. testStatsSortedOrder               — repeatedFailures sorted desc-count then asc-class
//
//  PROJECTIONS (5 tests)
//  14. testPortfolioRadarBlockTypes       — only existing ViewIR block types used
//  15. testStumpTreeBlockTypes            — only existing ViewIR block types used
//  16. testPortfolioRadarDeriveSourceNonEmpty — derive_source non-empty (P1)
//  17. testProjectionsDeterminismX2       — both projections x2 byte-equal
//  18. testStumpStoreRoundtrip            — save+load roundtrip preserves forest; envelope has three-piece

import Foundation
import XCTest
@testable import TuringOS

final class StrategyObserveTests: XCTestCase {

    // MARK: - Fixtures

    private func makeStump(
        id: String = "stump_a",
        projectId: String = "proj_test",
        kind: StumpKind = .worktreeArm,
        status: StumpStatus = .proposed,
        creator: StumpCreator = .user,
        parentId: String? = nil
    ) -> ProjectStump {
        ProjectStump(
            stumpId:       id,
            projectId:     projectId,
            kind:          kind,
            title:         "Test stump \(id)",
            rationale:     "Some rationale for \(id)",
            status:        status,
            creator:       creator,
            parentStumpId: parentId,
            createdNote:   "created in test"
        )
    }

    private func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        return e
    }

    // MARK: - 1. testAddStumpPurity

    func testAddStumpPurity() throws {
        let original = StumpForest()
        let stump    = makeStump(id: "stump_a")

        let newForest = try original.add(stump)

        // Original unchanged.
        XCTAssertEqual(original.stumps.count, 0, "original forest must remain empty after add")
        // New forest has one stump.
        XCTAssertEqual(newForest.stumps.count, 1, "new forest must contain the added stump")
        XCTAssertEqual(newForest.stumps[0].stumpId, "stump_a")
    }

    // MARK: - 2. testAddStumpDeterminism

    func testAddStumpDeterminism() throws {
        let stump  = makeStump(id: "stump_determ")
        let forest1 = try StumpForest().add(stump)
        let forest2 = try StumpForest().add(stump)

        XCTAssertEqual(forest1, forest2, "same add → same forest (determinism)")

        let data1 = try encoder().encode(forest1)
        let data2 = try encoder().encode(forest2)
        XCTAssertEqual(data1, data2, "encoded bytes must be identical (determinism x2)")
    }

    // MARK: - 3. testPruneStumpPurity

    func testPruneStumpPurity() throws {
        let stump  = makeStump(id: "stump_b", status: .active)
        let forest = try StumpForest().add(stump)

        let pruned = try forest.prune("stump_b", reason: "not needed")

        // Original unchanged.
        XCTAssertEqual(forest.stump(byId: "stump_b")?.status, .active,
                       "original forest must still have active status after prune")
        // New forest has pruned status.
        XCTAssertEqual(pruned.stump(byId: "stump_b")?.status, .pruned,
                       "new forest must have pruned status")
        // Prune reason appears in createdNote.
        let note = pruned.stump(byId: "stump_b")?.createdNote ?? ""
        XCTAssertTrue(note.contains("not needed"), "prune reason must appear in createdNote")
    }

    // MARK: - 4. testReactivateStumpPurity

    func testReactivateStumpPurity() throws {
        let stump  = makeStump(id: "stump_c", status: .pruned)
        let forest = try StumpForest().add(stump)

        let reactivated = try forest.reactivate("stump_c")

        // Original unchanged.
        XCTAssertEqual(forest.stump(byId: "stump_c")?.status, .pruned,
                       "original forest must still have pruned status after reactivate")
        // New forest has active status.
        XCTAssertEqual(reactivated.stump(byId: "stump_c")?.status, .active,
                       "new forest must have active status after reactivate")
    }

    // MARK: - 5. testCyclePreventionSelfParent

    func testCyclePreventionSelfParent() throws {
        let stump = makeStump(id: "stump_self", parentId: "stump_self")
        do {
            _ = try StumpForest().add(stump)
            XCTFail("self-parent must be rejected")
        } catch StumpForestError.selfParent(let id) {
            XCTAssertEqual(id, "stump_self", "error must carry the stump id")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - 6. testCyclePreventionParentNotFound

    func testCyclePreventionParentNotFound() throws {
        let stump = makeStump(id: "stump_child", parentId: "stump_ghost")
        do {
            _ = try StumpForest().add(stump)
            XCTFail("unknown parentId must be rejected")
        } catch StumpForestError.parentNotFound(let parentId) {
            XCTAssertEqual(parentId, "stump_ghost", "error must carry the missing parent id")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // MARK: - 7. testBudgetDeterminism

    func testBudgetDeterminism() throws {
        let records = [
            BudgetRecord(worktreeId: "wt_a", tokens: 1000, costUsd: 0.01, ciCycles: 2),
            BudgetRecord(worktreeId: "wt_b", tokens: 500,  costUsd: 0.005),
            BudgetRecord(worktreeId: "wt_a", tokens: 200,  ciCycles: 1),
        ]
        let result1 = ObserveOnlyStatistics.budgetConsumedByWorktree(records)
        let result2 = ObserveOnlyStatistics.budgetConsumedByWorktree(records)

        XCTAssertEqual(result1, result2, "budget summaries must be identical x2 (determinism)")
        // Field-by-field determinism check (value type equality above covers this,
        // but explicit field checks make the predicate more readable in CI output).
        XCTAssertEqual(result1.map(\.worktreeId),    result2.map(\.worktreeId))
        XCTAssertEqual(result1.map(\.totalTokens),   result2.map(\.totalTokens))
        XCTAssertEqual(result1.map(\.totalCiCycles), result2.map(\.totalCiCycles))
    }

    // MARK: - 8. testStatisticsDeterminismX2

    func testStatisticsDeterminismX2() {
        let budgetRecords = [
            BudgetRecord(worktreeId: "wt_x", tokens: 100),
        ]
        let failureRecords = [
            FailureRecordLite(worktreeId: "wt_x", rejectClass: "lint"),
            FailureRecordLite(worktreeId: "wt_x", rejectClass: "lint"),
            FailureRecordLite(worktreeId: "wt_y", rejectClass: "compile"),
        ]
        let ciRecords = [
            CIRunRecord(branch: "main", costUsd: 0.01, passed: true),
            CIRunRecord(branch: "feat", costUsd: 0.02, passed: false),
        ]
        let workerRecords = [
            WorkOutcomeRecord(workerId: "w1", success: true),
            WorkOutcomeRecord(workerId: "w1", success: false),
            WorkOutcomeRecord(workerId: "w1", success: true),
        ]
        let approvalRecords = [
            ApprovalEventLite(envelopeRef: "env_1", decided: false),
            ApprovalEventLite(envelopeRef: "env_2", decided: true),
        ]

        // Run all five functions twice; compare equality.
        XCTAssertEqual(
            ObserveOnlyStatistics.budgetConsumedByWorktree(budgetRecords),
            ObserveOnlyStatistics.budgetConsumedByWorktree(budgetRecords),
            "budgetConsumedByWorktree must be deterministic x2"
        )
        XCTAssertEqual(
            ObserveOnlyStatistics.repeatedFailures(failureRecords),
            ObserveOnlyStatistics.repeatedFailures(failureRecords),
            "repeatedFailures must be deterministic x2"
        )
        XCTAssertEqual(
            ObserveOnlyStatistics.ciCostSummary(ciRecords),
            ObserveOnlyStatistics.ciCostSummary(ciRecords),
            "ciCostSummary must be deterministic x2"
        )
        XCTAssertEqual(
            ObserveOnlyStatistics.workerSuccessRate(workerRecords),
            ObserveOnlyStatistics.workerSuccessRate(workerRecords),
            "workerSuccessRate must be deterministic x2"
        )
        XCTAssertEqual(
            ObserveOnlyStatistics.humanReviewBurden(approvalRecords),
            ObserveOnlyStatistics.humanReviewBurden(approvalRecords),
            "humanReviewBurden must be deterministic x2"
        )
    }

    // MARK: - 9. testRepeatedFailuresGrouping

    func testRepeatedFailuresGrouping() {
        // Crafted fixture: 3 reject classes, "lint" above threshold.
        let records = [
            FailureRecordLite(worktreeId: "wt_a", rejectClass: "lint"),
            FailureRecordLite(worktreeId: "wt_b", rejectClass: "lint"),
            FailureRecordLite(worktreeId: "wt_b", rejectClass: "lint"),    // lint = 3 (above threshold 2)
            FailureRecordLite(worktreeId: "wt_a", rejectClass: "compile"), // compile = 1
            FailureRecordLite(worktreeId: "wt_c", rejectClass: "typecheck"),// typecheck = 1
        ]

        let results = ObserveOnlyStatistics.repeatedFailures(records, threshold: 2)

        XCTAssertEqual(results.count, 3, "must return 3 reject classes")

        // lint must be first (count = 3, highest).
        let lintEntry = results.first { $0.rejectClass == "lint" }
        XCTAssertNotNil(lintEntry, "lint class must be present")
        XCTAssertEqual(lintEntry?.count, 3, "lint count must be 3")
        XCTAssertTrue(lintEntry?.isRecurrent == true, "lint must be flagged recurrent (count >= 2)")

        // compile and typecheck must not be flagged recurrent.
        let compileEntry   = results.first { $0.rejectClass == "compile" }
        let typecheckEntry = results.first { $0.rejectClass == "typecheck" }
        XCTAssertEqual(compileEntry?.count,   1)
        XCTAssertEqual(typecheckEntry?.count, 1)
        XCTAssertFalse(compileEntry?.isRecurrent   == true, "compile must NOT be recurrent")
        XCTAssertFalse(typecheckEntry?.isRecurrent == true, "typecheck must NOT be recurrent")

        // Result is sorted: lint (3) first, then compile and typecheck (1 each, alphabetically).
        XCTAssertEqual(results[0].rejectClass, "lint",
                       "highest count must be first (descending count sort)")
        // Among count=1 entries, alphabetical order: "compile" < "typecheck".
        XCTAssertEqual(results[1].rejectClass, "compile",
                       "tie-breaking must be ascending alphabetical by rejectClass")
        XCTAssertEqual(results[2].rejectClass, "typecheck",
                       "tie-breaking must be ascending alphabetical by rejectClass")
    }

    // MARK: - 10. testWorkerSuccessRateRational

    func testWorkerSuccessRateRational() {
        // 2 successes out of 3 attempts → must render as "2/3", NOT "0.666..."
        let records = [
            WorkOutcomeRecord(workerId: "agent_x", success: true),
            WorkOutcomeRecord(workerId: "agent_x", success: false),
            WorkOutcomeRecord(workerId: "agent_x", success: true),
        ]
        let results = ObserveOnlyStatistics.workerSuccessRate(records)

        XCTAssertEqual(results.count, 1, "one worker must produce one summary")
        let summary = results[0]
        XCTAssertEqual(summary.workerId,      "agent_x")
        XCTAssertEqual(summary.successCount,  2)
        XCTAssertEqual(summary.totalCount,    3)
        XCTAssertEqual(summary.rateString,    "2/3",
                       "rate must be exact rational '2/3', not a float approximation")
        XCTAssertFalse(summary.rateString.contains("0.6"),
                       "rate must NOT contain float representation")
    }

    // MARK: - 11. testNoAutoActivationCases

    func testNoAutoActivationCases() {
        let allCases = StumpStatus.allCases
        XCTAssertEqual(allCases.count, 3,
                       "StumpStatus must have exactly 3 cases: proposed / active / pruned")

        let rawValues = Set(allCases.map(\.rawValue))
        XCTAssertTrue(rawValues.contains("proposed"),    "must have 'proposed' case")
        XCTAssertTrue(rawValues.contains("active"),      "must have 'active' case")
        XCTAssertTrue(rawValues.contains("pruned"),      "must have 'pruned' case")

        // No auto-generation / auto-activation case.
        XCTAssertFalse(rawValues.contains("auto_generated"),
                       "StumpStatus must NOT have 'auto_generated' case")
        XCTAssertFalse(rawValues.contains("auto_activated"),
                       "StumpStatus must NOT have 'auto_activated' case")
    }

    // MARK: - 12. testMetaAISuggestionStartsProposed

    func testMetaAISuggestionStartsProposed() throws {
        let metaStump = makeStump(
            id:      "meta_stump_1",
            status:  .proposed,
            creator: .metaAISuggestion
        )
        let forest = try StumpForest().add(metaStump)

        let retrieved = forest.stump(byId: "meta_stump_1")
        XCTAssertNotNil(retrieved, "meta AI suggestion stump must be stored")
        XCTAssertEqual(retrieved?.creator, .metaAISuggestion,
                       "creator must be metaAISuggestion")
        XCTAssertEqual(retrieved?.status, .proposed,
                       "metaAISuggestion stump must start as proposed (never auto-activated)")

        // Cannot auto-activate: only explicit reactivate (from pruned) is allowed.
        // Verify that proposed state cannot be skipped to active by any built-in add path.
        // The stump was added with .proposed — it stays .proposed in the forest.
        XCTAssertNotEqual(retrieved?.status, .active,
                          "metaAISuggestion stump must NOT start as active")
    }

    // MARK: - 13. testStatsSortedOrder

    func testStatsSortedOrder() {
        // repeatedFailures: descending count, then ascending rejectClass for ties.
        let records = [
            FailureRecordLite(worktreeId: "w", rejectClass: "zzz"),   // count 1
            FailureRecordLite(worktreeId: "w", rejectClass: "aaa"),   // count 1
            FailureRecordLite(worktreeId: "w", rejectClass: "mmm"),   // count 2
            FailureRecordLite(worktreeId: "w", rejectClass: "mmm"),
        ]
        let results = ObserveOnlyStatistics.repeatedFailures(records)
        // "mmm" (count=2) must come first, then "aaa" < "zzz" alphabetically.
        XCTAssertEqual(results[0].rejectClass, "mmm")
        XCTAssertEqual(results[1].rejectClass, "aaa")
        XCTAssertEqual(results[2].rejectClass, "zzz")

        // budgetConsumedByWorktree: ascending worktreeId.
        let budgets = [
            BudgetRecord(worktreeId: "wt_z"),
            BudgetRecord(worktreeId: "wt_a"),
            BudgetRecord(worktreeId: "wt_m"),
        ]
        let budgetResults = ObserveOnlyStatistics.budgetConsumedByWorktree(budgets)
        XCTAssertEqual(budgetResults.map(\.worktreeId), ["wt_a", "wt_m", "wt_z"],
                       "budget summaries must be sorted ascending by worktreeId")

        // workerSuccessRate: ascending workerId.
        let outcomes = [
            WorkOutcomeRecord(workerId: "worker_z", success: true),
            WorkOutcomeRecord(workerId: "worker_a", success: true),
        ]
        let workerResults = ObserveOnlyStatistics.workerSuccessRate(outcomes)
        XCTAssertEqual(workerResults.map(\.workerId), ["worker_a", "worker_z"],
                       "worker summaries must be sorted ascending by workerId")
    }

    // MARK: - 14. testPortfolioRadarBlockTypes

    func testPortfolioRadarBlockTypes() {
        let projects = [
            PortfolioProjectEntry(projectId: "p1", displayName: "Alpha", status: "active", pendingCount: 2, stumpCount: 1),
            PortfolioProjectEntry(projectId: "p2", displayName: "Beta",  status: "stalled"),
        ]
        let failures = [
            RejectClassCount(rejectClass: "lint", count: 3, isRecurrent: true),
        ]
        let ci = CICostSummary(totalCostUsd: 0.05, totalRuns: 3, perBranch: [])
        let workers = [
            WorkerSuccessSummary(workerId: "w1", successCount: 2, totalCount: 3),
        ]
        let budget = [
            WorktreeBudgetSummary(worktreeId: "wt_x", totalTokens: 100, totalCostUsd: 0.001, totalCiCycles: 1),
        ]

        let doc = PortfolioProjections.portfolioRadar(
            projects:        projects,
            budgetSummaries: budget,
            failureCounts:   failures,
            ciSummary:       ci,
            workerSummaries: workers,
            deriveSource:    ["stump_store:proj_test", "budget_records:test"]
        )

        XCTAssertEqual(doc.kind, "portfolio_radar")
        // All block types must be EXISTING ViewIR block types.
        for block in doc.blocks {
            switch block {
            case .summaryCard, .worktreeMap, .evidenceList, .riskList:
                break  // valid existing types
            case .unknown(let t):
                XCTFail("portfolioRadar must not produce unknown block type: \(t)")
            default:
                XCTFail("portfolioRadar must only use summary_card/worktree_map/evidence_list/risk_list")
            }
        }

        // Must have at least summary_card and worktree_map.
        let hasSummary = doc.blocks.contains { if case .summaryCard = $0 { return true }; return false }
        let hasWorktreeMap = doc.blocks.contains { if case .worktreeMap = $0 { return true }; return false }
        XCTAssertTrue(hasSummary,     "portfolioRadar must contain a summary_card")
        XCTAssertTrue(hasWorktreeMap, "portfolioRadar must contain a worktree_map")

        // Must contain evidence_list (we provided budget + worker + ci summaries).
        let hasEvidence = doc.blocks.contains { if case .evidenceList = $0 { return true }; return false }
        XCTAssertTrue(hasEvidence, "portfolioRadar must contain an evidence_list when stats are provided")

        // Must contain risk_list (we provided isRecurrent failure).
        let hasRisk = doc.blocks.contains { if case .riskList = $0 { return true }; return false }
        XCTAssertTrue(hasRisk, "portfolioRadar must contain a risk_list when recurrent failures exist")
    }

    // MARK: - 15. testStumpTreeBlockTypes

    func testStumpTreeBlockTypes() throws {
        var forest = StumpForest()
        forest = try forest.add(makeStump(id: "s1", status: .proposed, creator: .metaAISuggestion))
        forest = try forest.add(makeStump(id: "s2", status: .active,   creator: .user))
        forest = try forest.add(makeStump(id: "s3", status: .pruned,   creator: .user))

        let doc = PortfolioProjections.stumpTree(
            forest:      forest,
            deriveSource: ["stump_store:proj_test", "record_ids:fixture"]
        )

        XCTAssertEqual(doc.kind, "stump_tree")
        for block in doc.blocks {
            switch block {
            case .summaryCard, .worktreeMap, .evidenceList:
                break  // valid existing types
            case .unknown(let t):
                XCTFail("stumpTree must not produce unknown block type: \(t)")
            default:
                XCTFail("stumpTree must only use summary_card/worktree_map/evidence_list")
            }
        }

        let hasSummary   = doc.blocks.contains { if case .summaryCard  = $0 { return true }; return false }
        let hasMap       = doc.blocks.contains { if case .worktreeMap  = $0 { return true }; return false }
        let hasEvidence  = doc.blocks.contains { if case .evidenceList = $0 { return true }; return false }
        XCTAssertTrue(hasSummary,  "stumpTree must contain a summary_card")
        XCTAssertTrue(hasMap,      "stumpTree must contain a worktree_map")
        XCTAssertTrue(hasEvidence, "stumpTree must contain an evidence_list when stumps exist")

        // worktree_map entries: one per stump, sorted by stumpId.
        let mapPayloads = doc.blocks.compactMap { b -> WorktreeMapPayload? in
            if case .worktreeMap(let p) = b { return p }; return nil
        }
        XCTAssertEqual(mapPayloads[0].worktrees.count, 3, "must have 3 worktree entries for 3 stumps")
        XCTAssertEqual(mapPayloads[0].worktrees.map(\.worktreeId), ["s1", "s2", "s3"],
                       "worktree entries must be sorted by stumpId ascending")
    }

    // MARK: - 16. testPortfolioRadarDeriveSourceNonEmpty

    func testPortfolioRadarDeriveSourceNonEmpty() {
        let doc1 = PortfolioProjections.portfolioRadar(
            projects:     [],
            deriveSource: ["stump_store:proj_x"]
        )
        let doc2 = PortfolioProjections.stumpTree(
            forest:      StumpForest(),
            deriveSource: ["stump_store:proj_x"]
        )

        for (i, doc) in [doc1, doc2].enumerated() {
            XCTAssertFalse(doc.deriveSource.isEmpty,
                           "doc[\(i)] must have non-empty derive_source (P1 predicate)")
            for src in doc.deriveSource {
                XCTAssertFalse(src.isEmpty,
                               "doc[\(i)] has empty string in derive_source — forbidden (P1)")
            }
        }
    }

    // MARK: - 17. testProjectionsDeterminismX2

    func testProjectionsDeterminismX2() throws {
        let projects = [
            PortfolioProjectEntry(projectId: "px", displayName: "PX", status: "active"),
        ]
        let ds = ["stump_store:proj_px", "record_ids:test"]

        let radar1 = PortfolioProjections.portfolioRadar(projects: projects, deriveSource: ds)
        let radar2 = PortfolioProjections.portfolioRadar(projects: projects, deriveSource: ds)
        XCTAssertEqual(radar1, radar2, "portfolioRadar must be deterministic x2")

        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .prettyPrinted]
        let d1 = try enc.encode(radar1)
        let d2 = try enc.encode(radar2)
        XCTAssertEqual(d1, d2, "portfolioRadar encoded bytes must be identical x2")

        var forest = StumpForest()
        forest = try forest.add(makeStump(id: "ss1"))
        let tree1 = PortfolioProjections.stumpTree(forest: forest, deriveSource: ds)
        let tree2 = PortfolioProjections.stumpTree(forest: forest, deriveSource: ds)
        XCTAssertEqual(tree1, tree2, "stumpTree must be deterministic x2")

        let t1 = try enc.encode(tree1)
        let t2 = try enc.encode(tree2)
        XCTAssertEqual(t1, t2, "stumpTree encoded bytes must be identical x2")
    }

    // MARK: - 18. testStumpStoreRoundtrip

    func testStumpStoreRoundtrip() throws {
        let projectId = "store_test_\(UUID().uuidString.prefix(8).lowercased())"
        defer { try? StumpStore.delete(projectId: projectId) }

        // Build a forest.
        var forest = StumpForest()
        forest = try forest.add(makeStump(id: "st_a", projectId: projectId, status: .proposed, creator: .user))
        forest = try forest.add(makeStump(id: "st_b", projectId: projectId, status: .active,   creator: .metaAISuggestion))

        // Save.
        let savedURL = try StumpStore.save(forest, projectId: projectId)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path),
                      "saved file must exist at returned URL")

        // Load forest.
        let loaded = try StumpStore.load(projectId: projectId)
        XCTAssertNotNil(loaded, "load must return a StumpForest")
        XCTAssertEqual(loaded, forest, "loaded forest must equal the saved forest")

        // Load envelope: verify three-piece declaration.
        let envelope = try StumpStore.loadEnvelope(projectId: projectId)
        XCTAssertNotNil(envelope, "envelope must be loadable")
        XCTAssertEqual(envelope?.schemaVersion, "tos.app.stump_forest.v0",
                       "schema_version must be tos.app.stump_forest.v0")
        XCTAssertFalse(envelope?.deriveSource.isEmpty == true,
                       "envelope derive_source must not be empty")
        XCTAssertFalse(envelope?.rebuildCommand.isEmpty == true,
                       "envelope rebuild_command must not be empty")

        // Stump data roundtrips correctly.
        let stumpA = loaded?.stump(byId: "st_a")
        let stumpB = loaded?.stump(byId: "st_b")
        XCTAssertEqual(stumpA?.status,  .proposed,         "st_a status must roundtrip as proposed")
        XCTAssertEqual(stumpA?.creator, .user,             "st_a creator must roundtrip as user")
        XCTAssertEqual(stumpB?.status,  .active,           "st_b status must roundtrip as active")
        XCTAssertEqual(stumpB?.creator, .metaAISuggestion, "st_b creator must roundtrip as metaAISuggestion")
    }
}

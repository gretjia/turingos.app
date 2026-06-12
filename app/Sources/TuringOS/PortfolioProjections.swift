// PortfolioProjections.swift — A1_24: strategy observe-only layer — portfolio projections.
//
// Governing ruling §二-1 / WHITEPAPER §11-12:
//   Portfolio Radar = deterministic projection over project status snapshots +
//   observe-only statistics summaries.  Zero market signals, zero MCTS, zero
//   reward-driven decisions.
//
// DESIGN CONTRACT (mirrors ProjectProjections.swift):
//   - Pure functions — same input → byte-identical output.
//   - No git, no FileManager writes, no model calls, no network.
//   - All documents carry non-empty derive_source (P1 predicate).
//   - Uses EXISTING ViewIR block types only (ViewIR.swift is NOT modified).
//
// Block types used:
//   summary_card    — portfolio/stump overview header
//   worktree_map    — project status list / stump tree nodes
//   evidence_list   — statistics summaries as evidence items
//   risk_list       — recurrent-failure alerts
//
// Orb IntentRouter wiring (added at bottom of OrbState.swift extension):
//   "组合" / "portfolio"  →  portfolioRadar
//   "树桩" / "stumps"     →  stumpTree

import Foundation

// MARK: - Portfolio entry input

/// One project's status snapshot for portfolioRadar.
/// Passed in by the caller (no IO in projections).
public struct PortfolioProjectEntry: Sendable, Equatable {
    public let projectId:     String
    public let displayName:   String
    /// "active" / "stalled" / "draft" / "archived" — caller-supplied string.
    public let status:        String
    public let pendingCount:  Int     // pending approval items
    public let stumpCount:    Int     // number of active stumps

    public init(
        projectId:    String,
        displayName:  String,
        status:       String,
        pendingCount: Int = 0,
        stumpCount:   Int = 0
    ) {
        self.projectId    = projectId
        self.displayName  = displayName
        self.status       = status
        self.pendingCount = pendingCount
        self.stumpCount   = stumpCount
    }
}

// MARK: - PortfolioProjections

public enum PortfolioProjections {

    // MARK: - portfolioRadar

    /// Deterministic factory: portfolio entries + statistics summaries → ViewIRDocument.
    ///
    /// Produces:
    ///   • summary_card — portfolio overview (project count, pending approvals, stump count)
    ///   • worktree_map — one WorktreeEntry per project (status/trust mapped from PortfolioProjectEntry)
    ///   • evidence_list — budget / CI / worker summaries as evidence items
    ///   • risk_list — recurrent failures (isRecurrent == true) as warn-level risk items
    ///
    /// derive_source cites: stump store identifier + provided record identifiers.
    /// Same input → byte-identical output (pure function).
    public static func portfolioRadar(
        projects:           [PortfolioProjectEntry],
        budgetSummaries:    [WorktreeBudgetSummary]    = [],
        failureCounts:      [RejectClassCount]         = [],
        ciSummary:          CICostSummary?             = nil,
        workerSummaries:    [WorkerSuccessSummary]     = [],
        reviewBurden:       ReviewBurden               = ReviewBurden(pendingCount: 0, decidedCount: 0),
        deriveSource:       [String]
    ) -> ViewIRDocument {
        // ---- summary_card ----
        let projectCount  = projects.count
        let totalPending  = projects.reduce(0) { $0 + $1.pendingCount }
        let totalStumps   = projects.reduce(0) { $0 + $1.stumpCount }
        let summaryBody   = """
        项目数：\(projectCount)
        待审批：\(totalPending)
        策略树桩（active）：\(totalStumps)
        CI 总费用：$\(String(format: "%.4f", ciSummary?.totalCostUsd ?? 0))
        人工审阅待处理：\(reviewBurden.pendingCount)  已决：\(reviewBurden.decidedCount)
        """
        let summaryCard = SummaryCardPayload(title: "组合雷达（Portfolio Radar）", body: summaryBody)

        // ---- worktree_map: one entry per project ----
        // Sort by projectId for determinism.
        let worktreeEntries = projects
            .sorted { $0.projectId < $1.projectId }
            .map { p -> WorktreeEntry in
                let wtStatus: String
                switch p.status {
                case "active":   wtStatus = "running"
                case "stalled":  wtStatus = "halted"
                case "draft":    wtStatus = "pending_approval"
                default:         wtStatus = "done"
                }
                return WorktreeEntry(
                    worktreeId: p.projectId,
                    headSha:    nil,
                    status:     wtStatus,
                    trustState: "observed_unsigned",
                    provenance: "stump_store:portfolio"
                )
            }
        let worktreeMap = WorktreeMapPayload(worktrees: worktreeEntries)

        // ---- evidence_list: statistics summaries ----
        var evidenceItems: [EvidenceItem] = []

        // Budget per worktree.
        for s in budgetSummaries.prefix(10) {  // cap at 10 to avoid wall-of-text
            evidenceItems.append(EvidenceItem(
                kind:  "budget_summary",
                label: "\(s.worktreeId)  tokens:\(s.totalTokens)  $\(String(format: "%.4f", s.totalCostUsd))  ci_cycles:\(s.totalCiCycles)",
                ref:   "budget_record:\(s.worktreeId)"
            ))
        }

        // Worker success rates.
        for w in workerSummaries.prefix(10) {
            evidenceItems.append(EvidenceItem(
                kind:  "worker_success_rate",
                label: "worker:\(w.workerId)  成功率 \(w.rateString)",
                ref:   "work_outcome_record:\(w.workerId)"
            ))
        }

        // CI totals.
        if let ci = ciSummary {
            evidenceItems.append(EvidenceItem(
                kind:  "ci_cost_summary",
                label: "CI 总计：\(ci.totalRuns) 次  $\(String(format: "%.4f", ci.totalCostUsd))",
                ref:   "ci_run_records:all"
            ))
        }

        // ---- risk_list: recurrent failures ----
        let riskItems = failureCounts
            .filter(\.isRecurrent)
            .sorted { $0.rejectClass < $1.rejectClass }  // deterministic order
            .map { fc in
                RiskItem(
                    level:     "warn",
                    text:      "重复失败类型 \(fc.rejectClass)：出现 \(fc.count) 次",
                    riskClass: "repeated_failure:\(fc.rejectClass)"
                )
            }

        // Assemble blocks (always emit all four types for a complete radar).
        var blocks: [ViewIRBlock] = [
            .summaryCard(summaryCard),
            .worktreeMap(worktreeMap),
        ]
        if !evidenceItems.isEmpty {
            blocks.append(.evidenceList(EvidenceListPayload(items: evidenceItems)))
        }
        if !riskItems.isEmpty {
            blocks.append(.riskList(RiskListPayload(items: riskItems)))
        }

        return ViewIRDocument(
            kind:         "portfolio_radar",
            deriveSource: deriveSource,
            blocks:       blocks
        )
    }

    // MARK: - stumpTree

    /// Deterministic factory: StumpForest → ViewIRDocument.
    ///
    /// Produces:
    ///   • summary_card — total stumps, status breakdown
    ///   • worktree_map — one WorktreeEntry per stump (re-using worktree_map for tree display)
    ///   • evidence_list — stump details (kind, rationale snippet, creator)
    ///
    /// Stumps sorted by stumpId ascending (deterministic, stable).
    /// derive_source must be non-empty (P1 predicate).
    public static func stumpTree(
        forest:      StumpForest,
        deriveSource: [String]
    ) -> ViewIRDocument {
        let allStumps  = forest.stumps.sorted { $0.stumpId < $1.stumpId }
        let proposed   = allStumps.filter { $0.status == .proposed }.count
        let active     = allStumps.filter { $0.status == .active   }.count
        let pruned     = allStumps.filter { $0.status == .pruned   }.count

        // ---- summary_card ----
        let summaryCard = SummaryCardPayload(
            title: "策略树桩（Strategy Stumps）",
            body:  """
            树桩总数：\(allStumps.count)
            proposed：\(proposed)  active：\(active)  pruned：\(pruned)
            """
        )

        // ---- worktree_map: one entry per stump ----
        let worktreeEntries = allStumps.map { s -> WorktreeEntry in
            let wtStatus: String
            switch s.status {
            case .proposed: wtStatus = "pending_approval"
            case .active:   wtStatus = "running"
            case .pruned:   wtStatus = "done"
            }
            return WorktreeEntry(
                worktreeId: s.stumpId,
                headSha:    nil,
                status:     wtStatus,
                trustState: "observed_unsigned",
                provenance: "stump_store:\(s.projectId)"
            )
        }
        let worktreeMap = WorktreeMapPayload(worktrees: worktreeEntries)

        // ---- evidence_list: stump detail lines ----
        let evidenceItems = allStumps.map { s -> EvidenceItem in
            let rationaleSnippet = String(s.rationale.prefix(60))
                + (s.rationale.count > 60 ? "…" : "")
            let creatorLabel = s.creator == .metaAISuggestion ? "Meta AI (proposal)" : "user"
            return EvidenceItem(
                kind:  "stump_detail",
                label: "[\(s.kind.rawValue)] \(s.title) · \(creatorLabel) · \(rationaleSnippet)",
                ref:   "stump:\(s.stumpId)"
            )
        }

        var blocks: [ViewIRBlock] = [
            .summaryCard(summaryCard),
            .worktreeMap(worktreeMap),
        ]
        if !evidenceItems.isEmpty {
            blocks.append(.evidenceList(EvidenceListPayload(items: evidenceItems)))
        }

        return ViewIRDocument(
            kind:         "stump_tree",
            deriveSource: deriveSource,
            blocks:       blocks
        )
    }
}

// MARK: - IntentRouter extension (A1_24 wiring)

extension IntentRouter {
    /// Route "组合"/"portfolio" → portfolioRadar; "树桩"/"stumps" → stumpTree.
    /// Called from routeBase after the existing routing table.
    static func routePortfolio(lower: String) -> ViewIRDocument? {
        if lower.contains("组合") || lower.contains("portfolio") {
            // Empty portfolio + no stats — show blank radar (caller can inject real data).
            return PortfolioProjections.portfolioRadar(
                projects:     [],
                deriveSource: ["fixture_event_stream:portfolio_router"]
            )
        }
        if lower.contains("树桩") || lower.contains("stumps") {
            return PortfolioProjections.stumpTree(
                forest:      StumpForest(),
                deriveSource: ["fixture_event_stream:stump_tree_router"]
            )
        }
        return nil
    }
}

// BudgetProjections.swift — Deterministic View IR projections for BudgetContract (A1_19).
//
// PROJECTION CONTRACT (docs/UPSTREAM_CONTRACT.md iron law 3 / Red Line 5):
//   derive_source: budget_draft:<budgetHash> + spec:<specHash>
//   schema_version: tos.app.view_ir.v0
//   rebuild_command: BudgetProjections.budgetDraftCard(for:specHash:)
//
// All functions are PURE (no Date(), no UUID(), no tape reads).
// Same inputs → same output (verified by determinism ×2 tests in BudgetContractTests).

import Foundation

// MARK: - BudgetProjections

/// Deterministic factory producing ViewIRDocuments for the budget domain.
///
/// ## Red Line 5 compliance
/// Every document carries a non-empty `derive_source` and declares `rebuild_command`
/// implicitly via the factory function signature (same inputs → same output).
public struct BudgetProjections {

    private init() {}

    // MARK: - budgetDraftCard

    /// Produces a ViewIRDocument showing the current budget contract draft.
    ///
    /// Rendered by the first-party ViewIRRenderer as a `budget_card` block (A1_15).
    ///
    /// - Parameters:
    ///   - contract:  The BudgetContract to display.
    ///   - specHash:  Hash of the associated SpecPackage (for derive_source).
    /// - Returns:     A deterministic ViewIRDocument.
    public static func budgetDraftCard(
        for contract: BudgetContract,
        specHash: String
    ) -> ViewIRDocument {
        let budgetHash = contract.budgetHash

        // BudgetCounts: limit column (consumed is zero — draft has not started).
        let limitCounts = BudgetCounts(
            tokens:     contract.limits.tokenLimit,
            ciCycles:   contract.limits.ciCyclesLimit,
            wallClockS: Double(contract.limits.wallClockSecs)
        )
        let zeroCounts = BudgetCounts(tokens: 0, ciCycles: 0, wallClockS: 0)

        let budgetBlock = ViewIRBlock.budgetCard(BudgetCardPayload(
            budgetRef: budgetHash,
            consumed:  zeroCounts,
            limit:     limitCounts,
            signatureNode: 2
        ))

        let statusBlock = ViewIRBlock.summaryCard(SummaryCardPayload(
            title: "Budget Contract Draft",
            body:  "Status: \(contract.status.rawValue) · Project: \(contract.projectId)\n" +
                   "Awaiting signature #2 (budget approval) + tape genesis via kernel import."
        ))

        let stopLossBlock = ViewIRBlock.summaryCard(SummaryCardPayload(
            title: "Stop-Loss Line",
            body:  "\(contract.limits.stopLossLine)\n" +
                   "Halt after \(contract.autonomy.maxRetryBeforeHalt) retries → HALT-止损."
        ))

        return ViewIRDocument(
            kind: "budget_draft",
            deriveSource: [
                "budget_draft:\(budgetHash)",
                "spec:\(specHash)",
                "project:\(contract.projectId)",
            ],
            blocks: [statusBlock, budgetBlock, stopLossBlock]
        )
    }

    // MARK: - projectReadyPendingCard

    /// Produces a ViewIRDocument explaining the pending project-ready state.
    ///
    /// Shown when a BudgetContract exists in draft/awaitingRatification but
    /// tape genesis has not yet been confirmed (P1.9 kernel import pending).
    ///
    /// - Parameters:
    ///   - projectId:   Project identifier.
    ///   - budgetHash:  Current budget hash (for traceability in derive_source).
    ///   - specHash:    Current spec hash (for traceability in derive_source).
    /// - Returns:       A deterministic ViewIRDocument.
    public static func projectReadyPendingCard(
        projectId: String,
        budgetHash: String,
        specHash: String
    ) -> ViewIRDocument {

        let summaryBlock = ViewIRBlock.summaryCard(SummaryCardPayload(
            title: "Project Not Yet Ready",
            body:  "Project '\(projectId)' has a sealed spec and budget draft. " +
                   "Project Ready state requires kernel tape genesis — " +
                   "awaiting runtime import (A1_9_01 / P1.9 lane).\n" +
                   "This is not an error. Tape genesis = constitutional ceremony, not a UI action."
        ))

        let checklistBlock = ViewIRBlock.summaryCard(SummaryCardPayload(
            title: "Pending Ceremonies",
            body:  "[ ] Signature #1 (spec ratification) via kernel\n" +
                   "[ ] Signature #2 (budget approval) via kernel\n" +
                   "[ ] tape_genesis_node written by ChainTape\n" +
                   "Once all three complete, project_ready=true is derivable from tape."
        ))

        return ViewIRDocument(
            kind: "project_ready_pending",
            deriveSource: [
                "budget_draft:\(budgetHash)",
                "spec:\(specHash)",
                "project:\(projectId)",
                "pending:tape_genesis",
            ],
            blocks: [summaryBlock, checklistBlock]
        )
    }
}

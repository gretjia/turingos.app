// ObserveOnlyStatistics.swift — A1_24: strategy observe-only layer — pure stat functions.
//
// Governing ruling §二-1 / WHITEPAPER §12 v0 observe-only phase:
//   Budget consumed, queue congestion, repeated failures, CI cost, worker
//   reliability, human review burden — ALL are deterministic statistics over
//   tape records.  Zero subjective valuation, zero market signals.
//
// Constitution Art. I.2: statistics are deterministic algorithms over observed
// data only.
//
// DESIGN CONTRACT:
//   - Pure functions — same input → byte-identical output.
//   - No IO, no singletons, no network, no randomness, no date-based logic.
//   - All output arrays are deterministically sorted (documented per function).
//   - Rational arithmetic for rates: use (numerator, denominator) integer pairs
//     and render as "x/y" strings — no floating-point surprises.
//
// Input record types are lightweight value types defined in this file.
// Real tape records arrive later via the kernel tape pipeline; these types
// serve as the typed boundary until that integration is wired.

import Foundation

// MARK: - Input record types
// (lite value types; real tape records arrive later — doc comment)

/// Lite record: budget consumed by a single worktree task.
/// Real tape source: WorktreeBudgetConsumed event payload.
public struct BudgetRecord: Sendable, Equatable {
    public let worktreeId: String
    /// Tokens consumed (nil = not recorded for this record).
    public let tokens:     Int?
    /// USD cost (nil = not recorded for this record).
    public let costUsd:    Double?
    /// CI cycles consumed (nil = not recorded for this record).
    public let ciCycles:   Int?

    public init(worktreeId: String, tokens: Int? = nil, costUsd: Double? = nil, ciCycles: Int? = nil) {
        self.worktreeId = worktreeId
        self.tokens     = tokens
        self.costUsd    = costUsd
        self.ciCycles   = ciCycles
    }
}

/// Lite record: one observed failure with a reject class label.
/// Real tape source: WorktreeFailureObserved / CIResultObserved event payload.
public struct FailureRecordLite: Sendable, Equatable {
    public let worktreeId:   String
    public let rejectClass:  String

    public init(worktreeId: String, rejectClass: String) {
        self.worktreeId  = worktreeId
        self.rejectClass = rejectClass
    }
}

/// Lite record: one CI run.
/// Real tape source: CIRunCompleted event payload.
public struct CIRunRecord: Sendable, Equatable {
    public let branch:   String
    public let costUsd:  Double
    public let passed:   Bool

    public init(branch: String, costUsd: Double, passed: Bool) {
        self.branch  = branch
        self.costUsd = costUsd
        self.passed  = passed
    }
}

/// Lite record: outcome of a single work unit by a worker.
/// Real tape source: WorkOutcomeRecorded event payload.
public struct WorkOutcomeRecord: Sendable, Equatable {
    public let workerId: String
    public let success:  Bool

    public init(workerId: String, success: Bool) {
        self.workerId = workerId
        self.success  = success
    }
}

/// Lite record: one human approval event.
/// Real tape source: ApprovalDecided / ApprovalPending event payload.
public struct ApprovalEventLite: Sendable, Equatable {
    public let envelopeRef: String
    public let decided:     Bool   // false = still pending

    public init(envelopeRef: String, decided: Bool) {
        self.envelopeRef = envelopeRef
        self.decided     = decided
    }
}

// MARK: - Summary output types

/// Budget summary for one worktree.
public struct WorktreeBudgetSummary: Sendable, Equatable {
    public let worktreeId:    String
    public let totalTokens:   Int
    public let totalCostUsd:  Double
    public let totalCiCycles: Int

    public init(worktreeId: String, totalTokens: Int, totalCostUsd: Double, totalCiCycles: Int) {
        self.worktreeId    = worktreeId
        self.totalTokens   = totalTokens
        self.totalCostUsd  = totalCostUsd
        self.totalCiCycles = totalCiCycles
    }
}

/// Failure count for one reject class.
public struct RejectClassCount: Sendable, Equatable {
    public let rejectClass:   String
    public let count:         Int
    /// True when count >= the threshold passed to repeatedFailures(_:threshold:).
    public let isRecurrent:   Bool

    public init(rejectClass: String, count: Int, isRecurrent: Bool) {
        self.rejectClass = rejectClass
        self.count       = count
        self.isRecurrent = isRecurrent
    }
}

/// CI cost summary across all branches.
public struct CICostSummary: Sendable, Equatable {
    public let totalCostUsd:    Double
    public let totalRuns:       Int
    public let perBranch:       [BranchCISummary]

    public init(totalCostUsd: Double, totalRuns: Int, perBranch: [BranchCISummary]) {
        self.totalCostUsd = totalCostUsd
        self.totalRuns    = totalRuns
        self.perBranch    = perBranch
    }
}

/// CI cost + run count for one branch.
public struct BranchCISummary: Sendable, Equatable {
    public let branch:      String
    public let runs:        Int
    public let costUsd:     Double
    public let passedRuns:  Int

    public init(branch: String, runs: Int, costUsd: Double, passedRuns: Int) {
        self.branch     = branch
        self.runs       = runs
        self.costUsd    = costUsd
        self.passedRuns = passedRuns
    }
}

/// Success-rate summary for one worker.
/// Rate expressed as "successCount/totalCount" (rational, no float).
public struct WorkerSuccessSummary: Sendable, Equatable {
    public let workerId:      String
    public let successCount:  Int
    public let totalCount:    Int
    /// Rational string representation: "\(successCount)/\(totalCount)".
    public let rateString:    String

    public init(workerId: String, successCount: Int, totalCount: Int) {
        self.workerId     = workerId
        self.successCount = successCount
        self.totalCount   = totalCount
        self.rateString   = "\(successCount)/\(totalCount)"
    }
}

/// Human review burden counts.
public struct ReviewBurden: Sendable, Equatable {
    public let pendingCount:  Int
    public let decidedCount:  Int

    public init(pendingCount: Int, decidedCount: Int) {
        self.pendingCount = pendingCount
        self.decidedCount = decidedCount
    }
}

// MARK: - ObserveOnlyStatistics

/// Pure, deterministic statistics over typed tape records.
///
/// GUARANTEES:
///   - Every function is referentially transparent: same input → same output.
///   - No IO, no singletons, no randomness, no date-based branching.
///   - All collection outputs are stably sorted (order documented per function).
///   - Rational arithmetic for rates: "successCount/totalCount" strings.
public enum ObserveOnlyStatistics {

    // MARK: - 1. budgetConsumedByWorktree

    /// Aggregate budget consumption per worktree.
    ///
    /// Returns summaries sorted ascending by worktreeId (deterministic, stable).
    /// Worktrees with zero records are not emitted.
    public static func budgetConsumedByWorktree(
        _ records: [BudgetRecord]
    ) -> [WorktreeBudgetSummary] {
        // Group by worktreeId.
        var tokenMap:   [String: Int]    = [:]
        var costMap:    [String: Double] = [:]
        var cyclesMap:  [String: Int]    = [:]
        var seen:       [String]         = []  // insertion-order set for determinism

        for r in records {
            if !seen.contains(r.worktreeId) { seen.append(r.worktreeId) }
            tokenMap[r.worktreeId,  default: 0] += r.tokens   ?? 0
            costMap[r.worktreeId,   default: 0] += r.costUsd  ?? 0
            cyclesMap[r.worktreeId, default: 0] += r.ciCycles ?? 0
        }

        // Sort by worktreeId ascending (deterministic).
        return seen.sorted().map { wid in
            WorktreeBudgetSummary(
                worktreeId:    wid,
                totalTokens:   tokenMap[wid]  ?? 0,
                totalCostUsd:  costMap[wid]   ?? 0,
                totalCiCycles: cyclesMap[wid] ?? 0
            )
        }
    }

    // MARK: - 2. repeatedFailures

    /// Count failures grouped by rejectClass.  Flag entries where count >= threshold.
    ///
    /// - Parameter threshold: minimum count to flag as recurrent (default = 2).
    ///
    /// Returns results sorted descending by count, then ascending by rejectClass
    /// for tie-breaking (deterministic, stable).
    public static func repeatedFailures(
        _ records: [FailureRecordLite],
        threshold: Int = 2
    ) -> [RejectClassCount] {
        var countMap: [String: Int] = [:]
        for r in records {
            countMap[r.rejectClass, default: 0] += 1
        }
        return countMap
            .map { (cls, cnt) in
                RejectClassCount(
                    rejectClass: cls,
                    count:       cnt,
                    isRecurrent: cnt >= threshold
                )
            }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.rejectClass < rhs.rejectClass
            }
    }

    // MARK: - 3. ciCostSummary

    /// Totals and per-branch breakdown of CI run costs.
    ///
    /// Per-branch results sorted ascending by branch name (deterministic, stable).
    public static func ciCostSummary(
        _ records: [CIRunRecord]
    ) -> CICostSummary {
        var totalCost:  Double = 0
        var runMap:     [String: Int]    = [:]
        var costMap:    [String: Double] = [:]
        var passedMap:  [String: Int]    = [:]
        var seen:       [String]         = []

        for r in records {
            if !seen.contains(r.branch) { seen.append(r.branch) }
            totalCost += r.costUsd
            runMap[r.branch,    default: 0] += 1
            costMap[r.branch,   default: 0] += r.costUsd
            passedMap[r.branch, default: 0] += r.passed ? 1 : 0
        }

        let perBranch = seen.sorted().map { branch in
            BranchCISummary(
                branch:     branch,
                runs:       runMap[branch]    ?? 0,
                costUsd:    costMap[branch]   ?? 0,
                passedRuns: passedMap[branch] ?? 0
            )
        }

        return CICostSummary(
            totalCostUsd: totalCost,
            totalRuns:    records.count,
            perBranch:    perBranch
        )
    }

    // MARK: - 4. workerSuccessRate

    /// Success rate per worker expressed as rational "x/y" string.
    ///
    /// Returns summaries sorted ascending by workerId (deterministic, stable).
    /// Workers with zero records are not emitted.
    public static func workerSuccessRate(
        _ records: [WorkOutcomeRecord]
    ) -> [WorkerSuccessSummary] {
        var successMap: [String: Int] = [:]
        var totalMap:   [String: Int] = [:]
        var seen:       [String]      = []

        for r in records {
            if !seen.contains(r.workerId) { seen.append(r.workerId) }
            totalMap[r.workerId,   default: 0] += 1
            successMap[r.workerId, default: 0] += r.success ? 1 : 0
        }

        return seen.sorted().map { wid in
            WorkerSuccessSummary(
                workerId:     wid,
                successCount: successMap[wid] ?? 0,
                totalCount:   totalMap[wid]   ?? 0
            )
        }
    }

    // MARK: - 5. humanReviewBurden

    /// Count pending vs decided approval events.
    ///
    /// Returns a single ReviewBurden struct (no sorting needed — scalar output).
    public static func humanReviewBurden(
        _ records: [ApprovalEventLite]
    ) -> ReviewBurden {
        let decidedCount = records.filter(\.decided).count
        let pendingCount = records.count - decidedCount
        return ReviewBurden(pendingCount: pendingCount, decidedCount: decidedCount)
    }
}

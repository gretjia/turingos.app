// BudgetContract.swift — Budget + Autonomy Contract model (A1_19, draft domain only).
//
// CONSTITUTIONAL BOUNDARY (docs/UPSTREAM_CONTRACT.md):
//   "App 想在上游不可达时'暂记'一笔 ratification → 拒绝：fail-closed，仪式不可用就是不可用"
//
// The runtime tape (ChainTape / approval_envelope) is not yet imported (P1.9 lane).
// Therefore this type models the DRAFT side only.  BudgetContractStatus has exactly
// two cases:
//   • draft                — user is editing / reviewing
//   • awaitingRatification — contract sealed; awaiting kernel signature #2 ceremony
//
// There is DELIBERATELY no `ratified` case.  Ratification is a kernel-side tape event
// (approval_envelope kind, signature_node==2).  Recording it here would violate
// UPSTREAM_CONTRACT iron law 1 ("外壳不复制 canonical state logic") and the judgment:
// "App 想在上游不可达时'暂记'一笔 ratification → 拒绝：fail-closed".
// Type-level enforcement: CaseIterable test in BudgetContractTests asserts
// BudgetContractStatus.allCases.count == 2.
//
// This is the exact same pattern as SpecPackage (A1_18), SkillStatus (A1_29),
// and ModelGateway.tapeSink guard (A1_22).

import CryptoKit
import Foundation

// MARK: - BudgetContractStatus

/// Lifecycle of a draft Budget + Autonomy Contract.
///
/// Exactly two cases — see constitutional comment at top of file.
public enum BudgetContractStatus: String, Codable, CaseIterable, Sendable, Equatable {
    /// User is actively drafting; limits not yet sealed.
    case draft
    /// Contract is sealed; awaiting kernel ceremony (signature #2, approval_envelope.signature_node==2).
    /// Kernel writes the approval_envelope to tape — this type never records that.
    case awaitingRatification = "awaiting_ratification"
}

// MARK: - BudgetLimits

/// Spending and time limits for the project lifecycle.
///
/// All limits participate in budgetHash (whitepaper §7.2 / docs/01_KERNEL_CONTRACTS.md I5).
public struct BudgetLimits: Codable, Sendable, Equatable {
    /// Total model token budget (input + output).
    public var tokenLimit: Int
    /// Wall-clock time limit in seconds.
    public var wallClockSecs: Int
    /// Maximum external tool calls allowed.
    public var toolCallsLimit: Int
    /// Maximum CI run cycles.
    public var ciCyclesLimit: Int
    /// Maximum reviewer attention burden in hours.
    public var reviewerBurdenHours: Double
    /// Maximum dispatches to external agents.
    public var externalDispatchLimit: Int
    /// Human-readable stop-loss trigger condition.
    public var stopLossLine: String

    enum CodingKeys: String, CodingKey {
        case tokenLimit             = "token_limit"
        case wallClockSecs          = "wall_clock_secs"
        case toolCallsLimit         = "tool_calls_limit"
        case ciCyclesLimit          = "ci_cycles_limit"
        case reviewerBurdenHours    = "reviewer_burden_hours"
        case externalDispatchLimit  = "external_dispatch_limit"
        case stopLossLine           = "stop_loss_line"
    }

    public init(
        tokenLimit: Int,
        wallClockSecs: Int,
        toolCallsLimit: Int = 500,
        ciCyclesLimit: Int = 20,
        reviewerBurdenHours: Double = 2.0,
        externalDispatchLimit: Int = 5,
        stopLossLine: String = "halt_on_3_consecutive_ci_failures"
    ) {
        self.tokenLimit = tokenLimit
        self.wallClockSecs = wallClockSecs
        self.toolCallsLimit = toolCallsLimit
        self.ciCyclesLimit = ciCyclesLimit
        self.reviewerBurdenHours = reviewerBurdenHours
        self.externalDispatchLimit = externalDispatchLimit
        self.stopLossLine = stopLossLine
    }
}

// MARK: - AutonomyConstraints

/// Governance rules for automated agent behaviour within this project.
public struct AutonomyConstraints: Codable, Sendable, Equatable {
    /// Maximum consecutive failures before triggering HALT-止损 (docs/02 §5.3).
    public var maxRetryBeforeHalt: Int
    /// Require human review (signature #5) before any merge, regardless of provenance.
    public var requireHumanReviewBeforeMerge: Bool
    /// Channels to surface HALT-止损 and budget-approaching events.
    public var notificationChannels: [String]

    enum CodingKeys: String, CodingKey {
        case maxRetryBeforeHalt             = "max_retry_before_halt"
        case requireHumanReviewBeforeMerge  = "require_human_review_before_merge"
        case notificationChannels           = "notification_channels"
    }

    public init(
        maxRetryBeforeHalt: Int = 3,
        requireHumanReviewBeforeMerge: Bool = true,
        notificationChannels: [String] = ["attention_channel"]
    ) {
        self.maxRetryBeforeHalt = maxRetryBeforeHalt
        self.requireHumanReviewBeforeMerge = requireHumanReviewBeforeMerge
        self.notificationChannels = notificationChannels
    }

    public static let sane = AutonomyConstraints()
}

// MARK: - BudgetContractValidator

/// Validates a BudgetContract for structural soundness before sealing.
///
/// Validation failures return a non-empty array of error strings.
/// An empty array means the contract is valid.
public struct BudgetContractValidator {
    private init() {}

    public static func validate(_ contract: BudgetContract) -> [String] {
        var errors: [String] = []
        if contract.limits.tokenLimit <= 0 {
            errors.append("token_limit must be > 0 (got \(contract.limits.tokenLimit))")
        }
        if contract.limits.wallClockSecs <= 0 {
            errors.append("wall_clock_secs must be > 0 (got \(contract.limits.wallClockSecs))")
        }
        if contract.limits.toolCallsLimit < 0 {
            errors.append("tool_calls_limit must be >= 0 (got \(contract.limits.toolCallsLimit))")
        }
        if contract.limits.ciCyclesLimit < 0 {
            errors.append("ci_cycles_limit must be >= 0 (got \(contract.limits.ciCyclesLimit))")
        }
        if contract.limits.reviewerBurdenHours < 0 {
            errors.append("reviewer_burden_hours must be >= 0 (got \(contract.limits.reviewerBurdenHours))")
        }
        if contract.limits.externalDispatchLimit < 0 {
            errors.append("external_dispatch_limit must be >= 0 (got \(contract.limits.externalDispatchLimit))")
        }
        if contract.limits.stopLossLine.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("stop_loss_line must be non-empty")
        }
        if contract.autonomy.maxRetryBeforeHalt <= 0 {
            errors.append("max_retry_before_halt must be > 0 (got \(contract.autonomy.maxRetryBeforeHalt))")
        }
        if contract.projectId.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append("project_id must be non-empty")
        }
        return errors
    }
}

// MARK: - BudgetContract

/// Budget + Autonomy Contract (项目预算契约) — whitepaper §7.2 立法回路.
///
/// ## Three-piece projection declaration (UPSTREAM_CONTRACT iron law 3)
/// - derive_source:      user_input + spec_hash
/// - schema_version:     tos.app.budget_contract.v0
/// - rebuild_command:    re-run budget wizard from draft store
///
/// budgetHash covers limits + autonomy (excludes status and projectId),
/// matching approval_envelope.budget_hash field semantics (contracts/approval_envelope.schema.json).
/// Status and projectId changes do NOT change the hash.
/// Any limit or autonomy change DOES change the hash.
public struct BudgetContract: Codable, Sendable, Equatable {

    public static let schemaVersionValue = "tos.app.budget_contract.v0"

    // MARK: Projection schema_version
    public let schemaVersion: String

    // MARK: Identity
    public let projectId: String

    // MARK: Content fields (all included in budgetHash)
    public var limits: BudgetLimits
    public var autonomy: AutonomyConstraints

    // MARK: Lifecycle (excluded from budgetHash)
    public var status: BudgetContractStatus

    enum CodingKeys: String, CodingKey {
        case schemaVersion  = "schema_version"
        case projectId      = "project_id"
        case limits
        case autonomy
        case status
    }

    public init(
        projectId: String,
        limits: BudgetLimits,
        autonomy: AutonomyConstraints = .sane
    ) {
        self.schemaVersion  = Self.schemaVersionValue
        self.projectId      = projectId
        self.limits         = limits
        self.autonomy       = autonomy
        self.status         = .draft
    }

    // MARK: - budgetHash

    /// SHA-256 over the canonical JSON encoding of limits + autonomy.
    /// status and projectId are excluded (identity/lifecycle metadata, not contract content).
    ///
    /// Pattern mirrors SpecPackage.specHash (A1_18) — sortedKeys canonical JSON.
    public var budgetHash: String {
        struct ContentOnly: Codable {
            var limits: BudgetLimits
            var autonomy: AutonomyConstraints
        }
        let content = ContentOnly(limits: limits, autonomy: autonomy)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(content) else { return "sha256:error" }
        let digest = SHA256.hash(data: data)
        return "sha256:" + digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

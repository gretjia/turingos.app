// SpecPackage.swift — Init Spec Package model (A1_18, draft domain only).
//
// CONSTITUTIONAL BOUNDARY (docs/UPSTREAM_CONTRACT.md):
//   "App 想在上游不可达时'暂记'一笔 ratification → 拒绝：fail-closed，仪式不可用就是不可用"
//
// The runtime tape (ChainTape / approval_envelope) is not yet imported (P1.9 lane).
// Therefore this type models the DRAFT side only.  SpecStatus has exactly two cases:
//   • draft             — user is still editing
//   • awaitingRatification — all fields filled; draft sealed; sent to kernel ceremony queue
//
// There is DELIBERATELY no `ratified` case.  Ratification is a kernel-side tape event
// (approval_envelope kind, signature_node==1).  Recording it here would violate
// UPSTREAM_CONTRACT iron law 1 ("外壳不复制 canonical state logic") and the
// boundary judgment: "App 想在上游不可达时'暂记'一笔 ratification → 拒绝：fail-closed".
// Type-level enforcement: CaseIterable test in SpecDraftTests asserts .allCases.count == 2.

import CryptoKit
import Foundation

// MARK: - SpecStatus

/// Lifecycle of a draft Init Spec Package.
///
/// Only two cases exist — see constitutional comment at top of file.
public enum SpecStatus: String, Codable, CaseIterable, Sendable, Equatable {
    /// User is actively drafting; not yet sealed.
    case draft
    /// Draft is sealed and awaiting the kernel ratification ceremony (signature #1).
    /// Kernel writes the approval_envelope to tape — this type never records that.
    case awaitingRatification = "awaiting_ratification"
}

// MARK: - SpecPackage

/// Init Spec Package (项目小宪法) — white paper §7.2 "Init Spec Package" contents:
/// 目标/非目标/DoD/验收谓词/数据边界/工具权限/CI 规则/风险/外派策略 + worktree plan + budget suggestion.
///
/// ## Three-piece projection declaration (UPSTREAM_CONTRACT iron law 3)
/// - derive_source:      user_input + catalog
/// - schema_version:     tos.app.spec_draft.v0
/// - rebuild_command:    re-run wizard (SpecDraftWizard.run or Retro-Init prefill path)
///
/// specHash covers all *content* fields (excludes `status` and `projectId`) using a
/// canonical JSON encoding (sortedKeys).  Status changes do NOT change the hash.
/// Content changes DO change the hash.  This mirrors how the kernel references a Spec
/// by hash in `spec_ratified` tape nodes (docs/03_OPERATING_FLOW_ACCEPTANCE_TESTS §2 PR-1).
public struct SpecPackage: Codable, Sendable, Equatable {
    // MARK: Projection three-piece (embedded in every persisted instance)
    public let schemaVersion: String
    // derive_source and rebuild_command are stored alongside each instance in the
    // SpecDraftStore envelope; they are not fields on SpecPackage itself to keep
    // the hash surface clean.

    // MARK: Identity
    public let projectId: String

    // MARK: Content fields (all included in specHash)
    public var goals: [String]
    public var nonGoals: [String]
    public var currentState: String
    public var definitionOfDone: [String]
    public var acceptancePredicates: [String]
    public var dataScope: [String]
    public var toolPermissions: [String]
    public var ciRules: [String]
    public var initialWorktreePlan: [String]
    public var risks: [String]
    public var budgetSuggestion: String
    public var externalDelegationPolicy: String

    // MARK: Status (excluded from hash — see constitutional comment above)
    public var status: SpecStatus

    // MARK: CodingKeys
    enum CodingKeys: String, CodingKey {
        case schemaVersion           = "schema_version"
        case projectId               = "project_id"
        case goals
        case nonGoals                = "non_goals"
        case currentState            = "current_state"
        case definitionOfDone        = "definition_of_done"
        case acceptancePredicates    = "acceptance_predicates"
        case dataScope               = "data_scope"
        case toolPermissions         = "tool_permissions"
        case ciRules                 = "ci_rules"
        case initialWorktreePlan     = "initial_worktree_plan"
        case risks
        case budgetSuggestion        = "budget_suggestion"
        case externalDelegationPolicy = "external_delegation_policy"
        case status
    }

    // MARK: Initialiser
    public init(
        projectId: String,
        goals: [String] = [],
        nonGoals: [String] = [],
        currentState: String = "",
        definitionOfDone: [String] = [],
        acceptancePredicates: [String] = [],
        dataScope: [String] = [],
        toolPermissions: [String] = [],
        ciRules: [String] = [],
        initialWorktreePlan: [String] = [],
        risks: [String] = [],
        budgetSuggestion: String = "",
        externalDelegationPolicy: String = "",
        status: SpecStatus = .draft
    ) {
        self.schemaVersion           = "tos.app.spec_draft.v0"
        self.projectId               = projectId
        self.goals                   = goals
        self.nonGoals                = nonGoals
        self.currentState            = currentState
        self.definitionOfDone        = definitionOfDone
        self.acceptancePredicates    = acceptancePredicates
        self.dataScope               = dataScope
        self.toolPermissions         = toolPermissions
        self.ciRules                 = ciRules
        self.initialWorktreePlan     = initialWorktreePlan
        self.risks                   = risks
        self.budgetSuggestion        = budgetSuggestion
        self.externalDelegationPolicy = externalDelegationPolicy
        self.status                  = status
    }

    // MARK: - specHash

    /// SHA-256 over the canonical JSON encoding of content fields (sortedKeys,
    /// status and projectId excluded — they are identity/lifecycle metadata, not Spec content).
    ///
    /// Same content → same hash, regardless of status.
    /// Any content change → different hash.
    public var specHash: String {
        struct ContentOnly: Codable {
            var goals: [String]
            var nonGoals: [String]
            var currentState: String
            var definitionOfDone: [String]
            var acceptancePredicates: [String]
            var dataScope: [String]
            var toolPermissions: [String]
            var ciRules: [String]
            var initialWorktreePlan: [String]
            var risks: [String]
            var budgetSuggestion: String
            var externalDelegationPolicy: String

            enum CodingKeys: String, CodingKey {
                case goals
                case nonGoals                = "non_goals"
                case currentState            = "current_state"
                case definitionOfDone        = "definition_of_done"
                case acceptancePredicates    = "acceptance_predicates"
                case dataScope               = "data_scope"
                case toolPermissions         = "tool_permissions"
                case ciRules                 = "ci_rules"
                case initialWorktreePlan     = "initial_worktree_plan"
                case risks
                case budgetSuggestion        = "budget_suggestion"
                case externalDelegationPolicy = "external_delegation_policy"
            }
        }
        let content = ContentOnly(
            goals: goals,
            nonGoals: nonGoals,
            currentState: currentState,
            definitionOfDone: definitionOfDone,
            acceptancePredicates: acceptancePredicates,
            dataScope: dataScope,
            toolPermissions: toolPermissions,
            ciRules: ciRules,
            initialWorktreePlan: initialWorktreePlan,
            risks: risks,
            budgetSuggestion: budgetSuggestion,
            externalDelegationPolicy: externalDelegationPolicy
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(content) else { return "sha256:error" }
        let digest = SHA256.hash(data: data)
        return "sha256:" + digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

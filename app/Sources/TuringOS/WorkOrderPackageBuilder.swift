// WorkOrderPackageBuilder.swift — build a WorkOrderPackage from a SpecPackage (A1_18).
//
// Contract: the resulting WorkOrderPackage struct, when JSON-encoded, must
// contain ALL required keys from contracts/work_order_package.schema.json.
// The test SpecDraftTests.testWorkOrderPackageBuilderSchemaKeys() asserts this
// mechanically by reading the schema file at test time and comparing the
// required[] array against the encoded JSON keys.
//
// Required keys (contracts/work_order_package.schema.json § "required"):
//   schema_version, work_order_id, project_id, spec_ref,
//   worktree_scope, allowed_files, forbidden_files,
//   objective, expected_outputs, acceptance_predicates,
//   budget_slice, provenance_requirement, prompt

import Foundation

// MARK: - ProvenanceRequirement

/// Maps to contracts/work_order_package.schema.json provenance_requirement enum.
public enum ProvenanceRequirement: String, Codable, Sendable, Equatable {
    case full                    = "full"
    case partialWithHumanConfirm = "partial_with_human_confirm"
}

// MARK: - BudgetSlice

/// Mirrors the budget_slice object in the schema (open object — extensible).
public struct BudgetSlice: Codable, Sendable, Equatable {
    public let description: String
    public let tokenBudget: Int?
    public let costUsdBudget: Double?
    public let ciCyclesBudget: Int?

    enum CodingKeys: String, CodingKey {
        case description
        case tokenBudget      = "token_budget"
        case costUsdBudget    = "cost_usd_budget"
        case ciCyclesBudget   = "ci_cycles_budget"
    }

    public init(
        description: String,
        tokenBudget: Int? = nil,
        costUsdBudget: Double? = nil,
        ciCyclesBudget: Int? = nil
    ) {
        self.description      = description
        self.tokenBudget      = tokenBudget
        self.costUsdBudget    = costUsdBudget
        self.ciCyclesBudget   = ciCyclesBudget
    }
}

// MARK: - WorkOrderPackage

/// Codable struct whose JSON encoding matches the schema
/// contracts/work_order_package.schema.json exactly.
///
/// CodingKeys are the snake_case schema keys — no divergence allowed.
public struct WorkOrderPackage: Codable, Sendable, Equatable {
    public let schemaVersion:         String              // "tos.app.work_order_package.v0"
    public let workOrderId:           String
    public let projectId:             String
    public let specRef:               String              // specHash of the SpecPackage
    public let worktreeScope:         String
    public let allowedFiles:          [String]
    public let forbiddenFiles:        [String]
    public let objective:             String
    public let expectedOutputs:       [String]
    public let acceptancePredicates:  [String]
    public let budgetSlice:           BudgetSlice
    public let provenanceRequirement: ProvenanceRequirement
    public let prompt:                String

    enum CodingKeys: String, CodingKey {
        case schemaVersion         = "schema_version"
        case workOrderId           = "work_order_id"
        case projectId             = "project_id"
        case specRef               = "spec_ref"
        case worktreeScope         = "worktree_scope"
        case allowedFiles          = "allowed_files"
        case forbiddenFiles        = "forbidden_files"
        case objective
        case expectedOutputs       = "expected_outputs"
        case acceptancePredicates  = "acceptance_predicates"
        case budgetSlice           = "budget_slice"
        case provenanceRequirement = "provenance_requirement"
        case prompt
    }
}

// MARK: - WorkOrderPackageBuilder

/// Builds a WorkOrderPackage from a SpecPackage.
///
/// The specRef is the SpecPackage.specHash (SHA-256 over canonical content JSON).
/// A unique work_order_id is generated via UUID.
///
/// Budget is expressed as a plain BudgetSlice.  Caller is responsible for keeping
/// the budget slice inside the ratified budget_contract from the kernel.
public enum WorkOrderPackageBuilder {

    /// Build a WorkOrderPackage from a sealed SpecPackage (status must be .awaitingRatification
    /// or .draft — the builder does not require ratification because it operates in the
    /// draft domain; the dispatch harness is responsible for requiring Project Ready).
    ///
    /// - Parameters:
    ///   - spec:                   Source SpecPackage.
    ///   - objective:              Task objective description.
    ///   - worktreeScope:          Worktree scope declaration string.
    ///   - allowedFiles:           Path glob list for files this work order may modify.
    ///   - forbiddenFiles:         Path glob list for files this work order must not touch.
    ///   - expectedOutputs:        List of expected output artifacts.
    ///   - budgetSlice:            Budget slice for this work order.
    ///   - provenanceRequirement:  full or partial_with_human_confirm.
    ///   - prompt:                 Full prompt to dispatch to the execution agent.
    /// - Returns: A WorkOrderPackage ready for dispatch.
    public static func build(
        from spec: SpecPackage,
        objective: String,
        worktreeScope: String,
        allowedFiles: [String],
        forbiddenFiles: [String],
        expectedOutputs: [String],
        budgetSlice: BudgetSlice,
        provenanceRequirement: ProvenanceRequirement,
        prompt: String
    ) -> WorkOrderPackage {
        WorkOrderPackage(
            schemaVersion:         "tos.app.work_order_package.v0",
            workOrderId:           UUID().uuidString,
            projectId:             spec.projectId,
            specRef:               spec.specHash,
            worktreeScope:         worktreeScope,
            allowedFiles:          allowedFiles,
            forbiddenFiles:        forbiddenFiles,
            objective:             objective,
            expectedOutputs:       expectedOutputs,
            acceptancePredicates:  spec.acceptancePredicates,
            budgetSlice:           budgetSlice,
            provenanceRequirement: provenanceRequirement,
            prompt:                prompt
        )
    }
}

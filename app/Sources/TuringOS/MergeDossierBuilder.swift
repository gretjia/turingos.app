// MergeDossierBuilder.swift — A1_45: 回路2 slice terminus.
//
// On ∏p==PASS, build the evidentiary MergeDossier (merge_dossier.schema.json)
// from the PredicateResult + git facts, and give the "可 merge" verdict.
//
// R1 CONSTITUTIONAL LAW (WHITEPAPER §7.3): a PARTIAL-provenance candidate (the
// external-dispatch worker model) is NOT allowed pure-predicate pass-through —
// it MUST escalate to a human signature at node 5. So provenance=PARTIAL ⇒
// approval_route=signature_5, NEVER autonomy_contract.
//
// FAIL ⇒ NO dossier (a failure certificate path instead). The slice stops at
// "可 merge, routed to signature_5" — no real merge, no signature ceremony.

import Foundation
import CryptoKit

public struct MergeDossier: Codable, Equatable, Sendable {
    public enum ProvenanceLevel: String, Codable, Sendable {
        case full = "FULL", repoLevel = "REPO_LEVEL", partial = "PARTIAL", outside = "OUTSIDE_GOVERNANCE"
    }
    public enum ApprovalRoute: String, Codable, Sendable {
        case autonomyContract = "autonomy_contract", signature5 = "signature_5"
    }

    public struct CiEvidence: Codable, Equatable, Sendable {
        public let commitSha: String
        public let mergeBase: String
        public let checkRunIds: [String]
        public let workflowFileHash: String
        public let branchProtectionSnapshot: [String: String]
        public let requiredChecksAtTime: [String]
        public let runnerType: String
        public let conclusion: String

        enum CodingKeys: String, CodingKey {
            case commitSha = "commit_sha"
            case mergeBase = "merge_base"
            case checkRunIds = "check_run_ids"
            case workflowFileHash = "workflow_file_hash"
            case branchProtectionSnapshot = "branch_protection_snapshot"
            case requiredChecksAtTime = "required_checks_at_time"
            case runnerType = "runner_type"
            case conclusion
        }
    }

    public struct RiskFinding: Codable, Equatable, Sendable {
        public let dimension: String
        public let note: String
    }

    public let schemaVersion: String
    public let dossierId: String
    public let projectId: String
    public let specDelta: [String: String]
    public let ciEvidence: CiEvidence
    public let changedFiles: [String]
    public let riskFindings: [RiskFinding]
    public let rollbackPlan: String
    public let budgetUsed: [String: String]
    public let provenanceLevel: ProvenanceLevel
    public let receipts: [String]
    public let knownLimitations: [String]
    public let approvalRoute: ApprovalRoute

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case dossierId = "dossier_id"
        case projectId = "project_id"
        case specDelta = "spec_delta"
        case ciEvidence = "ci_evidence"
        case changedFiles = "changed_files"
        case riskFindings = "risk_findings"
        case rollbackPlan = "rollback_plan"
        case budgetUsed = "budget_used"
        case provenanceLevel = "provenance_level"
        case receipts
        case knownLimitations = "known_limitations"
        case approvalRoute = "approval_route"
    }
}

public enum MergeDossierError: Error, Equatable, Sendable {
    /// ∏p did not pass — no dossier is produced (FAIL path = failure certificate).
    case predicateNotPassing(verdict: String)
}

public enum MergeDossierBuilder {
    public static func build(
        predicate: PredicateResult,
        projectId: String,
        worktreeBranch: String,
        commitSha: String,
        mergeBase: String,
        changedFiles: [String],
        provenance: MergeDossier.ProvenanceLevel = .partial,
        specDelta: [String: String] = [:],
        riskFindings: [MergeDossier.RiskFinding] = []
    ) throws -> MergeDossier {
        // Only PASS produces a dossier.
        guard predicate.verdict == .pass else {
            throw MergeDossierError.predicateNotPassing(verdict: predicate.verdict.rawValue)
        }

        // R1 LAW: anything short of locally-verified FULL provenance must route
        // to signature_5 (no autonomy auto-merge for external/partial work).
        let route: MergeDossier.ApprovalRoute = (provenance == .full) ? .autonomyContract : .signature5

        let ci = MergeDossier.CiEvidence(
            commitSha: commitSha,
            mergeBase: mergeBase,
            checkRunIds: [predicate.predicateId],
            workflowFileHash: predicate.evidenceHash,
            branchProtectionSnapshot: [:],
            requiredChecksAtTime: [predicate.predicateId],
            runnerType: "local_predicate_gate",
            conclusion: predicate.verdict.rawValue
        )

        let material = "\(projectId)\n\(worktreeBranch)\n\(commitSha)\n\(predicate.predicateId)"
        let hex = SHA256.hash(data: Data(material.utf8)).map { String(format: "%02x", $0) }.joined()
        let dossierId = "dossier_" + String(hex.prefix(16))

        let knownLimitations = [
            "provenance=\(provenance.rawValue)：外部 agent 产出的 diff，已由 ∏p 本地重新过门，但非动作级回执",
            "本切片仅到「可 merge 判定 + Dossier」；真 merge 与 签名#5 仪式在切片范围外",
        ]

        return MergeDossier(
            schemaVersion: "tos.app.merge_dossier.v0",
            dossierId: dossierId,
            projectId: projectId,
            specDelta: specDelta,
            ciEvidence: ci,
            changedFiles: changedFiles,
            riskFindings: riskFindings,
            rollbackPlan: "git worktree remove <path> + git branch -D \(worktreeBranch)（worktree 可回滚，未触 main）",
            budgetUsed: [:],
            provenanceLevel: provenance,
            receipts: [predicate.predicateId, predicate.evidenceHash],
            knownLimitations: knownLimitations,
            approvalRoute: route
        )
    }

    /// The "可 merge" verdict sentence for the UI (honest about the route).
    public static func verdictSentence(_ d: MergeDossier) -> String {
        switch d.approvalRoute {
        case .signature5:
            return "∏p 通过 → 可 merge，路由至 签名#5（partial provenance，真 merge 在切片范围外）"
        case .autonomyContract:
            return "∏p 通过 → 可 merge（autonomy_contract 范围内）"
        }
    }
}

// CIEvidenceCollector.swift — A1_20: assemble CIEvidence from a RepoObservationSource.
//
// Contract:
//   • CIEvidence Codable struct encodes all 8 required keys from
//     contracts/merge_dossier.schema.json ci_evidence:
//       commit_sha, merge_base, check_run_ids, workflow_file_hash,
//       branch_protection_snapshot, required_checks_at_time, runner_type, conclusion.
//   • Missing data (no branch protection access, no check runs) → explicit
//     "unavailable" marker values; keys are ALWAYS present in the JSON encoding
//     (fail-visible discipline: never silently drop required keys).
//   • Pure assembly — no git invocations, no network inside this file.
//     All side-effectful work is done by the injected RepoObservationSource.

import Foundation

// MARK: - ProvenanceLevel

/// Mirrors contracts/merge_dossier.schema.json provenance_level enum (UPPERCASE).
/// Must match the schema exactly — the test asserts case names against the schema.
public enum ProvenanceLevel: String, Codable, Sendable, Equatable, CaseIterable {
    case full             = "FULL"
    case repoLevel        = "REPO_LEVEL"
    case partial          = "PARTIAL"
    case outsideGovernance = "OUTSIDE_GOVERNANCE"
}

// MARK: - RiskFinding

/// One advisory finding in the risk_findings channel.
/// Carries NO verdict — advisory only (docs/03 §1.1 / contracts/merge_dossier.schema.json).
public struct RiskFinding: Codable, Sendable, Equatable {
    public let dimension: String
    public let note: String

    enum CodingKeys: String, CodingKey {
        case dimension, note
    }

    public init(dimension: String, note: String) {
        self.dimension = dimension
        self.note = note
    }
}

// MARK: - CIEvidence

/// Codable struct whose JSON encoding contains ALL 8 required keys of
/// merge_dossier.schema.json ci_evidence. Missing data → explicit "unavailable"
/// sentinel values; keys are always emitted (fail-visible).
public struct CIEvidence: Codable, Sendable, Equatable {

    // 1. commit_sha
    public let commitSha: String
    // 2. merge_base
    public let mergeBase: String
    // 3. check_run_ids (array of strings)
    public let checkRunIds: [String]
    // 4. workflow_file_hash (sha256:<hex>)
    public let workflowFileHash: String
    // 5. branch_protection_snapshot (raw JSON string object)
    public let branchProtectionSnapshot: BranchProtectionSnapshot
    // 6. required_checks_at_time (array of strings; "unavailable" sentinel when missing)
    public let requiredChecksAtTime: [String]
    // 7. runner_type
    public let runnerType: String
    // 8. conclusion
    public let conclusion: String

    enum CodingKeys: String, CodingKey {
        case commitSha              = "commit_sha"
        case mergeBase              = "merge_base"
        case checkRunIds            = "check_run_ids"
        case workflowFileHash       = "workflow_file_hash"
        case branchProtectionSnapshot = "branch_protection_snapshot"
        case requiredChecksAtTime   = "required_checks_at_time"
        case runnerType             = "runner_type"
        case conclusion
    }

    public init(
        commitSha: String,
        mergeBase: String,
        checkRunIds: [String],
        workflowFileHash: String,
        branchProtectionSnapshot: BranchProtectionSnapshot,
        requiredChecksAtTime: [String],
        runnerType: String,
        conclusion: String
    ) {
        self.commitSha = commitSha
        self.mergeBase = mergeBase
        self.checkRunIds = checkRunIds
        self.workflowFileHash = workflowFileHash
        self.branchProtectionSnapshot = branchProtectionSnapshot
        self.requiredChecksAtTime = requiredChecksAtTime
        self.runnerType = runnerType
        self.conclusion = conclusion
    }

    /// Sentinel values used when a field's data is unavailable.
    public enum Sentinel {
        public static let commitSha = "unavailable"
        public static let mergeBase = "unavailable"
        public static let checkRunIds: [String] = ["unavailable"]
        public static let workflowFileHash = "sha256:unavailable"
        public static let requiredChecksAtTime: [String] = ["unavailable"]
        public static let runnerType = "unavailable"
        public static let conclusion = "unavailable"
    }

    /// Convenience: an all-unavailable instance (e.g. when source has no access).
    public static let unavailable = CIEvidence(
        commitSha: Sentinel.commitSha,
        mergeBase: Sentinel.mergeBase,
        checkRunIds: Sentinel.checkRunIds,
        workflowFileHash: Sentinel.workflowFileHash,
        branchProtectionSnapshot: BranchProtectionSnapshot(raw: "unavailable"),
        requiredChecksAtTime: Sentinel.requiredChecksAtTime,
        runnerType: Sentinel.runnerType,
        conclusion: Sentinel.conclusion
    )
}

/// The branch_protection_snapshot field: encodes as a JSON object
/// wrapping the raw snapshot string (since the schema requires an object).
public struct BranchProtectionSnapshot: Codable, Sendable, Equatable {
    /// Raw JSON string from the API, or the literal "unavailable".
    public let raw: String

    enum CodingKeys: String, CodingKey {
        case raw = "raw_snapshot"
    }

    public init(raw: String) {
        self.raw = raw
    }
}

// MARK: - CIEvidenceCollector

/// Assembles CIEvidence from a RepoObservationSource for a given PR number.
/// Missing-data paths always produce explicit "unavailable" markers — never
/// silently drop required keys.
public enum CIEvidenceCollector {

    /// Assemble CIEvidence for a given PR (identified by prNumber + headRef).
    ///
    /// - Parameters:
    ///   - source:    The observation source (mock in tests; live in app).
    ///   - prNumber:  The PR number to evaluate.
    ///   - headRef:   The head branch ref name (e.g. "claude/a1-20-ci-observation").
    ///   - baseRef:   The base/target branch ref (e.g. "main").
    ///   - owner:     GitHub owner (e.g. "zephryj").
    ///   - repo:      GitHub repo name (e.g. "turingos.app").
    /// - Returns:     A fully-populated CIEvidence (unavailable sentinels for missing fields).
    public static func assemble(
        from source: any RepoObservationSource,
        prNumber: Int,
        headRef: String,
        baseRef: String = "main",
        owner: String = "",
        repo: String = ""
    ) -> CIEvidence {
        // 1. commit_sha
        let commitSha = (try? source.headSHA(branch: headRef))
            ?? CIEvidence.Sentinel.commitSha

        // 2. merge_base
        let mergeBase: String
        if commitSha == CIEvidence.Sentinel.commitSha {
            mergeBase = CIEvidence.Sentinel.mergeBase
        } else {
            mergeBase = (try? source.mergeBase(ref1: headRef, ref2: baseRef))
                ?? CIEvidence.Sentinel.mergeBase
        }

        // 3. check_run_ids + 7. runner_type + 8. conclusion
        let checkRuns = (try? source.checkRuns(prNumber: prNumber)) ?? []
        let checkRunIds: [String]
        let runnerType: String
        let conclusion: String
        if checkRuns.isEmpty {
            checkRunIds = CIEvidence.Sentinel.checkRunIds
            runnerType = CIEvidence.Sentinel.runnerType
            conclusion = CIEvidence.Sentinel.conclusion
        } else {
            checkRunIds = checkRuns.map(\.id)
            // Runner type: if all checks are github_actions, report that; else "mixed"
            let types = Set(checkRuns.map(\.runnerType))
            runnerType = types.count == 1 ? (types.first ?? "unknown") : "mixed"
            // Conclusion: "success" only if ALL checks succeeded; first failure wins
            if checkRuns.allSatisfy({ $0.conclusion == "success" || $0.conclusion == "skipped" }) {
                conclusion = "success"
            } else {
                conclusion = checkRuns.first(where: { $0.conclusion == "failure" })?
                    .conclusion ?? "pending"
            }
        }

        // 4. workflow_file_hash
        let workflowFileHash: String
        if commitSha == CIEvidence.Sentinel.commitSha {
            workflowFileHash = CIEvidence.Sentinel.workflowFileHash
        } else {
            workflowFileHash = (try? source.workflowFilesHash(commit: commitSha))
                ?? CIEvidence.Sentinel.workflowFileHash
        }

        // 5. branch_protection_snapshot
        let bpRaw = (owner.isEmpty || repo.isEmpty)
            ? "unavailable"
            : ((try? source.branchProtectionSnapshot(owner: owner, repo: repo)) ?? "unavailable")
        let branchProtectionSnapshot = BranchProtectionSnapshot(raw: bpRaw)

        // 6. required_checks_at_time
        // Derived from the check run names (what was configured at the time).
        let requiredChecksAtTime: [String] = checkRuns.isEmpty
            ? CIEvidence.Sentinel.requiredChecksAtTime
            : checkRuns.map(\.name)

        return CIEvidence(
            commitSha: commitSha,
            mergeBase: mergeBase,
            checkRunIds: checkRunIds,
            workflowFileHash: workflowFileHash,
            branchProtectionSnapshot: branchProtectionSnapshot,
            requiredChecksAtTime: requiredChecksAtTime,
            runnerType: runnerType,
            conclusion: conclusion
        )
    }
}

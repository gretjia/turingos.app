// ProjectStump.swift — A1_24: strategy observe-only layer — Project Stumps model.
//
// Governing ruling (user-approved §二-1): observe-only phase = Portfolio Radar /
// Project Stumps / observe-only statistics / manual strategy branching.
// ZERO market economy, ZERO automatic MCTS, ZERO reward-driven decisions.
// Constitution Art. I.2: statistics are deterministic algorithms over observed
// data, zero subjective valuation.
// Non-negotiable 8: market signal is never predicate truth.
//
// StumpForest is a pure value type.  Every mutating operation returns a NEW
// forest — no in-place mutation.  Cycle prevention: parentStumpId must exist
// in the forest before insertion; self-parenting is rejected.
//
// Live Software suggestion-only standard 7: creator=.metaAISuggestion stumps
// start as .proposed and CANNOT be auto-activated — they are DATA, never
// auto-actuators.

import Foundation

// MARK: - StumpKind

/// The seven stump kinds enumerated in WHITEPAPER §11.
public enum StumpKind: String, Codable, Sendable, CaseIterable, Equatable {
    case productDirection       = "product_direction"
    case technicalRoute         = "technical_route"
    case worktreeArm            = "worktree_arm"
    case experimentHypothesis   = "experiment_hypothesis"
    case riskIsolationBranch    = "risk_isolation_branch"
    case candidatePR            = "candidate_pr"
    case docArchMarketDirection = "doc_arch_market_direction"
}

// MARK: - StumpStatus

/// Lifecycle status of a stump.
/// Note: there is deliberately NO auto-activation case.
/// Transition to .active ONLY happens via an explicit reactivate(_:) op.
public enum StumpStatus: String, Codable, Sendable, CaseIterable, Equatable {
    case proposed = "proposed"
    case active   = "active"
    case pruned   = "pruned"
}

// MARK: - StumpCreator

/// Who created this stump.
/// metaAISuggestion stumps are DATA-only — they arrive as .proposed and cannot
/// be auto-activated (Live Software suggestion-only standard 7).
public enum StumpCreator: String, Codable, Sendable, Equatable {
    case user              = "user"
    case metaAISuggestion  = "meta_ai_suggestion"
}

// MARK: - ProjectStump

/// A single strategy stump node.  Codable for StumpForest persistence.
public struct ProjectStump: Codable, Sendable, Equatable {
    public let stumpId:       String
    public let projectId:     String
    public let kind:          StumpKind
    public let title:         String
    public let rationale:     String
    public let status:        StumpStatus
    public let creator:       StumpCreator
    /// Optional parent in the stump tree.  nil = root-level stump.
    public let parentStumpId: String?
    /// Human-readable creation note (timestamp, context summary, etc.).
    public let createdNote:   String

    public init(
        stumpId:       String,
        projectId:     String,
        kind:          StumpKind,
        title:         String,
        rationale:     String,
        status:        StumpStatus,
        creator:       StumpCreator,
        parentStumpId: String? = nil,
        createdNote:   String
    ) {
        self.stumpId       = stumpId
        self.projectId     = projectId
        self.kind          = kind
        self.title         = title
        self.rationale     = rationale
        self.status        = status
        self.creator       = creator
        self.parentStumpId = parentStumpId
        self.createdNote   = createdNote
    }

    enum CodingKeys: String, CodingKey {
        case stumpId       = "stump_id"
        case projectId     = "project_id"
        case kind
        case title
        case rationale
        case status
        case creator
        case parentStumpId = "parent_stump_id"
        case createdNote   = "created_note"
    }
}

// MARK: - StumpForestError

/// Errors returned by StumpForest mutation ops.
public enum StumpForestError: Error, Equatable {
    /// A stump with this stumpId already exists in the forest.
    case duplicateStumpId(String)
    /// parentStumpId was set but does not exist in the forest.
    case parentNotFound(String)
    /// A stump cannot be its own parent.
    case selfParent(String)
    /// No stump with this stumpId exists (prune/reactivate).
    case stumpNotFound(String)
    /// The stump is not in a state that can be pruned (already pruned).
    case alreadyPruned(String)
    /// The stump is not in a pruned state (reactivate).
    case notPruned(String)
}

// MARK: - StumpForest

/// Immutable value-type collection of ProjectStumps.
///
/// All ops return a NEW StumpForest — the original is never mutated.
/// This makes the forest safe to use as a functional value in tests and stores.
public struct StumpForest: Codable, Sendable, Equatable {
    /// All stumps in insertion order (stable, deterministic).
    public private(set) var stumps: [ProjectStump]

    public init(stumps: [ProjectStump] = []) {
        self.stumps = stumps
    }

    // MARK: - Queries

    /// Look up a stump by id.
    public func stump(byId id: String) -> ProjectStump? {
        stumps.first { $0.stumpId == id }
    }

    /// All stumps for a given projectId, in insertion order.
    public func stumps(forProject projectId: String) -> [ProjectStump] {
        stumps.filter { $0.projectId == projectId }
    }

    // MARK: - Pure ops (return new forest)

    /// Add a new stump to the forest.
    ///
    /// Invariants enforced:
    /// - stumpId must be unique.
    /// - parentStumpId (if non-nil) must exist in this forest.
    /// - A stump cannot be its own parent (stumpId != parentStumpId).
    ///
    /// - Returns: a NEW StumpForest containing the added stump.
    /// - Throws: StumpForestError on invariant violation.
    public func add(_ stump: ProjectStump) throws -> StumpForest {
        // Uniqueness check.
        if stumps.contains(where: { $0.stumpId == stump.stumpId }) {
            throw StumpForestError.duplicateStumpId(stump.stumpId)
        }
        // Self-parent check.
        if let parentId = stump.parentStumpId, parentId == stump.stumpId {
            throw StumpForestError.selfParent(stump.stumpId)
        }
        // Parent-exists check.
        if let parentId = stump.parentStumpId {
            guard stumps.contains(where: { $0.stumpId == parentId }) else {
                throw StumpForestError.parentNotFound(parentId)
            }
        }
        return StumpForest(stumps: stumps + [stump])
    }

    /// Prune an existing stump (set status to .pruned).
    ///
    /// - Parameters:
    ///   - stumpId: the id of the stump to prune.
    ///   - reason: recorded in the createdNote of the replacement stump.
    /// - Returns: a NEW StumpForest with the stump replaced.
    /// - Throws: StumpForestError if stump not found or already pruned.
    public func prune(_ stumpId: String, reason: String) throws -> StumpForest {
        guard let idx = stumps.firstIndex(where: { $0.stumpId == stumpId }) else {
            throw StumpForestError.stumpNotFound(stumpId)
        }
        let existing = stumps[idx]
        if existing.status == .pruned {
            throw StumpForestError.alreadyPruned(stumpId)
        }
        let updated = ProjectStump(
            stumpId:       existing.stumpId,
            projectId:     existing.projectId,
            kind:          existing.kind,
            title:         existing.title,
            rationale:     existing.rationale,
            status:        .pruned,
            creator:       existing.creator,
            parentStumpId: existing.parentStumpId,
            createdNote:   existing.createdNote + " [pruned: \(reason)]"
        )
        var newStumps = stumps
        newStumps[idx] = updated
        return StumpForest(stumps: newStumps)
    }

    /// Reactivate a pruned stump (set status back to .active).
    ///
    /// - Returns: a NEW StumpForest with the stump set to .active.
    /// - Throws: StumpForestError if stump not found or not currently pruned.
    public func reactivate(_ stumpId: String) throws -> StumpForest {
        guard let idx = stumps.firstIndex(where: { $0.stumpId == stumpId }) else {
            throw StumpForestError.stumpNotFound(stumpId)
        }
        let existing = stumps[idx]
        guard existing.status == .pruned else {
            throw StumpForestError.notPruned(stumpId)
        }
        let updated = ProjectStump(
            stumpId:       existing.stumpId,
            projectId:     existing.projectId,
            kind:          existing.kind,
            title:         existing.title,
            rationale:     existing.rationale,
            status:        .active,
            creator:       existing.creator,
            parentStumpId: existing.parentStumpId,
            createdNote:   existing.createdNote + " [reactivated]"
        )
        var newStumps = stumps
        newStumps[idx] = updated
        return StumpForest(stumps: newStumps)
    }
}

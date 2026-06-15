// A1_09: the galaxy radar's data spine - a DETERMINISTIC scene derivation
// (same ledger ⇒ same scene ⇒ same golden bytes).
//
// Honesty rule (card ruling, 2026-06-11): every node form and every edge is
// bound to a real daemon fact. The P1 read-only domain has NO merge fact
// and NO derivation-DAG fact, therefore: green is RESERVED (no node may
// wear verified-green), and the only edges drawn are (a) membership - node
// to its project's primary-checkout anchor (same-repo fact) and (b) the
// same-branch conflict tension between group members (same-branch fact).
// V6's merge-back/cross-tag edges return only when P2+ supplies the facts.

import CoreGraphics
import Foundation

// MARK: - Nodes (forms bound to facts; precedence = declaration order)

/// A1_69: commit-only display facts folded from CommitFact — all OBSERVED tape
/// facts (message / author / date), never fabricated. Shown in the commit popover
/// so the user can see what a commit actually did. View-layer only.
public struct CommitMeta: Equatable, Sendable {
    public let summary: String // full commit message (subject = first line)
    public let author: String
    public let ts: String // ISO-8601 author date
    public init(summary: String, author: String, ts: String) {
        self.summary = summary
        self.author = author
        self.ts = ts
    }
}

public struct RadarNode: Identifiable, Equatable, Sendable {
    /// A1_51b: the three node kinds in the galaxy. worktree chrome is driven
    /// by Form (the old path); branch/commit chrome uses a kind-based NEUTRAL
    /// path that never yields .green (honesty rule, card ruling 2026-06-14).
    public enum NodeKind: String, CaseIterable, Sendable {
        case worktree
        case branch
        case commit
    }

    public enum Form: String, CaseIterable, Sendable {
        case failed // fingerprint_error (red - 有失败证据)
        case conflict // same_branch_conflict (yellow)
        case orphan // prunable (gray, dashed)
        case active // dirty (blue, breathing)
        case quiet // none of the above (dim neutral)

        /// Status chrome per VISUAL_SEMANTICS rule 7. nil = neutral material
        /// (no semantic claim). Note .green is absent BY LAW until a
        /// verified merge fact exists in the stream.
        public var semantic: Tokens.Semantic? {
            switch self {
            case .failed: .red
            case .conflict: .yellow
            case .orphan: .gray
            case .active: .blue
            case .quiet: nil
            }
        }

        /// Text leg of the dual channel (rule 3: color never alone).
        public var label: String {
            switch self {
            case .failed: "读不出状态"
            case .conflict: "同分支冲突"
            case .orphan: "孤儿，可清理"
            case .active: "有未提交改动"
            case .quiet: "安静"
            }
        }

        /// Icon leg of the dual channel.
        public var iconName: String {
            switch self {
            case .failed: "xmark.octagon.fill"
            case .conflict: "exclamationmark.triangle.fill"
            case .orphan: "circle.dashed"
            case .active: "pencil.circle.fill"
            case .quiet: "circle"
            }
        }

        /// Fact precedence: a failure outranks everything; a conflict needs
        /// a ruling before its dirtiness matters; prunable beats dirty
        /// (a dirty orphan is still an orphan).
        public static func classify(_ fact: WorktreeFact) -> Form {
            if fact.fingerprintError != nil { return .failed }
            if fact.sameBranchConflict { return .conflict }
            if fact.prunable { return .orphan }
            if fact.dirty { return .active }
            return .quiet
        }
    }

    public let id: String // worktree_id / branch_ref / commit_sha (stable key)
    public let projectId: String
    public let title: String // Sentences.shortName for worktrees; ref/sha for others
    public let branch: String?
    public let head: String?
    public let form: Form
    /// A1_51b: which kind of entity this node represents.
    public let kind: NodeKind
    /// True when this worktree IS the project's registered checkout
    /// (path equality witness) - the V6 "Truth" anchor weight.
    /// For branch nodes: true when isDefault (the default branch is the anchor).
    public let isAnchor: Bool
    /// The raw FACT, kept alongside the form: edges derive from facts, so
    /// a failed node still carries its same-branch tension (S-stage
    /// blocker - form precedence must never eat an edge).
    public let sameBranchConflict: Bool
    public let locked: Bool
    public let detached: Bool
    public let evidence: JSONValue
    // A1_51b branch-specific flags (zero-value for worktree/commit nodes):
    /// ahead commits vs the default branch (from BranchFact).
    public let ahead: Int
    /// behind commits vs the default branch (from BranchFact).
    public let behind: Int
    /// merge_status string from BranchFact ("unknown" for non-branch nodes).
    public let mergeStatus: String
    /// True when branch head is contained in the default branch.
    public let containedInDefault: Bool
    /// True when branch was observed merged into default.
    public let mergedIntoDefault: Bool
    /// A1_69: commit-only display facts (message/author/date), folded from CommitFact;
    /// nil for worktree/branch nodes. `var` with a default so the many existing
    /// RadarNode call sites stay unchanged (only the commit node sets it). NOT emitted
    /// in canonicalDump — display facts, golden stays free.
    public var commitMeta: CommitMeta? = nil

    /// 0/1 accessibility predicate surface: every node MUST speak its
    /// project, name and form in text (rule 3; pinned by test).
    public var accessibilityLabel: String {
        let role = isAnchor ? "主轴锚点，" : ""
        return "「\(projectId)」的 \(title)：\(role)\(form.label)"
    }
}

// MARK: - Edges (only fact-backed couplings)

public struct RadarEdge: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case membership // node -> its project anchor (same-repo fact)
        case conflictTension // same-branch group members (yellow, thick)
        case fork // branch node -> its merge_base anchor on the trunk
        case parent // commit -> parent commit (DAG edge)
    }

    public let kind: Kind
    public let from: String // node id
    public let to: String // node id
}

// MARK: - Projects (identity lane)

public struct RadarProject: Identifiable, Equatable, Sendable {
    public let id: String
    public let path: String?
    public let nodeIds: [String] // sorted, anchor first
}

// MARK: - Scene

public struct RadarScene: Equatable, Sendable {
    public let projects: [RadarProject] // sorted by id
    public let nodes: [RadarNode] // sorted by (projectId, id)
    public let edges: [RadarEdge] // canonical order
    /// Deterministic initial layout in world space. User drag offsets are
    /// LOCAL PREFERENCE (UserDefaults), applied view-side, never here and
    /// never on tape.
    public let positions: [String: CGPoint]

    public static func derive(ledger: WorktreeLedger) -> RadarScene {
        let facts = ledger.worktrees.values.sorted {
            ($0.projectId, $0.worktreeId) < ($1.projectId, $1.worktreeId)
        }

        // --- Worktree nodes (unchanged from A1_49) ---
        var nodes: [RadarNode] = facts.map { fact in
            let projectPath = ledger.projects[fact.projectId]?.path
            let isAnchor: Bool = if let p = fact.path, let pp = projectPath {
                normalizedPath(p) == normalizedPath(pp)
            } else {
                false
            }
            return RadarNode(
                id: fact.worktreeId,
                projectId: fact.projectId,
                title: Sentences.shortName(fact),
                branch: fact.branch,
                head: fact.head,
                form: .classify(fact),
                kind: .worktree,
                isAnchor: isAnchor,
                sameBranchConflict: fact.sameBranchConflict,
                locked: fact.locked,
                detached: fact.detached,
                evidence: fact.evidence,
                ahead: 0, behind: 0,
                mergeStatus: "unknown",
                containedInDefault: false,
                mergedIntoDefault: false,
                commitMeta: nil
            )
        }

        // --- A1_51b: Branch nodes (from BranchObserved fold) ---
        // Kind-based neutral chrome: Form=.quiet so accessibilityLabel uses
        // "安静" (the neutral form label), but actual rendering uses kind path.
        for branchFact in ledger.branches.values.sorted(by: {
            ($0.projectId, $0.branchRef) < ($1.projectId, $1.branchRef)
        }) {
            nodes.append(RadarNode(
                id: "branch:\(branchFact.projectId):\(branchFact.branchRef)",
                projectId: branchFact.projectId,
                // title = last path component of the ref (human-readable)
                title: String(branchFact.branchRef.split(separator: "/").last ?? Substring(branchFact.branchRef)),
                branch: branchFact.branchRef,
                head: branchFact.headSha,
                form: .quiet, // kind-based neutral - never .green
                kind: .branch,
                isAnchor: branchFact.isDefault, // default branch = center anchor
                sameBranchConflict: false,
                locked: false,
                detached: false,
                evidence: .object([:]),
                ahead: branchFact.ahead,
                behind: branchFact.behind,
                mergeStatus: branchFact.mergeStatus,
                containedInDefault: branchFact.containedInDefault,
                mergedIntoDefault: branchFact.mergedIntoDefault,
                commitMeta: nil
            ))
        }

        // --- A1_51b: Commit nodes (from CommitObserved fold) ---
        // Only observed commits; no fabrication (honesty rule).
        for commitFact in ledger.commits.values.sorted(by: {
            ($0.projectId, $0.commitSha) < ($1.projectId, $1.commitSha)
        }) {
            nodes.append(RadarNode(
                id: "commit:\(commitFact.projectId):\(commitFact.commitSha)",
                projectId: commitFact.projectId,
                title: String(commitFact.commitSha.prefix(8)),
                branch: commitFact.branchRef,
                head: commitFact.commitSha,
                form: .quiet, // kind-based neutral - never .green
                kind: .commit,
                isAnchor: false,
                sameBranchConflict: false,
                locked: false,
                detached: false,
                evidence: .object([:]),
                ahead: 0, behind: 0,
                mergeStatus: "unknown",
                containedInDefault: false,
                mergedIntoDefault: false,
                commitMeta: CommitMeta(
                    summary: commitFact.summary,
                    author: commitFact.author,
                    ts: commitFact.ts)
            ))
        }

        nodes.sort { ($0.projectId, $0.id) < ($1.projectId, $1.id) }

        // Projects: every registered project gets a lane even with zero
        // worktrees (silence is a state, not an omission); unregistered
        // projects that own worktrees/branches/commits get a lane from the facts.
        var projectIds = Set(ledger.projects.keys)
        projectIds.formUnion(nodes.map(\.projectId))
        let projects: [RadarProject] = projectIds.sorted().map { pid in
            let members = nodes.filter { $0.projectId == pid }
            let ordered = members.filter(\.isAnchor).map(\.id)
                + members.filter { !$0.isAnchor }.map(\.id)
            return RadarProject(
                id: pid, path: ledger.projects[pid]?.path, nodeIds: ordered)
        }

        // Build a lookup for all node ids for fast edge-existence checks
        let nodeIdSet = Set(nodes.map(\.id))

        var edges: [RadarEdge] = []
        // Membership: each non-anchor WORKTREE member couples to its project anchor.
        for project in projects {
            guard let anchorId = project.nodeIds.first,
                  let anchorNode = nodes.first(where: { $0.id == anchorId }),
                  anchorNode.isAnchor, anchorNode.kind == .worktree
            else { continue }
            for memberId in project.nodeIds.dropFirst() {
                guard let memberNode = nodes.first(where: { $0.id == memberId }),
                      memberNode.kind == .worktree
                else { continue }
                edges.append(RadarEdge(kind: .membership, from: memberId, to: anchorId))
            }
        }
        // Conflict tension: chain the sorted members of each same-branch
        // group. Keyed on the FACT, not the form - a member that also has
        // a fingerprint failure wears .failed chrome yet keeps its tension
        // edge (S-stage blocker: the radar must agree with the stack).
        var conflictGroups: [String: [String]] = [:]
        for node in nodes where node.sameBranchConflict {
            let key = "\(node.projectId)\u{0}\(node.branch ?? "")"
            conflictGroups[key, default: []].append(node.id)
        }
        for (_, group) in conflictGroups.sorted(by: { $0.key < $1.key })
        where group.count >= 2 {
            for (a, b) in zip(group, group.dropFirst()) {
                edges.append(RadarEdge(kind: .conflictTension, from: a, to: b))
            }
        }

        // A1_51b: Fork edges (branch -> merge_base anchor on the trunk).
        // The merge_base is the commit sha of the common ancestor; if a
        // commit node for it exists in the scene, draw the fork edge.
        for branchFact in ledger.branches.values {
            guard let mergeBase = branchFact.mergeBase, !mergeBase.isEmpty else { continue }
            let branchNodeId = "branch:\(branchFact.projectId):\(branchFact.branchRef)"
            let mergeBaseNodeId = "commit:\(branchFact.projectId):\(mergeBase)"
            guard nodeIdSet.contains(branchNodeId), nodeIdSet.contains(mergeBaseNodeId) else { continue }
            edges.append(RadarEdge(kind: .fork, from: branchNodeId, to: mergeBaseNodeId))
        }

        // A1_51b: Parent edges (commit -> each parent_sha that exists as a node).
        for commitFact in ledger.commits.values {
            let fromId = "commit:\(commitFact.projectId):\(commitFact.commitSha)"
            for parentSha in commitFact.parentShas {
                let toId = "commit:\(commitFact.projectId):\(parentSha)"
                guard nodeIdSet.contains(toId) else { continue }
                edges.append(RadarEdge(kind: .parent, from: fromId, to: toId))
            }
        }

        edges.sort {
            ($0.kind.rawValue, $0.from, $0.to) < ($1.kind.rawValue, $1.from, $1.to)
        }

        return RadarScene(
            projects: projects,
            nodes: nodes,
            edges: edges,
            positions: RadarLayout.positions(projects: projects, branches: ledger.branches, commits: ledger.commits)
        )
    }

    /// Lexical path normalization for the anchor witness (trailing slash /
    /// "." / ".." differences must not kill the anchor). Symlink and
    /// unicode-normalization equivalence is a registered debt - it needs a
    /// daemon-side canonical fact, not client guessing.
    static func normalizedPath(_ p: String) -> String {
        URL(fileURLWithPath: p).standardizedFileURL.path
    }

    /// Fly-to resolution from a structured attention target: first member
    /// worktree that exists in the scene; nil = nothing to fly to (the
    /// caller keeps the camera where it is - no fake focus).
    public func resolve(_ target: AttentionTarget) -> String? {
        target.worktreeIds.first { positions[$0] != nil }
    }

    /// Golden bytes: a canonical text projection of the WHOLE scene
    /// (forms, anchors, edges, layout). Same ledger ⇒ same dump - pinned
    /// against fixtures/snapshots/p1_radar_scene.golden.txt in tests.
    /// A1_51b: extended with kind, ahead/behind for branch nodes.
    public func canonicalDump() -> String {
        var lines: [String] = []
        // Project header: node count (branch+commit nodes included now)
        let branchNodeCounts: [String: Int] = nodes.reduce(into: [:]) { acc, n in
            if n.kind == .branch { acc[n.projectId, default: 0] += 1 }
        }
        for p in projects {
            lines.append("project \(p.id) nodes=\(p.nodeIds.count) branches=\(branchNodeCounts[p.id] ?? 0)")
        }
        for n in nodes {
            let pos = positions[n.id] ?? .zero
            switch n.kind {
            case .worktree:
                lines.append(String(
                    format: "node %@ project=%@ form=%@ anchor=%@ branch=%@ pos=(%.1f,%.1f)",
                    n.id, n.projectId, n.form.rawValue, String(n.isAnchor),
                    n.branch ?? "-", pos.x, pos.y
                ))
            case .branch:
                lines.append(String(
                    format: "node %@ project=%@ kind=branch anchor=%@ ahead=%d behind=%d mergeStatus=%@ pos=(%.1f,%.1f)",
                    n.id, n.projectId, String(n.isAnchor),
                    n.ahead, n.behind, n.mergeStatus, pos.x, pos.y
                ))
            case .commit:
                lines.append(String(
                    format: "node %@ project=%@ kind=commit branch=%@ pos=(%.1f,%.1f)",
                    n.id, n.projectId,
                    n.branch ?? "-", pos.x, pos.y
                ))
            }
        }
        for e in edges {
            lines.append("edge \(e.kind.rawValue) \(e.from)->\(e.to)")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

// MARK: - Layout (pure arithmetic; no clock, no randomness)

public enum RadarLayout {
    // Legacy horizontal-lane constants (kept for laneSpan in RadarViews).
    public static let laneHeight: CGFloat = 320
    public static let topMargin: CGFloat = 220
    public static let anchorX: CGFloat = 280
    public static let nodeSpacing: CGFloat = 260
    public static let stagger: CGFloat = 44

    /// A1_51b: minimum distance between any two project galaxy centers.
    /// Any two galaxy centers satisfy |a - b| >= MIN_GALAXY_GAP (asserted in tests).
    public static let MIN_GALAXY_GAP: CGFloat = 1800

    /// A1_55: Deterministic Fermat-spiral placement of every project's galaxy
    /// center, with MIN_GALAXY_GAP enforced between any two. Pure function of the
    /// project-id set (sorted for stability) — NOT of observed node positions —
    /// so a project's center is fixed the instant it appears in the registry,
    /// before any branch is observed. Shared by positions() and galaxyCenter().
    public static func galaxyCenters(projectIds: [String]) -> [String: CGPoint] {
        var centers: [String: CGPoint] = [:]
        var placedCenters: [CGPoint] = []
        for pid in projectIds.sorted() {
            let h = abs(Tokens.Accent.stableHash(pid))
            // Search candidate spiral points until one satisfies the gap.
            var candidate = CGPoint.zero
            var k = 0
            repeat {
                // Fermat spiral: r = C*sqrt(n), angle = n * golden_angle
                let n = Double(h % 97 + k * 97) // start at a hash-seeded offset
                let r = MIN_GALAXY_GAP * CGFloat(sqrt(n) * 0.5 + 1.0)
                let angle = Double(n) * 2.399963 // 137.508° golden angle in radians
                candidate = CGPoint(x: r * CGFloat(cos(angle)), y: r * CGFloat(sin(angle)))
                k += 1
            } while placedCenters.contains(where: {
                hypot($0.x - candidate.x, $0.y - candidate.y) < MIN_GALAXY_GAP
            }) && k < 500
            centers[pid] = candidate
            placedCenters.append(candidate)
        }
        return centers
    }

    /// A1_55: Galaxy center for a project in world space.
    /// The default-branch anchor node is positioned exactly at this point in
    /// positions(); all visual elements (label, nebula, branch-ring, aggregate
    /// glyph) anchor here. Returns the DETERMINISTIC spiral center — identical
    /// whether or not the project's branches have streamed in — so unscanned /
    /// remote-only repos never collapse onto the world origin and overlap.
    public static func galaxyCenter(projectId: String, in scene: RadarScene) -> CGPoint {
        let ids = scene.projects.map(\.id)
        if let c = galaxyCenters(projectIds: ids)[projectId] { return c }
        // projectId not in the project list (defensive): fall back to origin.
        return .zero
    }

    /// Base radius for the star system (branch orbit around anchor).
    private static let starBaseRadius: CGFloat = 380
    /// Radius added per commit divergence unit (ahead + behind).
    private static let starRadiusPerDivergence: CGFloat = 18
    /// Maximum orbital radius cap.
    private static let starMaxRadius: CGFloat = 780

    /// A1_51b: Galaxy layout (pure arithmetic, deterministic, no clock/random).
    ///
    /// Three tiers:
    /// 1. galaxyCenters – scatter project centers by stableHash(projectId) in a
    ///    loose spiral with MIN_GALAXY_GAP guaranteed between any two centers.
    /// 2. starSystem – default branch at center anchor; each branch at a polar
    ///    angle derived from stableHash(branchRef), radius = base + k*(ahead+behind).
    /// 3. commitSwimlane – online lane algorithm (topological/temporal order,
    ///    vacant lanes set to nil not removed so columns don't shift).
    public static func positions(
        projects: [RadarProject],
        branches: [String: BranchFact] = [:],
        commits: [String: CommitFact] = [:]
    ) -> [String: CGPoint] {
        var out: [String: CGPoint] = [:]

        // --- 1. Galaxy centers (spiral scatter, MIN_GALAXY_GAP enforced) ---
        // Deterministic Fermat-spiral placement (shared with galaxyCenter so a
        // project's center is identical whether or not its branches have been
        // observed yet — no collapse to the origin for unscanned repos).
        let centers = galaxyCenters(projectIds: projects.map(\.id))

        // --- 2. Worktree nodes (legacy horizontal layout within galaxy) ---
        // Worktrees are positioned relative to their galaxy center in the
        // existing horizontal lane style so downstream consumers stay intact.
        for project in projects {
            guard let center = centers[project.id] else { continue }
            // Only worktree node ids in the project list (branch/commit ids
            // are handled below).
            let worktreeIds = project.nodeIds.filter { !$0.hasPrefix("branch:") && !$0.hasPrefix("commit:") }
            for (idx, nodeId) in worktreeIds.enumerated() {
                let x = center.x + CGFloat(idx) * nodeSpacing
                let y = idx == 0
                    ? center.y
                    : center.y + (idx.isMultiple(of: 2) ? stagger : -stagger)
                out[nodeId] = CGPoint(x: x, y: y)
            }
        }

        // --- 3. Star system (branch nodes in polar orbit around galaxy center) ---
        // Group branches by projectId.
        var branchByProject: [String: [BranchFact]] = [:]
        for bf in branches.values {
            branchByProject[bf.projectId, default: []].append(bf)
        }

        for (pid, branchFacts) in branchByProject {
            guard let center = centers[pid] else { continue }
            // Default branch sits at center anchor; others orbit.
            for bf in branchFacts {
                let nodeId = "branch:\(pid):\(bf.branchRef)"
                if bf.isDefault {
                    out[nodeId] = center
                } else {
                    let h = abs(Tokens.Accent.stableHash(bf.branchRef))
                    let angle = Double(h % 10000) / 10000.0 * 2.0 * .pi
                    let divergence = CGFloat(bf.ahead + bf.behind)
                    let radius = min(starBaseRadius + starRadiusPerDivergence * divergence,
                                     starMaxRadius)
                    out[nodeId] = CGPoint(
                        x: center.x + radius * CGFloat(cos(angle)),
                        y: center.y + radius * CGFloat(sin(angle))
                    )
                }
            }
        }

        // --- 4. Commit swimlane (online lane algorithm, topological order) ---
        // Per branch: sort commits by ts (temporal/topological), assign rows
        // and lanes. Lane = index in active-lane array; vacated slots stay nil
        // so columns don't shift (pvigier online-lane algorithm).
        var commitByBranch: [String: [CommitFact]] = [:]
        for cf in commits.values {
            let key = "\(cf.projectId)\u{0}\(cf.branchRef)"
            commitByBranch[key, default: []].append(cf)
        }

        for (key, branchCommits) in commitByBranch {
            // key = "projectId\0branchRef"
            let parts = key.split(separator: "\u{0}", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let pid = String(parts[0])
            let branchRef = String(parts[1])
            guard let branchCenter = out["branch:\(pid):\(branchRef)"] ?? centers[pid] else { continue }

            // Sort by ts (lexicographic on ISO-8601 = temporal order ascending).
            let sorted = branchCommits.sorted { $0.ts < $1.ts }
            let shaSet = Set(sorted.map(\.commitSha))

            // Online lane assignment: maintain active lanes array. nil = vacated.
            var activeLanes: [String?] = [] // lane index -> current commit sha

            for (row, commit) in sorted.enumerated() {
                // Which lane to use? Prefer the lane occupied by this commit's
                // parent (straight continuation); otherwise pick the first nil
                // or append a new lane.
                let parentInBranch = commit.parentShas.first { shaSet.contains($0) }
                var assignedLane: Int
                if let parent = parentInBranch,
                   let parentLane = activeLanes.firstIndex(where: { $0 == parent }) {
                    // Straight continuation: same lane, vacate the parent slot.
                    activeLanes[parentLane] = commit.commitSha
                    assignedLane = parentLane
                } else if let nilLane = activeLanes.firstIndex(where: { $0 == nil }) {
                    // Reuse a vacated lane (columns don't shift).
                    activeLanes[nilLane] = commit.commitSha
                    assignedLane = nilLane
                } else {
                    // Open a new lane.
                    activeLanes.append(commit.commitSha)
                    assignedLane = activeLanes.count - 1
                }

                // Vacate the lane of each parent that is now fully consumed.
                for parentSha in commit.parentShas {
                    if let idx = activeLanes.firstIndex(where: { $0 == parentSha }),
                       idx != assignedLane {
                        activeLanes[idx] = nil
                    }
                }

                // Position: row = temporal order (parents above children in y),
                // lane = horizontal column within the branch cluster.
                let commitRowSpacing: CGFloat = 80
                let commitLaneSpacing: CGFloat = 60
                let x = branchCenter.x + CGFloat(assignedLane) * commitLaneSpacing
                let y = branchCenter.y + 200 + CGFloat(row) * commitRowSpacing
                let nodeId = "commit:\(pid):\(commit.commitSha)"
                out[nodeId] = CGPoint(x: x, y: y)
            }
        }

        return out
    }
}

// MARK: - Camera (A1_51a: tldraw-style log-space model; pure + testable)
//
// Internal model: {x, y, logZoom} where z = pow(2, logZoom).
// Value-equivalent read surface {scale, isFar, offset, toScreen, toWorld,
// zoom(by:anchor:), pan, focusing} keeps RadarViews call sites unchanged and
// renders identically at every z in the default viewport.
//
// All world/transform math is in Double/CGFloat — no raw fp32 in this file.

public struct RadarCamera: Equatable, Sendable {
    // MARK: Internal model

    /// Page coordinate at the viewport top-left in world space (tldraw Camera.x/y).
    public var x: Double
    public var y: Double
    /// log2 of zoom factor. z = pow(2, logZoom) ∈ [~0.01, 256].
    public var logZoom: Double

    // Bounds in log2 space derived once from Tokens.Motion.zoomRange = 0.01...256.
    private static let logZoomMin: Double = log2(Tokens.Motion.zoomRange.lowerBound)
    private static let logZoomMax: Double = log2(Tokens.Motion.zoomRange.upperBound)

    /// Linear zoom factor.
    public var z: Double { pow(2, logZoom) }

    /// Default = compressed macro view (V6_RECONCILIATION §1: 压缩态=默认初始视角).
    /// x=0, y=0, logZoom=log2(0.25)=-2  →  z=0.25, isFar=true (value-equivalent to old default).
    public init(x: Double = 0, y: Double = 0, logZoom: Double = -2) {
        // Fail-safe clamp: NaN/overflow saturates to logZoomMin.
        let safeLog = logZoom.isFinite ? logZoom : Self.logZoomMin
        self.x = x.isFinite ? x : 0
        self.y = y.isFinite ? y : 0
        self.logZoom = max(Self.logZoomMin, min(Self.logZoomMax, safeLog))
    }

    // MARK: - Value-equivalent read surface (keeps RadarViews call sites unchanged)

    /// Zoom scale as CGFloat (value-equivalent to the old stored `scale` field).
    public var scale: CGFloat { CGFloat(z) }

    /// True when zoomed out past the semantic far threshold (same gate as before).
    public var isFar: Bool { z < Tokens.Motion.semanticFarThreshold }

    /// Screen-space offset derived from x, y, z.
    /// Invariant: screen = world * z + offset  (offset = −cameraPos * z).
    public var offset: CGSize { CGSize(width: -x * z, height: -y * z) }

    // MARK: - Non-floating-origin transforms (value-equivalent to old toScreen/toWorld)

    public func toScreen(_ world: CGPoint) -> CGPoint {
        let z = self.z
        return CGPoint(x: world.x * z - x * z, y: world.y * z - y * z)
    }

    public func toWorld(_ screen: CGPoint) -> CGPoint {
        let z = self.z
        return CGPoint(x: screen.x / z + x, y: screen.y / z + y)
    }

    // MARK: - Floating-origin transforms (A1_51a new API; A1_51c consumes these)

    /// Screen coordinate of a page point with floating-origin subtraction.
    /// screen = (page − renderOrigin) * z + offset
    /// At default renderOrigin=.zero this equals toScreen (value-equivalent).
    public func pageToScreen(_ page: CGPoint, renderOrigin: CGPoint = .zero) -> CGPoint {
        let z = self.z
        return CGPoint(
            x: (page.x - renderOrigin.x) * z - x * z,
            y: (page.y - renderOrigin.y) * z - y * z
        )
    }

    /// Page coordinate of a screen point (inverse of pageToScreen).
    public func screenToPage(_ screen: CGPoint, renderOrigin: CGPoint = .zero) -> CGPoint {
        let z = self.z
        return CGPoint(
            x: screen.x / z + x + renderOrigin.x,
            y: screen.y / z + y + renderOrigin.y
        )
    }

    // MARK: - Zoom (value-equivalent math, extended range [~0.01, 256])

    /// Zoom by `factor`, keeping the world point under `anchor` (screen coords) fixed.
    /// tldraw closed form: camera.x += anchor.x * (1/oldZ − 1/newZ).
    /// Clamped to [logZoomMin, logZoomMax]; saturates on NaN/overflow (fail-safe).
    public mutating func zoom(by factor: CGFloat, anchor: CGPoint) {
        let df = Double(factor)
        guard df > 0, df.isFinite else { return }
        let delta = log2(df)
        guard delta.isFinite else { return }
        let newLogZoom = max(Self.logZoomMin, min(Self.logZoomMax, logZoom + delta))
        guard newLogZoom != logZoom else { return }
        let oldZ = self.z
        let newZ = pow(2, newLogZoom)
        // Keep world point under anchor fixed.
        let dx = Double(anchor.x) * (1.0 / oldZ - 1.0 / newZ)
        let dy = Double(anchor.y) * (1.0 / oldZ - 1.0 / newZ)
        x += dx
        y += dy
        logZoom = newLogZoom
    }

    /// Zoom to an absolute z value with the same cursor-anchor invariant.
    public mutating func zoom(to targetZ: Double, anchor: CGPoint) {
        guard targetZ > 0, targetZ.isFinite else { return }
        let factor = targetZ / self.z
        zoom(by: CGFloat(factor), anchor: anchor)
    }

    public mutating func pan(by delta: CGSize) {
        let z = self.z
        // offset += delta  ⟺  −x*z += delta.width  ⟺  x −= delta.width/z
        x -= Double(delta.width) / z
        y -= Double(delta.height) / z
    }

    /// Camera that centers `world` in `viewport` at `scale` (fly-to).
    public static func focusing(
        on world: CGPoint, scale rawScale: CGFloat, viewport: CGSize
    ) -> RadarCamera {
        let targetZ = Double(rawScale)
        let safeTarget = (targetZ > 0 && targetZ.isFinite) ? targetZ : 1.0
        let clampedLogZoom = max(logZoomMin, min(logZoomMax, log2(safeTarget)))
        let clampedZ = pow(2, clampedLogZoom)
        // offset = viewport/2 − world*z  ⟹  x = world.x − viewport.width/(2*z)
        let cx = Double(world.x) - Double(viewport.width) / (2.0 * clampedZ)
        let cy = Double(world.y) - Double(viewport.height) / (2.0 * clampedZ)
        return RadarCamera(x: cx, y: cy, logZoom: clampedLogZoom)
    }

    /// A1_55: macro framing — a camera centered on the bounding-box centroid of
    /// `centers` (the project galaxy-centers) and zoomed to fit them with margin.
    /// The fixed origin default (x=0,y=0,z=0.25) parked world-origin at the
    /// screen's top-left while the Fermat-spiral centers scatter around world
    /// (0,0) out to several thousand units, so almost every aggregate fell
    /// off-screen (real-machine symptom: "zoom-out is a mess / can't see them").
    /// Clamped to stay strictly inside the galaxy/cluster band so the macro view
    /// always renders aggregates, never an accidental node-band expansion.
    /// Pure + deterministic (no clock/random) → testable.
    public static func fittingGalaxy(centers: [CGPoint], viewport: CGSize) -> RadarCamera {
        guard !centers.isEmpty, viewport.width > 0, viewport.height > 0 else {
            return RadarCamera()
        }
        let xs = centers.map(\.x), ys = centers.map(\.y)
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!
        let center = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        // 1.35× padding so edge aggregates (and glyph radius) are not clipped.
        let margin: CGFloat = 1.35
        let spanX = max((maxX - minX) * margin, 1)
        let spanY = max((maxY - minY) * margin, 1)
        let fitZ = min(Double(viewport.width) / Double(spanX),
                       Double(viewport.height) / Double(spanY))
        let macroZ = min(fitZ, Tokens.Motion.ZBand.nodeThreshold * 0.8)
        return .focusing(on: center, scale: CGFloat(macroZ), viewport: viewport)
    }

    // MARK: - Log-space interpolation (pure, no clock/random)

    /// Linear interpolation in log2 space. Deterministic: same inputs → same output.
    public static func logerp(_ a: Double, _ b: Double, t: Double) -> Double {
        let la = a > 0 ? log2(a) : logZoomMin
        let lb = b > 0 ? log2(b) : logZoomMin
        return pow(2, la + (lb - la) * t)
    }

    // MARK: - Z-band classification (A1_51a: defined; A1_51c+ consumes)

    public enum Band: Equatable, Sendable {
        case galaxy, cluster, node, detail
    }

    public func currentBand() -> Band {
        let z = self.z
        if z < Tokens.Motion.ZBand.clusterThreshold { return .galaxy }
        if z < Tokens.Motion.ZBand.nodeThreshold { return .cluster }
        if z < Tokens.Motion.ZBand.detailThreshold { return .node }
        return .detail
    }
}

// MARK: - Mood (the radar's honesty about a dead stream)

/// Same legislated discipline as the glance dot: anything but .connected
/// means the ledger is NOT live, so the galaxy must stop claiming current
/// activity - no breathing, no sweep, gray-washed chrome, and a visible
/// banner sentence (template-whitelisted). The stale facts STAY visible
/// under the notice; honesty hides nothing, it labels.
public struct RadarMood: Equatable, Sendable {
    /// Activity claims (breathing pulses, axis sweep) allowed.
    public let live: Bool
    /// nil when live; otherwise the visible staleness sentence.
    public let banner: String?

    public static func derive(connection: ConnectionState) -> RadarMood {
        switch connection {
        case .connected:
            RadarMood(live: true, banner: nil)
        case .connecting:
            RadarMood(live: false, banner: Sentences.reconciling())
        case .disconnected(let reason):
            RadarMood(live: false, banner: Sentences.disconnected(reason: reason))
        }
    }
}

// MARK: - Node card content (law 1 enforced structurally)

/// What a node card may RENDER, derived as data so the anti-pattern guard
/// is mechanical: default (unselected) = title + glow ONLY; far = glow dot
/// only; detail rows exist solely in the selected state.
public struct NodeCardContent: Equatable, Sendable {
    public let showsTitle: Bool
    /// A1_57 (absorbs A1_58): Software-3.0 language-first lead sentence, kind-aware.
    /// The card LEADS with what this node means (a sentence), not a generic
    /// "状态: 安静" row — which was meaningless for branch/commit nodes (#5).
    public let headline: String?
    public let detailRows: [(String, String)]
    public let showsEvidenceAction: Bool

    /// Assistive-tech mirror of the visible detail (S-stage blocker: the
    /// drill-down must be REACHABLE, not just painted - law 2). Includes the
    /// headline so VoiceOver hears the lead sentence too.
    public var accessibilityValue: String? {
        var parts: [String] = []
        if let headline { parts.append(headline) }
        parts.append(contentsOf: detailRows.map { "\($0.0) \($0.1)" })
        return parts.isEmpty ? nil : parts.joined(separator: "，")
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.showsTitle == rhs.showsTitle
            && lhs.headline == rhs.headline
            && lhs.detailRows.elementsEqual(rhs.detailRows, by: ==)
            && lhs.showsEvidenceAction == rhs.showsEvidenceAction
    }

    /// A1_57: far → glow only; unselected → title only; selected → KIND-SPECIFIC
    /// meaningful content (branch merge/opportunity framing, commit identity,
    /// worktree working-copy state). Replaces the old kind-blind generic rows.
    public static func derive(node: RadarNode, selected: Bool, far: Bool) -> NodeCardContent {
        if far {
            return NodeCardContent(showsTitle: false, headline: nil, detailRows: [], showsEvidenceAction: false)
        }
        guard selected else {
            return NodeCardContent(showsTitle: true, headline: nil, detailRows: [], showsEvidenceAction: false)
        }
        switch node.kind {
        case .branch: return deriveBranch(node)
        case .commit: return deriveCommit(node)
        case .worktree: return deriveWorktree(node)
        }
    }

    /// Branch: merge / opportunity framing from OBSERVED facts only. Never asserts
    /// "merged" and never green — mergedIntoDefault is daemon-hardcoded false, and
    /// containedInDefault is mere reachability (≠ merged content, ADR-017 §C).
    private static func deriveBranch(_ node: RadarNode) -> NodeCardContent {
        // Honesty: only claim "与主线一致" when the observation CONFIRMS it
        // (mergeStatus == "identical"). A branch that is only behind, or whose
        // relation is unobserved (mergeStatus "unknown", folded default 0/0/unknown),
        // must NOT be reported as in-sync — that would be a fake-green-adjacent
        // claim the observed facts don't support (Codex P2, ADR-017 honesty law).
        let headline: String
        if node.isAnchor {
            headline = "主干 · 默认分支"
        } else if node.containedInDefault {
            headline = "已在主线可达（≠ 已并入内容）"
        } else if node.ahead > 0, node.behind == 0 {
            headline = "\(node.ahead) 个 commit 待并入 — 未收割的机会"
        } else if node.ahead > 0, node.behind > 0 {
            headline = "分叉中：领先 \(node.ahead) / 落后 \(node.behind)"
        } else if node.behind > 0 {
            // ahead == 0, behind > 0 → strictly behind (stale), not in sync.
            headline = "落后主线 \(node.behind) 个 commit"
        } else if node.mergeStatus == "identical" {
            // ahead == 0, behind == 0, AND the daemon confirmed identical.
            headline = "与主线一致"
        } else {
            // ahead == 0, behind == 0, mergeStatus not confirmed (unknown) → unobserved.
            headline = "与主线关系未观测"
        }
        var rows: [(String, String)] = [("分歧", "↑\(node.ahead)  ↓\(node.behind)")]
        if let head = node.head, !head.isEmpty {
            rows.append(("HEAD", String(head.prefix(8))))
        }
        return NodeCardContent(showsTitle: true, headline: headline, detailRows: rows, showsEvidenceAction: true)
    }

    /// Commit: Software-3.0 language-first — the message SUBJECT (what the commit
    /// did) leads; author/date answer who/when; sha/branch give identity. All
    /// fields are OBSERVED (CommitMeta folded from CommitFact), never fabricated.
    private static func deriveCommit(_ node: RadarNode) -> NodeCardContent {
        let subject = node.commitMeta?.summary
            .split(separator: "\n", omittingEmptySubsequences: false).first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        let headline = subject.isEmpty ? "提交节点" : subject
        var rows: [(String, String)] = []
        if let head = node.head, !head.isEmpty {
            rows.append(("commit", String(head.prefix(8))))
        }
        if let m = node.commitMeta {
            if !m.author.isEmpty { rows.append(("作者", m.author)) }
            if !m.ts.isEmpty { rows.append(("时间", String(m.ts.prefix(10)))) }
        }
        if let branch = node.branch {
            rows.append(("分支", String(branch.split(separator: "/").last ?? Substring(branch))))
        }
        return NodeCardContent(showsTitle: true, headline: headline, detailRows: rows, showsEvidenceAction: true)
    }

    /// Worktree: the form label IS meaningful here (失败/冲突/孤儿/有未提交改动/安静),
    /// so it leads; plus the working-copy facts (branch / HEAD / lock).
    private static func deriveWorktree(_ node: RadarNode) -> NodeCardContent {
        var rows: [(String, String)] = []
        if let branch = node.branch {
            rows.append(("分支", branch))
        } else if node.detached {
            rows.append(("分支", "detached"))
        }
        if let head = node.head, !head.isEmpty {
            rows.append(("HEAD", String(head.prefix(8))))
        }
        if node.locked { rows.append(("锁", "已锁定")) }
        return NodeCardContent(showsTitle: true, headline: node.form.label, detailRows: rows, showsEvidenceAction: true)
    }
}

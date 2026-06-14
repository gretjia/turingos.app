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

public struct RadarNode: Identifiable, Equatable, Sendable {
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

    public let id: String // worktree_id (stable key)
    public let projectId: String
    public let title: String // Sentences.shortName - the only default text
    public let branch: String?
    public let head: String?
    public let form: Form
    /// True when this worktree IS the project's registered checkout
    /// (path equality witness) - the V6 "Truth" anchor weight.
    public let isAnchor: Bool
    /// The raw FACT, kept alongside the form: edges derive from facts, so
    /// a failed node still carries its same-branch tension (S-stage
    /// blocker - form precedence must never eat an edge).
    public let sameBranchConflict: Bool
    public let locked: Bool
    public let detached: Bool
    public let evidence: JSONValue

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
    /// A1_49: observed branch count per project (local git + GitHub via the
    /// daemon's BranchObserved stream). The macro view shows this on each lane;
    /// per-branch nodes + fork edges land in A1_50.
    public let branchCounts: [String: Int]

    public static func derive(ledger: WorktreeLedger) -> RadarScene {
        let facts = ledger.worktrees.values.sorted {
            ($0.projectId, $0.worktreeId) < ($1.projectId, $1.worktreeId)
        }

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
                isAnchor: isAnchor,
                sameBranchConflict: fact.sameBranchConflict,
                locked: fact.locked,
                detached: fact.detached,
                evidence: fact.evidence
            )
        }
        nodes.sort { ($0.projectId, $0.id) < ($1.projectId, $1.id) }

        // Projects: every registered project gets a lane even with zero
        // worktrees (silence is a state, not an omission); unregistered
        // projects that own worktrees get a lane from the facts.
        var projectIds = Set(ledger.projects.keys)
        projectIds.formUnion(nodes.map(\.projectId))
        let projects: [RadarProject] = projectIds.sorted().map { pid in
            let members = nodes.filter { $0.projectId == pid }
            let ordered = members.filter(\.isAnchor).map(\.id)
                + members.filter { !$0.isAnchor }.map(\.id)
            return RadarProject(
                id: pid, path: ledger.projects[pid]?.path, nodeIds: ordered)
        }

        var edges: [RadarEdge] = []
        // Membership: each non-anchor member couples to its project anchor.
        for project in projects {
            guard let anchor = project.nodeIds.first,
                  nodes.first(where: { $0.id == anchor })?.isAnchor == true
            else { continue }
            for member in project.nodeIds.dropFirst() {
                edges.append(RadarEdge(kind: .membership, from: member, to: anchor))
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
        edges.sort {
            ($0.kind.rawValue, $0.from, $0.to) < ($1.kind.rawValue, $1.from, $1.to)
        }

        // A1_49: per-project observed branch counts (BranchObserved fold).
        var branchCounts: [String: Int] = [:]
        for fact in ledger.branches.values {
            branchCounts[fact.projectId, default: 0] += 1
        }

        return RadarScene(
            projects: projects,
            nodes: nodes,
            edges: edges,
            positions: RadarLayout.positions(projects: projects),
            branchCounts: branchCounts
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
    public func canonicalDump() -> String {
        var lines: [String] = []
        for p in projects {
            lines.append("project \(p.id) nodes=\(p.nodeIds.count) branches=\(branchCounts[p.id] ?? 0)")
        }
        for n in nodes {
            let pos = positions[n.id] ?? .zero
            lines.append(String(
                format: "node %@ project=%@ form=%@ anchor=%@ branch=%@ pos=(%.1f,%.1f)",
                n.id, n.projectId, n.form.rawValue, String(n.isAnchor),
                n.branch ?? "-", pos.x, pos.y
            ))
        }
        for e in edges {
            lines.append("edge \(e.kind.rawValue) \(e.from)->\(e.to)")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

// MARK: - Layout (pure arithmetic; no clock, no randomness)

public enum RadarLayout {
    public static let laneHeight: CGFloat = 320
    public static let topMargin: CGFloat = 220
    public static let anchorX: CGFloat = 280
    public static let nodeSpacing: CGFloat = 260
    /// Deterministic vertical stagger for non-anchor nodes (galaxy feel
    /// without randomness: parity of the index).
    public static let stagger: CGFloat = 44

    public static func positions(projects: [RadarProject]) -> [String: CGPoint] {
        var out: [String: CGPoint] = [:]
        for (row, project) in projects.enumerated() {
            let laneY = topMargin + CGFloat(row) * laneHeight
            for (idx, nodeId) in project.nodeIds.enumerated() {
                let x = anchorX + CGFloat(idx) * nodeSpacing
                let y = idx == 0
                    ? laneY
                    : laneY + (idx.isMultiple(of: 2) ? stagger : -stagger)
                out[nodeId] = CGPoint(x: x, y: y)
            }
        }
        return out
    }
}

// MARK: - Camera (mouse-anchored zoom math, V6 §7.1; pure + testable)

public struct RadarCamera: Equatable, Sendable {
    /// screen = world * scale + offset
    public var scale: CGFloat
    public var offset: CGSize

    /// Default = compressed macro view (V6_RECONCILIATION §1: 压缩态=默认初始视角).
    public init(scale: CGFloat = 0.25, offset: CGSize = .zero) {
        self.scale = scale
        self.offset = offset
    }

    public var isFar: Bool { scale < Tokens.Motion.semanticFarThreshold }

    public func toScreen(_ world: CGPoint) -> CGPoint {
        CGPoint(x: world.x * scale + offset.width, y: world.y * scale + offset.height)
    }

    public func toWorld(_ screen: CGPoint) -> CGPoint {
        CGPoint(x: (screen.x - offset.width) / scale, y: (screen.y - offset.height) / scale)
    }

    /// Zoom keeping the world point under `anchor` (screen space) fixed -
    /// V6 §7.1: "以鼠标位置为中心的数学缩放，而不是以画布中心". Clamped to
    /// Tokens.Motion.zoomRange (0.1 galaxy macro … 2.0 code micro).
    public mutating func zoom(by factor: CGFloat, anchor: CGPoint) {
        let range = Tokens.Motion.zoomRange
        let new = min(max(scale * factor, range.lowerBound), range.upperBound)
        guard new != scale else { return }
        let ratio = new / scale
        offset.width = anchor.x - (anchor.x - offset.width) * ratio
        offset.height = anchor.y - (anchor.y - offset.height) * ratio
        scale = new
    }

    public mutating func pan(by delta: CGSize) {
        offset.width += delta.width
        offset.height += delta.height
    }

    /// Camera that centers `world` in `viewport` at `scale` (fly-to).
    public static func focusing(
        on world: CGPoint, scale rawScale: CGFloat, viewport: CGSize
    ) -> RadarCamera {
        let range = Tokens.Motion.zoomRange
        let scale = min(max(rawScale, range.lowerBound), range.upperBound)
        return RadarCamera(scale: scale, offset: CGSize(
            width: viewport.width / 2 - world.x * scale,
            height: viewport.height / 2 - world.y * scale
        ))
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
    public let detailRows: [(String, String)]
    public let showsEvidenceAction: Bool

    /// Assistive-tech mirror of the visible detail (S-stage blocker: the
    /// drill-down must be REACHABLE, not just painted - law 2).
    public var accessibilityValue: String? {
        detailRows.isEmpty
            ? nil
            : detailRows.map { "\($0.0) \($0.1)" }.joined(separator: "，")
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.showsTitle == rhs.showsTitle
            && lhs.detailRows.elementsEqual(rhs.detailRows, by: ==)
            && lhs.showsEvidenceAction == rhs.showsEvidenceAction
    }

    public static func derive(node: RadarNode, selected: Bool, far: Bool) -> NodeCardContent {
        if far {
            return NodeCardContent(showsTitle: false, detailRows: [], showsEvidenceAction: false)
        }
        guard selected else {
            return NodeCardContent(showsTitle: true, detailRows: [], showsEvidenceAction: false)
        }
        var rows: [(String, String)] = []
        rows.append(("状态", node.form.label))
        if let branch = node.branch {
            rows.append(("分支", branch))
        } else if node.detached {
            rows.append(("分支", "detached"))
        }
        if let head = node.head, !head.isEmpty {
            rows.append(("HEAD", String(head.prefix(8))))
        }
        if node.locked { rows.append(("锁", "locked")) }
        return NodeCardContent(showsTitle: true, detailRows: rows, showsEvidenceAction: true)
    }
}

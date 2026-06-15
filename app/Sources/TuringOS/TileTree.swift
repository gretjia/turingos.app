// TileTree.swift — pure semantic-zoom / LOD tile tree (A1_51c)
//
// This file is a pure functional core: NO SwiftUI/Metal/AppKit imports.
// All types are value types, all functions are deterministic pure functions.
// Tests (TileTreeTests.swift) verify correctness against independent oracles.
//
// Architecture:
//   project tile → (resolved) branch tiles
//   branch tile  → (resolved) commit tiles
//   commit tile  → (deferred) DeferredRef("chaintape", sha)
//                  leaf-until-provider: no registered provider → []
//                  NEVER synthesise decision nodes (honesty law).
//
// Consumed by: GalaxyRenderer.swift (rendering), RadarViews.swift (a11y mirror).

import CoreGraphics
import Foundation

// MARK: - Tile level hierarchy

/// Semantic granularity of a tile. Declaration order = coarse→fine.
public enum TileLevel: Int, Comparable, Sendable, CaseIterable {
    case project = 0
    case branch  = 1
    case commit  = 2
    case decision = 3 // leaf; only reachable when a registered ChainTapeProvider resolves it

    public static func < (lhs: TileLevel, rhs: TileLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Deferred child reference

/// A pointer to children that live in an external provider (e.g. ChainTape).
/// leaf-until-provider: if the provider is NOT registered, getChildren returns [].
/// NEVER synthesise decision nodes from this ref (honesty law).
public struct DeferredRef: Equatable, Sendable {
    /// Provider namespace, e.g. "chaintape". Matches DeriveSource::Chaintape.
    public let source: String
    /// Provider-specific reference (e.g. commit sha or tape head).
    public let ref: String

    public init(source: String, ref: String) {
        self.source = source
        self.ref = ref
    }
}

// MARK: - Child reference (resolved or deferred)

public enum ChildRef: Sendable {
    case resolved([Tile])
    case deferred(DeferredRef)

    /// True when this ref carries resolved children.
    public var isResolved: Bool {
        if case .resolved = self { return true }
        return false
    }

    /// Resolved children (empty for deferred).
    public var children: [Tile] {
        if case .resolved(let tiles) = self { return tiles }
        return []
    }
}

// MARK: - Tile (the core LOD unit)

/// One node in the LOD tile tree.
///
/// Invariant: each tile's `bounds` MUST be a subset of its parent's `bounds`.
/// Enforced by GitProvider and asserted in TileTreeTests.
///
/// `refine` policy is REPLACE (OGC 3D Tiles style): when z >= detailThreshold,
/// the tile DISAPPEARS and its children are rendered instead (not additive).
public struct Tile: Sendable {
    /// Which level of the hierarchy this tile represents.
    public let level: TileLevel
    /// Semantic world-space extent (child bounds ⊆ parent bounds).
    public let bounds: CGRect
    /// Human-readable label for the collapsed state (shown when z < detailThreshold).
    public let summary: String
    /// The z value at or above which this tile is REPLACED by its children.
    /// Below this threshold, the tile is drawn as a collapsed summary node.
    public let detailThreshold: Double
    /// Children: resolved tiles or a deferred provider reference.
    public let children: ChildRef

    public init(
        level: TileLevel,
        bounds: CGRect,
        summary: String,
        detailThreshold: Double,
        children: ChildRef
    ) {
        self.level = level
        self.bounds = bounds
        self.summary = summary
        self.detailThreshold = detailThreshold
        self.children = children
    }

    /// Whether to show this tile's summary or replace with children at zoom z.
    /// REPLACE: z >= detailThreshold → show children; z < threshold → show summary.
    public func shouldRefine(at z: Double) -> Bool {
        z >= detailThreshold
    }
}

// MARK: - LayerProvider protocol

/// A source that can serve tiles for one level of the hierarchy.
public protocol LayerProvider: Sendable {
    /// Return the root tile for a given key (e.g. projectId, branchRef).
    func getTile(key: String) -> Tile?
    /// Return the children of a tile.
    func getChildren(of tile: Tile) -> [Tile]
    /// Resolve a DeferredRef to children. Return [] if not registered.
    func resolve(_ ref: DeferredRef) -> [Tile]
}

// MARK: - ChainTapeProvider registry

/// Global registry of ChainTapeProvider instances. Thread-safe (actor).
/// leaf-until-provider: commit tiles return DeferredRef; only when a provider
/// is registered here does getChildren resolve them into decision tiles.
///
/// Honesty law: a registered provider MAY return decision tiles for observed
/// tape facts. An UNREGISTERED provider MUST return [] (never synthesise).
public final class ChainTapeRegistry: @unchecked Sendable {
    public static let shared = ChainTapeRegistry()
    private var providers: [String: any ChainTapeChildProvider] = [:]
    private let lock = NSLock()

    private init() {}

    public func register(_ provider: any ChainTapeChildProvider, forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        providers[key] = provider
    }

    public func unregister(forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        providers.removeValue(forKey: key)
    }

    /// Resolve a DeferredRef. Returns [] if no provider is registered.
    /// NEVER synthesises decision tiles: all tiles come from the provider.
    public func resolve(_ ref: DeferredRef) -> [Tile] {
        guard ref.source == "chaintape" else { return [] }
        lock.lock()
        let provider = providers[ref.ref]
        lock.unlock()
        return provider?.childTiles(forCommit: ref.ref) ?? []
    }
}

/// Protocol for providers that can serve decision-level tiles for a commit.
public protocol ChainTapeChildProvider: Sendable {
    /// Return decision tiles for the given commit sha.
    /// All returned tiles must have level == .decision and bounds ⊆ commit bounds.
    func childTiles(forCommit sha: String) -> [Tile]
}

// MARK: - GitProvider (serves project / branch / commit tiles from RadarScene)

/// Derives the tile tree from a RadarScene. Commit→decision boundary is always
/// a DeferredRef("chaintape", commitSha). No ChainTape facts exist in P1.
public struct GitProvider: LayerProvider, Sendable {
    private let scene: RadarScene

    public init(scene: RadarScene) {
        self.scene = scene
    }

    /// Build all root tiles (one per project).
    public func buildRoots() -> [Tile] {
        scene.projects.map { project in
            projectTile(for: project)
        }
    }

    public func getTile(key: String) -> Tile? {
        guard let project = scene.projects.first(where: { $0.id == key }) else {
            return nil
        }
        return projectTile(for: project)
    }

    public func getChildren(of tile: Tile) -> [Tile] {
        switch tile.level {
        case .project:
            return branchTiles(forProjectId: tile.summary)
        case .branch:
            let parts = tile.summary.split(separator: "/", maxSplits: 1)
            guard parts.count == 2 else { return [] }
            return commitTiles(projectId: String(parts[0]), branchRef: String(parts[1]))
        case .commit:
            // commit→decision boundary = DeferredRef; resolve via registry
            let ref = DeferredRef(source: "chaintape", ref: tile.summary)
            return ChainTapeRegistry.shared.resolve(ref)
        case .decision:
            return [] // leaf
        }
    }

    public func resolve(_ ref: DeferredRef) -> [Tile] {
        ChainTapeRegistry.shared.resolve(ref)
    }

    // MARK: - Private tile builders

    private func projectTile(for project: RadarProject) -> Tile {
        let nodePositions = project.nodeIds.compactMap { scene.positions[$0] }
        let bounds = GitProvider.encompassing(
            nodePositions, margin: Tokens.LOD.projectBoundsMargin)
        return Tile(
            level: .project,
            bounds: bounds,
            summary: project.id,
            detailThreshold: Tokens.Motion.ZBand.clusterThreshold,
            children: .resolved(branchTiles(forProjectId: project.id))
        )
    }

    private func branchTiles(forProjectId projectId: String) -> [Tile] {
        let branchNodes = scene.nodes.filter {
            $0.projectId == projectId && $0.kind == .branch
        }
        return branchNodes.map { branchNode in
            // Collect branch position + all commit positions for this branch.
            var positions: [CGPoint] = []
            if let p = scene.positions[branchNode.id] { positions.append(p) }
            let branchRef = branchNode.branch ?? branchNode.id
            let commitNodes = scene.nodes.filter {
                $0.projectId == projectId && $0.kind == .commit
                    && $0.branch == branchRef
            }
            for cn in commitNodes {
                if let p = scene.positions[cn.id] { positions.append(p) }
            }
            let bounds = GitProvider.encompassing(
                positions, margin: Tokens.LOD.branchBoundsMargin)
            return Tile(
                level: .branch,
                bounds: bounds,
                summary: "\(projectId)/\(branchRef)",
                detailThreshold: Tokens.Motion.ZBand.nodeThreshold,
                children: .resolved(commitTiles(projectId: projectId, branchRef: branchRef))
            )
        }
    }

    private func commitTiles(projectId: String, branchRef: String) -> [Tile] {
        let commitNodes = scene.nodes.filter {
            $0.projectId == projectId && $0.kind == .commit
                && $0.branch == branchRef
        }
        return commitNodes.map { commitNode in
            let pos = scene.positions[commitNode.id] ?? .zero
            let bounds = GitProvider.encompassing(
                [pos], margin: Tokens.LOD.commitBoundsMargin)
            let sha = commitNode.head ?? commitNode.id
            return Tile(
                level: .commit,
                bounds: bounds,
                summary: sha,
                detailThreshold: Tokens.Motion.ZBand.detailThreshold,
                children: .deferred(DeferredRef(source: "chaintape", ref: sha))
            )
        }
    }

    /// Minimum bounding rect of `points` expanded by `margin` on all sides.
    /// Returns a zero-origin rect of size (2*margin × 2*margin) when points is empty.
    static func encompassing(_ points: [CGPoint], margin: CGFloat) -> CGRect {
        guard !points.isEmpty else {
            return CGRect(x: -margin, y: -margin, width: margin * 2, height: margin * 2)
        }
        let minX = points.map(\.x).min()! - margin
        let minY = points.map(\.y).min()! - margin
        let maxX = points.map(\.x).max()! + margin
        let maxY = points.map(\.y).max()! + margin
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

// MARK: - Pure functions: cull, band, refine, visibleA11yElements

/// Viewport culling: returns tiles whose bounds intersect the world-space
/// viewport. Used by the renderer per frame to decide what to draw.
///
/// Production implementation uses CGRect.intersects for AABB testing.
/// Tests verify correctness against an INDEPENDENT brute-force oracle.
public func cull(tiles: [Tile], worldViewport: CGRect) -> [Tile] {
    tiles.filter { $0.bounds.intersects(worldViewport) }
}

/// World-space viewport rect derived from camera + screen size.
public func worldViewport(camera: RadarCamera, size: CGSize) -> CGRect {
    let z = camera.z
    return CGRect(
        x: camera.x,
        y: camera.y,
        width: Double(size.width) / z,
        height: Double(size.height) / z
    )
}

// MARK: - LOD band with hysteresis

/// Persistent state for LOD band transitions. Carries the last committed band
/// so hysteresis can delay a transition until z passes the threshold by a margin.
public struct LODState: Equatable {
    public var band: RadarCamera.Band
    /// Log2 hysteresis margin (from Tokens.LOD.bandHysteresisLog2).
    public var hysteresis: Double

    public init(
        band: RadarCamera.Band = .galaxy,
        hysteresis: Double = Tokens.LOD.bandHysteresisLog2
    ) {
        self.band = band
        self.hysteresis = hysteresis
    }

    /// Evaluate the new band given the current z. Applies hysteresis: crossing
    /// a threshold requires exceeding it by `hysteresis` log2 units. Deterministic
    /// given (current band, z, hysteresis). Prevents flickering at boundaries.
    public mutating func evaluate(z: Double) {
        let log2z = z > 0 ? log2(z) : -Double.infinity
        let h = hysteresis

        // Compute raw thresholds in log2 space.
        let clusterLog = log2(Tokens.Motion.ZBand.clusterThreshold)
        let nodeLog    = log2(Tokens.Motion.ZBand.nodeThreshold)
        let detailLog  = log2(Tokens.Motion.ZBand.detailThreshold)

        // Hysteresis: when in a coarser band, require z to exceed the threshold
        // by h before promoting. When in a finer band, require z to fall below
        // the threshold by h before demoting.
        switch band {
        case .galaxy:
            if log2z >= clusterLog + h { band = .cluster }
        case .cluster:
            if log2z >= nodeLog + h     { band = .node }
            else if log2z < clusterLog - h { band = .galaxy }
        case .node:
            if log2z >= detailLog + h   { band = .detail }
            else if log2z < nodeLog - h  { band = .cluster }
        case .detail:
            if log2z < detailLog - h    { band = .node }
        }
    }

    /// Cross-fade alpha in [0,1]: 1.0 when fully in the new band, fading in
    /// during the hysteresis window. Pure function of (z, targetBand, hysteresis).
    public static func crossFadeAlpha(
        z: Double, targetBand: RadarCamera.Band, hysteresis: Double
    ) -> Double {
        let log2z = z > 0 ? log2(z) : -Double.infinity
        let clusterLog = log2(Tokens.Motion.ZBand.clusterThreshold)
        let nodeLog    = log2(Tokens.Motion.ZBand.nodeThreshold)
        let detailLog  = log2(Tokens.Motion.ZBand.detailThreshold)
        let h = hysteresis
        guard h > 0 else { return 1.0 }
        switch targetBand {
        case .galaxy:
            return clamp01((clusterLog - log2z) / h)
        case .cluster:
            let enterFromGalaxy = clamp01((log2z - clusterLog) / h)
            let enterFromNode   = clamp01((nodeLog - log2z) / h)
            return min(enterFromGalaxy, enterFromNode)
        case .node:
            let enterFromCluster = clamp01((log2z - nodeLog) / h)
            let enterFromDetail  = clamp01((detailLog - log2z) / h)
            return min(enterFromCluster, enterFromDetail)
        case .detail:
            return clamp01((log2z - detailLog) / h)
        }
    }
}

private func clamp01(_ v: Double) -> Double { max(0, min(1, v)) }

// MARK: - A11y mirror

/// Accessibility mirror for one visible node. One per visible node (1:1 map).
/// Created by `visibleA11yElements` and rendered as transparent SwiftUI
/// accessibility elements overlaid on the Metal layer. VoiceOver sees every
/// visible node, including far-dot band nodes.
public struct A11yMirror: Sendable {
    /// Stable node id (matches RadarNode.id).
    public let nodeId: String
    /// Accessibility label (non-empty; from RadarNode.accessibilityLabel).
    public let label: String
    /// Screen-space position of the node (for .position() overlay placement).
    public let screenPoint: CGPoint

    public init(nodeId: String, label: String, screenPoint: CGPoint) {
        self.nodeId = nodeId
        self.label = label
        self.screenPoint = screenPoint
    }
}

/// Pure function: returns one A11yMirror for every visible node in the scene.
/// "Visible" = the node's world position is within the world viewport.
/// ALL visible nodes get exactly one mirror INCLUDING far-dot band nodes.
///
/// Predicate: |output| == |visible nodes|; each visible nodeId → exactly one
/// mirror; label non-empty. Verified in RadarLODTests (real teeth, no mock).
public func visibleA11yElements(
    scene: RadarScene,
    camera: RadarCamera,
    viewport: CGSize
) -> [A11yMirror] {
    let wv = worldViewport(camera: camera, size: viewport)
    var mirrors: [A11yMirror] = []
    // Collect position+offset per node. userOffsets live in the view;
    // this pure function uses only base scene positions (no drag offsets).
    for node in scene.nodes {
        guard let worldPos = scene.positions[node.id] else { continue }
        // Visibility check: world position inside world viewport.
        if wv.contains(worldPos) {
            let screenPt = camera.toScreen(worldPos)
            mirrors.append(A11yMirror(
                nodeId: node.id,
                label: node.accessibilityLabel,
                screenPoint: screenPt
            ))
        }
    }
    return mirrors
}

// MARK: - RenderSet (LOD aggregation, A1_55)
//
// Pure functional gate that replaces the unconditional `for node in scene.nodes` loop.
// GalaxyRenderer.buildInstances and RadarViews.nodeOverlay MUST consume this set
// instead of iterating scene.nodes directly.
//
// Honesty law: all counts (branchCount/commitCount) are derived from scene.nodes —
// never fabricated. Invariant: at galaxy/cluster band, expandedNodes is always empty.

/// One coarse-band glyph per project. Rendered as a single large Metal instance;
/// carries the honest branch/commit counts derived from actual scene nodes.
public struct ProjectAggregate: Sendable {
    /// Stable project identifier.
    public let projectId: String
    /// Galaxy center in world space (= RadarLayout.galaxyCenter(projectId, in: scene)).
    /// All visual elements (label, nebula, branch-ring) anchor here.
    public let center: CGPoint
    /// Count of branch-kind nodes for this project (scene-derived, never fabricated).
    public let branchCount: Int
    /// Count of commit-kind nodes for this project (scene-derived, never fabricated).
    public let commitCount: Int

    public init(projectId: String, center: CGPoint, branchCount: Int, commitCount: Int) {
        self.projectId = projectId
        self.center = center
        self.branchCount = branchCount
        self.commitCount = commitCount
    }
}

/// One item in the band-aware render set.
public enum RenderSetItem: Sendable {
    /// Coarse: one glyph representing the whole project (galaxy/cluster band).
    case aggregate(ProjectAggregate)
    /// Fine: an individual node that is currently expanded (node/detail band).
    case node(RadarNode)
}

/// The LOD-selected set of what GalaxyRenderer and RadarViews must render this frame.
///
/// Invariants (verifiable, pinned by integration tests):
/// - galaxy/cluster band: expandedNodes.count == 0, aggregates.count == scene.projects.count
/// - node/detail band: projects whose galaxyCenter is in the expanded viewport are
///   flattened to their individual nodes; others remain aggregates.
/// - edges: only between currently-expanded nodes (empty at galaxy/cluster band).
public struct RenderSet: Sendable {
    public let items: [RenderSetItem]
    /// Edges connecting expanded nodes only.
    public let edges: [RadarEdge]
    /// Band at which this render set was computed.
    public let band: RadarCamera.Band

    public init(items: [RenderSetItem], edges: [RadarEdge], band: RadarCamera.Band) {
        self.items = items
        self.edges = edges
        self.band = band
    }

    public var aggregates: [ProjectAggregate] {
        items.compactMap { guard case .aggregate(let a) = $0 else { return nil }; return a }
    }

    public var expandedNodes: [RadarNode] {
        items.compactMap { guard case .node(let n) = $0 else { return nil }; return n }
    }
}

/// Extra world-space margin added around the viewport when checking if a project center
/// is "in view" for the purpose of expanding it to individual nodes.
/// Ensures expansion starts slightly before the center enters the viewport.
private let renderSetExpansionMargin: CGFloat = 400

/// Pure function: LOD-selected render set for the current camera and viewport.
/// This is the mandatory gate replacing `for node in scene.nodes` everywhere.
///
/// - galaxy/cluster band → one `ProjectAggregate` per project, zero expanded nodes.
/// - node/detail band    → projects whose galaxyCenter is inside the expanded viewport
///   are flattened to their `[RadarNode]`; others remain aggregates.
///
/// Deterministic: same (scene, camera, viewport) → same RenderSet.
/// Consumed by: GalaxyRenderer.buildInstances, RadarViews.nodeOverlay+projectLaneCanvas.
public func renderSet(
    scene: RadarScene,
    camera: RadarCamera,
    viewport: CGSize
) -> RenderSet {
    let band = camera.currentBand()
    let wv = worldViewport(camera: camera, size: viewport)
    // Slightly expanded viewport for expansion-trigger tests (smooth transitions).
    let expandedWV = wv.insetBy(dx: -renderSetExpansionMargin, dy: -renderSetExpansionMargin)

    var items: [RenderSetItem] = []
    var expandedNodeIds: Set<String> = []

    // Compute the deterministic spiral centers once (avoids O(n²) per frame).
    let centers = RadarLayout.galaxyCenters(projectIds: scene.projects.map(\.id))

    for project in scene.projects {
        let center = centers[project.id] ?? .zero
        let branchCount = scene.nodes.filter {
            $0.projectId == project.id && $0.kind == .branch
        }.count
        let commitCount = scene.nodes.filter {
            $0.projectId == project.id && $0.kind == .commit
        }.count

        // Only expand when the galaxy center is visible AND we are zoomed in enough.
        let shouldExpand: Bool
        switch band {
        case .galaxy, .cluster:
            shouldExpand = false
        case .node, .detail:
            shouldExpand = expandedWV.contains(center)
        }

        if shouldExpand {
            for node in scene.nodes where node.projectId == project.id {
                items.append(.node(node))
                expandedNodeIds.insert(node.id)
            }
        } else {
            items.append(.aggregate(ProjectAggregate(
                projectId: project.id,
                center: center,
                branchCount: branchCount,
                commitCount: commitCount
            )))
        }
    }

    // Edges are only meaningful between currently-expanded nodes.
    let filteredEdges: [RadarEdge]
    switch band {
    case .galaxy, .cluster:
        filteredEdges = []
    case .node, .detail:
        filteredEdges = scene.edges.filter {
            expandedNodeIds.contains($0.from) && expandedNodeIds.contains($0.to)
        }
    }

    return RenderSet(items: items, edges: filteredEdges, band: band)
}

// MARK: - Tile tree canonical dump (for golden test)

/// Produce a deterministic text dump of a tile tree (BFS traversal).
/// Format: level key bounds detailThreshold childRef
/// Used by TileTreeTests.testTileTreeGolden to pin the derivation.
public func tileTreeCanonicalDump(roots: [Tile]) -> String {
    var lines: [String] = [
        "# p1_tiletree.golden.txt — tile-tree canonical dump (A1_51c)",
        "# level summary bounds detailThreshold childRef",
    ]
    func fmt(_ r: CGRect) -> String {
        String(format: "(%.1f,%.1f,%.1f,%.1f)", r.origin.x, r.origin.y, r.size.width, r.size.height)
    }
    func walk(_ tile: Tile, indent: Int) {
        let pad = String(repeating: "  ", count: indent)
        let childStr: String
        switch tile.children {
        case .resolved(let children):
            childStr = "resolved[\(children.count)]"
        case .deferred(let ref):
            childStr = "deferred[\(ref.source):\(ref.ref)]"
        }
        lines.append("\(pad)\(tile.level) \(tile.summary) \(fmt(tile.bounds)) \(tile.detailThreshold) \(childStr)")
        for child in tile.children.children {
            walk(child, indent: indent + 1)
        }
    }
    for root in roots { walk(root, indent: 0) }
    return lines.joined(separator: "\n") + "\n"
}

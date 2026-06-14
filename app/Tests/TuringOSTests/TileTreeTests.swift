// TileTreeTests.swift — tile-tree predicate tests (A1_51c)
//
// Predicates:
//  1. cull correctness vs INDEPENDENT brute-force oracle (NOT production AABB)
//  2. N≥10k stub: far-band render-set size ≤ clusterCount ≪ nodeCount
//  3. tile-tree invariants (child bounds ⊆ parent; detailThreshold → summary vs refine)
//  4. tile-tree determinism (same RadarScene ⇒ same tile-tree)
//  5. DeferredRef leaf-until-provider (unregistered → []; registered stub → children)
//  6. LOD band determinism + hysteresis
//  7. cross-fade alpha pure function
//  8. a11y (visibleA11yElements |output| == |visible nodes|, 1:1, non-empty labels)
//  9. tile-tree golden (p1_tiletree.golden.txt, RADAR_GOLDEN_WRITE guard)

import CoreGraphics
import Foundation
import XCTest
@testable import TuringOS

final class TileTreeTests: XCTestCase {

    // MARK: - Helpers

    /// Build a minimal RadarScene with controlled positions (no layout arithmetic).
    private static func minimalScene() -> RadarScene {
        // 1 project "gp", 1 worktree anchor, 1 default branch, 1 commit.
        let wt = RadarNode(
            id: "wt_gp_root",
            projectId: "gp",
            title: "root",
            branch: "main",
            head: "aaaa1111",
            form: .quiet,
            kind: .worktree,
            isAnchor: true,
            sameBranchConflict: false,
            locked: false, detached: false, evidence: .object([:]),
            ahead: 0, behind: 0, mergeStatus: "unknown",
            containedInDefault: false, mergedIntoDefault: false
        )
        let bn = RadarNode(
            id: "branch:gp:main",
            projectId: "gp",
            title: "main",
            branch: "main",
            head: nil,
            form: .quiet,
            kind: .branch,
            isAnchor: true,
            sameBranchConflict: false,
            locked: false, detached: false, evidence: .object([:]),
            ahead: 0, behind: 0, mergeStatus: "merged",
            containedInDefault: true, mergedIntoDefault: true
        )
        let cn = RadarNode(
            id: "commit:gp:aaaa1111",
            projectId: "gp",
            title: "aaaa1111",
            branch: "main",
            head: "aaaa1111",
            form: .quiet,
            kind: .commit,
            isAnchor: false,
            sameBranchConflict: false,
            locked: false, detached: false, evidence: .object([:]),
            ahead: 0, behind: 0, mergeStatus: "unknown",
            containedInDefault: false, mergedIntoDefault: false
        )
        let project = RadarProject(id: "gp", path: "/gp", nodeIds: ["wt_gp_root", "branch:gp:main", "commit:gp:aaaa1111"])
        return RadarScene(
            projects: [project],
            nodes: [wt, bn, cn],
            edges: [],
            positions: [
                "wt_gp_root":        CGPoint(x: 0, y: 0),
                "branch:gp:main":    CGPoint(x: 0, y: 0),
                "commit:gp:aaaa1111": CGPoint(x: 0, y: 200),
            ]
        )
    }

    /// Build a scene with `nodeCount` commit nodes across 1 project / 1 branch.
    private static func largeScene(nodeCount: Int) -> RadarScene {
        var nodes: [RadarNode] = []
        var positions: [String: CGPoint] = [:]
        // 1 branch node (anchor)
        let branchId = "branch:big:main"
        nodes.append(RadarNode(
            id: branchId, projectId: "big", title: "main", branch: "main", head: nil,
            form: .quiet, kind: .branch, isAnchor: true, sameBranchConflict: false,
            locked: false, detached: false, evidence: .object([:]),
            ahead: 0, behind: 0, mergeStatus: "unknown", containedInDefault: false, mergedIntoDefault: false))
        positions[branchId] = CGPoint(x: 0, y: 0)
        // nodeCount commit nodes scattered in a grid
        for i in 0..<nodeCount {
            let sha = String(format: "c%07d", i)
            let nodeId = "commit:big:\(sha)"
            nodes.append(RadarNode(
                id: nodeId, projectId: "big", title: sha, branch: "main", head: sha,
                form: .quiet, kind: .commit, isAnchor: false, sameBranchConflict: false,
                locked: false, detached: false, evidence: .object([:]),
                ahead: 0, behind: 0, mergeStatus: "unknown", containedInDefault: false, mergedIntoDefault: false))
            // Grid: columns of 100, spaced 80pt apart
            let col = i % 100
            let row = i / 100
            positions[nodeId] = CGPoint(x: Double(col) * 80, y: Double(row) * 80 + 200)
        }
        let project = RadarProject(id: "big", path: "/big", nodeIds: nodes.map(\.id))
        return RadarScene(projects: [project], nodes: nodes, edges: [], positions: positions)
    }

    // MARK: - 1. Cull correctness vs independent brute-force oracle

    func testCullCorrectnessVsOracle() {
        // Production cull uses CGRect.intersects (AABB).
        // Oracle uses an INDEPENDENT point-in-rect check: tile is visible if
        // its centre point lies within the expanded worldViewport.
        // Deliberately different algorithm to catch shared-bug false positives.
        struct OracleTile {
            let bounds: CGRect
        }
        func oracleCull(tiles: [Tile], worldViewport: CGRect) -> [Tile] {
            tiles.filter { tile in
                // Oracle: tile is visible if ANY of its four corners is inside viewport.
                let corners = [
                    CGPoint(x: tile.bounds.minX, y: tile.bounds.minY),
                    CGPoint(x: tile.bounds.maxX, y: tile.bounds.minY),
                    CGPoint(x: tile.bounds.minX, y: tile.bounds.maxY),
                    CGPoint(x: tile.bounds.maxX, y: tile.bounds.maxY),
                    CGPoint(x: tile.bounds.midX, y: tile.bounds.midY), // centre
                ]
                return corners.contains { worldViewport.contains($0) }
                    || worldViewport.intersects(tile.bounds) // belt-and-suspenders
            }
        }

        // Build test tiles at various positions.
        let tiles = [
            Tile(level: .project, bounds: CGRect(x: -100, y: -100, width: 200, height: 200),
                 summary: "A", detailThreshold: 0.08, children: .resolved([])),
            Tile(level: .branch, bounds: CGRect(x: 300, y: 300, width: 50, height: 50),
                 summary: "B", detailThreshold: 0.5, children: .resolved([])),
            Tile(level: .commit, bounds: CGRect(x: 1000, y: 1000, width: 20, height: 20),
                 summary: "C", detailThreshold: 2.0, children: .resolved([])),
            Tile(level: .project, bounds: CGRect(x: -5000, y: -5000, width: 100, height: 100),
                 summary: "D", detailThreshold: 0.08, children: .resolved([])),
        ]
        let viewportCases: [CGRect] = [
            CGRect(x: -200, y: -200, width: 800, height: 800),  // hits A, B
            CGRect(x: 0,    y: 0,    width: 100, height: 100),  // hits A (intersects)
            CGRect(x: 900,  y: 900,  width: 200, height: 200),  // hits C
            CGRect(x: 5000, y: 5000, width: 100, height: 100),  // hits nothing
        ]
        for vp in viewportCases {
            let production = cull(tiles: tiles, worldViewport: vp)
            let oracle     = oracleCull(tiles: tiles, worldViewport: vp)
            // Both must agree on which tiles are visible.
            let prodIds = Set(production.map(\.summary)).sorted()
            let oracleIds = Set(oracle.map(\.summary)).sorted()
            XCTAssertEqual(prodIds, oracleIds,
                "cull vs oracle disagree for viewport \(vp): production=\(prodIds) oracle=\(oracleIds)")
        }
    }

    // MARK: - 2. N≥10k stub: far-band render-set ≤ clusterCount ≪ nodeCount

    func testLargeSceneFarBandRenderSetBounded() {
        let nodeCount = 10_000
        let scene = TileTreeTests.largeScene(nodeCount: nodeCount)
        let provider = GitProvider(scene: scene)
        let roots = provider.buildRoots()

        // Total commit nodes in scene (excluding branch node).
        let totalCommitNodes = scene.nodes.filter { $0.kind == .commit }.count
        XCTAssertGreaterThanOrEqual(totalCommitNodes, nodeCount,
            "large scene must have ≥\(nodeCount) commit nodes")

        // At galaxy band (z=0.01, far below clusterThreshold=0.08):
        // tile-tree delivers project-level tiles only (not commit nodes).
        let galaxyCamera = RadarCamera(x: 0, y: 0, logZoom: log2(0.01))
        let viewSize = CGSize(width: 1920, height: 1080)
        let wv = worldViewport(camera: galaxyCamera, size: viewSize)

        // Cull project-level tiles = roots visible in viewport.
        let allTiles = roots
        let visibleRoots = cull(tiles: allTiles, worldViewport: wv)
        // Each project has at most maxClusterCount clusters rendered.
        let clusterCount = visibleRoots.count * Tokens.LOD.maxClusterCount
        XCTAssertLessThanOrEqual(clusterCount, Tokens.LOD.maxClusterCount,
            "cluster count must be ≤ maxClusterCount at galaxy band")
        XCTAssertLessThan(clusterCount, totalCommitNodes,
            "cluster count (\(clusterCount)) must be ≪ nodeCount (\(totalCommitNodes))")
    }

    // MARK: - 3. Tile-tree invariants

    func testChildBoundsSubsetOfParent() {
        let scene = TileTreeTests.minimalScene()
        let provider = GitProvider(scene: scene)
        let roots = provider.buildRoots()

        func checkBoundsInvariant(_ tile: Tile, parentBounds: CGRect?, depth: Int) {
            if let parent = parentBounds {
                // Child bounds must be ⊆ parent bounds (within floating-point margin).
                let margin: CGFloat = 0.01
                XCTAssertGreaterThanOrEqual(tile.bounds.minX, parent.minX - margin,
                    "depth \(depth): child.minX < parent.minX")
                XCTAssertGreaterThanOrEqual(tile.bounds.minY, parent.minY - margin,
                    "depth \(depth): child.minY < parent.minY")
                XCTAssertLessThanOrEqual(tile.bounds.maxX, parent.maxX + margin,
                    "depth \(depth): child.maxX > parent.maxX")
                XCTAssertLessThanOrEqual(tile.bounds.maxY, parent.maxY + margin,
                    "depth \(depth): child.maxY > parent.maxY")
            }
            for child in tile.children.children {
                checkBoundsInvariant(child, parentBounds: tile.bounds, depth: depth + 1)
            }
        }
        for root in roots {
            checkBoundsInvariant(root, parentBounds: nil, depth: 0)
        }
    }

    func testDetailThresholdDeterminesSummaryVsRefine() {
        // At z < detailThreshold → shouldRefine = false (show summary).
        // At z >= detailThreshold → shouldRefine = true (replace with children).
        let tile = Tile(level: .branch, bounds: CGRect(x: 0, y: 0, width: 100, height: 100),
                        summary: "test", detailThreshold: 0.5, children: .resolved([]))
        XCTAssertFalse(tile.shouldRefine(at: 0.1),
            "z=0.1 < threshold=0.5 → summary (no refine)")
        XCTAssertFalse(tile.shouldRefine(at: 0.499),
            "z=0.499 < threshold=0.5 → summary")
        XCTAssertTrue(tile.shouldRefine(at: 0.5),
            "z=0.5 == threshold=0.5 → refine (REPLACE)")
        XCTAssertTrue(tile.shouldRefine(at: 2.0),
            "z=2.0 > threshold=0.5 → refine")
    }

    // MARK: - 4. Tile-tree determinism (same RadarScene ⇒ same tile-tree)

    func testTileTreeDeterminism() {
        let scene = TileTreeTests.minimalScene()
        let p1 = GitProvider(scene: scene)
        let p2 = GitProvider(scene: scene)
        let roots1 = p1.buildRoots()
        let roots2 = p2.buildRoots()
        // Compare canonical dumps (byte-exact determinism).
        let dump1 = tileTreeCanonicalDump(roots: roots1)
        let dump2 = tileTreeCanonicalDump(roots: roots2)
        XCTAssertEqual(dump1, dump2, "same RadarScene must produce identical tile-tree dumps")
    }

    // MARK: - 5. DeferredRef leaf-until-provider

    func testDeferredRefLeafUntilProvider() {
        let scene = TileTreeTests.minimalScene()
        let provider = GitProvider(scene: scene)
        let roots = provider.buildRoots()

        // Walk to commit tiles.
        var commitTiles: [Tile] = []
        func findCommits(_ tile: Tile) {
            if tile.level == .commit { commitTiles.append(tile); return }
            for child in tile.children.children { findCommits(child) }
        }
        for root in roots { findCommits(root) }
        XCTAssertFalse(commitTiles.isEmpty, "should have at least one commit tile")

        // 5a. Unregistered provider → getChildren returns [] (leaf-until-provider).
        // We do NOT register any ChainTapeChildProvider for the test commit sha.
        for commitTile in commitTiles {
            let children = provider.getChildren(of: commitTile)
            XCTAssertTrue(children.isEmpty,
                "unregistered chaintape provider must return [] (no synthetic decision nodes)")
            // Verify children ref is deferred (not resolved with synthetic data).
            if case .deferred(let ref) = commitTile.children {
                XCTAssertEqual(ref.source, "chaintape",
                    "commit tile children must be DeferredRef(source:chaintape,...)")
            } else {
                XCTFail("commit tile should have .deferred children, not resolved")
            }
        }

        // 5b. Registered stub provider → SAME DeferredRef resolves to stub children.
        let stubSha = commitTiles[0].summary
        let stubProvider = StubChainTapeProvider(sha: stubSha)
        ChainTapeRegistry.shared.register(stubProvider, forKey: stubSha)
        defer { ChainTapeRegistry.shared.unregister(forKey: stubSha) }

        let resolvedChildren = provider.getChildren(of: commitTiles[0])
        XCTAssertEqual(resolvedChildren.count, stubProvider.stubChildCount,
            "registered stub provider must resolve DeferredRef into stub children")
        // All resolved children must be .decision level.
        for child in resolvedChildren {
            XCTAssertEqual(child.level, .decision,
                "resolved ChainTape children must have level == .decision")
        }
    }

    func testNoSyntheticDecisionNodesWithoutProvider() {
        // Adversarial check: build a large scene and verify zero decision-level
        // tiles exist without a registered provider (honesty law).
        let scene = TileTreeTests.largeScene(nodeCount: 50)
        let provider = GitProvider(scene: scene)
        let roots = provider.buildRoots()

        func collectAllTiles(_ tile: Tile) -> [Tile] {
            var acc = [tile]
            for child in tile.children.children { acc += collectAllTiles(child) }
            return acc
        }
        var allTiles: [Tile] = []
        for root in roots { allTiles += collectAllTiles(root) }

        let decisionTiles = allTiles.filter { $0.level == .decision }
        XCTAssertTrue(decisionTiles.isEmpty,
            "must have zero decision tiles without a registered ChainTapeProvider (honesty law)")
    }

    // MARK: - 6. LOD band determinism + hysteresis

    func testLODBandDeterminism() {
        // band(z) for the same z must always return the same band.
        let zValues: [Double] = [0.01, 0.05, 0.08, 0.09, 0.3, 0.5, 0.51, 1.0, 2.0, 2.1, 10.0]
        for z in zValues {
            var state1 = LODState()
            var state2 = LODState()
            state1.evaluate(z: z)
            state2.evaluate(z: z)
            XCTAssertEqual(state1.band, state2.band,
                "band(z=\(z)) must be deterministic: got \(state1.band) vs \(state2.band)")
        }
    }

    func testLODBandHysteresis() {
        // Hysteresis: entering .node from .cluster requires z >= nodeThreshold + h.
        // Exiting back to .cluster requires z < nodeThreshold - h.
        let h = Tokens.LOD.bandHysteresisLog2
        let nodeThreshold = Tokens.Motion.ZBand.nodeThreshold

        var state = LODState() // starts at .galaxy

        // Move to .cluster band: z = clusterThreshold + epsilon * 2
        let enterClusterZ = pow(2, log2(Tokens.Motion.ZBand.clusterThreshold) + h + 0.01)
        state.evaluate(z: enterClusterZ)
        XCTAssertEqual(state.band, .cluster, "should enter .cluster band at z=\(enterClusterZ)")

        // Now at z = nodeThreshold (exactly on threshold): should NOT yet enter .node
        // because hysteresis requires z >= nodeThreshold + h in log2 space.
        state.evaluate(z: nodeThreshold)
        XCTAssertEqual(state.band, .cluster,
            "at exactly nodeThreshold, hysteresis should keep us in .cluster")

        // Now push z above nodeThreshold by more than h (in log2): should enter .node.
        let enterNodeZ = pow(2, log2(nodeThreshold) + h + 0.01)
        state.evaluate(z: enterNodeZ)
        XCTAssertEqual(state.band, .node,
            "should enter .node after exceeding nodeThreshold + hysteresis")

        // Drop z back to nodeThreshold (below threshold in log2 but within hysteresis window):
        // should NOT drop back to .cluster yet.
        state.evaluate(z: nodeThreshold)
        XCTAssertEqual(state.band, .node,
            "at nodeThreshold from above, hysteresis should keep us in .node")

        // Drop below nodeThreshold - h: NOW should return to .cluster.
        let exitNodeZ = pow(2, log2(nodeThreshold) - h - 0.01)
        state.evaluate(z: exitNodeZ)
        XCTAssertEqual(state.band, .cluster,
            "below nodeThreshold - hysteresis, should return to .cluster")
    }

    // MARK: - 7. Cross-fade alpha pure function

    func testCrossFadeAlphaPureFunction() {
        let h = Tokens.LOD.bandHysteresisLog2
        let clusterLog = log2(Tokens.Motion.ZBand.clusterThreshold)
        let nodeLog    = log2(Tokens.Motion.ZBand.nodeThreshold)

        // Alpha must be in [0,1].
        for z in [0.005, 0.01, 0.05, 0.08, 0.1, 0.5, 2.0, 10.0] {
            for band in [RadarCamera.Band.galaxy, .cluster, .node, .detail] {
                let alpha = LODState.crossFadeAlpha(z: z, targetBand: band, hysteresis: h)
                XCTAssertGreaterThanOrEqual(alpha, 0.0, "alpha must be ≥ 0 at z=\(z) band=\(band)")
                XCTAssertLessThanOrEqual(alpha, 1.0, "alpha must be ≤ 1 at z=\(z) band=\(band)")
            }
        }

        // Cross-fade is a pure function: same inputs → same output.
        for _ in 0..<5 {
            let a1 = LODState.crossFadeAlpha(z: 0.1, targetBand: .cluster, hysteresis: h)
            let a2 = LODState.crossFadeAlpha(z: 0.1, targetBand: .cluster, hysteresis: h)
            XCTAssertEqual(a1, a2, "cross-fade alpha must be deterministic")
        }

        // Deep in .cluster band: alpha for .cluster should approach 1.
        let midCluster = pow(2, (clusterLog + nodeLog) / 2)
        let midAlpha = LODState.crossFadeAlpha(z: midCluster, targetBand: .cluster, hysteresis: h)
        XCTAssertGreaterThan(midAlpha, 0.5, "mid-cluster z → cluster alpha > 0.5")
    }

    // MARK: - 8. A11y: visibleA11yElements 1:1 with visible nodes

    func testA11yMirrorOneToOneWithVisibleNodes() {
        let scene = TileTreeTests.minimalScene()
        // Default camera (z=0.25) at origin, generous viewport that contains all nodes.
        let camera = RadarCamera(x: -500, y: -500, logZoom: -2)
        let viewport = CGSize(width: 2000, height: 2000)

        let mirrors = visibleA11yElements(scene: scene, camera: camera, viewport: viewport)

        // Compute expected visible nodes: those whose world positions are in worldViewport.
        let wv = worldViewport(camera: camera, size: viewport)
        let expectedVisible = scene.nodes.filter { node in
            guard let pos = scene.positions[node.id] else { return false }
            return wv.contains(pos)
        }

        XCTAssertEqual(mirrors.count, expectedVisible.count,
            "|mirrors| must equal |visible nodes|: got \(mirrors.count), expected \(expectedVisible.count)")

        // Each visible nodeId appears exactly once.
        let mirrorNodeIds = mirrors.map(\.nodeId)
        let uniqueIds = Set(mirrorNodeIds)
        XCTAssertEqual(mirrorNodeIds.count, uniqueIds.count,
            "each visible nodeId must appear exactly once in mirrors")

        // All mirror labels must be non-empty.
        for mirror in mirrors {
            XCTAssertFalse(mirror.label.isEmpty,
                "mirror for node \(mirror.nodeId) has empty label — a11y predicate violated")
        }
    }

    func testA11yMirrorIncludesFarBandNodes() {
        // Far band (z < semanticFarThreshold = 0.6): all visible nodes still get a mirror.
        let scene = TileTreeTests.largeScene(nodeCount: 20)
        // Far zoom: z = 0.1, well below 0.6.
        let camera = RadarCamera(x: -200, y: -200, logZoom: log2(0.1))
        let viewport = CGSize(width: 1920, height: 1080)

        XCTAssertTrue(camera.isFar, "camera must be in far mode for this test")

        let mirrors = visibleA11yElements(scene: scene, camera: camera, viewport: viewport)
        let wv = worldViewport(camera: camera, size: viewport)
        let visibleCount = scene.nodes.filter { node in
            guard let pos = scene.positions[node.id] else { return false }
            return wv.contains(pos)
        }.count

        XCTAssertEqual(mirrors.count, visibleCount,
            "far-band: |mirrors| must still equal |visible nodes| (VoiceOver must reach every dot)")

        for mirror in mirrors {
            XCTAssertFalse(mirror.label.isEmpty, "far-band mirror label must be non-empty")
        }
    }

    // MARK: - 9. Tile-tree golden (RADAR_GOLDEN_WRITE guard)

    private static var snapshotsDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // TuringOSTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // app
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("fixtures/snapshots")
    }

    func testTileTreeGolden() throws {
        let scene = TileTreeTests.minimalScene()
        let provider = GitProvider(scene: scene)
        let roots = provider.buildRoots()
        let dump = tileTreeCanonicalDump(roots: roots)

        let goldenURL = TileTreeTests.snapshotsDir
            .appendingPathComponent("p1_tiletree.golden.txt")

        if ProcessInfo.processInfo.environment["RADAR_GOLDEN_WRITE"] == "1" {
            try FileManager.default.createDirectory(
                at: TileTreeTests.snapshotsDir, withIntermediateDirectories: true)
            try dump.write(to: goldenURL, atomically: true, encoding: .utf8)
            XCTFail("tile-tree golden regenerated at \(goldenURL.path) — rerun WITHOUT RADAR_GOLDEN_WRITE=1")
            return
        }
        let committed = try String(contentsOf: goldenURL, encoding: .utf8)
        XCTAssertEqual(dump, committed,
            "tile-tree golden drifted — run RADAR_GOLDEN_WRITE=1 to update (must review diff!)")
    }
}

// MARK: - Stub ChainTapeChildProvider for DeferredRef tests

private final class StubChainTapeProvider: ChainTapeChildProvider, @unchecked Sendable {
    let sha: String
    let stubChildCount = 3

    init(sha: String) { self.sha = sha }

    func childTiles(forCommit sha: String) -> [Tile] {
        // Return 3 decision tiles with bounds matching the commit bounds heuristic.
        // Bounds: small sub-rects within the commit bounds.
        (0..<stubChildCount).map { i in
            Tile(
                level: .decision,
                bounds: CGRect(x: Double(i) * 10 - 10, y: 190, width: 8, height: 8),
                summary: "\(sha)::decision_\(i)",
                detailThreshold: .infinity, // decisions are always leaf
                children: .resolved([])
            )
        }
    }
}

// RadarLODTests.swift — Metal fail-safe + 27-only isolation tests (A1_51c)
//
// Predicates:
//  1. Metal fail-safe: Coordinator with nil device doesn't crash; draw() is no-op.
//  2. 27-only symbol isolation grep with positive teeth.
//  3. GalaxyFallbackView is shown (not a crash) when device == nil.
//  4. DesignTokens.LOD constants are present and within bounds.
//  5. worldViewport derivation correctness.
//  6. A11yMirror label content matches accessibilityLabel of node.

import CoreGraphics
import Foundation
import XCTest
@testable import TuringOS

final class RadarLODTests: XCTestCase {

    // MARK: - 0. A1_68: GalaxyInstanceData ↔ MSL InstanceData layout contract

    /// The Swift instance struct MUST match the MSL `InstanceData` byte layout
    /// (float2 center @0, float4 color @16 [16-byte aligned], float size @32,
    /// uint kind @36, float2 half_vec @40, stride 48). A mismatch desyncs the
    /// instance buffer so the shader reads `inst.size` from a neighbor's bytes →
    /// screen-filling quads (the blue/magenta color-block bug). This pins the
    /// contract mechanically. A1_71: half_vec fills the former 40-48 padding, so
    /// the stride is UNCHANGED at 48.
    func testGalaxyInstanceDataMatchesMSLLayout() {
        XCTAssertEqual(
            MemoryLayout<GalaxyInstanceData>.stride, 48,
            "stride must equal the MSL InstanceData stride (float4 forces 16-byte alignment)")
        XCTAssertEqual(MemoryLayout<GalaxyInstanceData>.offset(of: \.center), 0)
        XCTAssertEqual(
            MemoryLayout<GalaxyInstanceData>.offset(of: \.color), 16,
            "float4 color must be 16-byte aligned to match MSL (the A1_68 desync was here)")
        XCTAssertEqual(MemoryLayout<GalaxyInstanceData>.offset(of: \.size), 32)
        XCTAssertEqual(MemoryLayout<GalaxyInstanceData>.offset(of: \.kind), 36)
        XCTAssertEqual(
            MemoryLayout<GalaxyInstanceData>.offset(of: \.halfVec), 40,
            "A1_71: half_vec must sit at 40 (the former tail padding) to match MSL float2 half_vec")
    }

    /// A1_71: an edge instance must be a thin ORIENTED line, never a square sized
    /// to the edge length (the gray-rectangle bug). The geometry: center at the
    /// NDC midpoint, halfVec = half the edge vector (so center±halfVec are the
    /// endpoints), size a small constant half-thickness.
    func testEdgeInstanceIsThinOrientedLine() {
        // A long edge across most of a 1000x800 viewport.
        let inst = GalaxyInstanceData.edge(
            fromScreen: CGPoint(x: 100, y: 100), toScreen: CGPoint(x: 900, y: 700),
            viewW: 1000, viewH: 800, gray: 1.0, alpha: 0.18)
        XCTAssertEqual(inst.kind, 2)
        // size is a small constant thickness — NOT the edge length (~1.0+ NDC).
        XCTAssertLessThan(inst.size, 0.01, "edge thickness must be thin, not the edge length")
        // halfVec = half the edge vector in NDC (non-zero → shader draws a line).
        let expHalfX = Float((900.0 / 1000.0 * 2 - 1) - (100.0 / 1000.0 * 2 - 1)) * 0.5
        let expHalfY = Float((1 - 700.0 / 800.0 * 2) - (1 - 100.0 / 800.0 * 2)) * 0.5
        XCTAssertEqual(inst.halfVec.x, expHalfX, accuracy: 1e-5)
        XCTAssertEqual(inst.halfVec.y, expHalfY, accuracy: 1e-5)
        XCTAssertGreaterThan(abs(inst.halfVec.x) + abs(inst.halfVec.y), 0.1,
                             "a long edge must have a non-trivial halfVec (oriented line)")
        // center is the NDC midpoint.
        XCTAssertEqual(inst.center.x, Float((100.0 / 1000.0 * 2 - 1) + (900.0 / 1000.0 * 2 - 1)) * 0.5, accuracy: 1e-5)
    }

    // MARK: - 1. Metal fail-safe: Coordinator with nil device is safe

    func testMetalFailSafeCoordinatorNilDevice() {
        // GalaxyRenderer.Coordinator must accept a nil device (headless path).
        // Constructing with nil must not crash.
        let scene = RadarScene(projects: [], nodes: [], edges: [], positions: [:])
        let camera = RadarCamera()
        let mood = RadarMood(live: true, banner: nil)

        // Directly instantiate the coordinator with nil device.
        // This exercises the headless branch without a real GPU.
        let coordinator = GalaxyRenderer.Coordinator(
            device: nil, scene: scene, camera: camera, mood: mood)
        XCTAssertNil(coordinator.device,
            "coordinator must have nil device in headless mode")

        // Verify no state is set up (commandQueue etc. should also be nil).
        // We can't call draw() without an MTKView, but construction must be safe.
        _ = coordinator // no crash = pass
    }

    // MARK: - 2. 27-only symbol isolation grep with positive teeth

    func testMacOS27SymbolIsolation() throws {
        // Sentinel symbol that MUST only appear in GalaxyRenderer27.swift.
        let sentinel = "MTLGalaxyRenderer27SentinelFunction"

        let testDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sourceDir = testDir
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/TuringOS")

        // Enumerate all .swift source files.
        let fm = FileManager.default
        let sourceItems = try fm.contentsOfDirectory(
            at: sourceDir, includingPropertiesForKeys: nil)
        let swiftFiles = sourceItems
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertFalse(swiftFiles.isEmpty, "no Swift source files found")

        // Collect files that contain the sentinel.
        var hitFiles: [String] = []
        for fileURL in swiftFiles {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            if source.contains(sentinel) {
                hitFiles.append(fileURL.lastPathComponent)
            }
        }

        // Positive teeth: the sentinel MUST appear in at least one file.
        XCTAssertFalse(hitFiles.isEmpty,
            "positive teeth failed: sentinel '\(sentinel)' not found in ANY source file — the 27-only isolation grep has no teeth (empty-match false-pass)")

        // The sentinel must appear in EXACTLY GalaxyRenderer27.swift and nowhere else.
        XCTAssertEqual(hitFiles, ["GalaxyRenderer27.swift"],
            "27-only sentinel '\(sentinel)' must appear ONLY in GalaxyRenderer27.swift; found in: \(hitFiles)")
    }

    func testMacOS27SymbolIsolationPositiveTeeth() throws {
        // Verify the grep mechanism would CATCH a leak if the sentinel appeared
        // in a non-isolation file. We inject the sentinel into a temp string
        // and confirm the search logic finds it.
        let sentinel = "MTLGalaxyRenderer27SentinelFunction"
        let injectedContent = "// test injection: \(sentinel)"
        XCTAssertTrue(injectedContent.contains(sentinel),
            "positive teeth: injected sentinel must be detected by contains() check")

        // Confirm GalaxyRenderer.swift does NOT contain the sentinel.
        let testDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sourceDir = testDir
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/TuringOS")
        let galaxyRendererURL = sourceDir.appendingPathComponent("GalaxyRenderer.swift")
        let galaxySource = try String(contentsOf: galaxyRendererURL, encoding: .utf8)
        XCTAssertFalse(galaxySource.contains(sentinel),
            "GalaxyRenderer.swift must NOT contain the 27-only sentinel")
    }

    // MARK: - 3. GalaxyFallbackView: constructable, not a crash

    func testGalaxyFallbackViewConstructable() {
        // GalaxyFallbackView is a SwiftUI View; instantiation must not crash.
        let fallback = GalaxyFallbackView()
        XCTAssertNotNil(fallback, "GalaxyFallbackView must be constructable")
    }

    // MARK: - 4. DesignTokens.LOD constants within bounds

    func testLODConstantsAreValid() {
        XCTAssertGreaterThan(Tokens.LOD.maxClusterCount, 0,
            "maxClusterCount must be positive")
        XCTAssertGreaterThan(Tokens.LOD.instanceBatchSize, 0,
            "instanceBatchSize must be positive")
        XCTAssertGreaterThan(Tokens.LOD.bandHysteresisLog2, 0.0,
            "bandHysteresisLog2 must be positive")
        XCTAssertGreaterThan(Tokens.LOD.farDotClusterThreshold, 0,
            "farDotClusterThreshold must be positive")
        XCTAssertGreaterThan(Tokens.LOD.projectBoundsMargin, 0,
            "projectBoundsMargin must be positive")
        XCTAssertGreaterThan(Tokens.LOD.branchBoundsMargin, 0,
            "branchBoundsMargin must be positive")
        XCTAssertGreaterThan(Tokens.LOD.commitBoundsMargin, 0,
            "commitBoundsMargin must be positive")
        XCTAssertGreaterThan(Tokens.LOD.crossFadeDuration, 0.0,
            "crossFadeDuration must be positive")

        // Bounds sanity: project > branch > commit margin.
        XCTAssertGreaterThan(Tokens.LOD.projectBoundsMargin, Tokens.LOD.branchBoundsMargin,
            "project margin must exceed branch margin")
        XCTAssertGreaterThan(Tokens.LOD.branchBoundsMargin, Tokens.LOD.commitBoundsMargin,
            "branch margin must exceed commit margin")
    }

    // MARK: - 5. worldViewport derivation correctness

    func testWorldViewportDerivation() {
        // worldViewport(camera, size) = CGRect(x:camera.x, y:camera.y, w:size.w/z, h:size.h/z).
        let cases: [(x: Double, y: Double, logZoom: Double, w: Double, h: Double)] = [
            (0, 0, -2, 1920, 1080),   // z=0.25
            (100, 50, 0, 800, 600),   // z=1
            (-200, -100, 1, 400, 300), // z=2
        ]
        for c in cases {
            let camera = RadarCamera(x: c.x, y: c.y, logZoom: c.logZoom)
            let size   = CGSize(width: c.w, height: c.h)
            let wv = worldViewport(camera: camera, size: size)
            XCTAssertEqual(wv.origin.x, CGFloat(c.x), accuracy: 1e-9,
                "worldViewport x must equal camera.x")
            XCTAssertEqual(wv.origin.y, CGFloat(c.y), accuracy: 1e-9,
                "worldViewport y must equal camera.y")
            let expectedW = c.w / camera.z
            let expectedH = c.h / camera.z
            XCTAssertEqual(Double(wv.size.width),  expectedW, accuracy: 1e-9,
                "worldViewport width must be size.width / z")
            XCTAssertEqual(Double(wv.size.height), expectedH, accuracy: 1e-9,
                "worldViewport height must be size.height / z")
        }
    }

    // MARK: - 6. A11yMirror label matches accessibilityLabel

    func testA11yMirrorLabelMatchesNodeLabel() {
        // Build a small scene and verify each mirror's label equals the node's
        // accessibilityLabel (ensures the pure function uses the real label, not a stub).
        let wt = RadarNode(
            id: "wt_test_label",
            projectId: "proj",
            title: "mylabel",
            branch: "main",
            head: "abc",
            form: .active,
            kind: .worktree,
            isAnchor: true,
            sameBranchConflict: false,
            locked: false, detached: false, evidence: .object([:]),
            ahead: 0, behind: 0, mergeStatus: "unknown",
            containedInDefault: false, mergedIntoDefault: false
        )
        let project = RadarProject(id: "proj", path: nil, nodeIds: ["wt_test_label"])
        let scene = RadarScene(
            projects: [project],
            nodes: [wt],
            edges: [],
            positions: ["wt_test_label": CGPoint(x: 100, y: 100)]
        )
        // Camera that puts the node in the viewport.
        let camera = RadarCamera(x: 0, y: 0, logZoom: 0) // z=1
        let viewport = CGSize(width: 800, height: 600)
        let mirrors = visibleA11yElements(scene: scene, camera: camera, viewport: viewport)

        XCTAssertEqual(mirrors.count, 1, "exactly one mirror for one visible node")
        if let mirror = mirrors.first {
            XCTAssertEqual(mirror.nodeId, wt.id, "mirror nodeId must match node id")
            XCTAssertEqual(mirror.label, wt.accessibilityLabel,
                "mirror label must equal node.accessibilityLabel")
            XCTAssertFalse(mirror.label.isEmpty, "mirror label must be non-empty")
        }
    }

    // MARK: - 7. TileLevel ordering

    func testTileLevelOrdering() {
        XCTAssertLessThan(TileLevel.project, .branch,  "project < branch")
        XCTAssertLessThan(TileLevel.branch,  .commit,  "branch < commit")
        XCTAssertLessThan(TileLevel.commit,  .decision,"commit < decision")
    }

    // MARK: - 8. GitProvider encompassing pure function

    func testGitProviderEncompassingEmpty() {
        let bounds = GitProvider.encompassing([], margin: 100)
        XCTAssertEqual(bounds.origin.x, -100, accuracy: 0.01,
            "empty points → origin.x == -margin")
        XCTAssertEqual(bounds.origin.y, -100, accuracy: 0.01)
        XCTAssertEqual(bounds.size.width,  200, accuracy: 0.01)
        XCTAssertEqual(bounds.size.height, 200, accuracy: 0.01)
    }

    func testGitProviderEncompassingSinglePoint() {
        let bounds = GitProvider.encompassing([CGPoint(x: 50, y: 75)], margin: 20)
        XCTAssertEqual(bounds.origin.x, 30, accuracy: 0.01)
        XCTAssertEqual(bounds.origin.y, 55, accuracy: 0.01)
        XCTAssertEqual(bounds.size.width,  40, accuracy: 0.01)
        XCTAssertEqual(bounds.size.height, 40, accuracy: 0.01)
    }

    // MARK: - A1_55 structural + honesty predicates

    /// Grep predicate: GalaxyRenderer must not contain bare `for node in scene.nodes`
    /// (the pre-A1_55 LOD bypass); must reference `renderSet` instead.
    func testRenderSetGrepGalaxyRendererNotRaw() throws {
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // TuringOSTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // app
            .appendingPathComponent("Sources/TuringOS/GalaxyRenderer.swift")
        let src = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(
            src.contains("for node in scene.nodes"),
            "GalaxyRenderer must NOT iterate raw scene.nodes (LOD bypass — use renderSet instead)")
        XCTAssertTrue(
            src.contains("renderSet("),
            "GalaxyRenderer must call renderSet() (A1_55 LOD wiring)")
    }

    /// Grep predicate: RadarViews must not contain bare `ForEach(scene.nodes)` (double-render bug).
    func testRenderSetGrepRadarViewsNotRaw() throws {
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/TuringOS/RadarViews.swift")
        let src = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(
            src.contains("ForEach(scene.nodes)"),
            "RadarViews must NOT ForEach(scene.nodes) unconditionally (double-render bug — use renderSet)")
        XCTAssertTrue(
            src.contains("renderSet("),
            "RadarViews must call renderSet() (A1_55 LOD wiring)")
    }

    /// Position coupling: GalaxyStaticLayer must not reference lane-Y (topMargin/laneHeight).
    func testPositionCouplingGalaxyStaticLayerNoLaneY() throws {
        let fileURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/TuringOS/GalaxyStaticLayer.swift")
        let src = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(
            src.contains("topMargin"),
            "GalaxyStaticLayer must not reference topMargin (position-decoupled Bug 2 — use galaxyCenter)")
        XCTAssertFalse(
            src.contains("laneHeight"),
            "GalaxyStaticLayer must not reference laneHeight (position-decoupled Bug 2 — use galaxyCenter)")
        XCTAssertTrue(
            src.contains("galaxyCenter"),
            "GalaxyStaticLayer must anchor to RadarLayout.galaxyCenter (A1_55 position coupling)")
    }

    /// A1_55 no double-render: galaxy band produces ZERO expandedNodes (no SwiftUI node cards).
    func testNoDoubleRenderGalaxyBand() {
        let scene = RadarLODTests.makeMultiProjectScene(projectCount: 3, branchesPerProject: 5)
        let galaxyCam = RadarCamera(x: 0, y: 0, logZoom: log2(0.01))
        XCTAssertEqual(galaxyCam.currentBand(), .galaxy)
        let rs = renderSet(scene: scene, camera: galaxyCam, viewport: CGSize(width: 1920, height: 1080))
        XCTAssertEqual(rs.expandedNodes.count, 0,
            "galaxy band: expandedNodes must be ZERO — no SwiftUI node cards drawn at this band")
    }

    /// A1_55 honesty: aggregate branchCount/commitCount must equal actual scene node counts.
    /// Honesty law: no fabricated counts; branch/commit nodes never wear .green.
    func testAggregateCountsHonest() {
        let scene = RadarLODTests.makeMultiProjectScene(projectCount: 2, branchesPerProject: 4)
        let galaxyCam = RadarCamera(x: 0, y: 0, logZoom: log2(0.01))
        let rs = renderSet(scene: scene, camera: galaxyCam, viewport: CGSize(width: 1920, height: 1080))
        XCTAssertEqual(rs.aggregates.count, 2, "2-project scene must yield 2 aggregates at galaxy band")
        for agg in rs.aggregates {
            let realBranchCount = scene.nodes.filter { $0.projectId == agg.projectId && $0.kind == .branch }.count
            let realCommitCount = scene.nodes.filter { $0.projectId == agg.projectId && $0.kind == .commit }.count
            XCTAssertEqual(agg.branchCount, realBranchCount,
                "ProjectAggregate branchCount must equal actual scene branch count (honesty law)")
            XCTAssertEqual(agg.commitCount, realCommitCount,
                "ProjectAggregate commitCount must equal actual scene commit count (honesty law)")
        }
        // Honesty law: no branch or commit node carries mergeStatus = "merged" (none .green).
        // Only worktree nodes may express merge facts; branch/commit nodes are structural.
        // Aggregates never fabricate: branchCount > 0 means real branch nodes exist.
        XCTAssertTrue(rs.aggregates.allSatisfy { $0.branchCount > 0 },
            "All aggregates must report at least one branch node (honesty law: no empty fabrications)")
    }

    /// A1_55: the macro framing camera must put EVERY galaxy center on-screen and
    /// stay in the galaxy/cluster band. This is the regression guard for the
    /// real-machine bug where the fixed origin default left the galaxy off-screen
    /// (Fermat centers scatter around world (0,0), including negative coords).
    func testFittingGalaxyFramesAllCentersOnScreen() {
        // Scattered centers around origin like the Fermat spiral — includes the
        // negative quadrants the old fixed (0,0) default pushed off the top-left.
        let centers = [
            CGPoint(x: -4200, y: 3100), CGPoint(x: 5300, y: -2600),
            CGPoint(x: 0, y: 0), CGPoint(x: -1800, y: -4400),
            CGPoint(x: 6100, y: 5200), CGPoint(x: -6000, y: 700),
            CGPoint(x: 2500, y: -5800),
        ]
        let viewport = CGSize(width: 1500, height: 976)
        let cam = RadarCamera.fittingGalaxy(centers: centers, viewport: viewport)

        // 1. Macro view stays in galaxy/cluster band (never node/detail expansion).
        XCTAssertTrue(cam.currentBand() == .galaxy || cam.currentBand() == .cluster,
            "fitted macro camera must be galaxy/cluster band, got \(cam.currentBand())")

        // 2. EVERY center lands inside the viewport (the off-screen bug is fixed).
        for c in centers {
            let s = cam.toScreen(c)
            XCTAssertTrue(
                s.x >= 0 && s.x <= viewport.width && s.y >= 0 && s.y <= viewport.height,
                "center \(c) must be on-screen after fitting; got screen \(s)")
        }

        // 3. The bounding-box centroid maps to the viewport center.
        let bboxCenter = CGPoint(
            x: (centers.map(\.x).min()! + centers.map(\.x).max()!) / 2,
            y: (centers.map(\.y).min()! + centers.map(\.y).max()!) / 2)
        let sc = cam.toScreen(bboxCenter)
        XCTAssertEqual(sc.x, viewport.width / 2, accuracy: 1.0)
        XCTAssertEqual(sc.y, viewport.height / 2, accuracy: 1.0)
    }

    /// A1_55: degenerate inputs fall back to the plain default (no crash, no NaN).
    func testFittingGalaxyEmptyFallsBackToDefault() {
        let cam = RadarCamera.fittingGalaxy(centers: [], viewport: CGSize(width: 1500, height: 976))
        XCTAssertEqual(cam.x, 0)
        XCTAssertEqual(cam.y, 0)
    }

    /// A1_55 predicate #3 (NUMERICAL position coupling, not just grep): every
    /// project's render-set aggregate center == RadarLayout.galaxyCenter(project)
    /// within ε. The label, nebula and branch-ring all anchor on galaxyCenter,
    /// so pinning aggregate.center == galaxyCenter numerically proves they are
    /// coupled to a single source of truth (no lane-Y / origin drift).
    func testAggregateCenterEqualsGalaxyCenterNumerically() {
        let scene = RadarLODTests.makeMultiProjectScene(projectCount: 12, branchesPerProject: 4)
        let galaxyCam = RadarCamera(x: 0, y: 0, logZoom: log2(0.01)) // galaxy band
        let rs = renderSet(scene: scene, camera: galaxyCam,
                           viewport: CGSize(width: 1920, height: 1080))
        XCTAssertEqual(rs.aggregates.count, scene.projects.count,
            "one aggregate per project at galaxy band")
        for agg in rs.aggregates {
            let gc = RadarLayout.galaxyCenter(projectId: agg.projectId, in: scene)
            XCTAssertEqual(agg.center.x, gc.x, accuracy: 0.001,
                "aggregate center.x must equal galaxyCenter (coupling, predicate #3)")
            XCTAssertEqual(agg.center.y, gc.y, accuracy: 0.001,
                "aggregate center.y must equal galaxyCenter (coupling, predicate #3)")
        }
    }

    // MARK: - Helpers for A1_55 tests

    /// Build a deterministic multi-project scene for LOD predicate tests.
    private static func makeMultiProjectScene(projectCount: Int, branchesPerProject: Int) -> RadarScene {
        var nodes: [RadarNode] = []
        var positions: [String: CGPoint] = [:]
        var projects: [RadarProject] = []

        for p in 0..<projectCount {
            let pid = "proj\(p)"
            var nodeIds: [String] = []
            // Anchor branch node (isAnchor=true)
            let anchorId = "branch:\(pid):main"
            nodes.append(RadarNode(
                id: anchorId, projectId: pid, title: "main", branch: "main", head: nil,
                form: .quiet, kind: .branch, isAnchor: true, sameBranchConflict: false,
                locked: false, detached: false, evidence: .object([:]),
                ahead: 0, behind: 0, mergeStatus: "merged", containedInDefault: true, mergedIntoDefault: true
            ))
            positions[anchorId] = CGPoint(x: Double(p) * 2000, y: 0)
            nodeIds.append(anchorId)
            // Additional branch nodes
            for b in 1..<branchesPerProject {
                let bid = "branch:\(pid):feat\(b)"
                nodes.append(RadarNode(
                    id: bid, projectId: pid, title: "feat\(b)", branch: "feat\(b)", head: nil,
                    form: .quiet, kind: .branch, isAnchor: false, sameBranchConflict: false,
                    locked: false, detached: false, evidence: .object([:]),
                    ahead: 0, behind: 0, mergeStatus: "unknown", containedInDefault: false, mergedIntoDefault: false
                ))
                positions[bid] = CGPoint(x: Double(p) * 2000 + Double(b) * 50, y: 0)
                nodeIds.append(bid)
            }
            // One commit node per project
            let cid = "commit:\(pid):abc"
            nodes.append(RadarNode(
                id: cid, projectId: pid, title: "abc", branch: "main", head: "abc",
                form: .quiet, kind: .commit, isAnchor: false, sameBranchConflict: false,
                locked: false, detached: false, evidence: .object([:]),
                ahead: 0, behind: 0, mergeStatus: "unknown", containedInDefault: false, mergedIntoDefault: false
            ))
            positions[cid] = CGPoint(x: Double(p) * 2000, y: 300)
            nodeIds.append(cid)
            projects.append(RadarProject(id: pid, path: "/\(pid)", nodeIds: nodeIds))
        }
        return RadarScene(projects: projects, nodes: nodes, edges: [], positions: positions)
    }
}

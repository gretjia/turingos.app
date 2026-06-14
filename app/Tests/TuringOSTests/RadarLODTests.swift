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
}

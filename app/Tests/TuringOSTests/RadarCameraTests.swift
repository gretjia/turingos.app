// A1_51a: RadarCamera predicate tests — camera spine upgrade to tldraw-style
// {x, y, logZoom} internal model.  All world/transform math is Double/CGFloat.
//
// Predicates covered (from the atom card):
//   1. zoom-to-cursor invariant |Δ|≤1e-9
//   2. roundtrip identity (pageToScreen∘screenToPage == id) + nodeDrag inverse
//   3. log-space + clamp determinism (new range [~0.01, 256])
//   4. floating-origin bounded error |Δ|≤1e-6 at 1e7 (near AND far renderOrigin)
//   5. value-equivalence: default z==0.25, scale/isFar/nodeDrag factor
//   6. Float32 audit (regex zero-hit + positive teeth)
//   7. camera-transform golden (RADAR_GOLDEN_WRITE first-write guard)
//   [migrated] testCameraMouseAnchoredZoom — updated for new clamp [0.01, 256]
//   [migrated] testFocusingCentersWorldPoint — unchanged logic

import CoreGraphics
import Foundation
import XCTest
@testable import TuringOS

final class RadarCameraTests: XCTestCase {

    // MARK: - [migrated] Mouse-anchored zoom (new clamp [~0.01, 256])

    func testCameraMouseAnchoredZoom() {
        // Start with a camera derived from old-style offset: offset=(100,50) at z=0.5
        // In new model: x = -offset.width/z = -100/0.5 = -200, y = -50/0.5 = -100
        var camera = RadarCamera(x: -200, y: -100, logZoom: -1)  // z=0.5
        let anchor = CGPoint(x: 300, y: 200)
        let worldBefore = camera.toWorld(anchor)
        camera.zoom(by: 1.5, anchor: anchor)
        let worldAfter = camera.toWorld(anchor)
        XCTAssertEqual(worldBefore.x, worldAfter.x, accuracy: 0.0001,
                       "world point under cursor must not move")
        XCTAssertEqual(worldBefore.y, worldAfter.y, accuracy: 0.0001)
        XCTAssertEqual(camera.scale, 0.75, accuracy: 0.0001)

        // New clamp at max = 256 (was 2.0 in V6)
        camera.zoom(by: 1_000_000, anchor: anchor)
        XCTAssertEqual(Double(camera.scale), 256.0, accuracy: 0.001,
                       "clamped at detail-max (ADR-016)")
        // New clamp at min = ~0.01 (was 0.1 in V6)
        camera.zoom(by: 0.000001, anchor: anchor)
        XCTAssertEqual(Double(camera.scale), 0.01, accuracy: 1e-6,
                       "clamped at galaxy-macro (ADR-016)")

        // isFar threshold unchanged at 0.6
        var farCam = RadarCamera(x: 0, y: 0, logZoom: log2(0.59))
        XCTAssertTrue(farCam.isFar, "0.59 < 0.6 → isFar")
        var nearCam = RadarCamera(x: 0, y: 0, logZoom: log2(0.6))
        XCTAssertFalse(nearCam.isFar, "0.6 not < 0.6 → not isFar")
        XCTAssertTrue(RadarCamera().isFar, "default z=0.25 < 0.6 → isFar (compressed macro)")
        // suppress "unused variable" warnings
        _ = farCam; _ = nearCam
    }

    // MARK: - [migrated] Focusing centers world point in viewport

    func testFocusingCentersWorldPoint() {
        let world = CGPoint(x: 540, y: 176)
        let camera = RadarCamera.focusing(
            on: world, scale: 1.0, viewport: CGSize(width: 800, height: 600))
        let screen = camera.toScreen(world)
        XCTAssertEqual(screen.x, 400, accuracy: 0.0001)
        XCTAssertEqual(screen.y, 300, accuracy: 0.0001)
    }

    // MARK: - Zoom-to-cursor invariant |Δ|≤1e-9

    func testZoomToCursorInvariant() {
        struct Case {
            let x: Double; let y: Double; let logZoom: Double
            let world: CGPoint; let cursor: CGPoint; let factor: CGFloat
        }
        let cases: [Case] = [
            Case(x: 0, y: 0, logZoom: -2, world: .zero,
                 cursor: CGPoint(x: 300, y: 200), factor: 2.0),
            Case(x: -100, y: -50, logZoom: 0, world: CGPoint(x: 400, y: 300),
                 cursor: CGPoint(x: 150, y: 120), factor: 0.5),
            Case(x: 50, y: 30, logZoom: 3, world: CGPoint(x: 1000, y: 500),
                 cursor: CGPoint(x: 640, y: 480), factor: 3.0),
            Case(x: 0, y: 0, logZoom: -5, world: CGPoint(x: 10000, y: 8000),
                 cursor: CGPoint(x: 512, y: 384), factor: 4.0),
        ]
        for c in cases {
            var cam = RadarCamera(x: c.x, y: c.y, logZoom: c.logZoom)
            let screenBefore = cam.pageToScreen(c.world)
            // The world point that was under cursor before zoom
            let worldUnderCursor = cam.screenToPage(c.cursor)
            cam.zoom(by: c.factor, anchor: c.cursor)
            // After zoom, the same world point must map to the same cursor position
            let screenAfter = cam.pageToScreen(worldUnderCursor)
            XCTAssertEqual(screenAfter.x, Double(c.cursor.x), accuracy: 1e-9,
                           "cursor-anchor x invariant violated (factor=\(c.factor))")
            XCTAssertEqual(screenAfter.y, Double(c.cursor.y), accuracy: 1e-9,
                           "cursor-anchor y invariant violated (factor=\(c.factor))")
            _ = screenBefore
        }
    }

    // MARK: - Roundtrip identity + nodeDrag inverse

    func testPageScreenRoundtrip() {
        let zValues: [Double] = [0.01, 0.25, 1.0, 16.0, 256.0]
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: -50),
                      CGPoint(x: 1234.5, y: 678.9)]
        for z in zValues {
            let cam = RadarCamera(x: 10, y: -5, logZoom: log2(z))
            for p in points {
                // pageToScreen ∘ screenToPage == id
                let screen = cam.pageToScreen(p)
                let roundtrip = cam.screenToPage(screen)
                XCTAssertEqual(roundtrip.x, Double(p.x), accuracy: 1e-9,
                               "pageToScreen∘screenToPage x failed at z=\(z)")
                XCTAssertEqual(roundtrip.y, Double(p.y), accuracy: 1e-9,
                               "pageToScreen∘screenToPage y failed at z=\(z)")
                // screenToPage ∘ pageToScreen == id
                let page2 = cam.screenToPage(p)
                let screen2 = cam.pageToScreen(page2)
                XCTAssertEqual(screen2.x, Double(p.x), accuracy: 1e-9,
                               "screenToPage∘pageToScreen x failed at z=\(z)")
                XCTAssertEqual(screen2.y, Double(p.y), accuracy: 1e-9,
                               "screenToPage∘pageToScreen y failed at z=\(z)")
            }
        }

        // nodeDrag inverse: screenΔ/scale reproduces worldΔ (value-equivalent to today)
        let cam = RadarCamera()  // default z=0.25
        let screenDelta = CGSize(width: 80, height: -40)
        let worldDelta = CGSize(
            width: screenDelta.width / cam.scale,
            height: screenDelta.height / cam.scale)
        // Must equal the tldraw-formula worldDelta = screenDelta / z
        let expected = CGSize(width: Double(screenDelta.width) / cam.z,
                              height: Double(screenDelta.height) / cam.z)
        XCTAssertEqual(Double(worldDelta.width), expected.width, accuracy: 1e-9,
                       "nodeDrag inverse: scale-path != z-path")
        XCTAssertEqual(Double(worldDelta.height), expected.height, accuracy: 1e-9,
                       "nodeDrag inverse: scale-path != z-path (height)")
    }

    // MARK: - Log-space + clamp determinism

    func testLogSpaceClampDeterminism() {
        // z = pow(2, logZoom) exactly
        let lz = -3.5
        let cam = RadarCamera(x: 0, y: 0, logZoom: lz)
        XCTAssertEqual(cam.z, pow(2, lz), accuracy: 1e-15, "z = pow(2, logZoom)")
        XCTAssertEqual(Double(cam.scale), pow(2, lz), accuracy: 1e-15, "scale = z")

        // Clamp: zoom past max saturates to 256
        var maxCam = RadarCamera(x: 0, y: 0, logZoom: 0)
        maxCam.zoom(by: 1_000_000, anchor: .zero)
        XCTAssertEqual(maxCam.z, 256.0, accuracy: 0.001, "clamped at 256")
        XCTAssertFalse(maxCam.z.isNaN, "no NaN on overflow")

        // Clamp: zoom past min saturates to ~0.01
        var minCam = RadarCamera(x: 0, y: 0, logZoom: 0)
        minCam.zoom(by: 0.000001, anchor: .zero)
        XCTAssertEqual(minCam.z, 0.01, accuracy: 1e-6, "clamped at ~0.01")
        XCTAssertFalse(minCam.z.isNaN, "no NaN on underflow")

        // logerp: pure function determinism
        for _ in 0..<5 {
            let v1 = RadarCamera.logerp(0.25, 16.0, t: 0.5)
            let v2 = RadarCamera.logerp(0.25, 16.0, t: 0.5)
            XCTAssertEqual(v1, v2, "logerp must be deterministic")
        }
        // logerp(a, a, t) == a for any t
        let mid = RadarCamera.logerp(4.0, 4.0, t: 0.7)
        XCTAssertEqual(mid, 4.0, accuracy: 1e-12, "logerp at same point")

        // Fail-safe: NaN logZoom saturates to logMin on init
        let nanCam = RadarCamera(x: 0, y: 0, logZoom: .nan)
        XCTAssertFalse(nanCam.z.isNaN, "NaN logZoom must clamp to safe value")
    }

    // MARK: - Floating-origin bounded error at large world coords

    func testFloatingOriginBoundedError() {
        // Large world coords: both near and far renderOrigin must satisfy |Δ|≤1e-6.
        // Pure Double at 1e7 ≪ 9e15 (integer-exact ceiling) gives ~0 round-trip
        // error; the predicate is |Δ|≤1e-6, NOT near<far (see atom card note).
        let worldPoints = [
            CGPoint(x: 1e7, y: 5e6),
            CGPoint(x: 1e7 + 100, y: 5e6 + 50),
            CGPoint(x: -8.3e6, y: 3.1e7),
        ]
        let renderOrigins: [(label: String, origin: CGPoint)] = [
            ("origin=0,0", .zero),
            ("renderOrigin near world", CGPoint(x: 1e7, y: 5e6)),
        ]
        let cam = RadarCamera(x: 0, y: 0, logZoom: -1)  // z=0.5

        for ro in renderOrigins {
            for p in worldPoints {
                let screen = cam.pageToScreen(p, renderOrigin: ro.origin)
                let back = cam.screenToPage(screen, renderOrigin: ro.origin)
                XCTAssertEqual(back.x, Double(p.x), accuracy: 1e-6,
                               "floating-origin x round-trip |Δ|>1e-6 (\(ro.label))")
                XCTAssertEqual(back.y, Double(p.y), accuracy: 1e-6,
                               "floating-origin y round-trip |Δ|>1e-6 (\(ro.label))")
            }
        }
    }

    // MARK: - Value-equivalence (RadarViews read surface unchanged)

    func testValueEquivalence() {
        // Default camera: z == 0.25 exactly
        let def = RadarCamera()
        XCTAssertEqual(def.z, 0.25, accuracy: 1e-9, "default z must be 0.25")
        XCTAssertEqual(Double(def.scale), 0.25, accuracy: 1e-9, "default scale == 0.25")
        XCTAssertTrue(def.isFar, "default camera is in far mode (z=0.25 < 0.6)")

        // Across sampled logZoom values:
        //   scale == pow(2, logZoom)
        //   isFar == (z < 0.6)
        //   nodeDrag inverse factor == 1/scale
        let samples: [Double] = [-6.0, -4.0, -2.0, 0.0, 1.0, 3.0, 6.0, 8.0]
        for lz in samples {
            let cam = RadarCamera(x: 5, y: -3, logZoom: lz)
            let expectedZ = pow(2, cam.logZoom)  // use the clamped logZoom
            XCTAssertEqual(Double(cam.scale), expectedZ, accuracy: 1e-12,
                           "scale != pow(2,logZoom) at logZoom=\(lz)")
            let expectedFar = expectedZ < Tokens.Motion.semanticFarThreshold
            XCTAssertEqual(cam.isFar, expectedFar,
                           "isFar mismatch at logZoom=\(lz)")
            // nodeDrag inverse factor: screenΔ/scale == screenΔ * (1/z)
            let factor = 1.0 / Double(cam.scale)
            let factorZ = 1.0 / expectedZ
            XCTAssertEqual(factor, factorZ, accuracy: 1e-12,
                           "nodeDrag inverse factor mismatch at logZoom=\(lz)")
        }

        // offset invariant: offset = CGSize(-x*z, -y*z)
        let cam2 = RadarCamera(x: 12.5, y: -7.3, logZoom: 2.0)
        let expectedOffset = CGSize(width: -12.5 * cam2.z, height: 7.3 * cam2.z)
        XCTAssertEqual(Double(cam2.offset.width), expectedOffset.width, accuracy: 1e-9)
        XCTAssertEqual(Double(cam2.offset.height), expectedOffset.height, accuracy: 1e-9)
    }

    // MARK: - Float32 audit (regex zero-hit + positive teeth)

    func testFloat32Audit() throws {
        // Navigate from test file to source files.
        let testDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sourceDir = testDir
            .deletingLastPathComponent()  // TuringOSTests
            .deletingLastPathComponent()  // Tests
            .appendingPathComponent("Sources/TuringOS")

        let radarModel = try String(
            contentsOf: sourceDir.appendingPathComponent("RadarModel.swift"),
            encoding: .utf8)
        let radarViews = try String(
            contentsOf: sourceDir.appendingPathComponent("RadarViews.swift"),
            encoding: .utf8)

        // Audit regex (BSD/GNU portable, no \b): hits Float/Float32 standalone;
        // does NOT hit CGFloat (the 'G' is a word char, breaking the left boundary).
        let pattern = "(^|[^A-Za-z0-9_])Float(32)?([^A-Za-z0-9_]|$)"
        let regex = try NSRegularExpression(pattern: pattern, options: .anchorsMatchLines)

        let modelHits = regex.numberOfMatches(
            in: radarModel, range: NSRange(radarModel.startIndex..., in: radarModel))
        XCTAssertEqual(modelHits, 0,
                       "Float/Float32 found in RadarModel.swift (fp32 audit fail)")

        let viewsHits = regex.numberOfMatches(
            in: radarViews, range: NSRange(radarViews.startIndex..., in: radarViews))
        XCTAssertEqual(viewsHits, 0,
                       "Float/Float32 found in RadarViews.swift (fp32 audit fail)")

        // Positive teeth: injected string MUST match (proves regex is not empty).
        let injected = "let z: Float = 0"
        let teethHits = regex.numberOfMatches(
            in: injected, range: NSRange(injected.startIndex..., in: injected))
        XCTAssertGreaterThan(teethHits, 0,
                             "fp32 audit regex failed positive teeth — regex is broken")

        // Negative teeth: CGFloat must NOT match.
        let safe = "let x: CGFloat = 0.5"
        let safeHits = regex.numberOfMatches(
            in: safe, range: NSRange(safe.startIndex..., in: safe))
        XCTAssertEqual(safeHits, 0,
                       "CGFloat matched fp32 audit regex — regex is too broad")
    }

    // MARK: - Camera-transform golden (RADAR_GOLDEN_WRITE first-write guard)

    private func fmt(_ v: Double) -> String { String(format: "%.9f", v) }

    private func goldenLine(
        _ cam: RadarCamera, world: CGPoint, renderOrigin: CGPoint
    ) -> String {
        let s = cam.toScreen(world)
        let p = cam.pageToScreen(world, renderOrigin: renderOrigin)
        let parts = [
            fmt(cam.x), fmt(cam.y), fmt(cam.logZoom),
            fmt(Double(world.x)), fmt(Double(world.y)),
            fmt(Double(renderOrigin.x)), fmt(Double(renderOrigin.y)),
            "->",
            fmt(Double(s.x)), fmt(Double(s.y)),
            fmt(Double(p.x)), fmt(Double(p.y)),
            fmt(Double(cam.scale)),
            cam.isFar ? "true" : "false",
        ]
        return parts.joined(separator: " ")
    }

    func testCameraTransformGolden() throws {
        // Canonical (cam, world, renderOrigin) inputs — all exact powers of 2 for z
        // so Double produces exact values and the golden is bit-stable.
        struct Row {
            let cam: RadarCamera
            let world: CGPoint
            let renderOrigin: CGPoint
        }
        let rows: [Row] = [
            // Default camera, origin world point
            Row(cam: RadarCamera(x: 0, y: 0, logZoom: -2),
                world: .zero, renderOrigin: .zero),
            // Default camera, far world point
            Row(cam: RadarCamera(x: 0, y: 0, logZoom: -2),
                world: CGPoint(x: 100, y: 100), renderOrigin: .zero),
            // z=1, default position
            Row(cam: RadarCamera(x: 0, y: 0, logZoom: 0),
                world: CGPoint(x: 500, y: 300), renderOrigin: .zero),
            // z=16, default position
            Row(cam: RadarCamera(x: 0, y: 0, logZoom: 4),
                world: CGPoint(x: 100, y: 50), renderOrigin: .zero),
            // z≈0.0078 (logZoom=-7), large world coords
            Row(cam: RadarCamera(x: 0, y: 0, logZoom: -7),
                world: CGPoint(x: 10000, y: 5000), renderOrigin: .zero),
            // z=1, non-zero camera position
            Row(cam: RadarCamera(x: 100, y: 50, logZoom: 0),
                world: CGPoint(x: 500, y: 300), renderOrigin: .zero),
            // z=1, floating-origin at 1e7 (proves renderOrigin pipeline)
            Row(cam: RadarCamera(x: 0, y: 0, logZoom: 0),
                world: CGPoint(x: 10_000_100, y: 5_000_050),
                renderOrigin: CGPoint(x: 10_000_000, y: 5_000_000)),
        ]

        var lines: [String] = [
            "# p1_camera_transform.golden.txt — camera transform fixture (A1_51a)",
            "# cam_x cam_y logZoom world_x world_y ro_x ro_y -> toScreen_x toScreen_y pageToScreen_x pageToScreen_y scale isFar",
        ]
        for r in rows {
            lines.append(goldenLine(r.cam, world: r.world, renderOrigin: r.renderOrigin))
        }
        let dump = lines.joined(separator: "\n") + "\n"

        let golden = EventsContractTests.fixturesDir
            .deletingLastPathComponent()
            .appendingPathComponent("snapshots/p1_camera_transform.golden.txt")

        if ProcessInfo.processInfo.environment["RADAR_GOLDEN_WRITE"] == "1" {
            try dump.write(to: golden, atomically: true, encoding: .utf8)
            XCTFail("golden regenerated at \(golden.path) — rerun WITHOUT the flag")
            return
        }
        let committed = try String(contentsOf: golden, encoding: .utf8)
        XCTAssertEqual(dump, committed, "camera transform golden drifted from committed")
    }
}

// A1_09: scene derivation is a deterministic projection - forms/edges are
// fact-backed (no merge fact ⇒ no green), the layout is pure arithmetic,
// the camera math is mouse-anchored, and the whole scene golden-pins its
// bytes against the committed fixture stream.

import Foundation
import XCTest
@testable import TuringOS

final class RadarModelTests: XCTestCase {
    private func envelope(_ seq: UInt64, _ kind: String, _ payload: String) -> EventEnvelope {
        let json = """
        {"event_id":"evt_r_\(seq)","seq":\(seq),"ts":"2026-06-11T00:00:00Z",\
        "schema_version":"tos.app.event.v0","kind":"\(kind)","source":"daemon",\
        "trust_state":"observed_unsigned","payload":\(payload)}
        """
        return try! JSONDecoder().decode(EventEnvelope.self, from: Data(json.utf8))
    }

    /// A mixed ledger: anchored project p (anchor/failed/conflict×2/orphan/
    /// active) + pathless project q (one clean worktree, no anchor).
    private func mixedLedger() -> WorktreeLedger {
        var ledger = WorktreeLedger()
        ledger.apply(envelope(0, "ProjectRegistered",
            #"{"project_id":"p","local":true,"path":"/repos/p"}"#))
        ledger.apply(envelope(1, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_root_11111111","path":"/repos/p","branch":"main","dirty":false}"#))
        ledger.apply(envelope(2, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_bad_22222222","fingerprint_error":"boom","dirty":false}"#))
        ledger.apply(envelope(3, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_c1_33333333","branch":"feat","same_branch_conflict":true,"dirty":false}"#))
        ledger.apply(envelope(4, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_c2_44444444","branch":"feat","same_branch_conflict":true,"dirty":true}"#))
        ledger.apply(envelope(5, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_old_55555555","prunable":true,"dirty":true}"#))
        ledger.apply(envelope(6, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_w_66666666","branch":"work","dirty":true}"#))
        ledger.apply(envelope(7, "ProjectRegistered", #"{"project_id":"q","local":true}"#))
        ledger.apply(envelope(8, "WorktreeDiscovered",
            #"{"project_id":"q","worktree_id":"wt_q_77777777","branch":"main","dirty":false}"#))
        return ledger
    }

    // MARK: forms bound to facts

    func testFormClassificationAndAnchor() {
        let scene = RadarScene.derive(ledger: mixedLedger())
        let byId = Dictionary(uniqueKeysWithValues: scene.nodes.map { ($0.id, $0) })

        XCTAssertEqual(byId["wt_root_11111111"]?.form, .quiet)
        XCTAssertEqual(byId["wt_root_11111111"]?.isAnchor, true,
                       "path == registered project path IS the anchor witness")
        XCTAssertEqual(byId["wt_bad_22222222"]?.form, .failed)
        XCTAssertEqual(byId["wt_c1_33333333"]?.form, .conflict)
        XCTAssertEqual(byId["wt_c2_44444444"]?.form, .conflict,
                       "conflict outranks dirty")
        XCTAssertEqual(byId["wt_old_55555555"]?.form, .orphan,
                       "prunable outranks dirty - a dirty orphan is still an orphan")
        XCTAssertEqual(byId["wt_w_66666666"]?.form, .active)
        XCTAssertEqual(byId["wt_q_77777777"]?.isAnchor, false,
                       "no registered path ⇒ no anchor claim (honest absence)")
    }

    func testGreenIsReservedUntilMergeFactExists() {
        // Card ruling: the P1 read-only stream carries NO merge/verified
        // fact, so NO node form may wear green - V6's merged-green returns
        // only when the fact does.
        for form in RadarNode.Form.allCases {
            XCTAssertNotEqual(form.semantic, .green,
                              "form \(form) wears green without a verified fact")
        }
    }

    // MARK: edges only from real couplings

    func testEdgesAreFactBacked() {
        let scene = RadarScene.derive(ledger: mixedLedger())
        let byId = Dictionary(uniqueKeysWithValues: scene.nodes.map { ($0.id, $0) })

        for edge in scene.edges {
            XCTAssertEqual(
                byId[edge.from]?.projectId, byId[edge.to]?.projectId,
                "cross-project edge is a fabricated fact: \(edge)")
        }
        // Membership edges all point AT the anchor; project q (anchorless)
        // contributes none.
        let membership = scene.edges.filter { $0.kind == .membership }
        XCTAssertEqual(membership.count, 5, "5 non-anchor members in p")
        XCTAssertTrue(membership.allSatisfy { $0.to == "wt_root_11111111" })
        // Exactly one tension edge: the same-branch pair.
        let tension = scene.edges.filter { $0.kind == .conflictTension }
        XCTAssertEqual(tension.count, 1)
        XCTAssertEqual(tension[0].from, "wt_c1_33333333")
        XCTAssertEqual(tension[0].to, "wt_c2_44444444")
    }

    // MARK: determinism + golden bytes

    func testSceneGoldenOverP1Fixture() throws {
        let url = EventsContractTests.fixturesDir
            .appendingPathComponent("p1_worktree_radar.jsonl")
        let body = try String(contentsOf: url, encoding: .utf8)
        let events = try body.split(separator: "\n").filter { !$0.isEmpty }
            .map { try JSONDecoder().decode(EventEnvelope.self, from: Data($0.utf8)) }
        let dump1 = RadarScene.derive(ledger: .fold(events)).canonicalDump()
        let dump2 = RadarScene.derive(ledger: .fold(events)).canonicalDump()
        XCTAssertEqual(dump1, dump2, "same ledger must give the same bytes")

        let golden = EventsContractTests.fixturesDir
            .deletingLastPathComponent()
            .appendingPathComponent("snapshots/p1_radar_scene.golden.txt")
        if ProcessInfo.processInfo.environment["RADAR_GOLDEN_WRITE"] == "1" {
            try dump1.write(to: golden, atomically: true, encoding: .utf8)
            XCTFail("golden regenerated at \(golden.path) - rerun WITHOUT the flag")
            return
        }
        let committed = try String(contentsOf: golden, encoding: .utf8)
        XCTAssertEqual(dump1, committed, "scene drifted from the committed golden")
    }

    // MARK: camera math (V6 §7.1)

    func testCameraMouseAnchoredZoom() {
        var camera = RadarCamera(scale: 0.5, offset: CGSize(width: 100, height: 50))
        let anchor = CGPoint(x: 300, y: 200)
        let worldBefore = camera.toWorld(anchor)
        camera.zoom(by: 1.5, anchor: anchor)
        let worldAfter = camera.toWorld(anchor)
        XCTAssertEqual(worldBefore.x, worldAfter.x, accuracy: 0.0001,
                       "the world point under the cursor must not move")
        XCTAssertEqual(worldBefore.y, worldAfter.y, accuracy: 0.0001)
        XCTAssertEqual(camera.scale, 0.75, accuracy: 0.0001)

        camera.zoom(by: 1000, anchor: anchor)
        XCTAssertEqual(camera.scale, 2.0, "clamped at code-micro")
        camera.zoom(by: 0.00001, anchor: anchor)
        XCTAssertEqual(camera.scale, 0.1, accuracy: 0.0001, "clamped at galaxy-macro")

        XCTAssertTrue(RadarCamera(scale: 0.59).isFar)
        XCTAssertFalse(RadarCamera(scale: 0.6).isFar)
        XCTAssertTrue(RadarCamera().isFar, "default view = compressed macro")
    }

    func testFocusingCentersWorldPoint() {
        let world = CGPoint(x: 540, y: 176)
        let camera = RadarCamera.focusing(
            on: world, scale: 1.0, viewport: CGSize(width: 800, height: 600))
        let screen = camera.toScreen(world)
        XCTAssertEqual(screen.x, 400, accuracy: 0.0001)
        XCTAssertEqual(screen.y, 300, accuracy: 0.0001)
    }

    // MARK: fly-to resolution (structured target, no id parsing)

    func testFlyToResolvesFirstLivingTarget() {
        let scene = RadarScene.derive(ledger: mixedLedger())
        let target = AttentionTarget(
            projectId: "p", worktreeIds: ["wt_gone_00000000", "wt_c2_44444444"])
        XCTAssertEqual(scene.resolve(target), "wt_c2_44444444")
        let stale = AttentionTarget(projectId: "p", worktreeIds: ["wt_gone_00000000"])
        XCTAssertNil(scene.resolve(stale), "stale target resolves to nothing - no fake focus")
    }

    func testTriageItemsCarryStructuredTargets() {
        let triage = AttentionTriage.derive(ledger: mixedLedger(), connection: .connected)
        for item in triage.needsYou {
            let target = try? XCTUnwrap(item.target, "every fact-backed item carries a target")
            XCTAssertFalse(target?.worktreeIds.isEmpty ?? true)
        }
        let conflict = triage.needsYou.first { $0.id.hasPrefix("conflict:") }
        XCTAssertEqual(conflict?.target?.worktreeIds,
                       ["wt_c1_33333333", "wt_c2_44444444"])
    }

    // MARK: accessibility 0/1 predicate (rule 3: never color alone)

    func testEveryNodeSpeaksItsStateInText() {
        let scene = RadarScene.derive(ledger: mixedLedger())
        XCTAssertFalse(scene.nodes.isEmpty)
        for node in scene.nodes {
            let label = node.accessibilityLabel
            XCTAssertFalse(label.isEmpty)
            XCTAssertTrue(label.contains(node.title), "label must name the node: \(label)")
            XCTAssertTrue(label.contains(node.form.label), "label must speak the form: \(label)")
            XCTAssertTrue(label.contains("「\(node.projectId)」"), "label must name the project: \(label)")
            XCTAssertFalse(node.form.iconName.isEmpty, "icon leg of the dual channel missing")
        }
    }

    // MARK: anti-pattern guard (law 1, structural)

    func testDefaultNodeIsTitleAndGlowOnly() {
        let scene = RadarScene.derive(ledger: mixedLedger())
        for node in scene.nodes {
            let unselected = NodeCardContent.derive(node: node, selected: false, far: false)
            XCTAssertTrue(unselected.showsTitle)
            XCTAssertTrue(unselected.detailRows.isEmpty,
                          "default node renders data rows - dashboard-speak on \(node.id)")
            XCTAssertFalse(unselected.showsEvidenceAction)

            let far = NodeCardContent.derive(node: node, selected: true, far: true)
            XCTAssertFalse(far.showsTitle, "far mode hides node text (V6 §7.2)")
            XCTAssertTrue(far.detailRows.isEmpty)

            let selected = NodeCardContent.derive(node: node, selected: true, far: false)
            XCTAssertFalse(selected.detailRows.isEmpty, "selection opens the detail")
            XCTAssertTrue(selected.showsEvidenceAction)
        }
    }

    // MARK: mood - the radar's honesty about a dead stream

    func testMoodSuppressesActivityOverDeadStream() {
        let dead = RadarMood.derive(connection: .disconnected(reason: "socket gone"))
        XCTAssertFalse(dead.live, "no breathing/sweep over stale facts")
        XCTAssertEqual(dead.banner, "daemon 断连——socket gone")
        XCTAssertTrue(Sentences.matchesTemplate(dead.banner ?? ""),
                      "the banner is a whitelisted sentence")

        let connecting = RadarMood.derive(connection: .connecting)
        XCTAssertFalse(connecting.live)
        XCTAssertEqual(connecting.banner, "正在对账…")

        let live = RadarMood.derive(connection: .connected)
        XCTAssertTrue(live.live)
        XCTAssertNil(live.banner, "silence is success - no banner when live")
    }

    // MARK: tension edge survives form precedence (S-stage regression)

    func testConflictTensionSurvivesFingerprintFailure() {
        var ledger = WorktreeLedger()
        ledger.apply(envelope(0, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_a_11111111","branch":"main","same_branch_conflict":true,"fingerprint_error":"boom","dirty":false}"#))
        ledger.apply(envelope(1, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_b_22222222","branch":"main","same_branch_conflict":true,"dirty":false}"#))
        let scene = RadarScene.derive(ledger: ledger)
        XCTAssertEqual(
            scene.nodes.first { $0.id == "wt_a_11111111" }?.form, .failed,
            "form precedence stays: failure chrome wins")
        let tension = scene.edges.filter { $0.kind == .conflictTension }
        XCTAssertEqual(tension.count, 1,
                       "the same-branch FACT keeps its edge even when a member wears .failed")
        XCTAssertEqual(tension.first?.from, "wt_a_11111111")
        XCTAssertEqual(tension.first?.to, "wt_b_22222222")
    }

    // MARK: anchor witness tolerates lexical path noise

    func testAnchorWitnessNormalizesPathsLexically() {
        var ledger = WorktreeLedger()
        ledger.apply(envelope(0, "ProjectRegistered",
            #"{"project_id":"p","local":true,"path":"/repos/p/"}"#))
        ledger.apply(envelope(1, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_root_11111111","path":"/repos/./p","branch":"main","dirty":false}"#))
        let scene = RadarScene.derive(ledger: ledger)
        XCTAssertEqual(scene.nodes.first?.isAnchor, true,
                       "trailing slash / '.' must not kill the anchor witness")
    }

    // MARK: a11y reaches the drill-down (law 2 on the radar surface)

    func testSelectedCardContentSpeaksDetailToAssistiveTech() {
        let scene = RadarScene.derive(ledger: mixedLedger())
        for node in scene.nodes {
            let unselected = NodeCardContent.derive(node: node, selected: false, far: false)
            XCTAssertNil(unselected.accessibilityValue,
                         "default node carries no detail - nothing to mirror")
            let selected = NodeCardContent.derive(node: node, selected: true, far: false)
            let value = selected.accessibilityValue
            XCTAssertNotNil(value)
            XCTAssertTrue(value?.contains(node.form.label) ?? false,
                          "the state row must reach assistive tech: \(value ?? "nil")")
            XCTAssertTrue(selected.showsEvidenceAction,
                          "evidence action exists exactly when the drawer is offered")
        }
    }

    // MARK: golden #2 - a discriminative synthetic scene (the committed
    // p1 fixture has no path/conflict/orphan facts, so golden #1 cannot
    // pin anchors or edges; this one byte-pins all five forms + both edge
    // kinds without touching fixtures/event_streams - S-stage risk fix)

    func testMixedSceneGolden() throws {
        let dump = RadarScene.derive(ledger: mixedLedger()).canonicalDump()
        let golden = EventsContractTests.fixturesDir
            .deletingLastPathComponent()
            .appendingPathComponent("snapshots/a1_09_mixed_scene.golden.txt")
        if ProcessInfo.processInfo.environment["RADAR_GOLDEN_WRITE"] == "1" {
            try dump.write(to: golden, atomically: true, encoding: .utf8)
            XCTFail("golden regenerated at \(golden.path) - rerun WITHOUT the flag")
            return
        }
        let committed = try String(contentsOf: golden, encoding: .utf8)
        XCTAssertEqual(dump, committed, "mixed scene drifted from the committed golden")
    }
}

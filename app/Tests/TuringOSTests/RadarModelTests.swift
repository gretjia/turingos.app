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

        // A1_51b adversarial fixture: a BranchFact with containedInDefault=true
        // AND mergedIntoDefault=true must (a) carry those flags through the fold
        // into the branch node (non-vacuous), and (b) its chrome is neutral/nil
        // (merged-green is NEVER rendered - honesty rule, card ruling 2026-06-14).
        var ledger = WorktreeLedger()
        let mergedBranchJson = """
        {"event_id":"evt_green_adv","seq":1,"ts":"2026-06-15T00:00:00Z",\
        "schema_version":"tos.app.event.v0","kind":"BranchObserved","source":"github",\
        "trust_state":"observed_unsigned","payload":{"project_id":"adv_proj",\
        "branch_ref":"refs/heads/feat/merged-and-contained","head_sha":"cafebabe",\
        "is_default":false,"merged_into_default":true,"provenance":"github_api",\
        "ahead":0,"behind":3,"merge_status":"behind","merge_base":"deadbeef",\
        "contained_in_default":true}}
        """
        let advEnv = try! JSONDecoder().decode(EventEnvelope.self, from: Data(mergedBranchJson.utf8))
        ledger.apply(advEnv)

        // (a) Flag carries through the fold into the BranchFact.
        let branchKey = "adv_proj\u{0}refs/heads/feat/merged-and-contained"
        let bf = ledger.branches[branchKey]
        XCTAssertNotNil(bf, "BranchFact must be in ledger after fold")
        XCTAssertTrue(bf?.containedInDefault == true,
                      "containedInDefault flag must survive the fold (non-vacuous)")
        XCTAssertTrue(bf?.mergedIntoDefault == true,
                      "mergedIntoDefault flag must survive the fold (non-vacuous)")

        // (b) Derive the scene and find the branch node.
        let scene = RadarScene.derive(ledger: ledger)
        let branchNode = scene.nodes.first {
            $0.kind == .branch && $0.projectId == "adv_proj"
        }
        XCTAssertNotNil(branchNode, "branch node must be derived from the merged BranchFact")
        // The node carries the flags (non-vacuous: fold brought them through).
        XCTAssertTrue(branchNode?.containedInDefault == true,
                      "branch node must carry containedInDefault=true flag")
        XCTAssertTrue(branchNode?.mergedIntoDefault == true,
                      "branch node must carry mergedIntoDefault=true flag")
        // Chrome is neutral: kind=branch uses neutral path, never .green.
        XCTAssertNil(branchNode?.form.semantic,
                     "branch node form must be neutral (.quiet), never a semantic claim")
        XCTAssertNotEqual(branchNode?.form.semantic, .green,
                          "merged+contained branch node must NOT render .green (honesty rule)")

        // Same for all branch/commit nodes in any scene: none ever has .green.
        for node in scene.nodes where node.kind == .branch || node.kind == .commit {
            XCTAssertNotEqual(node.form.semantic, .green,
                              "node \(node.id) kind=\(node.kind) carries .green illegally")
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

    // MARK: A1_51b — BranchObserved fold → per-branch NODE derivation (not counts)

    func testBranchObservedFoldsToCounts() throws {
        // A1_51b: renamed but kept as testBranchObservedFoldsToCounts for
        // backward naming compatibility; now asserts per-branch NODE derivation.
        func branchEvent(_ seq: UInt64, _ pid: String, _ ref: String,
                         isDefault: Bool = false, ahead: Int = 0, behind: Int = 0) throws -> EventEnvelope {
            let json = """
            {"event_id":"evt_b\(seq)","seq":\(seq),"ts":"2026-06-14T00:00:00Z",\
            "schema_version":"tos.app.event.v0","kind":"BranchObserved","source":"github",\
            "trust_state":"observed_unsigned","payload":{"project_id":"\(pid)",\
            "branch_ref":"\(ref)","head_sha":"deadbeef","is_default":\(isDefault),\
            "merge_status":"unknown","merged_into_default":false,"provenance":"github_api",\
            "ahead":\(ahead),"behind":\(behind)}}
            """
            return try JSONDecoder().decode(EventEnvelope.self, from: Data(json.utf8))
        }
        var ledger = WorktreeLedger()
        ledger.apply(try branchEvent(1, "proj_a", "refs/heads/main", isDefault: true))
        ledger.apply(try branchEvent(2, "proj_a", "refs/heads/feature/x", ahead: 3))
        ledger.apply(try branchEvent(3, "proj_b", "refs/heads/main", isDefault: true))
        XCTAssertEqual(ledger.branches.count, 3)

        let scene = RadarScene.derive(ledger: ledger)
        // Each BranchFact must produce exactly ONE branch node.
        let aNodes = scene.nodes.filter { $0.projectId == "proj_a" && $0.kind == .branch }
        let bNodes = scene.nodes.filter { $0.projectId == "proj_b" && $0.kind == .branch }
        XCTAssertEqual(aNodes.count, 2, "proj_a: 2 BranchFacts → 2 branch nodes")
        XCTAssertEqual(bNodes.count, 1, "proj_b: 1 BranchFact → 1 branch node")
        XCTAssertTrue(scene.nodes.filter { $0.projectId == "proj_none" && $0.kind == .branch }.isEmpty,
                      "proj_none: no BranchFacts → no branch nodes")

        // Default branch node is the anchor.
        let mainA = aNodes.first { $0.branch == "refs/heads/main" }
        XCTAssertTrue(mainA?.isAnchor == true, "default branch node must be isAnchor=true")
        let featA = aNodes.first { $0.branch == "refs/heads/feature/x" }
        XCTAssertEqual(featA?.ahead, 3, "ahead field must survive the fold into the branch node")

        // Re-observing the same ref is idempotent (latest-wins, not double count).
        ledger.apply(try branchEvent(4, "proj_a", "refs/heads/feature/x", ahead: 5))
        let scene2 = RadarScene.derive(ledger: ledger)
        let aNodes2 = scene2.nodes.filter { $0.projectId == "proj_a" && $0.kind == .branch }
        XCTAssertEqual(aNodes2.count, 2, "idempotent re-observe must not add duplicate node")
        XCTAssertEqual(aNodes2.first { $0.branch == "refs/heads/feature/x" }?.ahead, 5,
                       "latest-wins: ahead updates to 5 on re-observe")

        // BranchRemoved removes the branch node.
        let remove = """
        {"event_id":"evt_r","seq":5,"ts":"2026-06-14T00:00:00Z","schema_version":"tos.app.event.v0",\
        "kind":"BranchRemoved","source":"github","trust_state":"observed_unsigned",\
        "payload":{"project_id":"proj_a","branch_ref":"refs/heads/feature/x"}}
        """
        ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(remove.utf8)))
        let scene3 = RadarScene.derive(ledger: ledger)
        let aNodes3 = scene3.nodes.filter { $0.projectId == "proj_a" && $0.kind == .branch }
        XCTAssertEqual(aNodes3.count, 1, "BranchRemoved must remove the branch node")
    }

    // MARK: camera math migrated to RadarCameraTests (A1_51a)
    // testCameraMouseAnchoredZoom and testFocusingCentersWorldPoint moved to
    // RadarCameraTests.swift with updated clamp bounds [0.01, 256].

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
            // A1_57: selection opens the detail — a kind-aware headline and/or rows.
            XCTAssertTrue(selected.headline != nil || !selected.detailRows.isEmpty,
                          "selection opens the detail (headline or rows) on \(node.id)")
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
            XCTAssertNotNil(value, "selected node must mirror its detail to assistive tech")
            XCTAssertTrue(selected.showsEvidenceAction,
                          "evidence action exists exactly when the drawer is offered")
            // A1_57: content is now KIND-SPECIFIC and meaningful — not the old
            // generic "状态: 安静" for every kind (#5). The mirror speaks per kind.
            switch node.kind {
            case .worktree:
                XCTAssertTrue(value?.contains(node.form.label) ?? false,
                              "worktree card must speak its (meaningful) form: \(value ?? "nil")")
            case .branch:
                let v = value ?? ""
                XCTAssertTrue(
                    v.contains("↑") || v.contains("主线") || v.contains("机会") || v.contains("分叉") || v.contains("主干"),
                    "branch card must speak merge/divergence framing, not '安静': \(v)")
            case .commit:
                let sha8 = String((node.head ?? "").prefix(8))
                XCTAssertTrue(!sha8.isEmpty && (value?.contains(sha8) ?? false),
                              "commit card must speak its sha: \(value ?? "nil")")
            }
        }
    }

    // A1_57 (absorbs A1_58): per-kind meaningful content; honesty (never green /
    // never asserts "merged"); the meaningless generic "安静" is gone for branch/commit.
    func testNodeCardContentIsKindSpecificAndHonest() {
        func branchNode(ahead: Int, behind: Int, contained: Bool, isDefault: Bool = false,
                        mergeStatus: String = "unknown") -> RadarNode {
            RadarNode(
                id: "branch:p:refs/heads/feature", projectId: "p", title: "feature",
                branch: "refs/heads/feature", head: "abcdef1234567890", form: .quiet,
                kind: .branch, isAnchor: isDefault, sameBranchConflict: false,
                locked: false, detached: false, evidence: .object([:]),
                ahead: ahead, behind: behind, mergeStatus: mergeStatus,
                containedInDefault: contained, mergedIntoDefault: false, commitMeta: nil)
        }
        // ahead-only branch → opportunity framing; never "安静"; never a merged claim.
        let opp = NodeCardContent.derive(node: branchNode(ahead: 3, behind: 0, contained: false), selected: true, far: false)
        XCTAssertEqual(opp.headline, "3 个 commit 待并入 — 未收割的机会")
        XCTAssertFalse((opp.accessibilityValue ?? "").contains("安静"),
                       "branch card must not show the meaningless '安静'")
        XCTAssertTrue(opp.detailRows.contains { $0.0 == "分歧" && $0.1.contains("↑3") },
                      "branch card must show the observed ahead/behind divergence")
        // contained-in-default → reachability disclaimer; NEVER asserts merged content.
        let contained = NodeCardContent.derive(node: branchNode(ahead: 0, behind: 0, contained: true), selected: true, far: false)
        XCTAssertEqual(contained.headline, "已在主线可达（≠ 已并入内容）")
        XCTAssertFalse((contained.headline ?? "").contains("已并入") && !(contained.headline ?? "").contains("≠"),
                       "contained-in-default must carry the ≠-merged disclaimer, never a bare merged claim")
        // default branch → trunk framing.
        let trunk = NodeCardContent.derive(node: branchNode(ahead: 0, behind: 0, contained: false, isDefault: true), selected: true, far: false)
        XCTAssertEqual(trunk.headline, "主干 · 默认分支")
        // HONESTY (Codex P2): behind-only / unobserved must NEVER claim "与主线一致".
        let behind = NodeCardContent.derive(node: branchNode(ahead: 0, behind: 2, contained: false, mergeStatus: "behind"), selected: true, far: false)
        XCTAssertEqual(behind.headline, "落后主线 2 个 commit",
                       "behind-only branch must report stale, not in-sync")
        let unobserved = NodeCardContent.derive(node: branchNode(ahead: 0, behind: 0, contained: false, mergeStatus: "unknown"), selected: true, far: false)
        XCTAssertEqual(unobserved.headline, "与主线关系未观测",
                       "unobserved relation must be fail-visible, never claimed in-sync")
        XCTAssertNotEqual(unobserved.headline, "与主线一致")
        // Only a CONFIRMED identical observation earns the in-sync claim.
        let identical = NodeCardContent.derive(node: branchNode(ahead: 0, behind: 0, contained: false, mergeStatus: "identical"), selected: true, far: false)
        XCTAssertEqual(identical.headline, "与主线一致")

        // commit node WITHOUT observed meta → sha identity + fallback headline.
        let commit = RadarNode(
            id: "commit:p:abcdef1234567890", projectId: "p", title: "abcdef12",
            branch: "refs/heads/main", head: "abcdef1234567890", form: .quiet,
            kind: .commit, isAnchor: false, sameBranchConflict: false, locked: false,
            detached: false, evidence: .object([:]), ahead: 0, behind: 0,
            mergeStatus: "unknown", containedInDefault: false, mergedIntoDefault: false, commitMeta: nil)
        let cc = NodeCardContent.derive(node: commit, selected: true, far: false)
        XCTAssertTrue(cc.detailRows.contains { $0.1.contains("abcdef12") },
                      "commit card must show its short sha")
        XCTAssertEqual(cc.headline, "提交节点", "no observed meta → fallback headline")
        XCTAssertNil(cc.body, "no observed meta → no description body")

        // A1_69/A1_70: commit WITH observed meta → the SUBJECT (git %s) leads,
        // the BODY (git %b, now a distinct observed field) is the description,
        // and author/date rows appear (all observed CommitFact facts).
        let commitWithMeta = RadarNode(
            id: "commit:p:abcdef1234567890", projectId: "p", title: "abcdef12",
            branch: "refs/heads/main", head: "abcdef1234567890", form: .quiet,
            kind: .commit, isAnchor: false, sameBranchConflict: false, locked: false,
            detached: false, evidence: .object([:]), ahead: 0, behind: 0,
            mergeStatus: "unknown", containedInDefault: false, mergedIntoDefault: false,
            commitMeta: CommitMeta(summary: "A1_70: show commit info",
                                   body: "body paragraph one\nbody paragraph two",
                                   author: "zephryj", ts: "2026-06-14T08:30:00Z"))
        let ccm = NodeCardContent.derive(node: commitWithMeta, selected: true, far: false)
        XCTAssertEqual(ccm.headline, "A1_70: show commit info",
                       "commit headline = message subject (git %s), the body is separate")
        XCTAssertEqual(ccm.body, "body paragraph one\nbody paragraph two",
                       "commit body (git %b, observed) shown as the description")
        XCTAssertTrue(ccm.detailRows.contains { $0.0 == "作者" && $0.1 == "zephryj" },
                      "commit card shows the observed author")
        XCTAssertTrue(ccm.detailRows.contains { $0.0 == "时间" && $0.1 == "2026-06-14" },
                      "commit card shows the observed date (yyyy-MM-dd)")

        // A1_70: commit WITH a subject but NO body → headline shows, body is nil
        // (empty body is never rendered as a description; no fabrication).
        let commitNoBody = RadarNode(
            id: "commit:p:abcdef1234567890", projectId: "p", title: "abcdef12",
            branch: "refs/heads/main", head: "abcdef1234567890", form: .quiet,
            kind: .commit, isAnchor: false, sameBranchConflict: false, locked: false,
            detached: false, evidence: .object([:]), ahead: 0, behind: 0,
            mergeStatus: "unknown", containedInDefault: false, mergedIntoDefault: false,
            commitMeta: CommitMeta(summary: "single-line commit, no body",
                                   body: "", author: "zephryj", ts: "2026-06-14T08:30:00Z"))
        let ccnb = NodeCardContent.derive(node: commitNoBody, selected: true, far: false)
        XCTAssertEqual(ccnb.headline, "single-line commit, no body")
        XCTAssertNil(ccnb.body, "empty observed body → no description block")

        // worktree node → form label leads (meaningful for a worktree).
        let wt = RadarNode(
            id: "wt_1", projectId: "p", title: "main", branch: "main", head: "deadbeef00000000",
            form: .active, kind: .worktree, isAnchor: true, sameBranchConflict: false,
            locked: false, detached: false, evidence: .object([:]), ahead: 0, behind: 0,
            mergeStatus: "unknown", containedInDefault: false, mergedIntoDefault: false, commitMeta: nil)
        let wc = NodeCardContent.derive(node: wt, selected: true, far: false)
        XCTAssertEqual(wc.headline, RadarNode.Form.active.label,
                       "worktree card leads with its (meaningful) form label")
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

    // MARK: A1_51b — branch->node derivation

    func testBranchNodeDerivation() throws {
        var ledger = WorktreeLedger()
        ledger.apply(envelope(0, "ProjectRegistered",
            #"{"project_id":"proj_x","local":true,"path":"/repos/x"}"#))
        // Default branch
        let defEvt = """
        {"event_id":"evt_dn1","seq":1,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
        "kind":"BranchObserved","source":"github","trust_state":"observed_unsigned",\
        "payload":{"project_id":"proj_x","branch_ref":"refs/heads/main","head_sha":"aaaa",\
        "is_default":true,"merged_into_default":false,"provenance":"github_api",\
        "ahead":0,"behind":0,"merge_status":"identical","merge_base":"aaaa","contained_in_default":true}}
        """
        let featEvt = """
        {"event_id":"evt_dn2","seq":2,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
        "kind":"BranchObserved","source":"github","trust_state":"observed_unsigned",\
        "payload":{"project_id":"proj_x","branch_ref":"refs/heads/feat/xyz","head_sha":"bbbb",\
        "is_default":false,"merged_into_default":false,"provenance":"github_api",\
        "ahead":4,"behind":2,"merge_status":"diverged","merge_base":"aaaa","contained_in_default":false}}
        """
        ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(defEvt.utf8)))
        ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(featEvt.utf8)))

        let scene = RadarScene.derive(ledger: ledger)
        let branchNodes = scene.nodes.filter { $0.kind == .branch }
        XCTAssertEqual(branchNodes.count, 2, "2 BranchFacts → 2 branch nodes")

        let mainNode = branchNodes.first { $0.branch == "refs/heads/main" }
        XCTAssertNotNil(mainNode)
        XCTAssertTrue(mainNode?.isAnchor == true, "default branch is the galaxy anchor")
        XCTAssertEqual(mainNode?.kind, .branch)
        XCTAssertEqual(mainNode?.form, .quiet, "branch nodes use neutral .quiet form")
        XCTAssertNil(mainNode?.form.semantic, "neutral branch node has no semantic claim")

        let featNode = branchNodes.first { $0.branch == "refs/heads/feat/xyz" }
        XCTAssertNotNil(featNode)
        XCTAssertFalse(featNode?.isAnchor == true)
        XCTAssertEqual(featNode?.ahead, 4)
        XCTAssertEqual(featNode?.behind, 2)

        // Worktree-independent: same positions on re-derive (determinism).
        let scene2 = RadarScene.derive(ledger: ledger)
        for node in scene.nodes where node.kind == .branch {
            XCTAssertEqual(scene.positions[node.id], scene2.positions[node.id],
                           "branch node position must be deterministic: \(node.id)")
        }
    }

    // MARK: A1_51b — commit->node derivation

    func testCommitNodeDerivation() throws {
        var ledger = WorktreeLedger()
        ledger.apply(envelope(0, "ProjectRegistered",
            #"{"project_id":"proj_c","local":true,"path":"/repos/c"}"#))
        let branchEvt = """
        {"event_id":"evt_cb1","seq":1,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
        "kind":"BranchObserved","source":"github","trust_state":"observed_unsigned",\
        "payload":{"project_id":"proj_c","branch_ref":"refs/heads/feat","head_sha":"sha2",\
        "is_default":false,"merged_into_default":false,"provenance":"github_api",\
        "ahead":2,"behind":0,"merge_status":"ahead","contained_in_default":false}}
        """
        ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(branchEvt.utf8)))

        // Two commit events on the branch.
        let c1 = """
        {"event_id":"evt_cc1","seq":2,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
        "kind":"CommitObserved","source":"github","trust_state":"observed_unsigned",\
        "payload":{"project_id":"proj_c","commit_sha":"sha1","parent_shas":["sha0"],\
        "branch_ref":"refs/heads/feat","author":"Alice","ts":"2026-06-15T09:00:00Z","summary":"first"}}
        """
        let c2 = """
        {"event_id":"evt_cc2","seq":3,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
        "kind":"CommitObserved","source":"github","trust_state":"observed_unsigned",\
        "payload":{"project_id":"proj_c","commit_sha":"sha2","parent_shas":["sha1"],\
        "branch_ref":"refs/heads/feat","author":"Alice","ts":"2026-06-15T10:00:00Z","summary":"second"}}
        """
        ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(c1.utf8)))
        ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(c2.utf8)))

        let scene = RadarScene.derive(ledger: ledger)
        let commitNodes = scene.nodes.filter { $0.kind == .commit }
        XCTAssertEqual(commitNodes.count, 2, "2 CommitObserved → 2 commit nodes")

        let n1 = commitNodes.first { $0.id.contains("sha1") }
        XCTAssertNotNil(n1)
        XCTAssertEqual(n1?.kind, .commit)
        XCTAssertEqual(n1?.form, .quiet, "commit nodes use neutral .quiet form")
        XCTAssertNil(n1?.form.semantic, "commit node has no semantic claim")

        // Parent edge: sha2 -> sha1 (sha1 exists as a node).
        let parentEdge = scene.edges.first { $0.kind == .parent && $0.from.contains("sha2") }
        XCTAssertNotNil(parentEdge, "parent edge must exist from sha2 to sha1")
        XCTAssertTrue(parentEdge?.to.contains("sha1") == true)

        // No commit node without a CommitObserved.
        XCTAssertNil(scene.nodes.first { $0.id.contains("sha0") },
                     "sha0 was never observed → no commit node (honesty rule)")
    }

    func testBranchRemovedCascadesPrunesCommits() throws {
        var ledger = WorktreeLedger()
        let branchEvt = """
        {"event_id":"evt_br1","seq":1,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
        "kind":"BranchObserved","source":"github","trust_state":"observed_unsigned",\
        "payload":{"project_id":"proj_p","branch_ref":"refs/heads/feat","head_sha":"h1",\
        "is_default":false,"merged_into_default":false,"provenance":"github_api"}}
        """
        let commitEvt = """
        {"event_id":"evt_br2","seq":2,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
        "kind":"CommitObserved","source":"github","trust_state":"observed_unsigned",\
        "payload":{"project_id":"proj_p","commit_sha":"c1","parent_shas":[],\
        "branch_ref":"refs/heads/feat","author":"A","ts":"2026-06-15T00:00:00Z","summary":"s"}}
        """
        let removeEvt = """
        {"event_id":"evt_br3","seq":3,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
        "kind":"BranchRemoved","source":"github","trust_state":"observed_unsigned",\
        "payload":{"project_id":"proj_p","branch_ref":"refs/heads/feat"}}
        """
        ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(branchEvt.utf8)))
        ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(commitEvt.utf8)))
        XCTAssertEqual(ledger.commits.count, 1, "commit must be in ledger before removal")

        ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(removeEvt.utf8)))
        XCTAssertEqual(ledger.commits.count, 0,
                       "branchRemoved must cascade-prune commits on that branch_ref")
        let scene = RadarScene.derive(ledger: ledger)
        XCTAssertTrue(scene.nodes.filter { $0.kind == .commit }.isEmpty,
                      "no commit nodes after branch cascade prune")
    }

    // MARK: A1_51b — galaxy layout geometric tests

    func testGalaxyMinSpacingBetweenProjectCenters() throws {
        // Build a scene with several projects and assert MIN_GALAXY_GAP.
        var ledger = WorktreeLedger()
        let pids = ["alpha", "beta", "gamma", "delta", "epsilon"]
        for (i, pid) in pids.enumerated() {
            ledger.apply(envelope(UInt64(i), "ProjectRegistered",
                "{\"project_id\":\"\(pid)\",\"local\":true}"))
            // Add a default branch so we get galaxy centers computed.
            let bj = """
            {"event_id":"evt_gs\(i)","seq":\(100+i),"ts":"2026-06-15T00:00:00Z",\
            "schema_version":"tos.app.event.v0","kind":"BranchObserved","source":"github",\
            "trust_state":"observed_unsigned","payload":{"project_id":"\(pid)",\
            "branch_ref":"refs/heads/main","head_sha":"aaa","is_default":true,\
            "merged_into_default":false,"provenance":"github_api"}}
            """
            ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(bj.utf8)))
        }

        let scene = RadarScene.derive(ledger: ledger)
        // Get all default-branch (anchor) positions as galaxy centers.
        let anchors = scene.nodes.filter { $0.kind == .branch && $0.isAnchor }
        let centers = anchors.compactMap { scene.positions[$0.id] }

        XCTAssertEqual(centers.count, pids.count,
                       "each project must have a default branch anchor center")

        // Assert pairwise MIN_GALAXY_GAP.
        for i in 0..<centers.count {
            for j in (i+1)..<centers.count {
                let d = hypot(centers[i].x - centers[j].x, centers[i].y - centers[j].y)
                XCTAssertGreaterThanOrEqual(d, RadarLayout.MIN_GALAXY_GAP,
                    "galaxy centers [\(i)] and [\(j)] are only \(d) apart < MIN_GALAXY_GAP")
            }
        }
    }

    func testNoCrossProjectEdges() throws {
        // ADR-009: no cross-project edges.
        var ledger = WorktreeLedger()
        ledger.apply(envelope(0, "ProjectRegistered", #"{"project_id":"px","local":true}"#))
        ledger.apply(envelope(1, "ProjectRegistered", #"{"project_id":"py","local":true}"#))
        ledger.apply(envelope(2, "WorktreeDiscovered",
            #"{"project_id":"px","worktree_id":"wt_px_11111111","branch":"main","dirty":false}"#))
        ledger.apply(envelope(3, "WorktreeDiscovered",
            #"{"project_id":"py","worktree_id":"wt_py_22222222","branch":"main","dirty":false}"#))
        let scene = RadarScene.derive(ledger: ledger)
        let nodeById = Dictionary(uniqueKeysWithValues: scene.nodes.map { ($0.id, $0) })
        for edge in scene.edges {
            let fromPid = nodeById[edge.from]?.projectId
            let toPid = nodeById[edge.to]?.projectId
            XCTAssertEqual(fromPid, toPid,
                           "cross-project edge is forbidden (ADR-009): \(edge)")
        }
    }

    func testForkEdgeExistsWhenMergeBaseIsObservedCommit() throws {
        var ledger = WorktreeLedger()
        // Branch with a known merge_base SHA.
        let bj = """
        {"event_id":"evt_fe1","seq":1,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
        "kind":"BranchObserved","source":"github","trust_state":"observed_unsigned",\
        "payload":{"project_id":"proj_f","branch_ref":"refs/heads/feat","head_sha":"f1",\
        "is_default":false,"merged_into_default":false,"provenance":"github_api",\
        "ahead":1,"behind":0,"merge_status":"ahead","merge_base":"base_sha","contained_in_default":false}}
        """
        let cj = """
        {"event_id":"evt_fe2","seq":2,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
        "kind":"CommitObserved","source":"github","trust_state":"observed_unsigned",\
        "payload":{"project_id":"proj_f","commit_sha":"base_sha","parent_shas":[],\
        "branch_ref":"refs/heads/main","author":"A","ts":"2026-06-15T00:00:00Z","summary":"base"}}
        """
        ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(bj.utf8)))
        ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(cj.utf8)))

        let scene = RadarScene.derive(ledger: ledger)
        let forkEdges = scene.edges.filter { $0.kind == .fork }
        XCTAssertFalse(forkEdges.isEmpty, "fork edge must exist when merge_base commit is observed")
        XCTAssertTrue(forkEdges.first?.from.contains("refs/heads/feat") == true)
        XCTAssertTrue(forkEdges.first?.to.contains("base_sha") == true)
    }

    func testForkEdgeAbsentWhenMergeBaseNotObserved() throws {
        // If merge_base commit is not in ledger.commits, no fork edge.
        var ledger = WorktreeLedger()
        let bj = """
        {"event_id":"evt_fa1","seq":1,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
        "kind":"BranchObserved","source":"github","trust_state":"observed_unsigned",\
        "payload":{"project_id":"proj_g","branch_ref":"refs/heads/feat","head_sha":"f1",\
        "is_default":false,"merged_into_default":false,"provenance":"github_api",\
        "ahead":1,"behind":0,"merge_status":"ahead","merge_base":"not_observed_sha","contained_in_default":false}}
        """
        ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(bj.utf8)))
        let scene = RadarScene.derive(ledger: ledger)
        XCTAssertTrue(scene.edges.filter { $0.kind == .fork }.isEmpty,
                      "no fork edge when merge_base commit is not observed (honesty rule)")
    }

    // MARK: A1_51b — swimlane lane stability

    func testSwimlaneColumnStability() throws {
        // Online lane algorithm: vacated lanes set to nil, columns don't shift.
        // Linear chain: sha1 -> sha2 -> sha3 (same branch lane).
        var ledger = WorktreeLedger()
        let bj = """
        {"event_id":"evt_sw0","seq":0,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
        "kind":"BranchObserved","source":"github","trust_state":"observed_unsigned",\
        "payload":{"project_id":"proj_s","branch_ref":"refs/heads/main","head_sha":"sha3",\
        "is_default":true,"merged_into_default":false,"provenance":"github_api"}}
        """
        let c1j = """
        {"event_id":"evt_sw1","seq":1,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
        "kind":"CommitObserved","source":"github","trust_state":"observed_unsigned",\
        "payload":{"project_id":"proj_s","commit_sha":"sha1","parent_shas":[],\
        "branch_ref":"refs/heads/main","author":"A","ts":"2026-06-15T09:00:00Z","summary":"c1"}}
        """
        let c2j = """
        {"event_id":"evt_sw2","seq":2,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
        "kind":"CommitObserved","source":"github","trust_state":"observed_unsigned",\
        "payload":{"project_id":"proj_s","commit_sha":"sha2","parent_shas":["sha1"],\
        "branch_ref":"refs/heads/main","author":"A","ts":"2026-06-15T10:00:00Z","summary":"c2"}}
        """
        let c3j = """
        {"event_id":"evt_sw3","seq":3,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
        "kind":"CommitObserved","source":"github","trust_state":"observed_unsigned",\
        "payload":{"project_id":"proj_s","commit_sha":"sha3","parent_shas":["sha2"],\
        "branch_ref":"refs/heads/main","author":"A","ts":"2026-06-15T11:00:00Z","summary":"c3"}}
        """
        ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(bj.utf8)))
        ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(c1j.utf8)))
        ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(c2j.utf8)))
        ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(c3j.utf8)))

        let scene = RadarScene.derive(ledger: ledger)
        let commitNodes = scene.nodes.filter { $0.kind == .commit }.sorted { $0.id < $1.id }
        XCTAssertEqual(commitNodes.count, 3)

        // All three commits should have the SAME x coordinate (same lane = same column).
        let xs = commitNodes.compactMap { scene.positions[$0.id]?.x }
        XCTAssertEqual(xs.count, 3)
        // Lane stability: all commits in a straight chain stay in the same column.
        if let first = xs.first {
            for x in xs {
                XCTAssertEqual(x, first, accuracy: 0.1,
                               "straight chain commits must stay in the same swimlane column")
            }
        }

        // Rows must be distinct (temporal order → different y values).
        let ys = commitNodes.compactMap { scene.positions[$0.id]?.y }
        XCTAssertEqual(Set(ys).count, 3, "each commit must occupy a distinct row")
    }

    // MARK: A1_51b — determinism

    func testSameLeadgeSameCanonicalDump() throws {
        var ledger = WorktreeLedger()
        ledger.apply(envelope(0, "ProjectRegistered",
            #"{"project_id":"det_proj","local":true,"path":"/repos/det"}"#))
        let bj = """
        {"event_id":"evt_det1","seq":1,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
        "kind":"BranchObserved","source":"github","trust_state":"observed_unsigned",\
        "payload":{"project_id":"det_proj","branch_ref":"refs/heads/main","head_sha":"aaa",\
        "is_default":true,"merged_into_default":false,"provenance":"github_api","ahead":0,"behind":0}}
        """
        ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(bj.utf8)))
        ledger.apply(envelope(2, "WorktreeDiscovered",
            #"{"project_id":"det_proj","worktree_id":"wt_det_11111111","path":"/repos/det","branch":"main","dirty":false}"#))

        let dump1 = RadarScene.derive(ledger: ledger).canonicalDump()
        let dump2 = RadarScene.derive(ledger: ledger).canonicalDump()
        XCTAssertEqual(dump1, dump2, "same ledger must give identical canonicalDump (no clock/random)")
    }

    // MARK: A1_51b — galaxy scene golden (multi-project, branch+commit)

    func testGalaxySceneGolden() throws {
        // Build a multi-project ledger with branches and commits.
        var ledger = WorktreeLedger()
        ledger.apply(envelope(0, "ProjectRegistered",
            #"{"project_id":"gal_alpha","local":true,"path":"/repos/alpha"}"#))
        ledger.apply(envelope(1, "ProjectRegistered",
            #"{"project_id":"gal_beta","local":true,"path":"/repos/beta"}"#))
        ledger.apply(envelope(2, "WorktreeDiscovered",
            #"{"project_id":"gal_alpha","worktree_id":"wt_gal_11111111","path":"/repos/alpha","branch":"main","dirty":false}"#))

        let evts: [(UInt64, String)] = [
            (10, """
            {"event_id":"evt_gal1","seq":10,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
            "kind":"BranchObserved","source":"github","trust_state":"observed_unsigned",\
            "payload":{"project_id":"gal_alpha","branch_ref":"refs/heads/main","head_sha":"a0",\
            "is_default":true,"merged_into_default":false,"provenance":"github_api","ahead":0,"behind":0,\
            "merge_status":"identical","merge_base":"a0","contained_in_default":true}}
            """),
            (11, """
            {"event_id":"evt_gal2","seq":11,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
            "kind":"BranchObserved","source":"github","trust_state":"observed_unsigned",\
            "payload":{"project_id":"gal_alpha","branch_ref":"refs/heads/feat/wip","head_sha":"a1",\
            "is_default":false,"merged_into_default":false,"provenance":"github_api","ahead":2,"behind":0,\
            "merge_status":"ahead","merge_base":"a0","contained_in_default":false}}
            """),
            (12, """
            {"event_id":"evt_gal3","seq":12,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
            "kind":"BranchObserved","source":"github","trust_state":"observed_unsigned",\
            "payload":{"project_id":"gal_beta","branch_ref":"refs/heads/main","head_sha":"b0",\
            "is_default":true,"merged_into_default":false,"provenance":"github_api","ahead":0,"behind":0,\
            "merge_status":"identical","merge_base":"b0","contained_in_default":true}}
            """),
            (20, """
            {"event_id":"evt_gal4","seq":20,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
            "kind":"CommitObserved","source":"github","trust_state":"observed_unsigned",\
            "payload":{"project_id":"gal_alpha","commit_sha":"a0","parent_shas":[],\
            "branch_ref":"refs/heads/main","author":"Alice","ts":"2026-06-15T08:00:00Z","summary":"Initial"}}
            """),
            (21, """
            {"event_id":"evt_gal5","seq":21,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
            "kind":"CommitObserved","source":"github","trust_state":"observed_unsigned",\
            "payload":{"project_id":"gal_alpha","commit_sha":"a1","parent_shas":["a0"],\
            "branch_ref":"refs/heads/feat/wip","author":"Bob","ts":"2026-06-15T09:00:00Z","summary":"WIP"}}
            """),
        ]
        for (_, json) in evts.sorted(by: { $0.0 < $1.0 }) {
            ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(json.utf8)))
        }

        let dump1 = RadarScene.derive(ledger: ledger).canonicalDump()
        let dump2 = RadarScene.derive(ledger: ledger).canonicalDump()
        XCTAssertEqual(dump1, dump2, "galaxy scene must be deterministic (same ledger → same dump)")

        let golden = EventsContractTests.fixturesDir
            .deletingLastPathComponent()
            .appendingPathComponent("snapshots/p1_galaxy_scene.golden.txt")
        if ProcessInfo.processInfo.environment["RADAR_GOLDEN_WRITE"] == "1" {
            try dump1.write(to: golden, atomically: true, encoding: .utf8)
            XCTFail("galaxy golden regenerated at \(golden.path) - rerun WITHOUT the flag")
            return
        }
        let committed = try String(contentsOf: golden, encoding: .utf8)
        XCTAssertEqual(dump1, committed, "galaxy scene drifted from the committed golden")
    }

    // MARK: A1_51b — kind distinguishes worktree/branch/commit

    func testKindDistinguishesNodeTypes() throws {
        var ledger = WorktreeLedger()
        ledger.apply(envelope(0, "ProjectRegistered",
            #"{"project_id":"kinds_proj","local":true,"path":"/repos/kp"}"#))
        ledger.apply(envelope(1, "WorktreeDiscovered",
            #"{"project_id":"kinds_proj","worktree_id":"wt_kinds_11111111","path":"/repos/kp","branch":"main","dirty":false}"#))
        let bj = """
        {"event_id":"evt_kd1","seq":2,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
        "kind":"BranchObserved","source":"github","trust_state":"observed_unsigned",\
        "payload":{"project_id":"kinds_proj","branch_ref":"refs/heads/main","head_sha":"k0",\
        "is_default":true,"merged_into_default":false,"provenance":"github_api"}}
        """
        let cj = """
        {"event_id":"evt_kd2","seq":3,"ts":"2026-06-15T00:00:00Z","schema_version":"tos.app.event.v0",\
        "kind":"CommitObserved","source":"github","trust_state":"observed_unsigned",\
        "payload":{"project_id":"kinds_proj","commit_sha":"k_sha1","parent_shas":[],\
        "branch_ref":"refs/heads/main","author":"A","ts":"2026-06-15T08:00:00Z","summary":"c"}}
        """
        ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(bj.utf8)))
        ledger.apply(try JSONDecoder().decode(EventEnvelope.self, from: Data(cj.utf8)))

        let scene = RadarScene.derive(ledger: ledger)
        let worktreeNodes = scene.nodes.filter { $0.kind == .worktree }
        let branchNodes = scene.nodes.filter { $0.kind == .branch }
        let commitNodes = scene.nodes.filter { $0.kind == .commit }

        XCTAssertEqual(worktreeNodes.count, 1)
        XCTAssertEqual(branchNodes.count, 1)
        XCTAssertEqual(commitNodes.count, 1)

        // Kinds must not bleed into each other.
        XCTAssertTrue(worktreeNodes.allSatisfy { $0.id.hasPrefix("wt_") },
                      "worktree nodes must have wt_ prefixed ids")
        XCTAssertTrue(branchNodes.allSatisfy { $0.id.hasPrefix("branch:") },
                      "branch nodes must have branch: prefixed ids")
        XCTAssertTrue(commitNodes.allSatisfy { $0.id.hasPrefix("commit:") },
                      "commit nodes must have commit: prefixed ids")
    }
}

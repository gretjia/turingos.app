// A1_08: sentence templates are deterministic projections - golden tests
// pin the exact bytes (law 2); triage ordering and quiet states pin law 1
// and law 3. The ledger folds the same committed fixtures the daemon and
// GlanceProjection replay.

import Foundation
import XCTest
@testable import TuringOS

final class AttentionModelTests: XCTestCase {
    private func envelope(_ seq: UInt64, _ kind: String, _ payload: String) -> EventEnvelope {
        let json = """
        {"event_id":"evt_t_\(seq)","seq":\(seq),"ts":"2026-06-11T00:00:00Z",\
        "schema_version":"tos.app.event.v0","kind":"\(kind)","source":"daemon",\
        "trust_state":"observed_unsigned","payload":\(payload)}
        """
        return try! JSONDecoder().decode(EventEnvelope.self, from: Data(json.utf8))
    }

    private func fact(
        project: String = "omega", worktree: String, branch: String? = nil,
        dirty: Bool = false, prunable: Bool = false, conflict: Bool = false,
        fingerprintError: String? = nil
    ) -> WorktreeFact {
        WorktreeFact(
            projectId: project, worktreeId: worktree, branch: branch,
            dirty: dirty, prunable: prunable, sameBranchConflict: conflict,
            fingerprintError: fingerprintError, evidence: .null
        )
    }

    // MARK: golden sentences (同账本 ⇒ 同字节)

    func testSentenceGolden() {
        let a = fact(worktree: "wt_sched_a1b2c3d4", branch: "feat/scheduler", conflict: true)
        let b = fact(worktree: "wt_fix_e5f6a7b8", branch: "feat/scheduler", conflict: true)
        XCTAssertEqual(
            Sentences.sameBranchConflict(group: [a, b]),
            "「omega」的 feat/scheduler 被 2 个 worktree（sched、fix）同时检出，等你裁决"
        )
        XCTAssertEqual(
            Sentences.orphan(fact: a),
            "「omega」有一个孤儿 worktree（sched），可以清理"
        )
        XCTAssertEqual(
            Sentences.fingerprintFailure(fact: a, error: "index locked"),
            "「omega」的 sched 读不出状态：index locked"
        )
        XCTAssertEqual(Sentences.disconnected(reason: "socket gone"), "daemon 断连——socket gone")
        XCTAssertEqual(Sentences.reconciling(), "正在对账…")
        XCTAssertEqual(Sentences.popoverOverflow(hidden: 3), "还有 3 件，去主窗看全部")
        XCTAssertEqual(Sentences.working(dirtyCount: 2), "2 个 worktree 有未提交改动")
        XCTAssertEqual(Sentences.quiet(count: 3), "其余 3 个项目一切安静")
        XCTAssertEqual(Sentences.allQuiet(projects: 4), "一切安静，4 个项目在看管中")
        XCTAssertEqual(Sentences.allQuiet(projects: 0), "还没有看管任何项目")
        XCTAssertEqual(Sentences.glanceNeedsYou(count: 2), "2 件事等你")
    }

    func testShortNameOnlyStripsRealDigests() {
        // wt_<name>_<8hex> drops the plumbing digest; everything else keeps
        // its name intact (an id like wt_release_v2 must not lose "v2").
        XCTAssertEqual(Sentences.shortName(fact(worktree: "wt_sched_a1b2c3d4")), "sched")
        XCTAssertEqual(Sentences.shortName(fact(worktree: "wt_release_v2")), "release_v2")
        XCTAssertEqual(Sentences.shortName(fact(worktree: "wt_main")), "main")
        XCTAssertEqual(Sentences.shortName(fact(worktree: "feature")), "feature")
    }

    // MARK: triage law 1 - severity order; disconnect grays the glance

    func testTriageSeverityOrdering() {
        var ledger = WorktreeLedger()
        ledger.apply(envelope(0, "ProjectRegistered", #"{"project_id":"p","local":true}"#))
        ledger.apply(envelope(1, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_a_11111111","same_branch_conflict":true,"dirty":false}"#))
        ledger.apply(envelope(2, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_b_22222222","fingerprint_error":"boom","dirty":false}"#))

        let triage = AttentionTriage.derive(
            ledger: ledger, connection: .disconnected(reason: "x"))
        XCTAssertEqual(
            triage.needsYou.map(\.severity),
            [.failure, .decision, .disconnect],
            "失败 > 裁决 > 断连"
        )
        // The stale items stay LISTED, but the glance never wears a
        // confident red over a dead stream: disconnect overrides to gray.
        XCTAssertEqual(triage.glanceSemantic, .gray)
        XCTAssertEqual(triage.glanceSentence, "daemon 断连——x")
    }

    func testConnectionStateOverridesGlance() {
        var ledger = WorktreeLedger()
        ledger.apply(envelope(0, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_b_22222222","fingerprint_error":"boom","dirty":false}"#))

        let connecting = AttentionTriage.derive(ledger: ledger, connection: .connecting)
        XCTAssertEqual(connecting.glanceSentence, "正在对账…")
        XCTAssertEqual(connecting.glanceSemantic, .gray)

        let connected = AttentionTriage.derive(ledger: ledger, connection: .connected)
        XCTAssertEqual(connected.glanceSemantic, .red, "live stream → the dot wears the worst level")
        XCTAssertEqual(connected.glanceSentence, "1 件事等你")
    }

    // MARK: one conflict == one decision (counting is not triage)

    func testSameBranchConflictGroupsToOneItem() {
        var ledger = WorktreeLedger()
        ledger.apply(envelope(0, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_a_11111111","branch":"main","same_branch_conflict":true,"dirty":false}"#))
        ledger.apply(envelope(1, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_b_22222222","branch":"main","same_branch_conflict":true,"dirty":false}"#))

        let triage = AttentionTriage.derive(ledger: ledger, connection: .connected)
        XCTAssertEqual(triage.needsYou.count, 1, "N conflicted worktrees on one branch = ONE decision")
        XCTAssertEqual(
            triage.needsYou[0].sentence,
            "「p」的 main 被 2 个 worktree（a、b）同时检出，等你裁决"
        )
        // Evidence keeps every member's payload for the drill-down.
        if case .array(let parts)? = triage.needsYou[0].evidence {
            XCTAssertEqual(parts.count, 2)
        } else {
            XCTFail("grouped conflict must carry array evidence, got \(String(describing: triage.needsYou[0].evidence))")
        }
    }

    // MARK: contract-violating events are dropped, never materialized

    func testPhantomEventsAreDropped() {
        var ledger = WorktreeLedger()
        ledger.apply(envelope(0, "WorktreeDiscovered", #"{"worktree_id":"wt_x_77777777","dirty":true}"#))
        ledger.apply(envelope(1, "WorktreeDiscovered", #"{"project_id":"p","dirty":true}"#))
        XCTAssertTrue(ledger.worktrees.isEmpty, "events missing ids must not materialize phantom rows")

        let triage = AttentionTriage.derive(ledger: ledger, connection: .connected)
        XCTAssertTrue(triage.needsYou.isEmpty)
        XCTAssertTrue(triage.working.isEmpty, "no fake『?』project activity")
        XCTAssertEqual(triage.glanceSentence, "还没有看管任何项目")
    }

    // MARK: law 3 - silence is success

    func testAllQuietState() {
        var ledger = WorktreeLedger()
        ledger.apply(envelope(0, "ProjectRegistered", #"{"project_id":"p","local":true}"#))
        ledger.apply(envelope(1, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_main_33333333","dirty":false}"#))

        let triage = AttentionTriage.derive(ledger: ledger, connection: .connected)
        XCTAssertTrue(triage.needsYou.isEmpty)
        XCTAssertTrue(triage.working.isEmpty)
        XCTAssertEqual(triage.glanceSentence, "一切安静，1 个项目在看管中")
        XCTAssertEqual(triage.glanceSemantic, .blue)
    }

    func testWorkingIsAmbientNotAttention() {
        var ledger = WorktreeLedger()
        ledger.apply(envelope(0, "ProjectRegistered", #"{"project_id":"p","local":true}"#))
        ledger.apply(envelope(1, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_f_44444444","dirty":true}"#))

        let triage = AttentionTriage.derive(ledger: ledger, connection: .connected)
        XCTAssertTrue(triage.needsYou.isEmpty, "dirty alone never demands attention")
        XCTAssertEqual(triage.working.map(\.sentence), ["1 个 worktree 有未提交改动"])
        XCTAssertEqual(triage.glanceSentence, "1 个项目有动静，无需介入")
    }

    func testWorktreeRemovedRetiresItsAttention() {
        var ledger = WorktreeLedger()
        ledger.apply(envelope(0, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_x_55555555","prunable":true,"dirty":false}"#))
        var triage = AttentionTriage.derive(ledger: ledger, connection: .connected)
        XCTAssertEqual(triage.needsYou.count, 1)

        ledger.apply(envelope(1, "WorktreeRemoved", #"{"project_id":"p","worktree_id":"wt_x_55555555"}"#))
        triage = AttentionTriage.derive(ledger: ledger, connection: .connected)
        XCTAssertTrue(triage.needsYou.isEmpty, "removal retires the item - no ghost attention")
    }

    // MARK: ledger over the committed fixtures (cross-surface conservation)

    func testLedgerFoldOverP1Fixture() throws {
        let url = EventsContractTests.fixturesDir.appendingPathComponent("p1_worktree_radar.jsonl")
        let body = try String(contentsOf: url, encoding: .utf8)
        let events = try body.split(separator: "\n").filter { !$0.isEmpty }
            .map { try JSONDecoder().decode(EventEnvelope.self, from: Data($0.utf8)) }
        let ledger = WorktreeLedger.fold(events)
        XCTAssertEqual(ledger.worktrees.count, 2, "wt_main + wt_feature_x")
        XCTAssertEqual(ledger.projects.count, 1, "proj_demo registered")
        let triage = AttentionTriage.derive(ledger: ledger, connection: .connected)
        XCTAssertTrue(triage.needsYou.isEmpty, "fixture stream is healthy")
    }

    // MARK: structural anti-pattern guard (反模式黑名单)

    func testNoCountGridComponentSurvives() {
        // The dashboard count-grid was deleted; the home/glance surfaces
        // carry numbers ONLY inside sentences. Mechanical witness: every
        // user-facing string the triage produces must match the sentence
        // grammar whitelist - a "活跃: 3" metric label matches nothing.
        var ledger = WorktreeLedger()
        ledger.apply(envelope(0, "ProjectRegistered", #"{"project_id":"p","local":true}"#))
        ledger.apply(envelope(1, "ProjectRegistered", #"{"project_id":"q","local":true}"#))
        ledger.apply(envelope(2, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_a_66666666","branch":"main","same_branch_conflict":true,"dirty":true}"#))
        ledger.apply(envelope(3, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_b_88888888","branch":"main","same_branch_conflict":true,"dirty":false}"#))
        ledger.apply(envelope(4, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_c_99999999","prunable":true,"dirty":false}"#))
        ledger.apply(envelope(5, "WorktreeDiscovered",
            #"{"project_id":"p","worktree_id":"wt_d_aaaaaaaa","fingerprint_error":"boom","dirty":false}"#))
        ledger.apply(envelope(6, "WorktreeDiscovered",
            #"{"project_id":"q","worktree_id":"wt_e_bbbbbbbb","dirty":true}"#))

        for connection in [ConnectionState.connected, .connecting, .disconnected(reason: "x")] {
            let triage = AttentionTriage.derive(ledger: ledger, connection: connection)
            let surfaces = [triage.glanceSentence]
                + triage.needsYou.map(\.sentence)
                + triage.working.map(\.sentence)
                + (triage.quietSentence.map { [$0] } ?? [])
                + [Sentences.popoverOverflow(hidden: max(1, triage.needsYou.count))]
            for sentence in surfaces {
                XCTAssertTrue(
                    Sentences.matchesTemplate(sentence),
                    "surface string outside the sentence grammar whitelist: \(sentence)"
                )
            }
        }

        // Negative control: the guard has DISCRIMINATING power - metric
        // labels and bare numbers turn it red.
        for dashboardSpeak in ["活跃: 3", "3", "Active: 3", "worktrees 7"] {
            XCTAssertFalse(
                Sentences.matchesTemplate(dashboardSpeak),
                "dashboard-speak must NOT pass the whitelist: \(dashboardSpeak)"
            )
        }
    }
}

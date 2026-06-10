// Cross-language conservation: the Swift fold over the SAME committed
// fixtures must produce the SAME counts the Rust projection produces
// (daemon/src/projection.rs has an independent hand-tally test over these
// fixtures - these hardcoded expectations are that gold standard).

import Foundation
import XCTest
@testable import TuringOS

final class GlanceProjectionTests: XCTestCase {
    private func loadFixture(_ name: String) throws -> [EventEnvelope] {
        let url = EventsContractTests.fixturesDir.appendingPathComponent(name)
        let body = try String(contentsOf: url, encoding: .utf8)
        let decoder = JSONDecoder()
        return try body.split(separator: "\n")
            .filter { !$0.isEmpty }
            .map { try decoder.decode(EventEnvelope.self, from: Data($0.utf8)) }
    }

    func testP1FixtureGoldCounts() throws {
        let events = try loadFixture("p1_worktree_radar.jsonl")
        let p = GlanceProjection.fold(events)
        XCTAssertEqual(p.activeSessions, 1, "one AgentSessionStarted, no Ended")
        XCTAssertEqual(p.pendingProposals, 0, "ProposalCandidate is NOT Submitted")
        XCTAssertEqual(p.anomalousWorktrees, 0, "both discovered worktrees clean")
        XCTAssertEqual(p.asOfSeq, 7)
    }

    func testAnomalyLedgerLatestVerdictWins() {
        func discovered(_ seq: UInt64, _ id: String, conflict: Bool) -> EventEnvelope {
            let json = """
            {"event_id":"evt_t_\(seq)","seq":\(seq),"ts":"2026-06-10T00:00:00Z",\
            "schema_version":"tos.app.event.v0","kind":"WorktreeDiscovered","source":"git",\
            "trust_state":"observed_unsigned",\
            "payload":{"worktree_id":"\(id)","same_branch_conflict":\(conflict)}}
            """
            return try! JSONDecoder().decode(EventEnvelope.self, from: Data(json.utf8))
        }
        var p = GlanceProjection()
        p.apply(discovered(0, "wt_a_1", conflict: true))
        XCTAssertEqual(p.anomalousWorktrees, 1)
        p.apply(discovered(1, "wt_a_1", conflict: false))
        XCTAssertEqual(p.anomalousWorktrees, 0, "latest verdict wins")
    }

    func testConservationIncrementalEqualsFoldOverAllFixtures() throws {
        let files = try FileManager.default
            .contentsOfDirectory(at: EventsContractTests.fixturesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "jsonl" }
        XCTAssertGreaterThanOrEqual(files.count, 4)
        for file in files {
            let events = try loadFixture(file.lastPathComponent)
            var incremental = GlanceProjection()
            for e in events { incremental.apply(e) }
            XCTAssertEqual(incremental, GlanceProjection.fold(events), file.lastPathComponent)
        }
    }
}

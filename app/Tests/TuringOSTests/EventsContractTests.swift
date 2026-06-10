// Repo law replayed in Swift: every committed fixture line must decode into
// the envelope mirror with strictly increasing seq and the pinned
// schema_version - the exact counterpart of daemon/src/events.rs
// fixtures_conform_to_envelope, so the two language mirrors cannot drift.

import Foundation
import XCTest
@testable import TuringOS

final class EventsContractTests: XCTestCase {
    static var fixturesDir: URL {
        // app/Tests/TuringOSTests/EventsContractTests.swift -> repo root
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // TuringOSTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // app
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("fixtures/event_streams")
    }

    func testFixturesConformToEnvelope() throws {
        let files = try FileManager.default
            .contentsOfDirectory(at: Self.fixturesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "jsonl" }
            .sorted { $0.path < $1.path }
        XCTAssertFalse(files.isEmpty, "no fixtures found - repo law missing")

        let decoder = JSONDecoder()
        for file in files {
            let body = try String(contentsOf: file, encoding: .utf8)
            var prevSeq: UInt64?
            for (n, line) in body.split(separator: "\n").enumerated() where !line.isEmpty {
                let envelope: EventEnvelope
                do {
                    envelope = try decoder.decode(EventEnvelope.self, from: Data(line.utf8))
                } catch {
                    XCTFail("\(file.lastPathComponent):\(n + 1) bad envelope: \(error)")
                    return
                }
                XCTAssertEqual(envelope.schemaVersion, eventSchemaVersion, file.lastPathComponent)
                if let prev = prevSeq {
                    XCTAssertGreaterThan(envelope.seq, prev,
                                         "\(file.lastPathComponent): seq not strictly increasing")
                }
                prevSeq = envelope.seq
            }
        }
    }

    func testEnvelopeRoundTrip() throws {
        let line = #"{"event_id":"evt_t_0001","seq":1,"ts":"2026-06-10T00:00:00Z","schema_version":"tos.app.event.v0","kind":"WorktreeDiscovered","source":"git","trust_state":"observed_unsigned","payload":{"worktree_id":"wt_x_1","dirty":true,"insertions":7}}"#
        let decoder = JSONDecoder()
        let envelope = try decoder.decode(EventEnvelope.self, from: Data(line.utf8))
        XCTAssertEqual(envelope.kind, .worktreeDiscovered)
        XCTAssertEqual(envelope.payload["worktree_id"]?.stringValue, "wt_x_1")
        XCTAssertEqual(envelope.payload["dirty"]?.boolValue, true)
        XCTAssertEqual(envelope.payload["insertions"]?.numberValue, 7)

        let encoded = try JSONEncoder().encode(envelope)
        let back = try decoder.decode(EventEnvelope.self, from: encoded)
        XCTAssertEqual(back, envelope, "round trip must be lossless")
    }
}

// A1_44: PredicateGate — {PASS,FAIL} reduction, fail-closed, evidence + schema.

import Foundation
import XCTest
@testable import TuringOS

final class PredicateGateTests: XCTestCase {
    private func tmpDir() -> URL {
        let d = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tos_pg_\(UInt32.random(in: 0 ..< .max))", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func testPassWhenPredicateExitsZero() throws {
        let wt = tmpDir(); defer { try? FileManager.default.removeItem(at: wt) }
        let spec = PredicateSpec(tag: "demo_pass", executable: "/bin/bash", arguments: ["-c", "echo ok; exit 0"])
        let r = try PredicateGate.evaluate(worktree: wt, target: "feat/x", predicate: spec)
        XCTAssertEqual(r.verdict, .pass)
        XCTAssertEqual(r.target, "feat/x")
        XCTAssertEqual(r.schemaVersion, "tos.app.predicate.v0")
    }

    func testFailWhenPredicateExitsNonZero() throws {
        let wt = tmpDir(); defer { try? FileManager.default.removeItem(at: wt) }
        let spec = PredicateSpec(tag: "demo_fail", executable: "/bin/bash", arguments: ["-c", "echo boom >&2; exit 1"])
        let r = try PredicateGate.evaluate(worktree: wt, target: "feat/x", predicate: spec)
        XCTAssertEqual(r.verdict, .fail, "non-zero exit ⇒ FAIL (mutation-sensitive)")
    }

    func testFailClosedWhenNoPredicate() throws {
        let wt = tmpDir(); defer { try? FileManager.default.removeItem(at: wt) }
        XCTAssertThrowsError(try PredicateGate.evaluate(worktree: wt, target: "feat/x", predicate: nil)) { err in
            XCTAssertEqual(err as? PredicateGateError, .noPredicateConfigured(target: "feat/x"),
                           "no predicate ⇒ fail-closed throw, NEVER a silent PASS")
        }
    }

    func testEvidenceAndIdFormats() throws {
        let wt = tmpDir(); defer { try? FileManager.default.removeItem(at: wt) }
        let spec = PredicateSpec(tag: "Swift Build!", executable: "/bin/bash", arguments: ["-c", "exit 0"])
        let r = try PredicateGate.evaluate(worktree: wt, target: "main", predicate: spec)
        XCTAssertNotNil(r.evidenceHash.range(of: "^sha256:[0-9a-f]{8,64}$", options: .regularExpression),
                        "evidence_hash matches schema pattern: \(r.evidenceHash)")
        XCTAssertNotNil(r.predicateId.range(of: "^prd_[a-z0-9_]+$", options: .regularExpression),
                        "predicate_id matches schema pattern (tag slugged): \(r.predicateId)")
    }

    func testEncodingKeysMatchSchema() throws {
        let wt = tmpDir(); defer { try? FileManager.default.removeItem(at: wt) }
        let spec = PredicateSpec(tag: "k", executable: "/bin/bash", arguments: ["-c", "exit 0"])
        let r = try PredicateGate.evaluate(worktree: wt, target: "main", predicate: spec)
        let data = try JSONEncoder().encode(r)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        // predicate_result.schema.json required[]
        for key in ["predicate_id", "schema_version", "verdict", "evidence_hash", "target"] {
            XCTAssertNotNil(obj[key], "encoded PredicateResult must carry schema key '\(key)'")
        }
        XCTAssertTrue(["PASS", "FAIL"].contains(obj["verdict"] as? String ?? ""), "verdict domain {PASS,FAIL}")
    }
}

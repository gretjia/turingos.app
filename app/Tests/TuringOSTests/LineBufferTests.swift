// JSONL framing is the wire contract - partial reads and coalesced reads
// must both reassemble into exact lines.

import Foundation
import XCTest
@testable import TuringOS

final class LineBufferTests: XCTestCase {
    func testPartialThenCompleteFrame() {
        var buf = LineBuffer()
        XCTAssertEqual(buf.append(Data("{\"a\":".utf8)), [])
        let lines = buf.append(Data("1}\n".utf8))
        XCTAssertEqual(lines.map { String(data: $0, encoding: .utf8) }, ["{\"a\":1}"])
    }

    func testMultipleFramesInOneRead() {
        var buf = LineBuffer()
        let lines = buf.append(Data("{\"a\":1}\n{\"b\":2}\n{\"c\":".utf8))
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(String(data: lines[1], encoding: .utf8), "{\"b\":2}")
        XCTAssertEqual(buf.append(Data("3}\n".utf8)).count, 1, "tail completes later")
    }

    func testEmptyLinesAreSurfacedAsEmptyFrames() {
        var buf = LineBuffer()
        let lines = buf.append(Data("\n{\"a\":1}\n".utf8))
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].isEmpty, "caller filters empties explicitly")
    }
}

// A1_38 regression suite: the bug that shipped (NWConnection-over-UDS stuck
// in .waiting -> app frozen in .connecting) had NO transport test, only the
// pure LineBuffer test. These tests drive the REAL socket path end to end so
// a transport that never reaches .connected, or one that swallows failures,
// turns the gate red.

import Foundation
import XCTest
import Darwin
@testable import TuringOS

/// Minimal real AF_UNIX line server: binds, accepts one client, writes the
/// given frames (newline-appended), then closes (EOF). Mirrors the daemon's
/// wire shape closely enough to exercise UDSClient's transport + framing.
final class UnixLineServer: @unchecked Sendable {
    let path: String
    private let listenFd: Int32
    private var thread: Thread?

    init(frames: [String], at customPath: String? = nil) throws {
        path = customPath ?? "/tmp/tos_t_\(getpid())_\(UInt32.random(in: 0 ..< .max)).sock"
        unlink(path)
        listenFd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listenFd >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EINVAL) }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        precondition(bytes.count <= MemoryLayout.size(ofValue: addr.sun_path) - 1)
        withUnsafeMutableBytes(of: &addr.sun_path) { dst in
            for (i, b) in bytes.enumerated() { dst[i] = b }
        }
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(listenFd, $0, size) }
        }
        guard bound == 0 else { let e = errno; close(listenFd); throw POSIXError(.init(rawValue: e) ?? .EINVAL) }
        guard listen(listenFd, 1) == 0 else { let e = errno; close(listenFd); throw POSIXError(.init(rawValue: e) ?? .EINVAL) }

        let lf = listenFd
        let payload = Array((frames.map { $0 + "\n" }.joined()).utf8)
        let t = Thread {
            let cf = accept(lf, nil, nil)
            guard cf >= 0 else { return }
            payload.withUnsafeBytes { raw in
                var off = 0
                while off < raw.count {
                    let n = write(cf, raw.baseAddress!.advanced(by: off), raw.count - off)
                    if n <= 0 { break }
                    off += n
                }
            }
            close(cf) // EOF -> client sees .closed after the frames
        }
        t.start()
        thread = t
    }

    func stop() { close(listenFd); unlink(path) }
}

/// Thread-safe collector (updates land on the consumer Task; the test reads
/// them after the fulfillment barrier).
private final class UpdateBox: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [ClientUpdate] = []
    func add(_ u: ClientUpdate) { lock.lock(); items.append(u); lock.unlock() }
    func all() -> [ClientUpdate] { lock.lock(); defer { lock.unlock() }; return items }
    var eventCount: Int { all().filter { if case .event = $0 { return true }; return false }.count }
    var hasConnected: Bool { all().contains { if case .state(.connected) = $0 { return true }; return false } }
    var disconnectReason: String? {
        for u in all() { if case .state(.disconnected(let r)) = u { return r } }
        return nil
    }
}

private func envelopeJSON(seq: UInt64) -> String {
    """
    {"event_id":"e\(seq)","seq":\(seq),"ts":"2026-06-14T00:00:00Z","schema_version":"tos.app.event.v0","kind":"ProjectRegistered","source":"daemon","trust_state":"observed_unsigned","payload":{"project_id":"p"}}
    """
}

final class UDSTransportTests: XCTestCase {
    func testConnectsAndStreamsFramesInOrder() async throws {
        let server = try UnixLineServer(frames: [envelopeJSON(seq: 0), envelopeJSON(seq: 1), envelopeJSON(seq: 2)])
        defer { server.stop() }
        let client = UDSClient(socketPath: server.path)
        let box = UpdateBox()
        let exp = expectation(description: "3 events received in order")
        let consumer = Task {
            for await u in client.updates {
                box.add(u)
                if box.eventCount == 3 { exp.fulfill(); break }
            }
        }
        await client.connect()
        await fulfillment(of: [exp], timeout: 5)
        consumer.cancel()
        await client.disconnect(reason: "test done")

        XCTAssertTrue(box.hasConnected, "transport never reached .connected (the shipped freeze)")
        let seqs = box.all().compactMap { u -> UInt64? in
            if case .event(let e) = u { return e.seq }; return nil
        }
        XCTAssertEqual(seqs, [0, 1, 2], "frames must arrive once, in wire order")
    }

    func testDeadSocketFailsVisiblyNotStuckConnecting() async throws {
        // No listener at this path: with one attempt (no retry) connect() must
        // surface a .disconnected reason FAST, NEVER sit silently in .connecting
        // (the root-cause bug). maxConnectAttempts:1 = one shot.
        let client = UDSClient(
            socketPath: "/tmp/tos_nonexistent_\(getpid())_\(UInt32.random(in: 0 ..< .max)).sock",
            maxConnectAttempts: 1)
        let box = UpdateBox()
        let exp = expectation(description: "fails visibly")
        let consumer = Task {
            for await u in client.updates {
                box.add(u)
                if case .state(.disconnected) = u { exp.fulfill(); break }
            }
        }
        await client.connect()
        await fulfillment(of: [exp], timeout: 5)
        consumer.cancel()

        XCTAssertNotNil(box.disconnectReason, "dead socket must yield a fail-visible reason")
        XCTAssertFalse(box.hasConnected, "must not claim .connected against a dead socket")
    }

    func testRetriesUntilLateDaemonAppears() async throws {
        // The p1 wire-probe scenario: the daemon is spawned just before connect,
        // so the socket may not exist at the first attempt. BSD connect() is
        // one-shot, so the client must retry (bounded) and connect once the
        // listener appears — restoring NWConnection's old .waiting resilience.
        let path = "/tmp/tos_late_\(getpid())_\(UInt32.random(in: 0 ..< .max)).sock"
        let client = UDSClient(socketPath: path, maxConnectAttempts: 100, connectRetryNanos: 50_000_000)
        let box = UpdateBox()
        let exp = expectation(description: "connects after the listener appears late")
        let consumer = Task {
            for await u in client.updates {
                box.add(u)
                if case .event = u { exp.fulfill(); break }
            }
        }
        await client.connect()                          // socket absent -> retries
        try await Task.sleep(nanoseconds: 200_000_000)  // a few retries elapse
        let server = try UnixLineServer(frames: [envelopeJSON(seq: 0)], at: path)
        defer { server.stop() }
        await fulfillment(of: [exp], timeout: 5)
        consumer.cancel()
        await client.disconnect(reason: "test done")
        XCTAssertTrue(box.hasConnected, "must connect once the daemon's socket appears late")
    }

    func testSystemProcessRunnerDrainsBothPipesWithoutDeadlock() throws {
        // Child writes >64KB to stderr FIRST, then >64KB to stdout. Sequential
        // "read stdout to EOF, then stderr" deadlocks (stderr pipe fills while
        // we block on stdout). Concurrent drain must capture both fully.
        let big = 200_000
        let runner = SystemProcessRunner()
        let (code, out, err) = try runner.run(
            "/bin/sh", ["-c", "head -c \(big) /dev/zero >&2; head -c \(big) /dev/zero"])
        XCTAssertEqual(code, 0)
        XCTAssertEqual(out.count, big, "stdout fully drained")
        XCTAssertEqual(err.count, big, "stderr fully drained (no 64KB-pipe deadlock)")
    }
}

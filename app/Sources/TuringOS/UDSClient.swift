// UDS JSONL subscription client (ADR-005: the app is a pure projection
// consumer over the daemon's event stream).
//
// Transport (A1_38): BSD AF_UNIX SOCK_STREAM, NOT Network.framework.
// `NWConnection(to:.unix, using:.tcp)` stalls in `.waiting` on macOS 27
// (Darwin 27.0) and never reaches `.ready`; the prior handleState swallowed
// `.waiting` into `default: break`, so the app sat in `.connecting` forever
// ("正在对账…") with every view data-starved. V6_RECONCILIATION §3 had
// pre-authorised the BSD fallback for exactly this UNVERIFIED risk, and
// DaemonController.socketIsLive already proves raw unix connect works here.
//
// Ordering law (S-stage critique): state changes and envelopes are ONE
// totally-ordered stream. The raw socket's readable bytes are handed to a
// SINGLE consumer over a FIFO AsyncStream, so reassembly and the seq guard
// always see frames in true wire order - no Task-scheduling reordering.
//
// Generation guard (S-stage critique): every connection attempt gets a
// generation token; callbacks from a previous generation are dropped, so
// "disconnected" is a terminal barrier and a re-entrant connect() cannot
// interleave two sockets into one buffer.
//
// fd ownership: the DispatchSource's cancel handler is the SOLE closer of
// the fd (no double-close), and teardown always cancels the source.

import Foundation
import Darwin

public enum ConnectionState: Sendable, Equatable {
    case disconnected(reason: String)
    case connecting
    case connected
}

/// One totally-ordered client update.
public enum ClientUpdate: Sendable {
    case state(ConnectionState)
    case event(EventEnvelope)
}

/// Splits a byte stream into newline-terminated JSONL frames. Pure logic,
/// unit-tested separately from the socket.
public struct LineBuffer: Sendable {
    private var buffer = Data()

    public init() {}

    public mutating func append(_ data: Data) -> [Data] {
        buffer.append(data)
        var lines: [Data] = []
        while let nl = buffer.firstIndex(of: 0x0A) {
            lines.append(buffer.subdata(in: buffer.startIndex..<nl))
            buffer.removeSubrange(buffer.startIndex...nl)
        }
        return lines
    }
}

/// Actor owning one subscription connection.
public actor UDSClient {
    private let socketPath: String
    private var readSource: DispatchSourceRead?
    private var ioTask: Task<Void, Never>?
    private var lineBuffer = LineBuffer()
    private var lastSeq: UInt64?
    private var generation: UInt64 = 0
    private let decoder = JSONDecoder()

    /// Immutable Sendable stream - readable cross-actor without await (this
    /// is how GlanceStore and the tests consume it); `nonisolated` makes that
    /// contract explicit for the strict-concurrency test target.
    public nonisolated let updates: AsyncStream<ClientUpdate>
    private let continuation: AsyncStream<ClientUpdate>.Continuation

    /// Bounded connect retry budget (injectable for tests). The daemon is
    /// often spawned moments before the app connects (DaemonController.
    /// ensureRunning then store.start); on a loaded machine binding the socket
    /// can take many seconds. BSD connect() is one-shot (unlike NWConnection's
    /// .waiting auto-retry), so we retry transient failures ourselves - BOUNDED
    /// then fail-visible (NOT the old silent-forever .connecting).
    private let maxConnectAttempts: Int
    private let connectRetryNanos: UInt64

    public init(socketPath: String, maxConnectAttempts: Int = 60, connectRetryNanos: UInt64 = 500_000_000) {
        self.socketPath = socketPath
        self.maxConnectAttempts = maxConnectAttempts
        self.connectRetryNanos = connectRetryNanos
        (updates, continuation) = AsyncStream.makeStream(of: ClientUpdate.self)
    }

    /// Ordered handoff from the read source (background queue) to the single
    /// actor-side consumer. FIFO AsyncStream preserves byte order.
    private enum ReadSignal: Sendable {
        case data(Data)
        case closed(reason: String)
    }

    /// Re-entrant safe: tears down any previous connection (its callbacks
    /// are fenced out by the generation bump) and starts fresh. Fresh
    /// lastSeq is part of the contract - the daemon replays its retained
    /// log from its own seq floor on every connect.
    public func connect() {
        generation += 1
        teardown()
        lineBuffer = LineBuffer()
        lastSeq = nil
        continuation.yield(.state(.connecting))
        attemptConnect(gen: generation, attempt: 0)
    }

    private func attemptConnect(gen: UInt64, attempt: Int) {
        guard gen == generation else { return }

        // --- BSD AF_UNIX connect (fail-visible at every step) ---
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            let e = errno
            continuation.yield(.state(.disconnected(reason: "socket() errno \(e) (\(Self.errString(e)))")))
            return
        }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let maxLen = MemoryLayout.size(ofValue: addr.sun_path) - 1
        let bytes = Array(socketPath.utf8)
        guard bytes.count <= maxLen else {
            Darwin.close(fd)
            continuation.yield(.state(.disconnected(reason: "socket path too long (\(bytes.count) > \(maxLen))")))
            return
        }
        withUnsafeMutableBytes(of: &addr.sun_path) { dst in
            for (i, b) in bytes.enumerated() { dst[i] = b }
        }
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let rc = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, size)
            }
        }
        guard rc == 0 else {
            let e = errno
            Darwin.close(fd)
            // Daemon not accepting yet (ENOENT: socket file not created yet;
            // ECONNREFUSED: file present but not listening) -> bounded retry,
            // staying .connecting; after the deadline, fail-visible.
            if Self.isTransientConnectError(e), attempt + 1 < maxConnectAttempts {
                let delay = connectRetryNanos
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: delay)
                    await self?.attemptConnect(gen: gen, attempt: attempt + 1)
                }
                return
            }
            continuation.yield(.state(.disconnected(reason: "connect() errno \(e) after \(attempt + 1) attempts (\(Self.errString(e)))")))
            return
        }

        // --- non-blocking read pump ---
        // fcntl is fail-visible too: a blocking fd would let read() stall the
        // dispatch queue with no error/EOF/EAGAIN - the very silent-stall class
        // this atom kills (adversarial-review hardening, A1_38).
        let flags = fcntl(fd, F_GETFL, 0)
        guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) >= 0 else {
            let e = errno
            Darwin.close(fd)
            continuation.yield(.state(.disconnected(reason: "fcntl O_NONBLOCK errno \(e) (\(Self.errString(e)))")))
            return
        }
        let queue = DispatchQueue(label: "app.turingos.uds")
        let (signals, signalCont) = AsyncStream.makeStream(of: ReadSignal.self)
        let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        src.setEventHandler {
            var chunk = Data()
            var buf = [UInt8](repeating: 0, count: 1 << 16)
            readLoop: while true {
                let n = read(fd, &buf, buf.count)
                if n > 0 {
                    chunk.append(contentsOf: buf[0..<n])
                    // keep reading; EAGAIN/EWOULDBLOCK below is the authoritative
                    // drain signal (a short read does NOT prove the buffer is
                    // empty). DispatchSource is level-triggered, so order holds
                    // regardless, but draining fully here avoids extra wakeups.
                } else if n == 0 {
                    if !chunk.isEmpty { signalCont.yield(.data(chunk)) }
                    signalCont.yield(.closed(reason: "daemon closed the stream"))
                    return
                } else {
                    let e = errno
                    if e == EAGAIN || e == EWOULDBLOCK { break readLoop } // drained
                    if e == EINTR { continue readLoop }
                    if !chunk.isEmpty { signalCont.yield(.data(chunk)) }
                    signalCont.yield(.closed(reason: "read errno \(e) (\(Self.errString(e)))"))
                    return
                }
            }
            if !chunk.isEmpty { signalCont.yield(.data(chunk)) }
        }
        src.setCancelHandler {
            Darwin.close(fd) // sole fd owner - no double-close
            signalCont.finish()
        }
        readSource = src

        // Single ordered consumer: byte order is preserved by the FIFO
        // AsyncStream, so LineBuffer reassembly + the seq guard are exact.
        ioTask = Task { [weak self] in
            for await sig in signals {
                guard let self else { return }
                await self.handleSignal(sig, gen: gen)
            }
        }

        continuation.yield(.state(.connected))
        src.resume()
    }

    public func disconnect(reason: String) {
        generation += 1 // fence out all in-flight callbacks
        teardown()
        continuation.yield(.state(.disconnected(reason: reason)))
    }

    /// Cancel the read source (its cancel handler closes the fd and finishes
    /// the signal stream, which ends the consumer Task) and the consumer.
    private func teardown() {
        ioTask?.cancel()
        ioTask = nil
        readSource?.cancel()
        readSource = nil
    }

    private func handleSignal(_ sig: ReadSignal, gen: UInt64) {
        guard gen == generation else { return }
        switch sig {
        case .data(let data):
            for line in lineBuffer.append(data) where !line.isEmpty {
                do {
                    let envelope = try decoder.decode(EventEnvelope.self, from: line)
                    // Stream-integrity guard: the daemon promises strictly
                    // increasing seq; a violation means a lying/duplicated
                    // stream and must surface, not be shrugged off.
                    if let prev = lastSeq, envelope.seq <= prev {
                        disconnect(reason: "stream integrity: seq \(envelope.seq) after \(prev)")
                        return
                    }
                    lastSeq = envelope.seq
                    continuation.yield(.event(envelope))
                } catch {
                    disconnect(reason: "undecodable frame: \(error)")
                    return
                }
            }
        case .closed(let reason):
            disconnect(reason: reason)
        }
    }

    /// Transient = the daemon just isn't accepting yet; worth a bounded retry.
    private static func isTransientConnectError(_ e: Int32) -> Bool {
        e == ENOENT || e == ECONNREFUSED || e == EAGAIN || e == EWOULDBLOCK || e == EINTR
    }

    private static func errString(_ e: Int32) -> String {
        String(cString: strerror(e))
    }
}

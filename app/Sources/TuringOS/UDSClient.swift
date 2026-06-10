// UDS JSONL subscription client (ADR-005: the app is a pure projection
// consumer over the daemon's event stream). NWConnection-over-UDS was
// verified live before this atom opened (A1_05 card verified_external_facts).
//
// Ordering law (S-stage critique): state changes and envelopes are ONE
// totally-ordered stream. Two separate streams gave no happens-before
// between "connecting -> reset projection" and the replayed events, which
// could double-count or wipe the fold on reconnect. One stream, one order.
//
// Generation guard (S-stage critique): every connection attempt gets a
// generation token; callbacks from a previous generation are dropped, so
// "disconnected" is a terminal barrier - no envelope can arrive after it,
// and a re-entrant connect() cannot interleave two sockets into one buffer.

import Foundation
import Network

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
    private var connection: NWConnection?
    private var lineBuffer = LineBuffer()
    private var lastSeq: UInt64?
    private var generation: UInt64 = 0
    private let decoder = JSONDecoder()

    public let updates: AsyncStream<ClientUpdate>
    private let continuation: AsyncStream<ClientUpdate>.Continuation

    public init(socketPath: String) {
        self.socketPath = socketPath
        (updates, continuation) = AsyncStream.makeStream(of: ClientUpdate.self)
    }

    /// Re-entrant safe: tears down any previous connection (its callbacks
    /// are fenced out by the generation bump) and starts fresh. Fresh
    /// lastSeq is part of the contract - the daemon replays its retained
    /// log from its own seq floor on every connect.
    public func connect() {
        generation += 1
        connection?.cancel()
        lineBuffer = LineBuffer()
        lastSeq = nil
        continuation.yield(.state(.connecting))

        let gen = generation
        let conn = NWConnection(to: .unix(path: socketPath), using: .tcp)
        connection = conn
        conn.stateUpdateHandler = { [weak self] newState in
            guard let self else { return }
            Task { await self.handleState(newState, gen: gen) }
        }
        conn.start(queue: DispatchQueue(label: "app.turingos.uds"))
    }

    public func disconnect(reason: String) {
        generation += 1 // fence out all in-flight callbacks
        connection?.cancel()
        connection = nil
        continuation.yield(.state(.disconnected(reason: reason)))
    }

    private func handleState(_ newState: NWConnection.State, gen: UInt64) {
        guard gen == generation else { return }
        switch newState {
        case .ready:
            continuation.yield(.state(.connected))
            receiveLoop(gen: gen)
        case .failed(let error):
            disconnect(reason: "connection failed: \(error)")
        case .cancelled:
            // Reached only when the OS cancels outside disconnect(); our own
            // cancels bump the generation first and are fenced out here.
            disconnect(reason: "cancelled")
        default:
            break
        }
    }

    private func receiveLoop(gen: UInt64) {
        guard gen == generation, let conn = connection else { return }
        conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            Task {
                await self.handleReceive(data: data, isComplete: isComplete, error: error, gen: gen)
            }
        }
    }

    private func handleReceive(data: Data?, isComplete: Bool, error: NWError?, gen: UInt64) {
        guard gen == generation else { return }
        if let data, !data.isEmpty {
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
        }
        if isComplete {
            disconnect(reason: "daemon closed the stream")
            return
        }
        if let error {
            disconnect(reason: "receive error: \(error)")
            return
        }
        receiveLoop(gen: gen)
    }
}

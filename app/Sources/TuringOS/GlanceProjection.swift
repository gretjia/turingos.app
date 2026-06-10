// Client-side fold of the Glance three counts - the Swift mirror of
// daemon/src/projection.rs AggregateProjection. Cross-language drift is
// pinned by shared-fixture conservation tests: both mirrors fold the SAME
// committed fixtures and must produce the SAME counts (the Rust side's
// independent tally doubles as the gold standard here).

import Foundation

public struct GlanceProjection: Sendable, Equatable {
    public private(set) var activeSessions: UInt64 = 0
    public private(set) var pendingProposals: UInt64 = 0
    private var anomalies: [String: Bool] = [:]
    public private(set) var asOfSeq: UInt64 = 0

    public init() {}

    public var anomalousWorktrees: UInt64 {
        UInt64(anomalies.values.filter(\.self).count)
    }

    public mutating func apply(_ event: EventEnvelope) {
        switch event.kind {
        case .agentSessionStarted:
            activeSessions += 1
        case .agentSessionEnded:
            activeSessions = activeSessions > 0 ? activeSessions - 1 : 0
        case .proposalSubmitted:
            pendingProposals += 1
        case .proposalAccepted, .proposalRejected:
            pendingProposals = pendingProposals > 0 ? pendingProposals - 1 : 0
        case .worktreeDiscovered:
            if let id = event.payload["worktree_id"]?.stringValue {
                let anomalous = (event.payload["prunable"]?.boolValue ?? false)
                    || (event.payload["same_branch_conflict"]?.boolValue ?? false)
                    || event.payload["fingerprint_error"] != nil
                anomalies[id] = anomalous
            }
        case .worktreeRemoved:
            if let id = event.payload["worktree_id"]?.stringValue {
                anomalies.removeValue(forKey: id)
            }
        default:
            break
        }
        asOfSeq = max(asOfSeq, event.seq)
    }

    public static func fold(_ events: some Sequence<EventEnvelope>) -> GlanceProjection {
        var p = GlanceProjection()
        for e in events { p.apply(e) }
        return p
    }
}

/// @MainActor store SwiftUI views observe: connection state is a first-class
/// visible fact (gray 未对账 when disconnected - never silent). Consumes the
/// client's single totally-ordered update stream, so "connecting resets the
/// fold" and "replay refills it" can never race (S-stage critique fix).
@MainActor
public final class GlanceStore: ObservableObject {
    @Published public private(set) var projection = GlanceProjection()
    /// Latest-fact ledger feeding the Attention Stack (A1_08).
    @Published public private(set) var ledger = WorktreeLedger()
    @Published public private(set) var connection: ConnectionState = .disconnected(reason: "not started")
    @Published public private(set) var lastEventTs: String?
    /// Single derivation point: menubar dot, popover and home all read
    /// this one cached triage (S-stage: three per-frame re-derivations).
    @Published public private(set) var triage = AttentionTriage.derive(
        ledger: WorktreeLedger(), connection: .disconnected(reason: "not started"))

    private var client: UDSClient?
    private var consumer: Task<Void, Never>?

    public init() {}

    public func start(socketPath: String) {
        stop()
        projection = GlanceProjection()
        ledger = WorktreeLedger()
        let client = UDSClient(socketPath: socketPath)
        self.client = client
        consumer = Task { [weak self] in
            for await update in client.updates {
                guard let self else { return }
                switch update {
                case .state(let state):
                    self.connection = state
                    if case .connecting = state {
                        self.projection = GlanceProjection()
                        self.ledger = WorktreeLedger()
                    }
                case .event(let envelope):
                    self.projection.apply(envelope)
                    self.ledger.apply(envelope)
                    self.lastEventTs = envelope.ts
                }
                self.triage = AttentionTriage.derive(
                    ledger: self.ledger, connection: self.connection)
            }
        }
        Task { await client.connect() }
    }

    public func stop() {
        consumer?.cancel()
        consumer = nil
        let client = client
        Task { await client?.disconnect(reason: "stopped by user") }
        self.client = nil
    }
}

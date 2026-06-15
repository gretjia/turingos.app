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
    /// Same discipline for the radar: ONE cached scene per ledger change,
    /// never re-derived per frame in a view body.
    @Published public private(set) var radarScene = RadarScene.derive(ledger: WorktreeLedger())

    private var client: UDSClient?
    private var consumer: Task<Void, Never>?
    /// A1_56: reconnect supervisor — re-drives connect() after a LIVE stream
    /// drops. Lives here (not in UDSClient) so UDSClient's terminal-disconnect
    /// generation/ordering guarantees stay intact.
    private var supervisor: ReconnectSupervisor?

    /// The disconnect reason stop() uses; the supervisor treats it as
    /// user-initiated and does NOT reconnect (only daemon-side drops do).
    public nonisolated static let userStopReason = "stopped by user"

    public init() {}

    /// - Parameters:
    ///   - ensureDaemon: optional hook to (re)spawn a dead daemon before a
    ///     reconnect attempt. Injected by the app (= DaemonController.ensureRunning)
    ///     so GlanceStore stays decoupled from process management.
    ///   - socketIsLive: liveness probe used to gate reconnects; defaults to the
    ///     real witness-grade probe, injectable for deterministic tests.
    public func start(
        socketPath: String,
        ensureDaemon: (@MainActor () -> Void)? = nil,
        socketIsLive: (@MainActor (String) -> Bool)? = nil
    ) {
        stop()
        projection = GlanceProjection()
        ledger = WorktreeLedger()
        let client = UDSClient(socketPath: socketPath)
        self.client = client
        let liveProbe: @MainActor (String) -> Bool = socketIsLive ?? { DaemonController.socketIsLive($0) }
        let supervisor = ReconnectSupervisor(
            connect: { [weak client] in Task { await client?.connect() } },
            socketIsLive: { liveProbe(socketPath) },
            ensureDaemon: ensureDaemon
        )
        self.supervisor = supervisor
        consumer = Task { [weak self] in
            for await update in client.updates {
                guard let self else { return }
                switch update {
                case .state(let state):
                    self.connection = state
                    switch state {
                    case .connecting:
                        self.projection = GlanceProjection()
                        self.ledger = WorktreeLedger()
                    case .connected:
                        // Live stream restored — stop the reconnect backoff.
                        self.supervisor?.noteConnected()
                    case .disconnected(let reason):
                        // A live stream dropped (or initial connect failed):
                        // schedule a gated reconnect unless the user stopped us.
                        self.supervisor?.noteDisconnected(reason: reason)
                    }
                case .event(let envelope):
                    self.projection.apply(envelope)
                    self.ledger.apply(envelope)
                    self.lastEventTs = envelope.ts
                }
                self.triage = AttentionTriage.derive(
                    ledger: self.ledger, connection: self.connection)
                self.radarScene = RadarScene.derive(ledger: self.ledger)
            }
        }
        Task { await client.connect() }
    }

    public func stop() {
        supervisor?.markUserStopped()
        supervisor = nil
        consumer?.cancel()
        consumer = nil
        let client = client
        Task { await client?.disconnect(reason: Self.userStopReason) }
        self.client = nil
    }

    /// Manual 重连 affordance: reset the backoff and force one immediate,
    /// socket-liveness-gated attempt. Surfaced as a button in the disconnect banner.
    public func reconnect() {
        supervisor?.requestManual()
    }
}

/// A1_56: bounded-backoff reconnect supervisor, layered ABOVE UDSClient's
/// terminal disconnect (UDSClient is unchanged). Fail-visible discipline: it
/// NEVER hides the disconnected state — the honest banner stays until a real
/// `.connected` arrives; each attempt only fires when the socket is actually
/// accepting (witness-grade probe), never a swallowed `.waiting` spinner.
/// All side effects are injected closures, so the decision logic is unit-tested
/// without a real client/timer.
@MainActor
final class ReconnectSupervisor {
    private let connect: @MainActor () -> Void
    private let socketIsLive: @MainActor () -> Bool
    private let ensureDaemon: (@MainActor () -> Void)?
    private let sleepFor: (TimeInterval) async -> Void
    private(set) var attempt = 0
    private(set) var userStopped = false
    private var task: Task<Void, Never>?

    /// Exposed for deterministic tests: await the in-flight scheduled step.
    var inFlight: Task<Void, Never>? { task }

    init(
        connect: @escaping @MainActor () -> Void,
        socketIsLive: @escaping @MainActor () -> Bool,
        ensureDaemon: (@MainActor () -> Void)? = nil,
        sleepFor: @escaping (TimeInterval) async -> Void = {
            try? await Task.sleep(nanoseconds: UInt64(max($0, 0) * 1_000_000_000))
        }
    ) {
        self.connect = connect
        self.socketIsLive = socketIsLive
        self.ensureDaemon = ensureDaemon
        self.sleepFor = sleepFor
    }

    /// Bounded exponential backoff capped at 8s. Pure → directly testable.
    nonisolated static func backoff(attempt: Int) -> TimeInterval {
        let capped = min(max(attempt, 0), 4)
        return min(0.5 * pow(2.0, Double(capped)), 8.0)
    }

    /// User-initiated stop suppresses reconnect; daemon-side drops do not. Pure.
    nonisolated static func shouldReconnect(reason: String, userStopped: Bool) -> Bool {
        !userStopped && reason != GlanceStore.userStopReason
    }

    func noteConnected() {
        attempt = 0
        task?.cancel()
        task = nil
    }

    func noteDisconnected(reason: String) {
        guard Self.shouldReconnect(reason: reason, userStopped: userStopped) else { return }
        schedule()
    }

    func markUserStopped() {
        userStopped = true
        task?.cancel()
        task = nil
    }

    /// Force an immediate gated attempt (manual 重连): reset backoff + stop flag.
    func requestManual() {
        userStopped = false
        attempt = 0
        task?.cancel()
        task = Task { [weak self] in
            guard let self, !Task.isCancelled else { return }
            self.performStep()
        }
    }

    /// One reconnect step: revive a dead daemon via the injected hook if one is
    /// provided, then connect ONLY when the socket is actually accepting.
    /// Returns true iff a connect() was issued. Internal for unit tests.
    @discardableResult
    func performStep() -> Bool {
        if !socketIsLive() { ensureDaemon?() }
        guard socketIsLive() else { return false }
        connect()
        return true
    }

    private func schedule() {
        task?.cancel()
        let scheduledAttempt = attempt
        task = Task { [weak self] in
            guard let self else { return }
            await self.sleepFor(Self.backoff(attempt: scheduledAttempt))
            if Task.isCancelled || self.userStopped { return }
            self.attempt = min(self.attempt + 1, 5)
            if !self.performStep() {
                // Socket still dead — keep probing with capped backoff so the
                // stream self-heals when the daemon returns. Banner stays up.
                self.schedule()
            }
        }
    }
}

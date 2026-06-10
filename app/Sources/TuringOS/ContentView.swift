// Main-window shell skeleton: V6 sidebar structure (NAVIGATION_MODEL ten
// navs; only what P1 ships is enabled) + connection visibility. The radar
// canvas itself is A1_08 - this window proves the shell + live counts.

import SwiftUI

enum NavItem: String, CaseIterable, Identifiable {
    case globalOps = "Global Ops"
    case projects = "Projects"
    case worktreeRadar = "Worktree Radar"
    case missions = "Missions"
    case proposals = "Proposals"
    case identity = "Identity"
    case ratification = "Ratification"
    case replay = "Replay"
    case marketSignals = "Market Signals"
    case settings = "Settings"

    var id: String { rawValue }

    /// P1 read-only scope (V6_RECONCILIATION §2): everything else is
    /// visible-but-disabled, never hidden (failure/absence is a state).
    var enabledInP1: Bool {
        switch self {
        case .globalOps, .worktreeRadar, .settings: true
        default: false
        }
    }
}

struct ContentView: View {
    @ObservedObject var store: GlanceStore
    @State private var selection: NavItem? = .worktreeRadar
    @AppStorage("daemonSocketPath") private var socketPath = ""

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Workspace") {
                    navRow(.globalOps)
                    navRow(.projects)
                    navRow(.worktreeRadar)
                    navRow(.missions)
                    navRow(.proposals)
                }
                Section("Security & Trust") {
                    navRow(.identity)
                    navRow(.ratification)
                    navRow(.replay)
                }
                Section("Signals") {
                    navRow(.marketSignals)
                    navRow(.settings)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Tokens.Space.background)
        }
        .frame(minWidth: 960, minHeight: 600)
    }

    @ViewBuilder
    private func navRow(_ item: NavItem) -> some View {
        Text(item.rawValue)
            .font(Tokens.Typography.ui(13))
            .foregroundStyle(item.enabledInP1 ? Tokens.Text.primary : Tokens.Text.tertiary)
            .tag(item)
            .selectionDisabled(!item.enabledInP1)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .settings:
            SettingsPane(store: store, socketPath: $socketPath)
        default:
            VStack(spacing: 16) {
                ConnectionBadge(state: store.connection)
                GlanceMetrics(projection: store.projection)
                Text("Radar canvas lands in A1_08")
                    .font(Tokens.Typography.ui(12))
                    .foregroundStyle(Tokens.Text.tertiary)
            }
        }
    }
}

/// Connection visibility: gray badge with the literal reason - the user
/// always sees WHY data is stale (M2: no silent states).
struct ConnectionBadge: View {
    let state: ConnectionState

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(semantic.color).frame(width: 8, height: 8)
            Text(label)
                .font(Tokens.Typography.mono(11))
                .foregroundStyle(Tokens.Text.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Tokens.Space.glassBase, in: Capsule())
        .overlay(Capsule().stroke(Tokens.Space.glassBorder))
        .accessibilityLabel("daemon connection: \(label)")
    }

    private var semantic: Tokens.Semantic {
        switch state {
        case .connected: .blue
        case .connecting, .disconnected: .gray
        }
    }

    private var label: String {
        switch state {
        case .connected: "connected"
        case .connecting: "connecting…"
        case .disconnected(let reason): "disconnected — \(reason)"
        }
    }
}

struct GlanceMetrics: View {
    let projection: GlanceProjection

    var body: some View {
        HStack(spacing: 8) {
            metric(num: projection.activeSessions, label: "Active", semantic: .blue)
            metric(num: projection.pendingProposals, label: "Pending", semantic: .yellow)
            metric(num: projection.anomalousWorktrees, label: "Anomalous", semantic: .yellow)
        }
    }

    private func metric(num: UInt64, label: String, semantic: Tokens.Semantic) -> some View {
        VStack(spacing: 2) {
            Text(String(num))
                .font(Tokens.Typography.mono(18, weight: .semibold))
                .foregroundStyle(semantic.color)
            Text(label.uppercased())
                .font(Tokens.Typography.ui(10))
                .foregroundStyle(Tokens.Text.secondary)
        }
        .frame(width: 90)
        .padding(.vertical, 10)
        .background(Tokens.Space.glassBase, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Tokens.Space.glassBorder))
        .accessibilityLabel("\(label): \(num)")
    }
}

struct GlancePopover: View {
    @ObservedObject var store: GlanceStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Global Workspace")
                .font(Tokens.Typography.ui(13, weight: .semibold))
                .foregroundStyle(Tokens.Text.primary)
            GlanceMetrics(projection: store.projection)
            ConnectionBadge(state: store.connection)
            if let ts = store.lastEventTs {
                Text("last event \(ts)")
                    .font(Tokens.Typography.mono(10))
                    .foregroundStyle(Tokens.Text.tertiary)
            }
        }
        .padding(16)
        .frame(width: 340)
        .background(Tokens.Space.background)
    }
}

struct SettingsPane: View {
    @ObservedObject var store: GlanceStore
    @Binding var socketPath: String

    var body: some View {
        Form {
            Section("Daemon") {
                TextField("UDS socket path", text: $socketPath)
                    .font(Tokens.Typography.mono(12))
                HStack {
                    Button("Connect") { store.start(socketPath: socketPath) }
                        .disabled(socketPath.isEmpty)
                    Button("Disconnect") { store.stop() }
                }
                ConnectionBadge(state: store.connection)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 480)
    }
}

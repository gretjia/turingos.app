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
    // Landing screen == the Attention Stack home (S-stage blocker: the
    // atom's whole deliverable must be what the user opens into).
    @State private var selection: NavItem? = .globalOps
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
        case .worktreeRadar:
            VStack(spacing: 12) {
                Text("星系视图在 A1_09 点亮")
                    .font(Tokens.Typography.ui(12))
                    .foregroundStyle(Tokens.Text.tertiary)
            }
        default:
            // Home == the Attention Stack (Software 3.0 law 1: the screen
            // answers "do I need to act, and on what?" - nothing else).
            AttentionStackView(store: store)
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

// GlanceMetrics (the three-count grid) was DELETED in A1_08: the count
// grid is the dashboard anti-pattern the 五次裁决 outlawed. The Glance is
// now one dot + one sentence + (only when nonempty) the attention items.

struct GlancePopover: View {
    @ObservedObject var store: GlanceStore

    private static let maxItems = 4

    var body: some View {
        let triage = store.triage
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(triage.glanceSemantic.color)
                    .frame(width: 8, height: 8)
                Text(triage.glanceSentence)
                    .font(Tokens.Typography.ui(13, weight: .medium))
                    .foregroundStyle(Tokens.Text.primary)
            }
            .accessibilityElement(children: .combine)
            if !triage.needsYou.isEmpty {
                Divider()
                ForEach(triage.needsYou.prefix(Self.maxItems)) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: item.severity.iconName)
                            .font(.system(size: 9))
                            .foregroundStyle(item.severity.semantic.color)
                            .padding(.top, 2)
                        Text(item.sentence)
                            .font(Tokens.Typography.ui(11))
                            .foregroundStyle(Tokens.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(item.sentence)
                }
                // Truncation is VISIBLE (报忧义务): the popover never
                // pretends 4 items are the whole story.
                if triage.needsYou.count > Self.maxItems {
                    Text(Sentences.popoverOverflow(hidden: triage.needsYou.count - Self.maxItems))
                        .font(Tokens.Typography.ui(10))
                        .foregroundStyle(Tokens.Text.tertiary)
                }
            }
        }
        .padding(14)
        .frame(width: 320)
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

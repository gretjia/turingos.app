// Kernel debug pane (内核调试面): full-frame detail view + connection
// visibility. A1_30 (用户裁决 2026-06-12): the V6 left sidebar (split-view
// + List) is REMOVED — panel switching now arrives over the AppCommandBus
// from the macOS system menu bar (视图 menu). NavItem stays as the panel
// enumeration (NAVIGATION_MODEL ten navs; only what P1 ships is enabled).

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
    /// A1_30: panel switching arrives over the bus (视图 menu), not a sidebar.
    @EnvironmentObject private var commandBus: AppCommandBus
    // Landing screen == the Attention Stack home (S-stage blocker: the
    // atom's whole deliverable must be what the user opens into).
    @State private var selection: NavItem? = .globalOps
    /// Fly-to channel: an attention row hands its structured target here;
    /// the radar consumes it (focus + select) and clears it.
    @State private var radarFocus: AttentionTarget?
    @AppStorage("daemonSocketPath") private var socketPath = ""

    var body: some View {
        detail
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Tokens.Space.background)
            .frame(minWidth: 960, minHeight: 600)
            .onReceive(commandBus.$pending) { command in
                // @Published replays the current value on subscription, so a
                // command sent BEFORE this pane was presented still lands.
                guard let command else { return }
                var target = selection
                if Self.applyCommand(command, to: &target) {
                    selection = target
                    commandBus.consume()
                }
            }
    }

    // MARK: - Menu command mapping (A1_30)

    /// Pure command → panel mapping. `nonisolated static` so tests exercise
    /// it without SwiftUI rendering. Returns whether ContentView handled the
    /// command (unhandled commands belong to OrbView and stay on the bus).
    @discardableResult
    nonisolated static func applyCommand(_ command: AppCommand, to selection: inout NavItem?) -> Bool {
        switch command {
        case .showRadar:
            selection = .worktreeRadar
            return true
        case .showAttention:
            // Home == the Attention Stack (default detail branch).
            selection = .globalOps
            return true
        case .showCI:
            // P1 has no dedicated CI NavItem yet: CI evidence surfaces in
            // the attention stack home (visible-but-shared, never hidden).
            selection = .globalOps
            return true
        case .showKernelDebug:
            // ContentView IS the kernel debug pane — presentation is
            // OrbView's sheet; the current panel selection is kept.
            return true
        case .newInit, .connectRepo, .projectOverview, .showOrb,
             .runCICheck, .morningRitual:
            return false
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .settings:
            SettingsPane(store: store, socketPath: $socketPath)
        case .worktreeRadar:
            RadarCanvasView(store: store, focus: $radarFocus)
        default:
            // Home == the Attention Stack (Software 3.0 law 1: the screen
            // answers "do I need to act, and on what?" - nothing else).
            // Tapping a row flies to its node in the galaxy (charter:
            // 注意力项从 Home 点入时直接飞到对应节点并聚焦).
            AttentionStackView(store: store) { target in
                radarFocus = target
                selection = .worktreeRadar
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

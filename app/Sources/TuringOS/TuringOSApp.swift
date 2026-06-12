// TuringOS.app entry. A1_05 scope: MenuBarExtra Glance + main-window shell
// skeleton wired to the daemon event stream. `--probe <socket>` runs a
// headless one-envelope smoke (machine JSONL on stdout, CLI_ABI discipline)
// so CI and the shipgate can exercise the real client path without a GUI.

import SwiftUI

@main
struct TuringOSMain {
    static func main() {
        let args = CommandLine.arguments
        if args.count >= 3, args[1] == "--probe" {
            probeMain(socketPath: args[2])
            return
        }
        // Headless onboarding coupling probe (A1_07): exercise the REAL
        // catalog->entries->write path for one local repo. build_app.sh's
        // registry wire-probe chains this with `turingosd serve --registry`
        // and asserts the daemon announces the Swift-written project.
        if args.count >= 4, args[1] == "--onboard-probe" {
            let item = CatalogItem(
                displayName: URL(fileURLWithPath: args[2]).lastPathComponent,
                remoteKey: nil, localPath: args[2], pushedAt: nil
            )
            do {
                try RegistryWriter.write(
                    projects: RegistryWriter.entries(from: [item]),
                    to: URL(fileURLWithPath: args[3])
                )
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("onboard-probe: \(error)\n".utf8))
                exit(1)
            }
        }
        TuringOSApp.main()
    }

    /// Headless smoke: connect, print the first envelope as JSONL, exit 0;
    /// any failure is a visible nonzero exit (fail-closed, never hang).
    static func probeMain(socketPath: String) {
        let sema = DispatchSemaphore(value: 0)
        let box = ProbeBox()
        let client = UDSClient(socketPath: socketPath)
        let reader = Task {
            for await update in client.updates {
                switch update {
                case .event(let envelope):
                    box.set(envelope)
                    sema.signal()
                    return
                case .state(.disconnected(let reason)):
                    FileHandle.standardError.write(Data("probe: \(reason)\n".utf8))
                    sema.signal()
                    return
                case .state:
                    continue
                }
            }
        }
        Task { await client.connect() }
        let outcome = sema.wait(timeout: .now() + 10)
        reader.cancel()
        guard outcome == .success, let envelope = box.get() else {
            FileHandle.standardError.write(Data("probe: no envelope within 10s\n".utf8))
            exit(1)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let line = try? encoder.encode(envelope) else { exit(1) }
        FileHandle.standardOutput.write(line)
        FileHandle.standardOutput.write(Data("\n".utf8))
        exit(0)
    }
}

/// Tiny lock box so the probe can pass the envelope across concurrency
/// domains without an actor hop in a synchronous main.
final class ProbeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var envelope: EventEnvelope?
    func set(_ e: EventEnvelope) {
        lock.lock()
        defer { lock.unlock() }
        envelope = e
    }
    func get() -> EventEnvelope? {
        lock.lock()
        defer { lock.unlock() }
        return envelope
    }
}

struct TuringOSApp: App {
    @StateObject private var store = GlanceStore()
    @StateObject private var daemon = DaemonController()
    /// A1_30: menu bar → views command channel. The sidebar is gone; the
    /// macOS system menu bar is the quiet discoverability escape hatch
    /// (docs/02 §6) and the bus is its only delivery path.
    @StateObject private var commandBus = AppCommandBus()
    /// Onboarded == the registry exists (one source of truth, no flag).
    @State private var onboarded = FileManager.default
        .fileExists(atPath: Workspace.registryURL.path)
    @AppStorage("daemonBinaryPath") private var daemonBinaryPath = ""

    var body: some Scene {
        // WindowGroup MUST be the first scene: SwiftUI launches into the
        // first scene in body, and a leading MenuBarExtra leaves the app
        // running with ZERO windows (A1_10 - lsappinfo-proven on the real
        // bundle; the headless probes never caught it because they never
        // open a GUI).
        //
        // A1_16: First screen is OrbView (docs/02 §2.1 — P4 UI constitution).
        // Existing onboarding gate preserved. A1_30: ContentView (内核调试面)
        // is reachable via the 视图 menu (⌘D formal entry) through the
        // AppCommandBus; the sidebar is gone.
        WindowGroup("TuringOS") {
            Group {
                if onboarded {
                    OrbView(store: store)
                        .preferredColorScheme(.dark)
                        .task { startWorkspace() }
                } else {
                    OnboardingView {
                        onboarded = true
                        startWorkspace()
                    }
                }
            }
            .environmentObject(commandBus)
        }
        .commands {
            // A1_30: system menu bar replaces the sidebar. Menu items only
            // publish onto the AppCommandBus — views consume (no direct
            // navigation from the scene; pure state, testable).
            // 立项 owns ⌘N per charter: replace the default File > New
            // Window item so the chartered shortcut reaches 立项 instead
            // of spawning windows (menus match key equivalents in order;
            // File precedes the custom menus).
            CommandGroup(replacing: .newItem) {}
            CommandMenu("项目") {
                commandButton(.newInit)          // 立项 ⌘N
                commandButton(.connectRepo)      // 连接仓库 ⌘O
                commandButton(.projectOverview)  // 项目总览 ⌘1
            }
            CommandMenu("视图") {
                commandButton(.showOrb)          // Orb 主屏 ⌘0
                commandButton(.showKernelDebug)  // 内核调试面 ⌘D（暗捷径升级为正式菜单项）
                commandButton(.showRadar)
                commandButton(.showAttention)
                commandButton(.showCI)
            }
            CommandMenu("检查") {
                commandButton(.runCICheck)       // CI 检查 ⌘R
                commandButton(.morningRitual)    // Morning Ritual ⌘M
            }
        }

        MenuBarExtra {
            GlancePopover(store: store)
        } label: {
            // The dot = the whole product compressed to one pixel cluster:
            // gray whenever the stream is not live (未对账 overrides all),
            // else the worst triage level (red failure / yellow decision /
            // blue ambient-or-quiet) - same derivation as home & popover.
            Image(systemName: "circle.fill")
                .foregroundStyle(menubarSemantic.color)
        }
        .menuBarExtraStyle(.window)
    }

    /// One menu item == one bus command. Title + shortcut key are data on
    /// AppCommand (single source of truth; the tests assert the charter).
    @ViewBuilder
    private func commandButton(_ command: AppCommand) -> some View {
        if let key = command.keyboardShortcutKey {
            Button(command.menuTitle) { commandBus.send(command) }
                .keyboardShortcut(KeyEquivalent(key), modifiers: [.command])
        } else {
            Button(command.menuTitle) { commandBus.send(command) }
        }
    }

    private func startWorkspace() {
        daemon.ensureRunning(daemonPath: daemonBinaryPath.isEmpty ? nil : daemonBinaryPath)
        store.start(socketPath: Workspace.socketPath)
    }

    /// One law, three surfaces: dot, popover and home all read the store's
    /// single cached triage.
    private var menubarSemantic: Tokens.Semantic {
        store.triage.glanceSemantic
    }
}

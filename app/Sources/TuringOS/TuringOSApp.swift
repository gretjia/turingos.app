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

    var body: some Scene {
        MenuBarExtra {
            GlancePopover(store: store)
        } label: {
            // Health dot semantics: worst level across the product
            // (gray = disconnected/unreconciled, yellow = anomalies, blue = healthy+active)
            Image(systemName: "circle.fill")
                .foregroundStyle(menubarSemantic.color)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("TuringOS") {
            ContentView(store: store)
                .preferredColorScheme(.dark)
        }
    }

    private var menubarSemantic: Tokens.Semantic {
        switch store.connection {
        case .connected:
            store.projection.anomalousWorktrees > 0 ? .yellow : .blue
        case .connecting, .disconnected:
            .gray
        }
    }
}

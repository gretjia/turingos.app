// Workspace plumbing (A1_07): registry writing (the daemon's A1_06 format,
// byte-shape pinned by tests) + daemon lifecycle (spawn-or-connect with the
// state always visible as a sentence).

import AppKit
import Foundation

public enum Workspace {
    public static var supportDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TuringOS", isDirectory: true)
    }

    public static var registryURL: URL { supportDir.appendingPathComponent("projects.json") }
    public static var socketPath: String { supportDir.appendingPathComponent("daemon.sock").path }
}

// MARK: - Registry writing (mirror of daemon/src/registry.rs RegistryFile)

public struct RegistryProject: Codable, Equatable, Sendable {
    public let projectId: String
    public let path: String?
    public let remote: String?

    enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case path, remote
    }
}

public enum RegistryWriter {
    /// Same identifier DISCIPLINE as the daemon (events.rs sanitize_id):
    /// lowercase [a-z0-9_]. Not byte-identical on exotic Unicode (Swift
    /// folds per-grapheme, Rust per-scalar - e.g. combining marks); harmless
    /// because the daemon stores project_id verbatim from the registry and
    /// only re-sanitizes when deriving event_ids.
    public static func sanitizeProjectId(_ s: String) -> String {
        var out = String(s.lowercased().map { c in
            (c.isASCII && (c.isLowercase || c.isNumber)) ? c : "_"
        })
        if out.isEmpty { out = "x" }
        return out
    }

    /// Selection -> registry entries: ids unique (suffix on collision),
    /// paths passed through (daemon canonicalizes + enforces uniqueness -
    /// its rejections are visible, we don't duplicate its law here).
    public static func entries(from selection: [CatalogItem]) -> [RegistryProject] {
        var used = Set<String>()
        return selection.map { item in
            let base = sanitizeProjectId(
                item.remoteKey.map { String($0.split(separator: "/").last ?? "x") }
                    ?? item.displayName
            )
            var id = base
            var n = 2
            while used.contains(id) {
                id = "\(base)_\(n)"
                n += 1
            }
            used.insert(id)
            return RegistryProject(projectId: id, path: item.localPath, remote: item.remoteKey)
        }
    }

    public static func registryJSON(projects: [RegistryProject]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        struct File: Codable {
            let version: Int
            let projects: [RegistryProject]
        }
        return try encoder.encode(File(version: 1, projects: projects))
    }

    /// Atomic write (temp + rename) so the daemon's hot reload never reads
    /// a half-written registry.
    public static func write(projects: [RegistryProject], to url: URL = Workspace.registryURL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let tmp = url.deletingLastPathComponent()
            .appendingPathComponent(".projects.json.tmp")
        try registryJSON(projects: projects).write(to: tmp)
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
    }
}

// MARK: - Daemon lifecycle

/// Spawn-or-connect with a visible sentence per state. The daemon is a
/// child process in P1 dev reality (launchd packaging is a P1-close-out
/// concern). Two S-stage blockers shaped this type:
/// - On Darwin a child does NOT die with its parent, so app termination
///   explicitly terminates the child (willTerminate observer below) -
///   no orphan keeps re-reading the registry forever.
/// - A live daemon already on the socket (external or prior orphan) is
///   ADOPTED, never re-spawned: combined with bind_socket's liveness
///   refusal on the daemon side, the socket cannot be stolen into a
///   split brain. The registry + git remain the truth either way (ADR-003).
@MainActor
public final class DaemonController: ObservableObject {
    @Published public private(set) var sentence = "daemon 未启动"
    private var process: Process?
    private var terminationObserver: NSObjectProtocol?

    public init() {
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Synchronous on purpose: the app is dying right now.
            self?.process?.terminate()
        }
    }

    /// True when something is accepting on the UDS path (a connect probe -
    /// witness-grade liveness, not a file-exists name match).
    public static func socketIsLive(_ path: String) -> Bool {
        let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { Darwin.close(fd) }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let maxLen = MemoryLayout.size(ofValue: addr.sun_path) - 1
        let bytes = Array(path.utf8)
        guard bytes.count <= maxLen else { return false }
        withUnsafeMutableBytes(of: &addr.sun_path) { dst in
            for (i, b) in bytes.enumerated() {
                dst[i] = b
            }
        }
        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, size)
            }
        }
        return result == 0
    }

    /// Daemon binary discovery: explicit setting -> dev tree convention.
    public static func findDaemon(explicit: String?) -> String? {
        var candidates: [String] = []
        if let explicit, !explicit.isEmpty { candidates.append(explicit) }
        candidates.append(
            FileManager.default.currentDirectoryPath + "/daemon/target/debug/turingosd")
        candidates.append("\(NSHomeDirectory())/Developer/turingos.app/daemon/target/debug/turingosd")
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    public func ensureRunning(daemonPath: String?) {
        if process?.isRunning == true {
            sentence = "daemon 运行中"
            return
        }
        // Adopt a live daemon instead of racing it for the socket.
        if Self.socketIsLive(Workspace.socketPath) {
            sentence = "已连接到现有 daemon"
            return
        }
        guard let bin = Self.findDaemon(explicit: daemonPath) else {
            sentence = "找不到 turingosd（在设置里指定路径）"
            return
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = ["serve", "--registry", Workspace.registryURL.path, Workspace.socketPath]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        p.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                self?.sentence = "daemon 退出（status \(proc.terminationStatus)）"
            }
        }
        do {
            try p.run()
            process = p
            sentence = "daemon 已拉起（registry 模式）"
        } catch {
            sentence = "daemon 启动失败：\(error.localizedDescription)"
        }
    }

    public func stop() {
        process?.terminate()
        process = nil
        sentence = "daemon 已停止"
    }
}

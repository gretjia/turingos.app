// Connect level detection (R1_auth_memo §1 三级降档, A1_07 scope ruling):
// L-gh (reuse the user's gh CLI login - zero secrets, zero keychain writes,
// token re-derived per launch and NEVER persisted by us) -> Device Flow
// (visible "unconfigured" placeholder until a client_id is provisioned -
// consultation item) -> local-only. Every demotion carries a visible,
// structured reason (fail-visible; MANIFESTO 报忧义务).

import Foundation

/// Subprocess seam so the detection state machine is unit-testable without
/// a real gh binary.
public protocol ProcessRunner: Sendable {
    /// Returns (exitCode, stdout, stderr).
    func run(_ executable: String, _ arguments: [String]) throws -> (Int32, Data, Data)
}

public struct SystemProcessRunner: ProcessRunner {
    /// Wall-clock ceiling: a hung `gh` must never pin the caller (and thus
    /// the onboarding "接入" button) forever (MANIFESTO fail-visible).
    public static let timeoutSeconds = 15

    public init() {}

    /// Thread-safe one-shot box for a pipe's drained bytes (two concurrent
    /// drains write, the caller reads after the DispatchGroup barrier).
    private final class DataBox: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()
        func set(_ d: Data) { lock.lock(); data = d; lock.unlock() }
        func get() -> Data { lock.lock(); defer { lock.unlock() }; return data }
    }

    public func run(_ executable: String, _ arguments: [String]) throws -> (Int32, Data, Data) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        p.standardOutput = out
        p.standardError = err

        // Drain BOTH pipes concurrently: reading stdout to EOF while the
        // child blocks writing a full (64KB) stderr pipe is a classic
        // deadlock. A concurrent queue + group removes the ordering hazard.
        let outBox = DataBox()
        let errBox = DataBox()
        let group = DispatchGroup()
        let ioQueue = DispatchQueue(label: "app.turingos.gitconnect.io", attributes: .concurrent)

        // terminationHandler + semaphore (don't mix with waitUntilExit).
        let done = DispatchSemaphore(value: 0)
        p.terminationHandler = { _ in done.signal() }

        try p.run()

        group.enter()
        ioQueue.async { outBox.set(out.fileHandleForReading.readDataToEndOfFile()); group.leave() }
        group.enter()
        ioQueue.async { errBox.set(err.fileHandleForReading.readDataToEndOfFile()); group.leave() }

        let deadline = DispatchTime.now() + .seconds(Self.timeoutSeconds)
        if done.wait(timeout: deadline) == .timedOut {
            p.terminate()   // SIGTERM; closes the child's write ends -> drains return
            // Escalate if the child ignores SIGTERM, so the wall-clock ceiling
            // is a real bound, not a hope (adversarial-review hardening, A1_38).
            if done.wait(timeout: .now() + .seconds(2)) == .timedOut {
                kill(p.processIdentifier, SIGKILL)
                done.wait()
            }
        }
        group.wait()        // both pipes fully drained
        return (p.terminationStatus, outBox.get(), errBox.get())
    }
}

/// The connect outcome - one sentence per level (language-first law).
/// Deliberately token-free (S-stage risk: this enum flows into @Published
/// UI state, which is reflectable via Mirror/dump - the secret must never
/// ride along). The token travels separately in ConnectResult and stays in
/// a non-published local.
public enum ConnectLevel: Equatable, Sendable {
    /// gh CLI login reused; token re-derived per launch, never persisted.
    case ghCli(login: String, scopes: String)
    /// Device Flow exists as a visible placeholder until a GitHub OAuth App
    /// client_id is provisioned (stop-point consultation item on the card).
    case deviceFlowUnconfigured(demotedFrom: String)
    /// Pure local mode - repo discovery only, no GitHub API.
    case localOnly(reason: String)

    /// The single status sentence the Connect screen shows (语言优先).
    public var sentence: String {
        switch self {
        case .ghCli(let login, _):
            "已通过 gh 接入 GitHub（@\(login)）"
        case .deviceFlowUnconfigured(let from):
            "\(from)；GitHub 联网授权待配置（需要 OAuth App client_id），先以本地模式继续"
        case .localOnly(let reason):
            "本地模式（\(reason)）"
        }
    }
}

/// Detection outcome: display-safe level + the session token kept apart.
public struct ConnectResult: Sendable {
    public let level: ConnectLevel
    public let token: String?
}

public enum GitConnect {
    /// Probe order pinned by R1_auth_memo §2 + on-machine facts (gh 2.92.0
    /// at /opt/homebrew/bin; sandbox-narrow PATH means explicit candidates).
    public static let ghCandidates = [
        "/opt/homebrew/bin/gh",
        "/usr/local/bin/gh",
        "\(NSHomeDirectory())/.local/bin/gh",
    ]

    public static func detect(runner: ProcessRunner = SystemProcessRunner()) -> ConnectResult {
        guard let gh = ghCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return ConnectResult(
                level: .deviceFlowUnconfigured(demotedFrom: "未发现 gh CLI"), token: nil)
        }
        // Dual criterion per memo (§6.2 belt): exit != 0 OR empty stdout
        // both mean "no usable login".
        guard let (code, out, _) = try? runner.run(gh, ["auth", "token"]),
              code == 0,
              let token = String(data: out, encoding: .utf8)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              !token.isEmpty
        else {
            return ConnectResult(
                level: .deviceFlowUnconfigured(demotedFrom: "gh 未登录"), token: nil)
        }

        // Identity + scopes from the on-machine-verified --json hosts schema
        // (hosts.{host}[] = {state,active,login,scopes,...}).
        var login = "github"
        var scopes = ""
        if let (sCode, sOut, _) = try? runner.run(gh, ["auth", "status", "--json", "hosts"]),
           sCode == 0,
           let parsed = try? JSONSerialization.jsonObject(with: sOut) as? [String: Any],
           let hosts = parsed["hosts"] as? [String: Any],
           let entries = hosts["github.com"] as? [[String: Any]],
           let active = entries.first(where: { ($0["active"] as? Bool) == true }) ?? entries.first {
            login = (active["login"] as? String) ?? login
            scopes = (active["scopes"] as? String) ?? ""
        }
        return ConnectResult(level: .ghCli(login: login, scopes: scopes), token: token)
    }
}

/// Normalized GitHub remote identity: `github.com/owner/repo` (lowercased,
/// `.git` stripped). SSH and HTTPS forms of one repo collapse to one key
/// (R1_auth_memo §4).
public func normalizeGitHubRemote(_ url: String) -> String? {
    let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
    var rest: String?
    if let r = trimmed.range(of: "git@github.com:") {
        rest = String(trimmed[r.upperBound...])
    } else if let r = trimmed.range(of: "ssh://git@github.com/") {
        rest = String(trimmed[r.upperBound...])
    } else if let r = trimmed.range(of: "https://github.com/") {
        rest = String(trimmed[r.upperBound...])
    } else if let r = trimmed.range(of: "http://github.com/") {
        rest = String(trimmed[r.upperBound...])
    }
    guard var path = rest else { return nil }
    if path.hasSuffix(".git") { path.removeLast(4) }
    while path.hasSuffix("/") { path.removeLast() }
    let parts = path.split(separator: "/")
    guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
    return "github.com/\(parts[0])/\(parts[1])".lowercased()
}

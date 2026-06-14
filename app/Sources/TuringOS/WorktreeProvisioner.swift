// WorktreeProvisioner.swift — A1_40: 回路2 write-side entry point.
//
// Real `git worktree add` for a project repo, into an app-controlled worktrees
// root, via the established Process/git seam (mirrors ShadowWorkspace's
// commands-as-data whitelist + path-containment guard + hermetic env, and
// A1_38's concurrent-pipe-drain + timeout to avoid the 64KB-stderr deadlock
// that `git worktree add`'s verbose "Updating files: N%" progress would
// otherwise trigger).
//
// SAFETY BOUNDARY:
//   - Creates worktrees ONLY under <app-support>/TuringOS/worktrees/<project>/<dir>.
//     The target path must canonicalize INSIDE that root (absolute names refused;
//     ".." neutralised by sanitisation — it can never escape the root).
//   - NEW BRANCH ONLY: always `-b <branch>`; refuses if the branch already exists
//     (no overwrite of an existing branch / no second checkout of a live branch).
//   - Verb whitelist: worktree add/list + rev-parse ONLY. NEVER push/remote/clone/
//     fetch/pull/merge/reset/rebase/rm. (ShadowWorkspace FORBIDS "worktree"; this
//     module is the sanctioned place that ALLOWS worktree add/list.)
//   - Class-1 reversible-local action (WHITEPAPER §13.3): a worktree is a checkout,
//     removable with `git worktree remove`. It does NOT mutate the project's
//     branches/HEAD and pushes nothing.
//   - The daemon's existing reconcile observes the new worktree (`git worktree
//     list`) and emits WorktreeDiscovered → the app renders it as a RadarNode.
//     No daemon/radar change is needed (verified 2026-06-14).

import Foundation

// MARK: - Commands-as-data whitelist (test-enumerable)

public struct WorktreeGitSpec: Sendable, Equatable {
    public let tag: String
    public let baseArgs: [String]
    public var verb: String { baseArgs.first(where: { !$0.hasPrefix("-") }) ?? baseArgs.first ?? "" }

    public init(tag: String, baseArgs: [String]) {
        self.tag = tag
        self.baseArgs = baseArgs
    }

    /// Every git command WorktreeProvisioner may invoke (variable parts appended
    /// at call time). Tests enumerate this to assert the verb whitelist.
    public static let allSpecs: [WorktreeGitSpec] = [
        WorktreeGitSpec(tag: "git:worktree:add", baseArgs: ["worktree", "add"]),
        WorktreeGitSpec(tag: "git:worktree:list", baseArgs: ["worktree", "list", "--porcelain"]),
        WorktreeGitSpec(tag: "git:rev-parse:branch", baseArgs: ["rev-parse", "--verify", "--quiet"]),
    ]

    /// Strictly forbidden verbs (enumerated by tests). "worktree" is ALLOWED here.
    public static let forbiddenVerbs: Set<String> = [
        "push", "remote", "clone", "fetch", "pull",
        "merge", "reset", "rebase", "rm", "checkout", "commit", "branch", "tag", "gc", "prune",
    ]

    /// Allowed `worktree` subcommands — add/list only (no remove/move/prune).
    public static let allowedWorktreeSubcommands: Set<String> = ["add", "list"]
}

// MARK: - Errors

public enum WorktreeProvisionError: Error, Equatable, Sendable {
    case outsideWorktreeRoot(path: String, root: String)
    case branchAlreadyExists(branch: String)
    case gitCommandFailed(tag: String, exit: Int32, stderr: String)
    case worktreeNotListed(path: String)
}

// MARK: - Runner seam

public protocol RepoGitRunner: Sendable {
    /// Run git `args` with `repo` as the working directory.
    /// Returns (exitCode, trimmed stdout, trimmed stderr).
    func run(args: [String], inRepo repo: URL) throws -> (Int32, String, String)
}

/// Real runner: /usr/bin/git, hermetic env, concurrent pipe drain + wall-clock
/// ceiling with SIGTERM→SIGKILL escalation (A1_38 lesson: sequential pipe reads
/// deadlock on `git worktree add`'s large stderr progress).
public struct LiveRepoGitRunner: RepoGitRunner, Sendable {
    public static let timeoutSeconds = 120 // worktree add checks out the whole tree

    private final class DataBox: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()
        func set(_ d: Data) { lock.lock(); data = d; lock.unlock() }
        func get() -> Data { lock.lock(); defer { lock.unlock() }; return data }
    }

    public init() {}

    public func run(args: [String], inRepo repo: URL) throws -> (Int32, String, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = args
        p.currentDirectoryURL = repo
        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe
        var env = ProcessInfo.processInfo.environment
        env["GIT_CONFIG_GLOBAL"] = "/dev/null"
        env["GIT_CONFIG_SYSTEM"] = "/dev/null"
        env["GIT_TERMINAL_PROMPT"] = "0"
        p.environment = env

        let outBox = DataBox()
        let errBox = DataBox()
        let group = DispatchGroup()
        let q = DispatchQueue(label: "app.turingos.worktree.io", attributes: .concurrent)
        let done = DispatchSemaphore(value: 0)
        p.terminationHandler = { _ in done.signal() }

        try p.run()
        group.enter()
        q.async { outBox.set(outPipe.fileHandleForReading.readDataToEndOfFile()); group.leave() }
        group.enter()
        q.async { errBox.set(errPipe.fileHandleForReading.readDataToEndOfFile()); group.leave() }

        if done.wait(timeout: .now() + .seconds(Self.timeoutSeconds)) == .timedOut {
            p.terminate()
            if done.wait(timeout: .now() + .seconds(2)) == .timedOut {
                kill(p.processIdentifier, SIGKILL)
                done.wait()
            }
        }
        group.wait()

        let out = (String(data: outBox.get(), encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let err = (String(data: errBox.get(), encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (p.terminationStatus, out, err)
    }
}

// MARK: - Provisioner

public struct WorktreeProvisioner: Sendable {
    /// App-controlled root for all created worktrees.
    public static func worktreesRoot() -> URL {
        Workspace.supportDir.appendingPathComponent("worktrees", isDirectory: true)
    }

    /// Sanitise one path component: keep only safe chars, neutralise "..", strip
    /// leading dots. Guarantees the component cannot traverse out of its parent.
    static func sanitizeComponent(_ s: String) -> String {
        var out = String(s.map { c -> Character in
            (c.isLetter || c.isNumber || c == "-" || c == "_" || c == ".") ? c : "-"
        })
        while out.contains("..") { out = out.replacingOccurrences(of: "..", with: "-") }
        while out.hasPrefix(".") { out.removeFirst() }
        return out.isEmpty ? "x" : out
    }

    public struct Provisioned: Equatable, Sendable {
        public let path: URL
        public let branch: String
        public let base: String
    }

    /// Provision a new worktree for `projectRepo` on a fresh branch. `root` is the
    /// allowed worktrees root (injectable for tests). Synchronous + blocking —
    /// callers MUST dispatch off the main thread.
    @discardableResult
    public static func provision(
        projectRepo: URL,
        projectId: String,
        newBranch: String,
        base: String,
        root: URL = worktreesRoot(),
        runner: RepoGitRunner = LiveRepoGitRunner()
    ) throws -> Provisioned {
        // Absolute names refused outright (a leading "/" is an escape attempt).
        guard !newBranch.hasPrefix("/"), !projectId.hasPrefix("/") else {
            throw WorktreeProvisionError.outsideWorktreeRoot(path: newBranch, root: root.path)
        }

        let projComp = sanitizeComponent(projectId)
        let branchDir = sanitizeComponent(newBranch.replacingOccurrences(of: "/", with: "-"))
        let target = root
            .appendingPathComponent(projComp, isDirectory: true)
            .appendingPathComponent(branchDir, isDirectory: true)
            .standardized

        // Path-containment guard: target MUST be inside root (belt + suspenders
        // over sanitisation).
        let resolvedRoot = root.resolvingSymlinksInPath().standardized.path
        guard target.path == resolvedRoot || target.path.hasPrefix(resolvedRoot + "/") else {
            throw WorktreeProvisionError.outsideWorktreeRoot(path: target.path, root: resolvedRoot)
        }

        // New-branch-only: refuse if the branch already exists (exit 0 = exists).
        let (existsCode, _, _) = try runner.run(
            args: ["rev-parse", "--verify", "--quiet", "refs/heads/\(newBranch)"], inRepo: projectRepo)
        if existsCode == 0 {
            throw WorktreeProvisionError.branchAlreadyExists(branch: newBranch)
        }

        try FileManager.default.createDirectory(
            at: target.deletingLastPathComponent(), withIntermediateDirectories: true)

        // git worktree add <target> -b <newBranch> <base>
        let (addCode, _, addErr) = try runner.run(
            args: ["worktree", "add", target.path, "-b", newBranch, base], inRepo: projectRepo)
        guard addCode == 0 else {
            throw WorktreeProvisionError.gitCommandFailed(tag: "git:worktree:add", exit: addCode, stderr: addErr)
        }

        // Verify it shows in the worktree list (real, not assumed).
        let (listCode, listOut, listErr) = try runner.run(
            args: ["worktree", "list", "--porcelain"], inRepo: projectRepo)
        guard listCode == 0 else {
            throw WorktreeProvisionError.gitCommandFailed(tag: "git:worktree:list", exit: listCode, stderr: listErr)
        }
        let targetResolved = target.resolvingSymlinksInPath().standardized.path
        let listed = listOut.split(separator: "\n").contains { line in
            guard line.hasPrefix("worktree ") else { return false }
            let p = String(line.dropFirst("worktree ".count))
            return URL(fileURLWithPath: p).resolvingSymlinksInPath().standardized.path == targetResolved
        }
        guard listed else {
            throw WorktreeProvisionError.worktreeNotListed(path: target.path)
        }

        return Provisioned(path: target, branch: newBranch, base: base)
    }
}

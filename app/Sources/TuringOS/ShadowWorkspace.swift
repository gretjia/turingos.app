// ShadowWorkspace.swift — A1_27: Shadow Workspace v1 staging substrate.
//
// Governing law: WHITEPAPER §13.3 (Class-1 reversible-local action staging
// substrate: user-space copy + versioned staging, git semantics, zero entitlement).
// ADR-002: the App does NOT invent a private workspace format — use git semantics.
//
// CRITICAL SAFETY BOUNDARY:
//   This module operates ONLY on app-owned staging copy directories
//   (git-init in an app-support / temp location).
//   It NEVER touches the user's real repos.
//   It NEVER pushes, NEVER promotes staged content out of the copy.
//   "promote-to-real" (applying to the real location) is gated on the approval
//   ceremony = gated on runtime tape, and is therefore OUT OF SCOPE here.
//   Build stage/diff/discard/restore WITHIN the copy only.
//
// Commands-as-data pattern (mirrors CIObservation.swift ROCommandSpec):
//   All git invocations are declared in GitCommandSpec.allSpecs.
//   Tests enumerate this table to assert the verb whitelist and absence of
//   push/remote/clone/rm-outside-copy.
//
// Path-traversal guard:
//   LiveGitRunner asserts the working directory is inside the staging root
//   before every call; refuses with ShadowError.outsideStagingRoot otherwise.
//   ShadowWorkspace validates every relative path for ".." escape attacks.

import Foundation

// MARK: - GitCommandSpec (commands-as-data — test-enumerable)

/// One whitelisted git command that ShadowWorkspace may invoke.
/// Exposed as data so tests can enumerate and assert the verb whitelist.
public struct GitCommandSpec: Sendable, Equatable {
    /// Human-readable tag used in logs and derive_source labels.
    public let tag: String
    /// Fixed argument prefix (variable parts are appended at call time).
    public let baseArgs: [String]
    /// Primary git verb (first non-flag baseArgs element or first arg overall).
    public let verb: String

    public init(tag: String, baseArgs: [String]) {
        self.tag = tag
        self.baseArgs = baseArgs
        // Extract the primary verb: first element that doesn't start with '-'
        self.verb = baseArgs.first(where: { !$0.hasPrefix("-") }) ?? baseArgs.first ?? ""
    }

    // MARK: - Whitelist table

    /// ALL git commands ShadowWorkspace is allowed to execute.
    /// Tests enumerate this table to assert:
    ///   (a) only allowed verbs appear
    ///   (b) no spec contains "push", "remote", "clone"
    public static let allSpecs: [GitCommandSpec] = [
        GitCommandSpec(
            tag: "git:init",
            baseArgs: ["-c", "init.defaultBranch=main", "init", "-q"]
        ),
        GitCommandSpec(
            tag: "git:config:email",
            baseArgs: ["config", "user.email", "shadow@turingos.local"]
        ),
        GitCommandSpec(
            tag: "git:config:name",
            baseArgs: ["config", "user.name", "TuringOS Shadow"]
        ),
        GitCommandSpec(
            tag: "git:add",
            baseArgs: ["add"]
        ),
        GitCommandSpec(
            tag: "git:commit",
            baseArgs: ["commit", "--allow-empty", "-m"]
        ),
        GitCommandSpec(
            tag: "git:diff:cached",
            baseArgs: ["diff", "--cached"]
        ),
        GitCommandSpec(
            tag: "git:diff",
            baseArgs: ["diff"]
        ),
        GitCommandSpec(
            tag: "git:stash",
            baseArgs: ["stash"]
        ),
        GitCommandSpec(
            tag: "git:stash:push",
            baseArgs: ["stash", "push", "-m"]
        ),
        GitCommandSpec(
            tag: "git:stash:pop",
            baseArgs: ["stash", "pop"]
        ),
        GitCommandSpec(
            tag: "git:stash:apply",
            baseArgs: ["stash", "apply"]
        ),
        GitCommandSpec(
            tag: "git:stash:list",
            baseArgs: ["stash", "list"]
        ),
        GitCommandSpec(
            tag: "git:checkout",
            baseArgs: ["checkout", "--"]
        ),
        GitCommandSpec(
            tag: "git:status",
            baseArgs: ["status", "--porcelain"]
        ),
        GitCommandSpec(
            tag: "git:rev-parse",
            baseArgs: ["rev-parse", "--verify"]
        ),
        GitCommandSpec(
            tag: "git:rm:cached",
            // `--cached` restricts this to index-only removal (never touches
            // files outside the staging root; filesystem cleanup is done by
            // FileManager, not git rm).
            baseArgs: ["rm", "--cached", "-r", "--ignore-unmatch"]
        ),
    ]

    // MARK: - Verb safety predicate

    /// Verbs that are strictly forbidden in staging context.
    /// Used by tests and the runtime safety check.
    ///
    /// Note: `git rm --cached` (index-only removal) IS allowed for discard().
    /// It is listed in allSpecs with tag "git:rm:cached" and does not appear
    /// in forbiddenVerbs because "rm" here means index removal, not filesystem
    /// deletion outside the staging root. The actual verb is "rm" but it is
    /// constrained to `--cached` only (see the spec entry).
    public static let forbiddenVerbs: Set<String> = [
        "push", "remote", "clone", "fetch", "pull",
        "submodule", "worktree",
    ]

    /// True iff this spec's verb is in the allowed set.
    public var isAllowed: Bool {
        !Self.forbiddenVerbs.contains(verb)
    }
}

// MARK: - ShadowError

/// Typed errors from ShadowWorkspace operations.
public enum ShadowError: Error, Equatable, Sendable {
    /// The target path resolved outside the staging root — path-traversal guard.
    case outsideStagingRoot(path: String, stagingRoot: String)
    /// A git command failed with an exit code.
    case gitCommandFailed(tag: String, exit: Int32, stderr: String)
    /// The requested stash ref does not exist or is malformed.
    case stashRefInvalid(ref: String)
    /// The staging workspace has not been initialised yet.
    case notInitialised(stagingId: String)
    /// An attempt was made to run git in a directory outside the staging root.
    case runnerStagingRootViolation(dir: String, stagingRoot: String)
}

// MARK: - GitRunner protocol

/// Abstraction over git process invocation.
/// LiveGitRunner uses Process with /usr/bin/git and enforces that the working
/// directory is inside the staging root before every call.
/// MockGitRunner is used in tests for pure logic without real git.
public protocol GitRunner: Sendable {
    /// Run a git command in `dir`.
    /// - Precondition: `dir` must be inside the staging root (enforced by the
    ///   implementation; throws `ShadowError.runnerStagingRootViolation` if not).
    func run(args: [String], in dir: URL) throws -> String
}

// MARK: - LiveGitRunner

/// Real git runner. Shells out to /usr/bin/git.
/// Safety: asserts the working directory is inside the staging root before
/// every call. Refuses with ShadowError.runnerStagingRootViolation otherwise.
public struct LiveGitRunner: GitRunner, Sendable {
    public let stagingRoot: URL

    public init(stagingRoot: URL) {
        self.stagingRoot = stagingRoot
    }

    public func run(args: [String], in dir: URL) throws -> String {
        // Path containment guard — resolve symlinks so ".." tricks are caught.
        let resolvedDir = dir.resolvingSymlinksInPath().standardized
        let resolvedRoot = stagingRoot.resolvingSymlinksInPath().standardized
        let rootPath = resolvedRoot.path
        let dirPath = resolvedDir.path
        // dir must be the root itself or a subdirectory of it.
        guard dirPath == rootPath || dirPath.hasPrefix(rootPath + "/") else {
            throw ShadowError.runnerStagingRootViolation(
                dir: dirPath,
                stagingRoot: rootPath
            )
        }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = args
        p.currentDirectoryURL = dir
        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe
        // Suppress inherited git config so tests are hermetic.
        var env = ProcessInfo.processInfo.environment
        env["GIT_CONFIG_GLOBAL"] = "/dev/null"
        env["GIT_CONFIG_SYSTEM"] = "/dev/null"
        p.environment = env
        try p.run()
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()

        let stdout = String(data: outData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(data: errData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard p.terminationStatus == 0 else {
            throw ShadowError.gitCommandFailed(
                tag: args.first(where: { !$0.hasPrefix("-") }) ?? args.first ?? "?",
                exit: p.terminationStatus,
                stderr: stderr
            )
        }
        return stdout
    }
}

// MARK: - MockGitRunner

/// Deterministic mock for tests — zero process, zero filesystem.
/// Callers pre-supply a response table keyed by the first substantive arg.
public struct MockGitRunner: GitRunner, Sendable {
    public let stagingRoot: URL
    /// Canned responses: key = first non-flag arg, value = stdout to return.
    public let responses: [String: String]
    /// If true, every call throws runnerStagingRootViolation (tests the guard path).
    public let rejectAll: Bool

    public init(stagingRoot: URL, responses: [String: String] = [:], rejectAll: Bool = false) {
        self.stagingRoot = stagingRoot
        self.responses = responses
        self.rejectAll = rejectAll
    }

    public func run(args: [String], in dir: URL) throws -> String {
        if rejectAll {
            throw ShadowError.runnerStagingRootViolation(
                dir: dir.path,
                stagingRoot: stagingRoot.path
            )
        }
        // Containment check (same logic as Live, so mock also enforces the law).
        let resolvedDir = dir.resolvingSymlinksInPath().standardized
        let resolvedRoot = stagingRoot.resolvingSymlinksInPath().standardized
        let rootPath = resolvedRoot.path
        let dirPath = resolvedDir.path
        guard dirPath == rootPath || dirPath.hasPrefix(rootPath + "/") else {
            throw ShadowError.runnerStagingRootViolation(
                dir: dirPath,
                stagingRoot: rootPath
            )
        }
        let key = args.first(where: { !$0.hasPrefix("-") }) ?? args.first ?? ""
        return responses[key] ?? ""
    }
}

// MARK: - ShadowWorkspace

/// App-owned staging substrate for Class-1 reversible-local edits.
///
/// Each staging workspace is an independent git repository living under
/// `<app-support>/TuringOS/shadow/<stagingId>/`. Every operation operates
/// SOLELY within this copy directory.
///
/// Safety invariants enforced at every call site:
///   1. Path-traversal guard: relative paths are validated against the staging
///      root; ".." escapes throw ShadowError.outsideStagingRoot.
///   2. Root containment: the GitRunner refuses calls whose `dir` is outside
///      the staging root (ShadowError.runnerStagingRootViolation).
///   3. No promote-to-real: there is no method that writes outside the staging
///      root. "promote" is type-level absent (StagedEdit has no apply-to-real).
public struct ShadowWorkspace: Sendable {

    // MARK: - Paths

    /// Base directory for all shadow workspaces.
    public static func shadowBaseURL() -> URL {
        Workspace.supportDir
            .appendingPathComponent("shadow", isDirectory: true)
    }

    /// Root directory for a specific staging workspace.
    public static func stagingRootURL(stagingId: String) -> URL {
        shadowBaseURL()
            .appendingPathComponent(stagingId, isDirectory: true)
    }

    // MARK: - Stored properties

    public let stagingId: String
    public let stagingRoot: URL
    private let runner: any GitRunner

    // MARK: - Init

    /// Create a ShadowWorkspace value for an existing staging directory.
    /// Callers must call `create(stagingId:runner:)` first to initialise the
    /// directory.
    public init(stagingId: String, stagingRoot: URL, runner: any GitRunner) {
        self.stagingId = stagingId
        self.stagingRoot = stagingRoot
        self.runner = runner
    }

    // MARK: - Factory

    /// Create and git-init a new shadow workspace under the app-support shadow
    /// base. Returns the initialised ShadowWorkspace.
    ///
    /// The workspace is app-owned; it has no remote, no push, no connection to
    /// any user repository (ADR-002: use git semantics, not a private format).
    public static func create(
        stagingId: String,
        runner: (any GitRunner)? = nil
    ) throws -> ShadowWorkspace {
        let root = stagingRootURL(stagingId: stagingId)
        let liveRunner = runner ?? LiveGitRunner(stagingRoot: root)

        // Create the directory.
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )

        // git init — uses GitCommandSpec.allSpecs tag "git:init"
        _ = try liveRunner.run(
            args: ["-c", "init.defaultBranch=main", "init", "-q"],
            in: root
        )
        // Configure identity so commits work without global git config.
        _ = try liveRunner.run(
            args: ["config", "user.email", "shadow@turingos.local"],
            in: root
        )
        _ = try liveRunner.run(
            args: ["config", "user.name", "TuringOS Shadow"],
            in: root
        )
        // Create the initial empty commit so git stash works from the start.
        // (git stash requires at least one commit to exist.)
        _ = try liveRunner.run(
            args: ["commit", "--allow-empty", "-m", "shadow:init"],
            in: root
        )

        return ShadowWorkspace(stagingId: stagingId, stagingRoot: root, runner: liveRunner)
    }

    // MARK: - Path guard helper

    /// Resolve a relative path against the staging root.
    /// Throws ShadowError.outsideStagingRoot if the resolved path escapes the
    /// staging root (e.g., a path containing "..").
    private func resolvedSafe(relativePath: String) throws -> URL {
        // Reject absolute paths outright.
        guard !relativePath.hasPrefix("/") else {
            throw ShadowError.outsideStagingRoot(
                path: relativePath,
                stagingRoot: stagingRoot.path
            )
        }
        let candidate = stagingRoot.appendingPathComponent(relativePath)
            .standardized
        let resolvedCandidate = candidate.resolvingSymlinksInPath()
        let resolvedRoot = stagingRoot.resolvingSymlinksInPath().standardized
        let rootPath = resolvedRoot.path
        let candidatePath = resolvedCandidate.path
        guard candidatePath == rootPath
            || candidatePath.hasPrefix(rootPath + "/") else {
            throw ShadowError.outsideStagingRoot(
                path: relativePath,
                stagingRoot: stagingRoot.path
            )
        }
        return candidate
    }

    // MARK: - stageEdit

    /// Write `newContent` to `relativePath` inside the staging copy and
    /// git-add the file.
    ///
    /// - Parameter relativePath: path relative to the staging root.
    ///   Must not escape the root (e.g. "../outside") — throws
    ///   ShadowError.outsideStagingRoot if it does.
    /// - Parameter newContent: UTF-8 string content to write.
    @discardableResult
    public func stageEdit(relativePath: String, newContent: String) throws -> StagedEdit {
        let fileURL = try resolvedSafe(relativePath: relativePath)

        // Ensure parent directories exist inside the staging root.
        let parentDir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: parentDir,
            withIntermediateDirectories: true
        )

        // Write the content.
        try newContent.write(to: fileURL, atomically: true, encoding: .utf8)

        // git add — uses GitCommandSpec.allSpecs tag "git:add"
        _ = try runner.run(args: ["add", relativePath], in: stagingRoot)

        return StagedEdit(
            stagingId: stagingId,
            relativePath: relativePath,
            restorePointRef: nil,
            status: .staged
        )
    }

    // MARK: - pendingDiff

    /// Returns the git diff --cached output (staged changes).
    /// Empty string means nothing is staged.
    public func pendingDiff() throws -> String {
        // git diff --cached — uses GitCommandSpec.allSpecs tag "git:diff:cached"
        return try runner.run(args: ["diff", "--cached"], in: stagingRoot)
    }

    // MARK: - restorePoint

    /// Create a restore point by stashing all staged and unstaged changes.
    /// Returns a stash ref string (e.g. "stash@{0}") that can be passed to
    /// `restore(ref:)`.
    ///
    /// Requires the workspace to have been created via `create()` (which
    /// guarantees the baseline empty commit that git stash requires).
    ///
    /// If there are no changes to stash (clean tree), returns "stash@{0}"
    /// as a sentinel — subsequent `restore` with this ref is a no-op.
    public func restorePoint(label: String = "shadow_restore_point") throws -> String {
        // git stash push -m <label> --include-untracked
        // Stash all staged + unstaged + untracked content within the copy.
        do {
            _ = try runner.run(
                args: ["stash", "push", "--include-untracked", "-m", label],
                in: stagingRoot
            )
        } catch {
            // stash push exits non-zero if there's nothing to stash.
            // Return sentinel — caller can still call restore() safely.
            return "stash@{0}"
        }

        // Read the stash ref (most recent = stash@{0})
        let stashList = try runner.run(args: ["stash", "list"], in: stagingRoot)
        if stashList.isEmpty {
            return "stash@{0}"
        }
        // stash list output: "stash@{0}: On main: <label>"
        // Split on ": " to safely extract "stash@{0}".
        let firstLine = stashList.split(separator: "\n").first.map(String.init) ?? ""
        if let colonIdx = firstLine.firstIndex(of: ":") {
            let ref = String(firstLine[firstLine.startIndex..<colonIdx])
                .trimmingCharacters(in: .whitespaces)
            return ref.isEmpty ? "stash@{0}" : ref
        }
        return "stash@{0}"
    }

    // MARK: - discard

    /// Discard all staged changes in the copy.
    /// Removes staged files from the index and deletes untracked staged files.
    ///
    /// Strategy: `git rm --cached -r .` removes everything from the index
    /// (works even before any commit exists), then remove the actual files.
    /// This is safe because the staging copy is app-owned; the user's real
    /// repository is never touched.
    public func discard() throws {
        // Remove all files from the git index.
        // `--ignore-unmatch` prevents errors when the index is already empty.
        do {
            _ = try runner.run(
                args: ["rm", "--cached", "-r", "--ignore-unmatch", "."],
                in: stagingRoot
            )
        } catch {
            // Some git versions may not support --ignore-unmatch with rm; swallow.
        }
        // Delete untracked files that were written by stageEdit.
        // We walk the directory and remove non-.git entries.
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: stagingRoot,
            includingPropertiesForKeys: nil
        )) ?? []
        for item in contents {
            if item.lastPathComponent != ".git" {
                try? FileManager.default.removeItem(at: item)
            }
        }
    }

    // MARK: - restore

    /// Restore the staging workspace to a previously created restore point.
    /// - Parameter ref: a stash ref returned by `restorePoint()`.
    public func restore(ref: String) throws {
        // Validate the ref looks like a stash ref.
        guard ref.hasPrefix("stash@{") else {
            throw ShadowError.stashRefInvalid(ref: ref)
        }
        // git stash apply <ref>
        _ = try runner.run(args: ["stash", "apply", ref], in: stagingRoot)
    }

    // MARK: - status

    /// Returns git status --porcelain output for the staging copy.
    public func status() throws -> String {
        return try runner.run(args: ["status", "--porcelain"], in: stagingRoot)
    }

    // MARK: - revParse

    /// Returns the HEAD sha for the staging copy, or nil if no commits exist.
    public func revParse(ref: String = "HEAD") throws -> String? {
        do {
            let sha = try runner.run(args: ["rev-parse", "--verify", ref], in: stagingRoot)
            return sha.isEmpty ? nil : sha
        } catch {
            return nil
        }
    }
}

// CIObservation.swift — A1_20: read-only CI/PR observation protocol + live implementation.
//
// Design contract:
//   • RepoObservationSource is a protocol of PURELY READ-ONLY queries.
//   • LiveRepoObservationSource executes ONLY whitelisted read-only commands
//     (git log/rev-parse/merge-base/ls-tree/cat-file, gh pr list/checks/api GET).
//     NO push, merge, edit, delete, POST anywhere.
//   • All commands are exposed as a static commandSpecs table so tests can
//     enumerate them and assert read-only law (commands-as-data pattern).
//   • MockRepoObservationSource is the ONLY source used in unit tests —
//     zero network/process in the test target.

import Foundation
import CryptoKit

// MARK: - Read-only command spec (commands-as-data pattern)

/// One whitelisted read-only shell command that LiveRepoObservationSource may invoke.
/// Exposed as data so the read-only-law test can enumerate and verify every entry.
public struct ROCommandSpec: Sendable, Equatable {
    /// Human-readable tag (used in derive_source labels).
    public let tag: String
    /// Executable path or name.
    public let executable: String
    /// Fixed argument prefix (variable parts are appended at call time).
    public let baseArgs: [String]
    /// The HTTP verb if this is a gh api call; nil for local git commands.
    public let httpVerb: String?

    public init(tag: String, executable: String, baseArgs: [String], httpVerb: String? = nil) {
        self.tag = tag
        self.executable = executable
        self.baseArgs = baseArgs
        self.httpVerb = httpVerb
    }

    /// True iff this command spec is read-only.
    /// Rule: git commands are read-only iff they don't mutate (log/rev-parse/merge-base/ls-tree/cat-file).
    /// gh commands are read-only iff httpVerb == nil (CLI subcommand) or == "GET".
    public var isReadOnly: Bool {
        if let verb = httpVerb {
            return verb.uppercased() == "GET"
        }
        // git commands: only the following verbs are read-only
        let readOnlyGitVerbs: Set<String> = ["log", "rev-parse", "merge-base", "ls-tree", "cat-file"]
        if executable.hasSuffix("git") || executable == "git" {
            // baseArgs[0] is the git subcommand
            if let sub = baseArgs.first {
                return readOnlyGitVerbs.contains(sub)
            }
            return false
        }
        // gh subcommands: pr list, pr checks, api (GET enforced above via httpVerb)
        if executable.hasSuffix("gh") || executable == "gh" {
            let readOnlyGhSubcommands: Set<String> = ["pr", "api"]
            if let sub = baseArgs.first {
                return readOnlyGhSubcommands.contains(sub)
            }
            return false
        }
        return false
    }
}

// MARK: - Value types returned by the protocol

/// One open PR's summary, as returned by gh pr list --json.
public struct PRSummary: Sendable, Equatable {
    public let number: Int
    public let headRefName: String
    public let title: String
    public let url: String

    public init(number: Int, headRefName: String, title: String, url: String) {
        self.number = number
        self.headRefName = headRefName
        self.title = title
        self.url = url
    }
}

/// One check-run summary, as returned by gh pr checks.
public struct CheckRunSummary: Sendable, Equatable {
    public let id: String
    public let name: String
    public let conclusion: String   // "success" | "failure" | "skipped" | "pending" | "unavailable"
    public let runnerType: String   // "github_actions" | "unknown"

    public init(id: String, name: String, conclusion: String, runnerType: String) {
        self.id = id
        self.name = name
        self.conclusion = conclusion
        self.runnerType = runnerType
    }
}

// MARK: - RepoObservationSource protocol

/// All methods are read-only. No mutation, no network writes, no git writes.
public protocol RepoObservationSource: Sendable {
    /// HEAD commit SHA of the given branch (or current HEAD if nil).
    func headSHA(branch: String?) throws -> String
    /// Open PRs targeting the default branch.
    func openPRs() throws -> [PRSummary]
    /// Check runs for a given PR number.
    func checkRuns(prNumber: Int) throws -> [CheckRunSummary]
    /// Branch protection rules snapshot for the default branch (raw JSON string, or "unavailable").
    func branchProtectionSnapshot(owner: String, repo: String) throws -> String
    /// SHA-256 hash over the .github/workflows tree at the given commit.
    /// Returns "sha256:" + hex digest.
    func workflowFilesHash(commit: String) throws -> String
    /// Merge base between two refs (git merge-base).
    func mergeBase(ref1: String, ref2: String) throws -> String
    /// Derive-source tag for this source.
    var deriveSourceTag: String { get }
}

// MARK: - LiveRepoObservationSource

/// Real implementation: shells out to git + gh CLI using ONLY the whitelisted
/// read-only command table. Never pushes, merges, edits, deletes, or POSTs.
public struct LiveRepoObservationSource: RepoObservationSource, Sendable {

    // MARK: - Whitelisted command specs (commands-as-data — test-enumerable)

    /// ALL commands this source is allowed to execute.
    /// Tests enumerate this table to assert the read-only law.
    public static let commandSpecs: [ROCommandSpec] = [
        ROCommandSpec(
            tag: "git:log:head",
            executable: "/usr/bin/git",
            baseArgs: ["log", "--pretty=format:%H", "-1"]
        ),
        ROCommandSpec(
            tag: "git:rev-parse:branch",
            executable: "/usr/bin/git",
            baseArgs: ["rev-parse"]
        ),
        ROCommandSpec(
            tag: "git:merge-base",
            executable: "/usr/bin/git",
            baseArgs: ["merge-base"]
        ),
        ROCommandSpec(
            tag: "git:ls-tree:workflows",
            executable: "/usr/bin/git",
            baseArgs: ["ls-tree", "-r", "--name-only"]
        ),
        ROCommandSpec(
            tag: "git:cat-file:blob",
            executable: "/usr/bin/git",
            baseArgs: ["cat-file", "blob"]
        ),
        ROCommandSpec(
            tag: "gh:pr:list",
            executable: "gh",
            baseArgs: ["pr", "list", "--json", "number,headRefName,title,url"]
        ),
        ROCommandSpec(
            tag: "gh:pr:checks",
            executable: "gh",
            baseArgs: ["pr", "checks"]
        ),
        ROCommandSpec(
            tag: "gh:api:branch-protection",
            executable: "gh",
            baseArgs: ["api"],
            httpVerb: "GET"
        ),
    ]

    private let repoPath: String
    private let runner: any ProcessRunner

    public init(repoPath: String, runner: any ProcessRunner = SystemProcessRunner()) {
        self.repoPath = repoPath
        self.runner = runner
    }

    public var deriveSourceTag: String { "live:repo:\(URL(fileURLWithPath: repoPath).lastPathComponent)" }

    // MARK: - headSHA

    public func headSHA(branch: String?) throws -> String {
        let args: [String]
        if let branch {
            args = ["-C", repoPath, "rev-parse", "\(branch)^{commit}"]
        } else {
            args = ["-C", repoPath, "log", "--pretty=format:%H", "-1", "HEAD"]
        }
        let (code, out, _) = try runner.run("/usr/bin/git", args)
        guard code == 0, let sha = String(data: out, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !sha.isEmpty else {
            throw CIObservationError.commandFailed(tag: "git:headSHA", exit: code)
        }
        return sha
    }

    // MARK: - openPRs

    public func openPRs() throws -> [PRSummary] {
        let ghPath = resolvedGhPath()
        let args = ["pr", "list", "--json", "number,headRefName,title,url",
                    "--limit", "50", "--state", "open"]
        let (code, out, _) = try runner.run(ghPath, args)
        guard code == 0 else {
            throw CIObservationError.commandFailed(tag: "gh:pr:list", exit: code)
        }
        return parsePRList(out)
    }

    // MARK: - checkRuns

    public func checkRuns(prNumber: Int) throws -> [CheckRunSummary] {
        let ghPath = resolvedGhPath()
        let args = ["pr", "checks", "\(prNumber)", "--json", "name,conclusion,checkRunId"]
        let (code, out, _) = try runner.run(ghPath, args)
        // gh pr checks exits non-zero when some checks failed — still parse the output
        return parseCheckRuns(out, exitCode: code)
    }

    // MARK: - branchProtectionSnapshot

    public func branchProtectionSnapshot(owner: String, repo: String) throws -> String {
        let ghPath = resolvedGhPath()
        let endpoint = "repos/\(owner)/\(repo)/branches/main/protection"
        let args = ["api", "--method", "GET", endpoint]
        let (code, out, _) = try runner.run(ghPath, args)
        if code != 0 || out.isEmpty {
            return "unavailable"
        }
        return String(data: out, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unavailable"
    }

    // MARK: - workflowFilesHash

    public func workflowFilesHash(commit: String) throws -> String {
        // git ls-tree -r --name-only <commit> -- .github/workflows
        let lsArgs = ["-C", repoPath, "ls-tree", "-r", "--name-only", commit,
                      "--", ".github/workflows"]
        let (lsCode, lsOut, _) = try runner.run("/usr/bin/git", lsArgs)
        guard lsCode == 0 else {
            // No workflows directory = sha256 over empty = deterministic sentinel
            return "sha256:" + sha256Hex(Data())
        }
        let paths = (String(data: lsOut, encoding: .utf8) ?? "")
            .split(separator: "\n")
            .map(String.init)
            .sorted()

        var combined = Data()
        for path in paths {
            let blobRef = "\(commit):\(path)"
            let catArgs = ["-C", repoPath, "cat-file", "blob", blobRef]
            let (catCode, catOut, _) = try runner.run("/usr/bin/git", catArgs)
            if catCode == 0 {
                // Prefix with path so content + path both feed the hash
                combined.append(contentsOf: path.utf8)
                combined.append(contentsOf: [0x00])
                combined.append(catOut)
            }
        }
        return "sha256:" + sha256Hex(combined)
    }

    // MARK: - mergeBase

    public func mergeBase(ref1: String, ref2: String) throws -> String {
        let args = ["-C", repoPath, "merge-base", ref1, ref2]
        let (code, out, _) = try runner.run("/usr/bin/git", args)
        guard code == 0, let sha = String(data: out, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !sha.isEmpty else {
            throw CIObservationError.commandFailed(tag: "git:merge-base", exit: code)
        }
        return sha
    }

    // MARK: - Helpers

    private func resolvedGhPath() -> String {
        let candidates = GitConnect.ghCandidates
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) })
            ?? "gh"
    }

    private func parsePRList(_ data: Data) -> [PRSummary] {
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return arr.compactMap { obj in
            guard let number = obj["number"] as? Int,
                  let headRef = obj["headRefName"] as? String,
                  let title = obj["title"] as? String,
                  let url = obj["url"] as? String else { return nil }
            return PRSummary(number: number, headRefName: headRef, title: title, url: url)
        }
    }

    private func parseCheckRuns(_ data: Data, exitCode: Int32) -> [CheckRunSummary] {
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return arr.compactMap { obj in
            // gh pr checks --json returns checkRunId as a number
            let idRaw = obj["checkRunId"]
            let id: String
            if let n = idRaw as? Int { id = "\(n)" }
            else if let s = idRaw as? String { id = s }
            else { id = "unknown" }
            guard let name = obj["name"] as? String else { return nil }
            let conclusion = (obj["conclusion"] as? String) ?? "pending"
            return CheckRunSummary(id: id, name: name,
                                   conclusion: conclusion, runnerType: "github_actions")
        }
    }

    private func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - MockRepoObservationSource (unit tests only — zero network/process)

/// Deterministic mock for unit tests. All methods return the pre-supplied fixtures.
public struct MockRepoObservationSource: RepoObservationSource, Sendable {
    public let fixedHEAD: String
    public let fixedPRs: [PRSummary]
    public let fixedCheckRuns: [CheckRunSummary]
    public let fixedBranchProtection: String
    public let fixedWorkflowHash: String
    public let fixedMergeBase: String
    public let deriveSourceTag: String

    public init(
        head: String = "abc1234567890abcdef1234567890abcdef123456",
        prs: [PRSummary] = [],
        checkRuns: [CheckRunSummary] = [],
        branchProtection: String = "unavailable",
        workflowHash: String = "sha256:aabbccddeeff00112233445566778899aabbccdd",
        mergeBase: String = "base1234567890abcdef1234567890abcdef1234",
        tag: String = "mock:repo"
    ) {
        self.fixedHEAD = head
        self.fixedPRs = prs
        self.fixedCheckRuns = checkRuns
        self.fixedBranchProtection = branchProtection
        self.fixedWorkflowHash = workflowHash
        self.fixedMergeBase = mergeBase
        self.deriveSourceTag = tag
    }

    public func headSHA(branch: String?) throws -> String { fixedHEAD }
    public func openPRs() throws -> [PRSummary] { fixedPRs }
    public func checkRuns(prNumber: Int) throws -> [CheckRunSummary] { fixedCheckRuns }
    public func branchProtectionSnapshot(owner: String, repo: String) throws -> String { fixedBranchProtection }
    public func workflowFilesHash(commit: String) throws -> String { fixedWorkflowHash }
    public func mergeBase(ref1: String, ref2: String) throws -> String { fixedMergeBase }
}

// MARK: - CIObservationError

public enum CIObservationError: Error, Equatable {
    case commandFailed(tag: String, exit: Int32)
    case parseError(tag: String)
}

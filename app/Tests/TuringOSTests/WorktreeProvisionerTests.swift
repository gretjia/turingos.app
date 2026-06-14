// A1_40 regression suite: real `git worktree add` provisioning + safety guards.
// The provision path is exercised end-to-end against a real temp git repo
// (real-run, exit-code) so a broken provisioner turns the gate red; the guards
// (verb whitelist, path containment, new-branch-only) are asserted mechanically.

import Foundation
import XCTest
@testable import TuringOS

final class WorktreeProvisionerTests: XCTestCase {
    /// Arbitrary git for FIXTURE setup only (NOT the restricted provisioner runner).
    @discardableResult
    private func git(_ args: [String], in dir: URL) throws -> (Int32, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = args
        p.currentDirectoryURL = dir
        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe
        var env = ProcessInfo.processInfo.environment
        env["GIT_CONFIG_GLOBAL"] = "/dev/null"
        env["GIT_CONFIG_SYSTEM"] = "/dev/null"
        env["GIT_AUTHOR_NAME"] = "t"; env["GIT_AUTHOR_EMAIL"] = "t@t"
        env["GIT_COMMITTER_NAME"] = "t"; env["GIT_COMMITTER_EMAIL"] = "t@t"
        p.environment = env
        try p.run()
        let o = outPipe.fileHandleForReading.readDataToEndOfFile()
        _ = errPipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, String(data: o, encoding: .utf8) ?? "")
    }

    private func makeRepo() throws -> URL {
        let repo = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tos_wtp_\(UInt32.random(in: 0 ..< .max))", isDirectory: true)
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        _ = try git(["-c", "init.defaultBranch=main", "init", "-q"], in: repo)
        try "hello".write(to: repo.appendingPathComponent("f.txt"), atomically: true, encoding: .utf8)
        _ = try git(["add", "."], in: repo)
        _ = try git(["commit", "-q", "-m", "init"], in: repo)
        return repo
    }

    private func tmpRoot() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tos_wtroot_\(UInt32.random(in: 0 ..< .max))", isDirectory: true)
    }

    func testProvisionsRealWorktree() throws {
        let repo = try makeRepo()
        let root = tmpRoot()
        defer { try? FileManager.default.removeItem(at: repo); try? FileManager.default.removeItem(at: root) }

        let p = try WorktreeProvisioner.provision(
            projectRepo: repo, projectId: "demo", newBranch: "feat/x", base: "main", root: root)

        let (listCode, listOut) = try git(["worktree", "list", "--porcelain"], in: repo)
        XCTAssertEqual(listCode, 0)
        XCTAssertTrue(listOut.contains(p.path.lastPathComponent), "new worktree is listed")
        let (branchCode, _) = try git(["rev-parse", "--verify", "--quiet", "refs/heads/feat/x"], in: repo)
        XCTAssertEqual(branchCode, 0, "the new branch was created")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: p.path.appendingPathComponent("f.txt").path),
            "the worktree is a real checkout")
        // containment: created path is inside the allowed root
        XCTAssertTrue(p.path.path.hasPrefix(root.resolvingSymlinksInPath().standardized.path))
    }

    func testForbiddenVerbsAbsent() {
        for spec in WorktreeGitSpec.allSpecs {
            XCTAssertFalse(WorktreeGitSpec.forbiddenVerbs.contains(spec.verb),
                           "\(spec.tag): verb '\(spec.verb)' is forbidden")
            XCTAssertTrue(["worktree", "rev-parse"].contains(spec.verb),
                          "\(spec.tag): unexpected verb '\(spec.verb)'")
            if spec.verb == "worktree" {
                let sub = spec.baseArgs.dropFirst().first ?? ""
                XCTAssertTrue(WorktreeGitSpec.allowedWorktreeSubcommands.contains(sub),
                              "worktree subcommand '\(sub)' not allowed")
            }
            for bad in ["push", "remote", "clone", "merge", "reset", "rebase", "rm", "fetch", "pull"] {
                XCTAssertFalse(spec.baseArgs.contains(bad), "\(spec.tag) must not contain '\(bad)'")
            }
        }
    }

    func testRejectsAbsoluteBranchName() throws {
        let repo = try makeRepo()
        let root = tmpRoot()
        defer { try? FileManager.default.removeItem(at: repo); try? FileManager.default.removeItem(at: root) }
        XCTAssertThrowsError(try WorktreeProvisioner.provision(
            projectRepo: repo, projectId: "demo", newBranch: "/etc/evil", base: "main", root: root)) { err in
            guard case WorktreeProvisionError.outsideWorktreeRoot = err else {
                return XCTFail("expected outsideWorktreeRoot, got \(err)")
            }
        }
    }

    func testTraversalNamesCannotEscapeRoot() throws {
        let repo = try makeRepo()
        let root = tmpRoot()
        defer { try? FileManager.default.removeItem(at: repo); try? FileManager.default.removeItem(at: root) }
        // projectId is NOT a git ref — only used to build the path; a malicious
        // "../../etc" must be neutralised so the worktree stays inside root.
        let p = try WorktreeProvisioner.provision(
            projectRepo: repo, projectId: "../../etc", newBranch: "safe-x", base: "main", root: root)
        let resolvedRoot = root.resolvingSymlinksInPath().standardized.path
        XCTAssertTrue(p.path.path.hasPrefix(resolvedRoot + "/"),
                      "sanitised path must stay inside root, got \(p.path.path)")
        XCTAssertFalse(p.path.path.contains("/etc/"), "must not resolve into a real /etc path")
    }

    func testRefusesExistingBranch() throws {
        let repo = try makeRepo()
        let root = tmpRoot()
        defer { try? FileManager.default.removeItem(at: repo); try? FileManager.default.removeItem(at: root) }
        _ = try git(["branch", "existing"], in: repo)
        XCTAssertThrowsError(try WorktreeProvisioner.provision(
            projectRepo: repo, projectId: "demo", newBranch: "existing", base: "main", root: root)) { err in
            XCTAssertEqual(err as? WorktreeProvisionError, .branchAlreadyExists(branch: "existing"))
        }
    }
}

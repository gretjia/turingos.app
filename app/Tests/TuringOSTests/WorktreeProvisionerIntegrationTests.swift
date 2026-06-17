// Integration coverage for the linked-checkout shape produced by WorktreeProvisioner.
// Existing A1_40 tests prove the worktree is created and listed; this locks the
// user-visible checkout semantics that later supervision flows rely on.

import Foundation
import XCTest
@testable import TuringOS

final class WorktreeProvisionerIntegrationTests: XCTestCase {
    @discardableResult
    private func git(_ args: [String], in dir: URL) throws -> (Int32, String, String) {
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
        env["GIT_AUTHOR_NAME"] = "t"
        env["GIT_AUTHOR_EMAIL"] = "t@t"
        env["GIT_COMMITTER_NAME"] = "t"
        env["GIT_COMMITTER_EMAIL"] = "t@t"
        p.environment = env

        try p.run()
        let stdout = outPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = errPipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (
            p.terminationStatus,
            String(data: stdout, encoding: .utf8) ?? "",
            String(data: stderr, encoding: .utf8) ?? ""
        )
    }

    private func makeRepo() throws -> URL {
        let repo = FileManager.default.temporaryDirectory
            .appendingPathComponent("tos_wt_integrity_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        _ = try git(["-c", "init.defaultBranch=main", "init", "-q"], in: repo)
        try "hello\n".write(to: repo.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        _ = try git(["add", "."], in: repo)
        _ = try git(["commit", "-q", "-m", "init"], in: repo)
        return repo
    }

    private func tmpRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("tos_wt_integrity_root_\(UUID().uuidString)", isDirectory: true)
    }

    func testProvisionedWorktreeIsFunctionalLinkedCheckout() throws {
        let repo = try makeRepo()
        let root = tmpRoot()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: repo)
        }

        let provisioned = try WorktreeProvisioner.provision(
            projectRepo: repo,
            projectId: "demo",
            newBranch: "integrity/check",
            base: "main",
            root: root
        )

        var isDir: ObjCBool = false
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: provisioned.path.path, isDirectory: &isDir),
            "provisioned checkout directory should exist"
        )
        XCTAssertTrue(isDir.boolValue, "provisioned checkout path should be a directory")

        let gitFile = provisioned.path.appendingPathComponent(".git")
        var gitIsDir: ObjCBool = true
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: gitFile.path, isDirectory: &gitIsDir),
            "linked worktree should expose a .git file"
        )
        XCTAssertFalse(gitIsDir.boolValue, "linked worktree .git should be a file, not a nested repository directory")

        let (statusCode, statusOut, statusErr) = try git(["status", "--porcelain"], in: provisioned.path)
        XCTAssertEqual(statusCode, 0, "git status should succeed in linked checkout: \(statusErr)")
        XCTAssertEqual(statusOut.trimmingCharacters(in: .whitespacesAndNewlines), "", "fresh checkout should be clean")

        let (listCode, listOut, listErr) = try git(["worktree", "list", "--porcelain"], in: repo)
        XCTAssertEqual(listCode, 0, "git worktree list should succeed in source repo: \(listErr)")
        let resolvedPath = provisioned.path.resolvingSymlinksInPath().standardized.path
        let listed = listOut.split(separator: "\n").contains { line in
            guard line.hasPrefix("worktree ") else { return false }
            let path = String(line.dropFirst("worktree ".count))
            return URL(fileURLWithPath: path).resolvingSymlinksInPath().standardized.path == resolvedPath
        }
        XCTAssertTrue(listed, "source repo worktree list should include the provisioned linked checkout")
    }
}

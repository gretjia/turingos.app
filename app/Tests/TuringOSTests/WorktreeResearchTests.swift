// A1_41: WorktreeResearch read-only git gather — real-run against a temp repo.

import Foundation
import XCTest
@testable import TuringOS

final class WorktreeResearchTests: XCTestCase {
    @discardableResult
    private func git(_ args: [String], in dir: URL) throws -> (Int32, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = args
        p.currentDirectoryURL = dir
        let outPipe = Pipe(); let errPipe = Pipe()
        p.standardOutput = outPipe; p.standardError = errPipe
        var env = ProcessInfo.processInfo.environment
        env["GIT_CONFIG_GLOBAL"] = "/dev/null"; env["GIT_CONFIG_SYSTEM"] = "/dev/null"
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
            .appendingPathComponent("tos_wtr_\(UInt32.random(in: 0 ..< .max))", isDirectory: true)
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        _ = try git(["-c", "init.defaultBranch=main", "init", "-q"], in: repo)
        try "v1".write(to: repo.appendingPathComponent("f.txt"), atomically: true, encoding: .utf8)
        _ = try git(["add", "."], in: repo)
        _ = try git(["commit", "-q", "-m", "init commit"], in: repo)
        _ = try git(["branch", "feature-a"], in: repo)
        _ = try git(["commit", "-q", "--allow-empty", "-m", "second commit"], in: repo)
        return repo
    }

    func testGatherResearchFromRepo() throws {
        let repo = try makeRepo()
        defer { try? FileManager.default.removeItem(at: repo) }

        let ctx = try WorktreeResearch.gather(projectRepo: repo)
        XCTAssertEqual(ctx.currentBranch, "main")
        XCTAssertTrue(ctx.branches.contains("main"), "branches list contains main")
        XCTAssertTrue(ctx.branches.contains("feature-a"), "branches list contains feature-a")
        XCTAssertFalse(ctx.recentCommits.isEmpty, "recent commits surfaced")
        XCTAssertTrue(ctx.recentCommits.contains { $0.contains("second commit") })
        XCTAssertFalse(ctx.dirty, "clean tree reads not-dirty")
    }

    func testGatherReflectsDirtyTree() throws {
        let repo = try makeRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        try "uncommitted".write(to: repo.appendingPathComponent("g.txt"), atomically: true, encoding: .utf8)

        let ctx = try WorktreeResearch.gather(projectRepo: repo)
        XCTAssertTrue(ctx.dirty, "untracked file makes the tree dirty")
    }

    func testContextStringIsDeterministicAndComplete() {
        let ctx = WorktreeResearchContext(
            currentBranch: "main",
            branches: ["main", "feature-a"],
            recentCommits: ["abc123 second commit", "def456 init commit"],
            dirty: false)
        let a = WorktreeResearch.contextString(ctx, projectId: "demo")
        let b = WorktreeResearch.contextString(ctx, projectId: "demo")
        XCTAssertEqual(a, b, "same facts ⇒ byte-identical context")
        XCTAssertTrue(a.contains("当前分支：main"))
        XCTAssertTrue(a.contains("feature-a"))
        XCTAssertTrue(a.contains("second commit"))
    }
}

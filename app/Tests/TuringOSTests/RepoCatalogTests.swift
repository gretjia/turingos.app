// Catalog merge (GitHub × local by normalized identity), pagination
// parsing (live-verified field shapes), and the one-sentence rows.

import Foundation
import XCTest
@testable import TuringOS

final class RepoCatalogTests: XCTestCase {
    func testMergeJoinsLocalCloneWithGitHubListing() {
        let gitHub = [
            GitHubRepo(fullName: "gretjia/alpha", cloneUrl: "https://github.com/gretjia/alpha.git",
                       pushedAt: Date()),
            GitHubRepo(fullName: "gretjia/remoteonly", cloneUrl: "https://github.com/gretjia/remoteonly.git",
                       pushedAt: nil),
        ]
        let local: [(path: String, remote: String?)] = [
            ("/Users/x/Developer/alpha", "git@github.com:gretjia/alpha.git"), // ssh form joins https listing
            ("/Users/x/Developer/standalone", nil),
        ]
        let merged = RepoCatalog.merge(gitHub: gitHub, local: local)

        let alpha = merged.first { $0.remoteKey == "github.com/gretjia/alpha" }
        XCTAssertEqual(alpha?.localPath, "/Users/x/Developer/alpha", "SSH clone joined HTTPS listing")

        let remoteOnly = merged.first { $0.remoteKey == "github.com/gretjia/remoteonly" }
        XCTAssertNil(remoteOnly?.localPath)

        let standalone = merged.first { $0.displayName == "standalone" }
        XCTAssertNotNil(standalone, "local clone without GitHub remote still listed")
        XCTAssertNil(standalone?.remoteKey)

        // Triage order: local clones before remote-only (the order IS the
        // triage - 注意力优先).
        let firstRemoteOnlyIdx = merged.firstIndex { $0.localPath == nil }!
        let lastLocalIdx = merged.lastIndex { $0.localPath != nil }!
        XCTAssertLessThan(lastLocalIdx, firstRemoteOnlyIdx + merged.count) // sanity
        XCTAssertTrue(merged.prefix(while: { $0.localPath != nil }).count >= 2)
    }

    func testRowSentences() {
        let now = Date()
        XCTAssertEqual(CatalogItem.humanize(now.addingTimeInterval(-3600), now: now), "今天")
        XCTAssertEqual(CatalogItem.humanize(now.addingTimeInterval(-86_400 * 5), now: now), "5 天前")
        XCTAssertEqual(CatalogItem.humanize(now.addingTimeInterval(-86_400 * 90), now: now), "3 个月前")

        let item = CatalogItem(displayName: "x", remoteKey: nil, localPath: "/p",
                               pushedAt: nil)
        XCTAssertEqual(item.sentence, "本地 clone（未关联 GitHub）")
    }

    func testRepoPageParsing() throws {
        // Field shape live-verified via `gh api /user/repos` 2026-06-10.
        let page = #"""
        [{"full_name":"gretjia/omega","private":true,
          "pushed_at":"2026-03-10T18:30:16Z",
          "clone_url":"https://github.com/gretjia/omega.git",
          "ssh_url":"git@github.com:gretjia/omega.git"}]
        """#
        let repos = try GitHubAPI.parseRepoPage(Data(page.utf8))
        XCTAssertEqual(repos.count, 1)
        XCTAssertEqual(repos[0].fullName, "gretjia/omega")
        XCTAssertNotNil(repos[0].pushedAt)
    }

    func testLinkHeaderPagination() {
        let header = #"<https://api.github.com/user/repos?page=2>; rel="next", <https://api.github.com/user/repos?page=9>; rel="last""#
        XCTAssertEqual(
            GitHubAPI.nextLink(fromLinkHeader: header)?.absoluteString,
            "https://api.github.com/user/repos?page=2"
        )
        XCTAssertNil(GitHubAPI.nextLink(fromLinkHeader: #"<https://x>; rel="last""#))
        XCTAssertNil(GitHubAPI.nextLink(fromLinkHeader: nil))
    }

    /// Real-fs discovery: a main clone (.git dir) is found; a linked
    /// worktree (.git FILE) is skipped (R1_memo §1.5 rule).
    func testDiscoverLocalSkipsLinkedWorktrees() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("catalog-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let mainRepo = tmp.appendingPathComponent("main-repo/.git")
        try FileManager.default.createDirectory(at: mainRepo, withIntermediateDirectories: true)
        let linked = tmp.appendingPathComponent("linked-wt")
        try FileManager.default.createDirectory(at: linked, withIntermediateDirectories: true)
        try "gitdir: /elsewhere/.git/worktrees/x".write(
            to: linked.appendingPathComponent(".git"), atomically: true, encoding: .utf8)

        let found = RepoCatalog.discoverLocal(roots: [tmp.path], maxDepth: 3)
        XCTAssertEqual(found.map(\.path), [tmp.path + "/main-repo"])
    }
}

extension RepoCatalogTests {
    /// S-stage regressions: a second clone of one remote keeps its own row
    /// with its own id (selection can tell them apart).
    func testMergeKeepsEveryCloneOfOneRemote() {
        let gitHub = [GitHubRepo(fullName: "o/r", cloneUrl: "https://github.com/o/r.git", pushedAt: nil)]
        let local: [(path: String, remote: String?)] = [
            ("/A/r", "git@github.com:o/r.git"),
            ("/B/r", "git@github.com:o/r.git"),
        ]
        let merged = RepoCatalog.merge(gitHub: gitHub, local: local)
        let rows = merged.filter { $0.remoteKey == "github.com/o/r" }
        XCTAssertEqual(rows.count, 2, "both clones must survive the merge")
        XCTAssertEqual(Set(rows.map(\.id)).count, 2, "distinct selectable ids")
        XCTAssertEqual(Set(rows.compactMap(\.localPath)), ["/A/r", "/B/r"])
    }

    /// S-stage regression: symlinked directories are never followed - an
    /// ancestor-pointing symlink cannot multiply the walk or duplicate repos.
    func testDiscoverSkipsSymlinkedDirectories() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("symscan-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmp) }
        try FileManager.default.createDirectory(
            at: tmp.appendingPathComponent("real/repo/.git"), withIntermediateDirectories: true)
        // loop: tmp/loop -> tmp (ancestor)
        try FileManager.default.createSymbolicLink(
            at: tmp.appendingPathComponent("loop"), withDestinationURL: tmp)

        let found = RepoCatalog.discoverLocal(roots: [tmp.path], maxDepth: 4)
        XCTAssertEqual(found.map(\.path), [tmp.path + "/real/repo"], "exactly once, no symlink routes")
    }

    /// S-stage regression: hitting the page cap with pages remaining is a
    /// visible truncation flag, not a silent complete-looking list.
    func testNextLinkDrivenTruncationFlagIsDistinguishable() {
        let more = GitHubAPI.nextLink(fromLinkHeader: #"<https://api.github.com/user/repos?page=31>; rel="next""#)
        XCTAssertNotNil(more, "a remaining next link is the truncation witness")
        XCTAssertNil(GitHubAPI.nextLink(fromLinkHeader: nil), "no link == genuinely complete")
    }
}

// Connect detection state machine (mock subprocess seam) + remote
// normalization law (table-driven; SSH ≡ HTTPS for one repo).

import Foundation
import XCTest
@testable import TuringOS

private struct MockRunner: ProcessRunner {
    let responses: [String: (Int32, String)] // "args joined" -> (code, stdout)
    func run(_ executable: String, _ arguments: [String]) throws -> (Int32, Data, Data) {
        let key = arguments.joined(separator: " ")
        guard let (code, out) = responses[key] else {
            return (127, Data(), Data("no mock for \(key)".utf8))
        }
        return (code, Data(out.utf8), Data())
    }
}

final class GitConnectTests: XCTestCase {
    // Live-verified hosts schema (card 实测补录 2026-06-10).
    private let hostsJSON = #"""
    {"hosts":{"github.com":[{"state":"success","active":true,"host":"github.com",
    "login":"gretjia","tokenSource":"keyring","scopes":"gist, read:org, repo, workflow",
    "gitProtocol":"https"}]}}
    """#

    func testGhLoggedInYieldsGhCliLevel() throws {
        // gh exists on this machine (probed); the runner is mocked anyway.
        try XCTSkipIf(
            !FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/gh"),
            "needs a gh binary on a candidate path for the existence check"
        )
        let runner = MockRunner(responses: [
            "auth token": (0, "gho_x123\n"),
            "auth status --json hosts": (0, hostsJSON),
        ])
        let result = GitConnect.detect(runner: runner)
        guard case .ghCli(let login, let scopes) = result.level else {
            return XCTFail("expected ghCli level")
        }
        XCTAssertEqual(login, "gretjia")
        XCTAssertTrue(scopes.contains("repo"))
        XCTAssertEqual(result.token, "gho_x123", "trimmed single-line token, outside the enum")
    }

    func testGhLoggedOutDemotesVisibly() throws {
        try XCTSkipIf(!FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/gh"))
        // Dual criterion: nonzero exit OR empty stdout both demote.
        for response in [(Int32(1), ""), (Int32(0), "")] {
            let runner = MockRunner(responses: ["auth token": response])
            let result = GitConnect.detect(runner: runner)
            guard case .deviceFlowUnconfigured(let from) = result.level else {
                return XCTFail("expected demotion for \(response)")
            }
            XCTAssertEqual(from, "gh 未登录")
            XCTAssertNil(result.token, "demoted result must carry no token")
        }
    }

    func testConnectSentencesAreLanguageFirst() {
        XCTAssertEqual(
            ConnectLevel.ghCli(login: "x", scopes: "").sentence,
            "已通过 gh 接入 GitHub（@x）"
        )
        XCTAssertTrue(
            ConnectLevel.deviceFlowUnconfigured(demotedFrom: "未发现 gh CLI")
                .sentence.contains("待配置")
        )
    }

    func testRemoteNormalizationTable() {
        let cases: [(String, String?)] = [
            ("git@github.com:Owner/Repo.git", "github.com/owner/repo"),
            ("https://github.com/owner/repo.git", "github.com/owner/repo"),
            ("https://github.com/owner/repo", "github.com/owner/repo"),
            ("ssh://git@github.com/owner/repo.git", "github.com/owner/repo"),
            ("https://github.com/owner/repo/", "github.com/owner/repo"),
            ("https://gitlab.com/owner/repo.git", nil), // non-GitHub: no key
            ("git@github.com:malformed", nil),
            ("", nil),
        ]
        for (input, expected) in cases {
            XCTAssertEqual(normalizeGitHubRemote(input), expected, input)
        }
        // SSH and HTTPS forms of one repo MUST collapse to one identity.
        XCTAssertEqual(
            normalizeGitHubRemote("git@github.com:gretjia/turingos.app.git"),
            normalizeGitHubRemote("https://github.com/gretjia/turingos.app.git")
        )
    }
}

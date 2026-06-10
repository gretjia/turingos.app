// Registry writing must produce EXACTLY the daemon's A1_06 format - the
// golden here mirrors daemon/src/registry.rs RegistryFile; build_app.sh's
// registry wire-probe (--onboard-probe + `turingosd serve --registry`)
// validates the real coupling: daemon loads the Swift-written file and
// announces the project over the UDS contract stream.

import Foundation
import XCTest
@testable import TuringOS

final class RegistryWriterTests: XCTestCase {
    func testProjectIdSanitization() {
        XCTAssertEqual(RegistryWriter.sanitizeProjectId("TuringOS.app"), "turingos_app")
        XCTAssertEqual(RegistryWriter.sanitizeProjectId("öß"), "__")
        XCTAssertEqual(RegistryWriter.sanitizeProjectId(""), "x")
    }

    func testEntriesUniquifyCollidingIds() {
        let items = [
            CatalogItem(displayName: "Alpha", remoteKey: "github.com/a/alpha",
                        localPath: "/x/alpha", pushedAt: nil),
            CatalogItem(displayName: "alpha", remoteKey: "github.com/b/alpha",
                        localPath: nil, pushedAt: nil),
        ]
        let entries = RegistryWriter.entries(from: items)
        XCTAssertEqual(entries.map(\.projectId), ["alpha", "alpha_2"])
        XCTAssertEqual(entries[0].path, "/x/alpha")
        XCTAssertEqual(entries[1].remote, "github.com/b/alpha")
    }

    func testRegistryJSONGoldenShape() throws {
        let data = try RegistryWriter.registryJSON(projects: [
            RegistryProject(projectId: "alpha", path: "/x/alpha", remote: "github.com/a/alpha"),
            RegistryProject(projectId: "ghost", path: nil, remote: "github.com/a/ghost"),
        ])
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(obj["version"] as? Int, 1, "daemon pins version == 1")
        let projects = obj["projects"] as! [[String: Any]]
        XCTAssertEqual(projects[0]["project_id"] as? String, "alpha", "snake_case key per registry.rs")
        XCTAssertEqual(projects[0]["path"] as? String, "/x/alpha")
        XCTAssertEqual(projects[1]["project_id"] as? String, "ghost")
        XCTAssertTrue(projects[1]["path"] is NSNull || projects[1]["path"] == nil,
                      "remote-only entry carries no path")
    }

    func testAtomicWriteRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("reg-\(UUID().uuidString)/projects.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try RegistryWriter.write(
            projects: [RegistryProject(projectId: "p", path: nil, remote: nil)],
            to: url
        )
        let body = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(body.contains("\"version\" : 1") || body.contains("\"version\": 1"))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: url.deletingLastPathComponent()
                    .appendingPathComponent(".projects.json.tmp").path),
            "temp file must not survive the atomic replace"
        )
    }
}

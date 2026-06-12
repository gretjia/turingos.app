// ProjectProjectionTests.swift — A1_17: unit tests for ProjectProjections factories
// and IntentRouter project-discovery routing.
//
// Test inventory (8 test functions, each covering one or more of the spec's
// acceptance criteria):
//
//   1. testProjectPickerThreeRepos           — 3-repo catalog → picker with exactly 3 names
//   2. testProjectPickerDeterminism          — encode×2 byte-equal (determinism)
//   3. testEmptyCatalogYieldsGuidanceCard    — empty catalog → summaryCard, no picker block
//   4. testProjectStateCountsAndMap         — ledger fixture → summary counts + worktree_map entries
//   5. testProjectStateDeterminism          — encode×2 byte-equal (determinism)
//   6. testDeriveSourceNonEmptyOnAllDocs    — every produced doc has non-empty derive_source (P1)
//   7. testIntentRoutingViaProtocol         — "项目" → picker via mocked catalog; name → state doc
//   8. testReadOnlyFixtureUnchangedAfterProjection
//                                           — ledger value unchanged after projection call

import Foundation
import XCTest
@testable import TuringOS

final class ProjectProjectionTests: XCTestCase {

    // MARK: - Helpers

    /// Three-item mock catalog (stable displayNames for assertion matching).
    private func threeRepoCatalog() -> MockCatalogSource {
        MockCatalogSource(items: [
            CatalogItem(displayName: "alpha",
                        remoteKey: "github.com/org/alpha",
                        localPath: "/repos/alpha",
                        pushedAt: nil),
            CatalogItem(displayName: "beta",
                        remoteKey: "github.com/org/beta",
                        localPath: "/repos/beta",
                        pushedAt: nil),
            CatalogItem(displayName: "gamma",
                        remoteKey: nil,
                        localPath: "/repos/gamma",
                        pushedAt: nil),
        ], tag: "catalog:test")
    }

    /// Mixed ledger fixture for projectState tests (reuses the RadarModelTests pattern).
    private func envelope(_ seq: UInt64, _ kind: String, _ payload: String) -> EventEnvelope {
        let json = """
        {"event_id":"evt_pp_\(seq)","seq":\(seq),"ts":"2026-06-12T00:00:00Z",\
        "schema_version":"tos.app.event.v0","kind":"\(kind)","source":"daemon",\
        "trust_state":"observed_unsigned","payload":\(payload)}
        """
        return try! JSONDecoder().decode(EventEnvelope.self, from: Data(json.utf8))
    }

    private func fixturedLedger() -> WorktreeLedger {
        var ledger = WorktreeLedger()
        ledger.apply(envelope(0, "ProjectRegistered",
            #"{"project_id":"proj_alpha","local":true,"path":"/repos/alpha"}"#))
        ledger.apply(envelope(1, "WorktreeDiscovered",
            #"{"project_id":"proj_alpha","worktree_id":"wt_main_aaaaaaaa","path":"/repos/alpha","branch":"main","dirty":false}"#))
        ledger.apply(envelope(2, "WorktreeDiscovered",
            #"{"project_id":"proj_alpha","worktree_id":"wt_feat_bbbbbbbb","branch":"feat/x","dirty":true,"prunable":false}"#))
        ledger.apply(envelope(3, "WorktreeDiscovered",
            #"{"project_id":"proj_alpha","worktree_id":"wt_bad_cccccccc","fingerprint_error":"io error","dirty":false}"#))
        return ledger
    }

    // MARK: - Test 1: three-repo catalog → picker block with exactly 3 names

    func testProjectPickerThreeRepos() {
        let catalog = threeRepoCatalog()
        let doc = ProjectProjections.projectPicker(from: catalog)

        XCTAssertEqual(doc.kind, "project_init")
        // Exactly one project_picker block.
        let pickerBlocks = doc.blocks.compactMap { block -> ProjectPickerPayload? in
            if case .projectPicker(let p) = block { return p }
            return nil
        }
        XCTAssertEqual(pickerBlocks.count, 1, "exactly one project_picker block")
        let projects = pickerBlocks[0].projects

        XCTAssertEqual(projects.count, 3, "picker must list all 3 repos")

        let names = Set(projects.map(\.name))
        XCTAssertTrue(names.contains("alpha"), "alpha present")
        XCTAssertTrue(names.contains("beta"),  "beta present")
        XCTAssertTrue(names.contains("gamma"), "gamma present")
    }

    // MARK: - Test 2: three-repo catalog → determinism (encode twice, byte-equal)

    func testProjectPickerDeterminism() throws {
        let catalog = threeRepoCatalog()
        let doc1 = ProjectProjections.projectPicker(from: catalog)
        let doc2 = ProjectProjections.projectPicker(from: catalog)

        XCTAssertEqual(doc1, doc2, "same catalog must produce identical documents")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data1 = try encoder.encode(doc1)
        let data2 = try encoder.encode(doc2)
        XCTAssertEqual(data1, data2, "encoded bytes must be identical (determinism)")
    }

    // MARK: - Test 3: empty catalog → guidance summary_card, no picker block

    func testEmptyCatalogYieldsGuidanceCard() {
        let catalog = MockCatalogSource(items: [], tag: "catalog:empty_test")
        let doc = ProjectProjections.projectPicker(from: catalog)

        XCTAssertEqual(doc.kind, "project_init")

        // Must NOT contain a project_picker block.
        let hasPickerBlock = doc.blocks.contains {
            if case .projectPicker = $0 { return true }
            return false
        }
        XCTAssertFalse(hasPickerBlock, "empty catalog must NOT produce a project_picker block")

        // Must contain a summary_card with the guidance text.
        let summaryBlocks = doc.blocks.compactMap { block -> SummaryCardPayload? in
            if case .summaryCard(let p) = block { return p }
            return nil
        }
        XCTAssertFalse(summaryBlocks.isEmpty, "empty catalog must produce a guidance summary_card")
        let bodyContainsGuidance = summaryBlocks.contains {
            $0.body.contains("连接项目")
        }
        XCTAssertTrue(bodyContainsGuidance, "guidance card must mention '连接项目'")
    }

    // MARK: - Test 4: projectState counts + worktree_map entries

    func testProjectStateCountsAndMap() {
        let ledger = fixturedLedger()
        let scene = RadarScene.derive(ledger: ledger)
        let doc = ProjectProjections.projectState(
            projectId: "proj_alpha",
            displayName: "Alpha",
            ledger: ledger,
            radarScene: scene,
            deriveSource: "event_stream:test"
        )

        XCTAssertEqual(doc.kind, "project_state")

        // Summary card: title must be the display name.
        let summaryCards = doc.blocks.compactMap { block -> SummaryCardPayload? in
            if case .summaryCard(let p) = block { return p }
            return nil
        }
        XCTAssertEqual(summaryCards.count, 1)
        XCTAssertEqual(summaryCards[0].title, "Alpha")

        // Summary body must mention worktree count (3 worktrees in fixture).
        let bodyText = summaryCards[0].body
        XCTAssertTrue(bodyText.contains("3"), "summary must mention 3 worktrees")

        // Must mention attention count (1 failed worktree in fixture = 1 attention).
        XCTAssertTrue(bodyText.contains("1"), "summary must mention 1 needs-attention worktree")

        // Worktree_map block: must contain exactly 3 entries.
        let worktreeMaps = doc.blocks.compactMap { block -> WorktreeMapPayload? in
            if case .worktreeMap(let p) = block { return p }
            return nil
        }
        XCTAssertEqual(worktreeMaps.count, 1, "exactly one worktree_map block")
        XCTAssertEqual(worktreeMaps[0].worktrees.count, 3, "all 3 worktrees in the map")

        // All worktree IDs must appear.
        let worktreeIds = Set(worktreeMaps[0].worktrees.map(\.worktreeId))
        XCTAssertTrue(worktreeIds.contains("wt_main_aaaaaaaa"))
        XCTAssertTrue(worktreeIds.contains("wt_feat_bbbbbbbb"))
        XCTAssertTrue(worktreeIds.contains("wt_bad_cccccccc"))

        // Evidence list: must appear (1 failed worktree triggers it).
        let evidenceLists = doc.blocks.compactMap { block -> EvidenceListPayload? in
            if case .evidenceList(let p) = block { return p }
            return nil
        }
        XCTAssertEqual(evidenceLists.count, 1, "evidence_list present when attention items exist")
        XCTAssertEqual(evidenceLists[0].items.count, 1, "exactly 1 attention item (the failed wt)")
    }

    // MARK: - Test 5: projectState → determinism (encode twice, byte-equal)

    func testProjectStateDeterminism() throws {
        let ledger = fixturedLedger()
        let scene = RadarScene.derive(ledger: ledger)

        let doc1 = ProjectProjections.projectState(
            projectId: "proj_alpha",
            displayName: "Alpha",
            ledger: ledger,
            radarScene: scene,
            deriveSource: "event_stream:test"
        )
        let doc2 = ProjectProjections.projectState(
            projectId: "proj_alpha",
            displayName: "Alpha",
            ledger: ledger,
            radarScene: scene,
            deriveSource: "event_stream:test"
        )

        XCTAssertEqual(doc1, doc2, "same state must produce identical documents")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data1 = try encoder.encode(doc1)
        let data2 = try encoder.encode(doc2)
        XCTAssertEqual(data1, data2, "encoded bytes must be identical (determinism)")
    }

    // MARK: - Test 6: derive_source non-empty on EVERY produced document

    func testDeriveSourceNonEmptyOnAllDocs() {
        let ledger = fixturedLedger()
        let scene = RadarScene.derive(ledger: ledger)
        let catalog = threeRepoCatalog()
        let emptyCatalog = MockCatalogSource(items: [], tag: "catalog:empty")

        let docs: [ViewIRDocument] = [
            ProjectProjections.projectPicker(from: catalog),
            ProjectProjections.projectPicker(from: emptyCatalog),
            ProjectProjections.projectPicker(entries: catalog.items(),
                                              deriveSource: "catalog:direct"),
            ProjectProjections.projectState(
                projectId: "proj_alpha",
                displayName: "Alpha",
                ledger: ledger,
                radarScene: scene,
                deriveSource: "event_stream:ds_test"
            ),
        ]

        for (i, doc) in docs.enumerated() {
            XCTAssertFalse(doc.deriveSource.isEmpty,
                           "doc[\(i)] must have non-empty derive_source (P1)")
            for src in doc.deriveSource {
                XCTAssertFalse(src.isEmpty,
                               "doc[\(i)] has an empty string in derive_source — forbidden (P1)")
            }
        }
    }

    // MARK: - Test 7: intent routing via CatalogSource protocol

    func testIntentRoutingViaProtocol() {
        let catalog = MockCatalogSource(items: [
            CatalogItem(displayName: "MyProject",
                        remoteKey: "github.com/org/my-project",
                        localPath: "/repos/my-project",
                        pushedAt: nil),
        ], tag: "catalog:routing_test")

        // "项目" → picker doc via mocked catalog
        let pickerDoc = IntentRouter.route(
            input: "项目", runtimeKind: .localFM, catalog: catalog)
        XCTAssertEqual(pickerDoc.kind, "project_init")
        let hasPickerBlock = pickerDoc.blocks.contains {
            if case .projectPicker = $0 { return true }
            return false
        }
        XCTAssertTrue(hasPickerBlock, "项目 intent with non-empty catalog must route to picker")
        XCTAssertFalse(pickerDoc.deriveSource.isEmpty, "picker doc must have derive_source")

        // Project-name input → projectState doc
        let stateLedger = WorktreeLedger()
        let stateScene = RadarScene.derive(ledger: stateLedger)
        let stateDoc = IntentRouter.route(
            input: "myproject",
            runtimeKind: .localFM,
            catalog: catalog,
            ledger: stateLedger,
            radarScene: stateScene
        )
        XCTAssertEqual(stateDoc.kind, "project_state",
                       "project-name input must route to project_state document")
        XCTAssertFalse(stateDoc.deriveSource.isEmpty,
                       "project_state doc must have derive_source")

        // Verify derive_source cites the catalog tag.
        XCTAssertTrue(stateDoc.deriveSource.contains("catalog:routing_test"),
                      "project_state derive_source must cite the catalog's tag")
    }

    // MARK: - Test 8: read-only — fixture state is unchanged after projection

    func testReadOnlyFixtureUnchangedAfterProjection() {
        let ledger = fixturedLedger()
        // Snapshot the ledger state before calling the factory.
        let worktreesBefore = ledger.worktrees
        let projectsBefore = ledger.projects

        let scene = RadarScene.derive(ledger: ledger)
        _ = ProjectProjections.projectState(
            projectId: "proj_alpha",
            displayName: "Alpha",
            ledger: ledger,
            radarScene: scene,
            deriveSource: "event_stream:readonly_test"
        )

        // WorktreeLedger is a value type; the factory receives a copy.
        // The original must be identical after the call.
        XCTAssertEqual(ledger.worktrees, worktreesBefore,
                       "ledger.worktrees must not change after projection (read-only)")
        XCTAssertEqual(ledger.projects, projectsBefore,
                       "ledger.projects must not change after projection (read-only)")
    }
}

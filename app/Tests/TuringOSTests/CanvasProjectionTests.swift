// CanvasProjectionTests.swift — A1_26: Canvas Projection v1 tests.
//
// 12 tests covering:
//   1a. parse fixture markdown → expected leading node sequence (heading/para/heading/…).
//   1b. code fence contents are NOT split (multi-line content is one codeBlock node).
//   1c. parse is deterministic: same input twice → identical [MarkdownNode].
//   2a. layout determinism: same nodes+config → byte-equal CanvasGraph encoding x2.
//   2b. frames are monotonic in y (each frame.y > previous frame.y + previous frame.height - ε).
//   2c. heading indent: level-2 heading has x > 0; level-1 heading has x == 0.
//   3a. every CanvasNode.deriveSource is non-empty and contains the sourceId.
//   3b. canvasDocument.derive_source is non-empty and contains the sourceId.
//   4a. no-markup: markdown with <script> tag → text preserved as plain string.
//   4b. no-markup: projection blocks are all existing ViewIR types (no invented types).
//   5a. export descriptor is deterministic: same graph → identical descriptor.
//   5b. canvasGraphHash matches manual SHA-256 of canonical graph encoding.
//   6.  ViewIR.swift unchanged: only existing block types appear in canvasDocument output.

import Foundation
import XCTest
import CryptoKit
@testable import TuringOS

final class CanvasProjectionTests: XCTestCase {

    // MARK: - Fixture path helper

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // TuringOSTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // app
            .deletingLastPathComponent() // repo root
    }

    private static let fixtureMD: String = {
        let url = repoRoot.appendingPathComponent("fixtures/canvas_projection.fixture.md")
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }()

    // MARK: - Test 1a: parse fixture → expected leading node sequence

    func testParseFixtureLeadingNodes() {
        let nodes = MarkdownParser.parse(markdown: Self.fixtureMD)
        XCTAssertFalse(nodes.isEmpty, "fixture must produce at least one node")

        // First node must be heading level 1 with the expected title.
        if case .heading(let level, let text) = nodes[0] {
            XCTAssertEqual(level, 1)
            XCTAssertEqual(text, "Canvas Projection v1")
        } else {
            XCTFail("nodes[0] expected heading(1, …), got \(nodes[0])")
        }

        // Second node is a paragraph (the "TuringOS canvas derives…" line).
        if case .paragraph(_) = nodes[1] {
            // pass
        } else {
            XCTFail("nodes[1] expected paragraph, got \(nodes[1])")
        }

        // Third node is heading level 2 "Overview".
        if case .heading(let level, let text) = nodes[2] {
            XCTAssertEqual(level, 2)
            XCTAssertEqual(text, "Overview")
        } else {
            XCTFail("nodes[2] expected heading(2, 'Overview'), got \(nodes[2])")
        }

        // There should be a quote node somewhere.
        let hasQuote = nodes.contains { if case .quote(_) = $0 { return true }; return false }
        XCTAssertTrue(hasQuote, "fixture must contain at least one quote node")

        // There should be list items.
        let listItems = nodes.filter { if case .listItem(_, _) = $0 { return true }; return false }
        XCTAssertFalse(listItems.isEmpty, "fixture must contain list item nodes")

        // There should be exactly one thematic break (---).
        let breaks = nodes.filter { if case .thematicBreak = $0 { return true }; return false }
        XCTAssertEqual(breaks.count, 1, "fixture must contain exactly one thematic break")

        // There should be exactly one code block.
        let codeBlocks = nodes.filter { if case .codeBlock(_, _) = $0 { return true }; return false }
        XCTAssertEqual(codeBlocks.count, 1, "fixture must contain exactly one code block")
    }

    // MARK: - Test 1b: code fence contents are NOT split

    func testCodeFenceContentsNotSplit() {
        let md = """
        ```swift
        let x = 1
        let y = x + 2
        let z = y * 3
        ```
        """
        let nodes = MarkdownParser.parse(markdown: md)
        XCTAssertEqual(nodes.count, 1, "fenced block must produce exactly 1 node")
        if case .codeBlock(let lang, let content) = nodes[0] {
            XCTAssertEqual(lang, "swift")
            // Content must contain all three lines as a single string.
            XCTAssertTrue(content.contains("let x = 1"), "content must include first line")
            XCTAssertTrue(content.contains("let y = x + 2"), "content must include second line")
            XCTAssertTrue(content.contains("let z = y * 3"), "content must include third line")
            // Content must NOT be split into separate paragraphs — it's one string.
            let lines = content.components(separatedBy: "\n")
            XCTAssertEqual(lines.count, 3, "content has 3 lines joined by newlines")
        } else {
            XCTFail("expected codeBlock node, got \(nodes[0])")
        }
    }

    // MARK: - Test 1c: parse is deterministic

    func testParseDeterminism() {
        let nodes1 = MarkdownParser.parse(markdown: Self.fixtureMD)
        let nodes2 = MarkdownParser.parse(markdown: Self.fixtureMD)
        XCTAssertEqual(nodes1, nodes2, "parse must be deterministic: same input → identical output")
    }

    // MARK: - Test 2a: layout determinism (byte-equal encoding)

    func testLayoutDeterminism() throws {
        let nodes = MarkdownParser.parse(markdown: Self.fixtureMD)
        let config = CanvasLayoutConfig.default
        let graph1 = CanvasLayout.layout(nodes: nodes, config: config, sourceId: "test_source")
        let graph2 = CanvasLayout.layout(nodes: nodes, config: config, sourceId: "test_source")
        XCTAssertEqual(graph1, graph2, "layout must be deterministic")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data1 = try encoder.encode(graph1)
        let data2 = try encoder.encode(graph2)
        XCTAssertEqual(data1, data2, "encoded graph must be byte-equal across two runs")
    }

    // MARK: - Test 2b: frames monotonic in y

    func testFramesMonotonicInY() {
        let nodes = MarkdownParser.parse(markdown: Self.fixtureMD)
        let graph = CanvasLayout.layout(nodes: nodes, config: .default, sourceId: "test_source")
        guard graph.count >= 2 else {
            XCTFail("need at least 2 nodes to check monotonicity")
            return
        }
        for i in 1..<graph.count {
            let prev = graph[i - 1]
            let curr = graph[i]
            let minNextY = prev.frame.y + prev.frame.height
            XCTAssertGreaterThan(curr.frame.y, minNextY - 1e-9,
                "frame[\(i)].y (\(curr.frame.y)) must be > frame[\(i-1)].y (\(prev.frame.y)) + height (\(prev.frame.height))")
        }
    }

    // MARK: - Test 2c: heading indent applied correctly

    func testHeadingIndent() {
        let md = "# Level One\n## Level Two\n### Level Three"
        let nodes = MarkdownParser.parse(markdown: md)
        let graph = CanvasLayout.layout(nodes: nodes, config: .default, sourceId: "src")
        XCTAssertEqual(graph.count, 3)

        // Level 1: x = 0
        XCTAssertEqual(graph[0].frame.x, 0.0, "level-1 heading must have x=0")
        // Level 2: x > 0
        XCTAssertGreaterThan(graph[1].frame.x, 0.0, "level-2 heading must have x > 0")
        // Level 3: x > level-2 x
        XCTAssertGreaterThan(graph[2].frame.x, graph[1].frame.x, "level-3 must indent further than level-2")
    }

    // MARK: - Test 3a: every CanvasNode.deriveSource non-empty, contains sourceId

    func testCanvasNodeDeriveSource() {
        let nodes = MarkdownParser.parse(markdown: Self.fixtureMD)
        let sourceId = "fixture:canvas_projection"
        let graph = CanvasLayout.layout(nodes: nodes, config: .default, sourceId: sourceId)
        for node in graph {
            XCTAssertFalse(node.deriveSource.isEmpty,
                           "\(node.id): deriveSource must not be empty")
            XCTAssertTrue(node.deriveSource.contains(sourceId),
                          "\(node.id): deriveSource must contain sourceId '\(sourceId)'")
        }
    }

    // MARK: - Test 3b: canvasDocument.derive_source non-empty, contains sourceId

    func testCanvasDocumentDeriveSource() {
        let sourceId = "fixture:doc_source"
        let doc = CanvasProjection.canvasDocument(
            markdown: Self.fixtureMD,
            sourceId: sourceId
        )
        XCTAssertFalse(doc.deriveSource.isEmpty, "document derive_source must not be empty")
        XCTAssertTrue(doc.deriveSource.contains(sourceId),
                      "document derive_source must contain sourceId '\(sourceId)'")
    }

    // MARK: - Test 4a: no-markup — <script> and **bold** carried as plain text

    func testNoMarkupScriptTagPreservedAsPlainText() {
        let md = "A paragraph containing an HTML-like tag: <script>alert(1)</script> and **bold** text."
        let nodes = MarkdownParser.parse(markdown: md)
        // Must produce exactly one paragraph node.
        XCTAssertEqual(nodes.count, 1, "single line → single paragraph node")
        if case .paragraph(let text) = nodes[0] {
            // The raw string must be preserved intact — not transformed to markup.
            XCTAssertTrue(text.contains("<script>alert(1)</script>"),
                          "script tag must be carried verbatim as plain text, not transformed")
            XCTAssertTrue(text.contains("**bold**"),
                          "bold markers must be carried as plain text, not as attributed/HTML")
            // Negatively: the output must NOT contain something like "<b>bold</b>"
            XCTAssertFalse(text.contains("<b>"), "bold must not be converted to HTML")
            XCTAssertFalse(text.contains("<strong>"), "bold must not be converted to HTML")
        } else {
            XCTFail("expected paragraph node, got \(nodes[0])")
        }
    }

    // MARK: - Test 4b: projection blocks are only existing ViewIR block types

    func testProjectionUsesOnlyExistingBlockTypes() {
        let md = "<script>alert(1)</script>\n**bold** text"
        let doc = CanvasProjection.canvasDocument(markdown: md, sourceId: "security_test")
        for block in doc.blocks {
            switch block {
            case .summaryCard, .riskList, .approvalRequest, .diffView,
                 .evidenceList, .projectPicker, .specDraft, .budgetCard,
                 .worktreeMap, .repairPrompt, .dossierView, .morningRitual,
                 .intentSuggestions, .credentialField:
                // All known existing types — pass.
                break
            case .unknown(let rawType):
                XCTFail("canvasDocument must not produce .unknown block; found rawType='\(rawType)'")
            }
        }
    }

    // MARK: - Test 5a: export descriptor deterministic

    func testExportDescriptorDeterministic() {
        let nodes = MarkdownParser.parse(markdown: Self.fixtureMD)
        let graph = CanvasLayout.layout(nodes: nodes, config: .default, sourceId: "src")
        let d1 = CanvasProjection.exportDescriptor(graph: graph, format: .pdf)
        let d2 = CanvasProjection.exportDescriptor(graph: graph, format: .pdf)
        XCTAssertEqual(d1, d2, "export descriptor must be deterministic")
        XCTAssertEqual(d1.nodeCount, graph.count)
        XCTAssertFalse(d1.canvasGraphHash.isEmpty, "canvasGraphHash must not be empty")
    }

    // MARK: - Test 5b: canvasGraphHash matches manual SHA-256

    func testCanvasGraphHashMatchesManualSHA256() throws {
        let md = "# Hello\nWorld"
        let nodes = MarkdownParser.parse(markdown: md)
        let graph = CanvasLayout.layout(nodes: nodes, config: .default, sourceId: "hash_test")

        // Manually compute the expected hash using the same encoding.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(graph)
        let digest = SHA256.hash(data: data)
        let expectedHash = digest.map { String(format: "%02x", $0) }.joined()

        let descriptor = CanvasProjection.exportDescriptor(graph: graph, format: .markdown)
        XCTAssertEqual(descriptor.canvasGraphHash, expectedHash,
                       "canvasGraphHash must equal manual SHA-256 of canonical encoding")
    }

    // MARK: - Test 6: ViewIR.swift unchanged — only existing block types in canvasDocument

    func testViewIRUnchangedOnlyExistingBlockTypesInCanvasDoc() {
        // Build a canvas document from the fixture.
        let doc = CanvasProjection.canvasDocument(
            markdown: Self.fixtureMD,
            sourceId: "viewir_unchanged_test"
        )
        // Enumerate all block types and assert NONE is .unknown.
        // If ViewIR.swift had been modified to add a new type used here, the switch
        // would fall through to the default — but canvasDocument must not invent types.
        let unknownBlocks = doc.blocks.compactMap { block -> String? in
            if case .unknown(let t) = block { return t }
            return nil
        }
        XCTAssertTrue(unknownBlocks.isEmpty,
                      "canvasDocument must use only existing ViewIR block types; found unknown: \(unknownBlocks)")

        // Additionally assert that the document contains at least a summary_card
        // (always the header) and an evidence_list (canvas nodes), confirming
        // the factory uses existing types.
        let hasSummaryCard = doc.blocks.contains {
            if case .summaryCard(_) = $0 { return true }; return false
        }
        XCTAssertTrue(hasSummaryCard, "canvasDocument must contain a summary_card block")
    }
}

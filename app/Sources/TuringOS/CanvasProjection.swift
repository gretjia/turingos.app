// CanvasProjection.swift — A1_26: Canvas Projection v1 end-to-end factory.
//
// Design contract:
//   • Pure functions — same input → byte-identical ViewIRDocument / descriptor.
//   • No IO, no Date, no random, no network.
//   • Uses ONLY existing ViewIR block types (ViewIR.swift is UNCHANGED).
//   • Canvas is NOT a second source of truth: every node derives from its source doc.
//   • Freeform bridge: intentionally absent pending Apple public board API.
//     TODO(§6.7) Freeform export/share bridge when Apple ships a public board API;
//     never reverse the private Freeform format.
//   • NO model-generated executable HTML/JS, NO WKWebView (red line 1).

import Foundation
import CryptoKit

// MARK: - CanvasExportDescriptor

/// A pure description of a potential canvas export.
/// This is a DESCRIPTION ONLY — no export API is called.
/// Encoding is deterministic for the same canvasGraph.
public struct CanvasExportDescriptor: Codable, Equatable, Sendable {
    /// Supported export formats (description only).
    public enum Format: String, Codable, Equatable, Sendable, CaseIterable {
        case pdf
        case png
        case html
        case markdown
    }

    public let format: Format
    /// SHA-256 hex digest of the canonical (sorted-key) JSON encoding of the CanvasGraph.
    public let canvasGraphHash: String
    /// Number of nodes in the graph.
    public let nodeCount: Int

    public init(format: Format, canvasGraphHash: String, nodeCount: Int) {
        self.format = format
        self.canvasGraphHash = canvasGraphHash
        self.nodeCount = nodeCount
    }
}

// MARK: - CanvasProjection (pure factory namespace)

public enum CanvasProjection {

    // MARK: - canvasDocument

    /// End-to-end factory: Markdown text → ViewIRDocument representing the canvas.
    ///
    /// Steps (all pure):
    ///   1. Parse Markdown → [MarkdownNode] via MarkdownParser.
    ///   2. Lay out nodes → CanvasGraph via CanvasLayout.
    ///   3. Encode graph into ViewIR using ONLY existing block types:
    ///      - One `summary_card` as the canvas header (node count + source id).
    ///      - One `evidence_list` per CanvasNode carrying:
    ///          kind = "canvas_node"
    ///          label = node text (plain data; never interpreted as markup)
    ///          ref   = "<sourceId>:node_<i>:frame=<x>,<y>,<w>,<h>"
    ///
    /// derive_source of the document = [sourceId, "canvas_layout:v1"].
    ///
    /// No new block types are introduced — ViewIR.swift stays UNCHANGED.
    public static func canvasDocument(
        markdown: String,
        sourceId: String,
        config: CanvasLayoutConfig = .default
    ) -> ViewIRDocument {
        let markdownNodes = MarkdownParser.parse(markdown: markdown)
        let graph = CanvasLayout.layout(nodes: markdownNodes, config: config, sourceId: sourceId)

        let header = SummaryCardPayload(
            title: "Canvas Projection",
            body: "source: \(sourceId) · nodes: \(graph.count)",
            tapeRef: sourceId
        )

        // Encode every canvas node as an evidence item (plain data; no markup interpretation).
        let evidenceItems: [EvidenceItem] = graph.map { node in
            let f = node.frame
            return EvidenceItem(
                kind: "canvas_node",
                label: node.text,
                ref: "\(sourceId):\(node.id):kind=\(node.kind.rawValue):frame=\(f.x),\(f.y),\(f.width),\(f.height)"
            )
        }

        var blocks: [ViewIRBlock] = [.summaryCard(header)]
        if !evidenceItems.isEmpty {
            blocks.append(.evidenceList(EvidenceListPayload(items: evidenceItems)))
        }

        return ViewIRDocument(
            kind: "canvas_projection",
            deriveSource: [sourceId, "canvas_layout:v1"],
            blocks: blocks
        )
    }

    // MARK: - exportDescriptor

    /// Build a CanvasExportDescriptor for a given graph and format.
    /// The canvasGraphHash is SHA-256 of the canonical JSON encoding of the graph.
    ///
    /// Canonical encoding: JSONEncoder with .sortedKeys + .withoutEscapingSlashes
    /// on the CanvasGraph array. Same graph → identical hash.
    public static func exportDescriptor(
        graph: CanvasGraph,
        format: CanvasExportDescriptor.Format
    ) -> CanvasExportDescriptor {
        let hash = canonicalGraphHash(graph)
        return CanvasExportDescriptor(
            format: format,
            canvasGraphHash: hash,
            nodeCount: graph.count
        )
    }

    // MARK: - Canonical hash (internal, exposed for test verification)

    /// SHA-256 hex of the sorted-key JSON encoding of a CanvasGraph.
    public static func canonicalGraphHash(_ graph: CanvasGraph) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        // Encode as array; on failure (should never happen for pure value types) use empty.
        let data = (try? encoder.encode(graph)) ?? Data()
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - IntentRouter extension (A1_26 canvas wiring)

extension IntentRouter {
    /// Route "画布"/"canvas" + a markdown source → canvasDocument projection.
    /// Called from routeBase before the fallthrough to intentSuggestionsDoc().
    static func routeCanvas(lower: String, rawInput: String) -> ViewIRDocument? {
        guard lower.contains("画布") || lower.contains("canvas") else { return nil }
        // Extract optional inline Markdown after the keyword.
        // Pattern: "画布 <markdown>" or "canvas <markdown>".
        let markdownContent: String
        if let range = lower.range(of: "画布") ?? lower.range(of: "canvas") {
            let afterKeyword = String(rawInput[rawInput.index(rawInput.startIndex,
                                                              offsetBy: lower.distance(from: lower.startIndex,
                                                                                       to: range.upperBound))...])
                .trimmingCharacters(in: .whitespaces)
            markdownContent = afterKeyword.isEmpty ? "# Canvas" : afterKeyword
        } else {
            markdownContent = "# Canvas"
        }
        return CanvasProjection.canvasDocument(
            markdown: markdownContent,
            sourceId: "intent_router:canvas",
            config: .default
        )
    }
}

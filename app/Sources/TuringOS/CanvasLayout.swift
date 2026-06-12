// CanvasLayout.swift — A1_26: deterministic layout engine for canvas projection.
//
// Design contract:
//   • Pure function: layout(nodes:config:sourceId:) → CanvasGraph.
//   • Same input + config → byte-equal CanvasGraph (and byte-equal encoding).
//   • No IO, no Date, no random, no network.
//   • Every CanvasNode carries a non-empty deriveSource that traces to sourceId.
//   • Frame arithmetic: vertical flow, kind-based heights, heading indent by level.
//   • The canvas is NOT a second source of truth — every node derives from source.

import Foundation

// MARK: - CanvasFrame

/// The 2-D bounding rectangle of a canvas node (pure value).
public struct CanvasFrame: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

// MARK: - CanvasNodeKind

/// Semantic kind of a canvas node (mirrors MarkdownNode cases).
public enum CanvasNodeKind: String, Codable, Equatable, Sendable, CaseIterable {
    case heading
    case paragraph
    case listItem
    case codeBlock
    case quote
    case thematicBreak
}

// MARK: - CanvasNode

/// One node in the canvas graph.
///
/// `id` is deterministic: "node_<i>" where i is the 0-based index in the graph.
/// `deriveSource` is non-empty and contains the sourceId passed into `layout(…)`.
public struct CanvasNode: Codable, Equatable, Sendable {
    /// Deterministic identifier: "node_<index>".
    public let id: String
    /// Semantic kind.
    public let kind: CanvasNodeKind
    /// Plain text content of the node (never interpreted as markup/HTML).
    public let text: String
    /// Optional code language (non-nil only for codeBlock nodes).
    public let codeLanguage: String?
    /// Bounding frame computed by pure arithmetic.
    public let frame: CanvasFrame
    /// Non-empty; traces this node back to its source document.
    public let deriveSource: [String]

    public init(
        id: String,
        kind: CanvasNodeKind,
        text: String,
        codeLanguage: String? = nil,
        frame: CanvasFrame,
        deriveSource: [String]
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.codeLanguage = codeLanguage
        self.frame = frame
        self.deriveSource = deriveSource
    }
}

// MARK: - CanvasGraph

/// The full canvas graph: an ordered array of CanvasNodes.
public typealias CanvasGraph = [CanvasNode]

// MARK: - CanvasLayoutConfig

/// Configuration for the pure layout engine.
/// All values are fixed Doubles — no adaptive sizing, no model calls.
public struct CanvasLayoutConfig: Codable, Equatable, Sendable {
    /// Base width for all nodes (heading indent reduces effective x).
    public let baseWidth: Double
    /// Base line height for paragraph / list / quote nodes.
    public let lineHeight: Double
    /// Vertical spacing between consecutive nodes.
    public let spacing: Double
    /// Height multiplier for headings (applied to lineHeight).
    public let headingHeightMultiplier: Double
    /// Height for code blocks per line of content (min 1 line).
    public let codeLineHeight: Double
    /// Height for thematic break nodes.
    public let thematicBreakHeight: Double
    /// Horizontal indent per heading level (level 1 = 0, level 2 = 1×indent, etc.).
    public let headingLevelIndent: Double

    public init(
        baseWidth: Double = 640,
        lineHeight: Double = 28,
        spacing: Double = 12,
        headingHeightMultiplier: Double = 1.5,
        codeLineHeight: Double = 22,
        thematicBreakHeight: Double = 12,
        headingLevelIndent: Double = 16
    ) {
        self.baseWidth = baseWidth
        self.lineHeight = lineHeight
        self.spacing = spacing
        self.headingHeightMultiplier = headingHeightMultiplier
        self.codeLineHeight = codeLineHeight
        self.thematicBreakHeight = thematicBreakHeight
        self.headingLevelIndent = headingLevelIndent
    }

    /// Default configuration.
    public static let `default` = CanvasLayoutConfig()
}

// MARK: - CanvasLayout (pure engine)

public enum CanvasLayout {

    /// Lay out an array of MarkdownNodes into a CanvasGraph using pure arithmetic.
    ///
    /// Layout algorithm:
    ///   • Nodes are placed in vertical flow (top-to-bottom).
    ///   • x origin for headings = (level - 1) × headingLevelIndent; others = 0.
    ///   • Width = baseWidth - x.
    ///   • Height per kind:
    ///       heading     → lineHeight × headingHeightMultiplier
    ///       paragraph   → lineHeight
    ///       listItem    → lineHeight
    ///       quote       → lineHeight
    ///       codeBlock   → max(1, lineCount) × codeLineHeight
    ///       thematicBreak → thematicBreakHeight
    ///   • y of node[i] = y of node[i-1] + height of node[i-1] + spacing  (node[0].y = 0).
    ///   • id = "node_<i>" (0-based).
    ///   • deriveSource = [sourceId, "canvas_layout:v1"].
    ///
    /// Determinism: given identical (nodes, config, sourceId), the result is byte-equal.
    public static func layout(
        nodes: [MarkdownNode],
        config: CanvasLayoutConfig = .default,
        sourceId: String
    ) -> CanvasGraph {
        let deriveSource = [sourceId, "canvas_layout:v1"]
        var graph: CanvasGraph = []
        var currentY: Double = 0

        for (i, node) in nodes.enumerated() {
            let id = "node_\(i)"
            let kind: CanvasNodeKind
            let text: String
            var codeLanguage: String? = nil
            let x: Double
            let width: Double
            let height: Double

            switch node {
            case .heading(let level, let t):
                kind = .heading
                text = t
                x = Double(level - 1) * config.headingLevelIndent
                width = config.baseWidth - x
                height = config.lineHeight * config.headingHeightMultiplier

            case .paragraph(let t):
                kind = .paragraph
                text = t
                x = 0
                width = config.baseWidth
                height = config.lineHeight

            case .listItem(_, let t):
                kind = .listItem
                text = t
                x = 0
                width = config.baseWidth
                height = config.lineHeight

            case .codeBlock(let lang, let content):
                kind = .codeBlock
                text = content
                codeLanguage = lang
                x = 0
                width = config.baseWidth
                let lineCount = max(1, content.components(separatedBy: "\n").count)
                height = Double(lineCount) * config.codeLineHeight

            case .quote(let t):
                kind = .quote
                text = t
                x = 0
                width = config.baseWidth
                height = config.lineHeight

            case .thematicBreak:
                kind = .thematicBreak
                text = ""
                x = 0
                width = config.baseWidth
                height = config.thematicBreakHeight
            }

            let frame = CanvasFrame(x: x, y: currentY, width: width, height: height)
            let canvasNode = CanvasNode(
                id: id,
                kind: kind,
                text: text,
                codeLanguage: codeLanguage,
                frame: frame,
                deriveSource: deriveSource
            )
            graph.append(canvasNode)
            currentY += height + config.spacing
        }

        return graph
    }
}

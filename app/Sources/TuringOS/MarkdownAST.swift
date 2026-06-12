// MarkdownAST.swift — A1_26: minimal deterministic block-level Markdown parser.
//
// Supported subset (block-level only; no inline emphasis in v1):
//   • heading(level:text:)    — ATX headings: # to ###### on their own line.
//   • paragraph(text:)        — non-empty lines that don't match any other rule.
//   • listItem(depth:text:)   — lines starting with optional indent + "- " or "* ".
//   • codeBlock(language:content:) — fenced with ``` … ```; language from info-string.
//   • quote(text:)            — lines starting with "> ".
//   • thematicBreak           — lines of "---", "***", or "___" (3+ chars).
//
// NOT supported (v1): setext headings, indented code, HTML blocks, inline emphasis,
//   tables, tight/loose list merging, blank-line paragraph continuation.
//
// Iron law: Markdown text is DATA. This parser never interprets angle-bracket
//   content as HTML/markup, and never produces executable output.
//   script/style/HTML tags pass through as plain text inside paragraph nodes.
//
// Determinism: parse(markdown:) is a pure function — same input → identical output.
// No Date, no random, no IO.

import Foundation

// MARK: - MarkdownNode

/// A single block-level node produced by the Markdown parser.
public enum MarkdownNode: Equatable, Sendable {
    /// ATX heading: level 1–6.
    case heading(level: Int, text: String)
    /// Plain paragraph text (never interpreted as markup).
    case paragraph(text: String)
    /// List item with indent depth and plain text.
    case listItem(depth: Int, text: String)
    /// Fenced code block. `language` is the optional info string; `content` is verbatim.
    case codeBlock(language: String?, content: String)
    /// Block quote text ("> …" prefix stripped).
    case quote(text: String)
    /// Thematic break ("---", "***", "___").
    case thematicBreak
}

// MARK: - Parser

public enum MarkdownParser {

    /// Parse a Markdown string into a sequence of block-level nodes.
    ///
    /// Rules applied in order per line:
    ///   1. Fenced code-block open/close — content lines collected verbatim.
    ///   2. ATX heading (# … ######).
    ///   3. Thematic break (--- / *** / ___ with 3+ repeated chars, optional leading spaces).
    ///   4. Block quote (> …).
    ///   5. List item (optional leading spaces + "- " or "* ").
    ///   6. Blank line — ignored (no paragraph grouping in v1).
    ///   7. Anything else — paragraph.
    ///
    /// Fenced code block: opening fence must be exactly ``` at the start of a line
    /// (optionally followed by a language tag); closing fence is ``` alone on a line.
    /// Contents inside the fence are collected VERBATIM — no further parsing.
    public static func parse(markdown: String) -> [MarkdownNode] {
        let lines = markdown.components(separatedBy: "\n")
        var nodes: [MarkdownNode] = []

        var inCodeFence = false
        var codeLanguage: String? = nil
        var codeLines: [String] = []

        for line in lines {
            // --- fenced code block ---
            if inCodeFence {
                if isFenceClose(line) {
                    nodes.append(.codeBlock(language: codeLanguage,
                                            content: codeLines.joined(separator: "\n")))
                    inCodeFence = false
                    codeLanguage = nil
                    codeLines = []
                } else {
                    codeLines.append(line)
                }
                continue
            }

            if let lang = fenceOpen(line) {
                inCodeFence = true
                codeLanguage = lang.isEmpty ? nil : lang
                codeLines = []
                continue
            }

            // --- ATX heading ---
            if let h = parseHeading(line) {
                nodes.append(h)
                continue
            }

            // --- thematic break ---
            if isThematicBreak(line) {
                nodes.append(.thematicBreak)
                continue
            }

            // --- block quote ---
            if let q = parseQuote(line) {
                nodes.append(q)
                continue
            }

            // --- list item ---
            if let li = parseListItem(line) {
                nodes.append(li)
                continue
            }

            // --- blank line: skip ---
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }

            // --- paragraph (plain text; HTML/tags are data, never markup) ---
            nodes.append(.paragraph(text: line))
        }

        // Unclosed fence: emit as code block with collected content.
        if inCodeFence {
            nodes.append(.codeBlock(language: codeLanguage,
                                    content: codeLines.joined(separator: "\n")))
        }

        return nodes
    }

    // MARK: - Private helpers

    /// Returns the language tag (possibly empty) if `line` is a fence opener (```[lang]).
    private static func fenceOpen(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .init(charactersIn: " \t"))
        guard trimmed.hasPrefix("```") else { return nil }
        let after = String(trimmed.dropFirst(3))
        // A fence CLOSE looks the same when no language — disambiguate: if we're
        // NOT already in a fence, any ``` line is an opener.
        return after.trimmingCharacters(in: .whitespaces)
    }

    /// Returns true if `line` is a fence closer (``` alone or with trailing spaces).
    private static func isFenceClose(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .init(charactersIn: " \t"))
        return trimmed == "```"
    }

    /// Parses an ATX heading line (# … ######).
    private static func parseHeading(_ line: String) -> MarkdownNode? {
        var rest = line[line.startIndex...]
        var level = 0
        while level < 6 && rest.hasPrefix("#") {
            level += 1
            rest = rest.dropFirst()
        }
        guard level > 0 else { return nil }
        // Must be followed by a space (or end of line for empty heading).
        if rest.isEmpty {
            return .heading(level: level, text: "")
        }
        guard rest.hasPrefix(" ") else { return nil }
        let text = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
        return .heading(level: level, text: text)
    }

    /// Detects thematic breaks: "---", "***", "___" (3+ repeated chars, optional spaces).
    private static func isThematicBreak(_ line: String) -> Bool {
        let stripped = line.trimmingCharacters(in: .init(charactersIn: " \t"))
        guard stripped.count >= 3 else { return false }
        let ch = stripped.first!
        guard ch == "-" || ch == "*" || ch == "_" else { return false }
        return stripped.allSatisfy { $0 == ch }
    }

    /// Parses a block quote line ("> ").
    private static func parseQuote(_ line: String) -> MarkdownNode? {
        let trimmed = line.trimmingCharacters(in: .init(charactersIn: " \t"))
        guard trimmed.hasPrefix(">") else { return nil }
        var rest = String(trimmed.dropFirst())
        if rest.hasPrefix(" ") { rest = String(rest.dropFirst()) }
        return .quote(text: rest)
    }

    /// Parses a list item: optional leading spaces + "- " or "* " + text.
    private static func parseListItem(_ line: String) -> MarkdownNode? {
        var idx = line.startIndex
        var spaces = 0
        while idx < line.endIndex && (line[idx] == " " || line[idx] == "\t") {
            spaces += line[idx] == "\t" ? 4 : 1
            idx = line.index(after: idx)
        }
        guard idx < line.endIndex else { return nil }
        let ch = line[idx]
        guard ch == "-" || ch == "*" else { return nil }
        let next = line.index(after: idx)
        guard next < line.endIndex && line[next] == " " else { return nil }
        let textStart = line.index(after: next)
        let text = String(line[textStart...])
        let depth = spaces / 2  // 2 spaces per depth level
        return .listItem(depth: depth, text: text)
    }
}

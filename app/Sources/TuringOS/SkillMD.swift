// SkillMD.swift — SKILL.md document parser (A1_29).
//
// BOUNDARY (WHITEPAPER.md §13.9):
//   Parse only — no script execution, no I/O beyond string processing.
//   Progressive disclosure: L1 = frontmatter (always loaded), L2 = body (loaded
//   when triggered), L3 = scripts/resources (referenced by path string only —
//   this atom does NOT execute or read them).
//
// Supported YAML frontmatter subset (--- delimited):
//   • key: scalar value   (string, including unquoted values)
//   • key:                (empty string → "")
//   • key:                followed by - item lines → String array
//   • One level of nesting: outer_key:\n  inner_key: value (parsed into [String: SkillMDValue])
//   Multi-line strings, anchors, aliases, and tags are NOT supported.
//   Unknown lines inside a nested block are silently skipped.
//
// Progressive disclosure model (FEASIBILITY Part IV-3):
//   L1 — frontmatter keys and scalar/list values; ALWAYS available after parse.
//   L2 — `body` (Markdown text after the closing ---); available after parse.
//   L3 — scripts and resources referenced by path string in frontmatter/body;
//        this parser surfaces them as path strings only — callers must resolve
//        and execute them through the appropriate runtime (not present yet).

import Foundation

// MARK: - SkillMDValue

/// A typed value from SKILL.md YAML frontmatter.
///
/// Only scalar (string) and list (array of strings) variants are produced by
/// this parser.  Nested objects are represented as `.object([String: SkillMDValue])`.
public indirect enum SkillMDValue: Equatable, Sendable {
    /// A single string scalar (including booleans/numbers as raw strings).
    case scalar(String)
    /// An ordered list of string items (`- item` YAML syntax).
    case list([String])
    /// One level of nested mapping (`outer_key:\n  inner_key: value`).
    case object([String: SkillMDValue])
}

// MARK: - SkillMDDocument

/// Parsed SKILL.md document.
///
/// Progressive disclosure levels:
///   - L1: `frontmatter` — always present after `SkillMDParser.parse(_:)`.
///   - L2: `body` — the Markdown instructions text; always present after parse.
///   - L3: scripts/resources — referenced as path strings inside `frontmatter`
///         or `body`; this model does NOT read or execute them.
public struct SkillMDDocument: Equatable, Sendable {
    /// L1: YAML frontmatter key/value map (parsed subset).
    /// Keys are trimmed; values are `.scalar`, `.list`, or `.object`.
    public let frontmatter: [String: SkillMDValue]

    /// L2: Markdown body text (everything after the closing `---` delimiter).
    /// Leading/trailing whitespace is stripped.
    public let body: String

    public init(frontmatter: [String: SkillMDValue], body: String) {
        self.frontmatter = frontmatter
        self.body = body
    }
}

// MARK: - SkillMDParser

/// Deterministic, pure SKILL.md parser.
///
/// All public functions are pure: identical input → identical output.
/// No I/O is performed (no file reading, no script execution).
///
/// ## Supported YAML subset
/// Delimited by `---` markers (standard YAML front matter convention).
/// Lines inside the front matter block:
///   - `key: scalar`          → `.scalar("scalar")`
///   - `key:`                 → `.scalar("")` (empty value)
///   - `key:` + subsequent `  - item` lines → `.list([...])`
///   - `outer_key:` + subsequent `  inner_key: value` lines → `.object([...])`
///
/// Limitation: only one level of nesting is supported.  Arrays of objects,
/// multi-document YAML, anchors, aliases, and complex types are not supported.
public enum SkillMDParser {

    // MARK: - parse

    /// Parse a SKILL.md string into a `SkillMDDocument`.
    ///
    /// - Parameter text: Raw SKILL.md content (UTF-8 string).
    /// - Returns: Parsed document.  If no `---` block is found, `frontmatter`
    ///   is empty and the entire text is treated as the body.
    ///
    /// ## Determinism guarantee
    /// For any fixed input string, the output is always identical (pure function,
    /// no randomness, no external state).
    public static func parse(_ text: String) -> SkillMDDocument {
        let lines = text.components(separatedBy: "\n")

        // Locate --- delimiters.
        var firstDash: Int? = nil
        var secondDash: Int? = nil
        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                if firstDash == nil {
                    firstDash = i
                } else {
                    secondDash = i
                    break
                }
            }
        }

        guard let start = firstDash, let end = secondDash, end > start else {
            // No valid frontmatter block — return empty frontmatter + full text body.
            let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return SkillMDDocument(frontmatter: [:], body: body)
        }

        let fmLines = Array(lines[(start + 1)..<end])
        let bodyLines = Array(lines[(end + 1)...])
        let body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        let frontmatter = parseFrontmatterLines(fmLines)
        return SkillMDDocument(frontmatter: frontmatter, body: body)
    }

    // MARK: - Private: frontmatter line parser

    private static func parseFrontmatterLines(_ lines: [String]) -> [String: SkillMDValue] {
        var result: [String: SkillMDValue] = [:]
        var i = 0

        while i < lines.count {
            let line = lines[i]
            // Skip blank lines.
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                i += 1
                continue
            }
            // Top-level lines must not be indented (first char not whitespace).
            guard let firstChar = line.first, !firstChar.isWhitespace else {
                i += 1
                continue
            }
            // Split on first colon.
            guard let colonIdx = line.firstIndex(of: ":") else {
                i += 1
                continue
            }
            let key = String(line[line.startIndex..<colonIdx]).trimmingCharacters(in: .whitespaces)
            let afterColon = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

            guard !key.isEmpty else { i += 1; continue }

            // Peek ahead to determine value type.
            // If afterColon is empty, look at the next lines.
            if afterColon.isEmpty {
                // Collect indented children.
                var children: [(String, String)] = []  // (raw_child_line_trimmed, _)
                var j = i + 1
                while j < lines.count {
                    let child = lines[j]
                    // A child line must be indented (starts with space/tab).
                    guard let fc = child.first, fc.isWhitespace else { break }
                    let trimmedChild = child.trimmingCharacters(in: .whitespaces)
                    if !trimmedChild.isEmpty {
                        children.append((trimmedChild, child))
                    }
                    j += 1
                }

                if children.isEmpty {
                    // Empty scalar.
                    result[key] = .scalar("")
                } else if children.first?.0.hasPrefix("- ") == true || children.first?.0 == "-" {
                    // List block.
                    let items: [String] = children.compactMap { (trimmed, _) in
                        if trimmed.hasPrefix("- ") {
                            return String(trimmed.dropFirst(2))
                        } else if trimmed == "-" {
                            return ""
                        }
                        return nil
                    }
                    result[key] = .list(items)
                } else {
                    // Nested object (one level).
                    var obj: [String: SkillMDValue] = [:]
                    for (trimmed, _) in children {
                        if let cColon = trimmed.firstIndex(of: ":") {
                            let cKey = String(trimmed[trimmed.startIndex..<cColon]).trimmingCharacters(in: .whitespaces)
                            let cVal = String(trimmed[trimmed.index(after: cColon)...]).trimmingCharacters(in: .whitespaces)
                            if !cKey.isEmpty {
                                obj[cKey] = .scalar(cVal)
                            }
                        }
                    }
                    result[key] = .object(obj)
                }
                i = j  // Skip consumed child lines.
            } else {
                // Inline scalar value.
                result[key] = .scalar(afterColon)
                i += 1
            }
        }

        return result
    }
}

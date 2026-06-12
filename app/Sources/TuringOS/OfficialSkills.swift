// OfficialSkills.swift — Official skill template registry (A1_29).
//
// BOUNDARY (WHITEPAPER.md §13.9):
//   This module parses and validates the bundled SKILL.md fixtures under
//   fixtures/skills/.  The resulting TuringSkill instances are TEMPLATE DATA —
//   drafts only.  NOTHING here activates a skill (activation is tape-gated,
//   P1.9 lane not yet available).
//
// officialSkillTemplates() reads the fixture files from the repo root path
// relative to the calling source file (using #filePath).  This is the same
// pattern used by CapabilityManifestTests and ViewIRTests for fixture loading —
// deterministic, no bundle lookup needed.
//
// Returned skills: all have status == .draft.  None are activated.

import Foundation

// MARK: - OfficialSkillsError

/// Errors emitted when an official skill fixture cannot be loaded or validated.
public enum OfficialSkillsError: Error, Sendable, CustomStringConvertible {
    case fileNotFound(URL)
    case validationFailed(filename: String, errors: [SkillValidationError])

    public var description: String {
        switch self {
        case .fileNotFound(let url):
            return "Official skill fixture not found: \(url.path)"
        case .validationFailed(let name, let errors):
            let detail = errors.map(\.description).joined(separator: "; ")
            return "Official skill fixture '\(name)' failed validation: \(detail)"
        }
    }
}

// MARK: - OfficialSkills

/// Registry of bundled official skill template definitions.
public enum OfficialSkills {

    // MARK: - Fixture filenames

    /// The canonical list of official SKILL.md fixture filenames under fixtures/skills/.
    public static let fixtureFilenames: [String] = [
        "markdown_to_doc.SKILL.md",
        "failure_certificate_root_cause.SKILL.md",
        "github_pr_review.SKILL.md",
    ]

    // MARK: - officialSkillTemplates

    /// Parse and validate all bundled official skill fixtures.
    ///
    /// Resolves fixture paths relative to the repo root (derived from `#filePath`
    /// at compile time — the same mechanism used throughout the test suite).
    ///
    /// All returned skills have `status == .draft`.  None are activated.
    ///
    /// - Throws: `OfficialSkillsError` if any fixture is missing or invalid.
    /// - Returns: An array of validated `TuringSkill` template drafts.
    public static func officialSkillTemplates(
        sourceFilePath: String = #filePath
    ) throws -> [TuringSkill] {
        let skillsDir = repoRoot(from: sourceFilePath)
            .appendingPathComponent("fixtures/skills")

        var skills: [TuringSkill] = []
        for filename in fixtureFilenames {
            let url = skillsDir.appendingPathComponent(filename)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                throw OfficialSkillsError.fileNotFound(url)
            }
            let doc = SkillMDParser.parse(text)
            switch SkillValidator.validate(doc) {
            case .valid(let skill, _):
                skills.append(skill)
            case .invalid(let errors):
                throw OfficialSkillsError.validationFailed(filename: filename, errors: errors)
            }
        }
        return skills
    }

    // MARK: - Private: repo root resolution

    /// Derive the repo root URL from the source file path.
    ///
    /// `OfficialSkills.swift` is at:
    ///   app/Sources/TuringOS/OfficialSkills.swift
    ///
    /// → delete: TuringOS → Sources → app → repo root
    private static func repoRoot(from filePath: String) -> URL {
        URL(fileURLWithPath: filePath)
            .deletingLastPathComponent() // TuringOS
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // app
            .deletingLastPathComponent() // repo root
    }
}

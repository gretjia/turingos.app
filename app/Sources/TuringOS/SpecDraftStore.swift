// SpecDraftStore.swift — persist draft SpecPackages to app support (A1_18).
//
// Persistence pattern: Workspace idiom (one JSON file per projectId under
// TuringOS/spec_drafts/<projectId>.json).  Atomic write (temp + rename).
//
// ## Projection three-piece declaration (UPSTREAM_CONTRACT iron law 3)
//
// Every stored envelope wraps the SpecPackage and adds the three-piece header:
//   derive_source:     user_input + catalog
//   schema_version:    tos.app.spec_draft.v0   (matches SpecPackage.schemaVersion)
//   rebuild_command:   re-run SpecDraftWizard or Retro-Init prefill path
//
// These fields are embedded in the persisted JSON via SpecDraftEnvelope.
//
// ## Status discipline
//
// The store persists whatever status the caller sets.  It never sets status=ratified
// itself — that case does not exist in SpecStatus.  See SpecPackage.swift for the
// constitutional boundary explanation.

import Foundation

// MARK: - SpecDraftEnvelope

/// Top-level persisted container.  Embeds the three-piece projection declaration
/// alongside the SpecPackage so any reader can trace provenance without extra
/// out-of-band metadata.
public struct SpecDraftEnvelope: Codable, Sendable, Equatable {
    // Three-piece declaration (UPSTREAM_CONTRACT iron law 3)
    public let schemaVersion: String   // == "tos.app.spec_draft.v0"
    public let deriveSource: [String]  // ["user_input", "catalog"]
    public let rebuildCommand: String  // human-readable re-run instruction

    public let spec: SpecPackage

    enum CodingKeys: String, CodingKey {
        case schemaVersion  = "schema_version"
        case deriveSource   = "derive_source"
        case rebuildCommand = "rebuild_command"
        case spec
    }

    public init(spec: SpecPackage) {
        self.schemaVersion  = "tos.app.spec_draft.v0"
        self.deriveSource   = ["user_input", "catalog"]
        self.rebuildCommand = "Re-run SpecDraftWizard.run(projectId:) or SpecDraftReducer.prefill(projectId:name:path:currentBranch:)"
        self.spec           = spec
    }
}

// MARK: - SpecDraftStore

/// Reads and writes draft SpecPackages as JSON files under TuringOS/spec_drafts/.
///
/// All writes are atomic (temp file + rename) to prevent torn reads.
/// One file per projectId; filename = "\(projectId).json".
public enum SpecDraftStore {

    // MARK: - Paths

    public static var draftsDirectory: URL {
        Workspace.supportDir.appendingPathComponent("spec_drafts", isDirectory: true)
    }

    public static func fileURL(for projectId: String) -> URL {
        draftsDirectory.appendingPathComponent("\(projectId).json")
    }

    // MARK: - Save

    /// Persist a SpecPackage as a draft envelope.  Creates parent directory if needed.
    /// Atomic write: write to a temp file first, then rename.
    ///
    /// - Returns: the URL the draft was written to.
    @discardableResult
    public static func save(_ spec: SpecPackage) throws -> URL {
        let envelope = SpecDraftEnvelope(spec: spec)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(envelope)

        let dir = draftsDirectory
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)

        let dest = fileURL(for: spec.projectId)
        let tmp  = dest.deletingLastPathComponent()
            .appendingPathComponent(".\(spec.projectId).json.tmp")
        try data.write(to: tmp, options: .atomic)
        // Atomic rename (replaceItemAt falls back to remove+move — acceptable here
        // because the temp file is in the same directory, same fs).
        _ = try FileManager.default.replaceItemAt(dest, withItemAt: tmp)
        return dest
    }

    // MARK: - Load

    /// Load a previously saved draft envelope.
    /// - Returns: the SpecPackage, or nil if no draft exists for this projectId.
    public static func load(projectId: String) throws -> SpecPackage? {
        let url = fileURL(for: projectId)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let envelope = try JSONDecoder().decode(SpecDraftEnvelope.self, from: data)
        return envelope.spec
    }

    // MARK: - Load envelope (for tests / three-piece verification)

    /// Load the full envelope (spec + three-piece declaration).
    public static func loadEnvelope(projectId: String) throws -> SpecDraftEnvelope? {
        let url = fileURL(for: projectId)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SpecDraftEnvelope.self, from: data)
    }

    // MARK: - Delete

    /// Remove a draft file.  Silently succeeds if the file does not exist.
    public static func delete(projectId: String) throws {
        let url = fileURL(for: projectId)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - List

    /// Return the projectIds of all stored drafts.
    public static func listProjectIds() throws -> [String] {
        let dir = draftsDirectory
        guard FileManager.default.fileExists(atPath: dir.path) else { return [] }
        let contents = try FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)
        return contents
            .filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasPrefix(".") }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }
}

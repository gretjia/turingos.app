// StumpStore.swift — A1_24: strategy observe-only layer — StumpForest persistence.
//
// Persistence pattern: mirrors SpecDraftStore idiom exactly.
//   - One JSON file per projectId under TuringOS/stump_forests/<projectId>.json.
//   - Atomic write (temp + rename) to prevent torn reads.
//   - Every stored envelope carries the three-piece declaration (UPSTREAM_CONTRACT
//     iron law 3):
//       schema_version:  tos.app.stump_forest.v0
//       derive_source:   ["user_input", "meta_suggestion"]
//       rebuild_command: re-create via ops log description
//
// No mutation of StumpForest happens here — the store is a pure read/write
// boundary.  All forest ops live in ProjectStump.swift (pure functions on
// StumpForest value type).

import Foundation

// MARK: - StumpForestEnvelope

/// Top-level persisted container.  Embeds the three-piece projection declaration
/// alongside the StumpForest so any reader can trace provenance without extra
/// out-of-band metadata.
public struct StumpForestEnvelope: Codable, Sendable, Equatable {
    // Three-piece declaration (UPSTREAM_CONTRACT iron law 3)
    public let schemaVersion:   String    // == "tos.app.stump_forest.v0"
    public let deriveSource:    [String]  // ["user_input", "meta_suggestion"]
    public let rebuildCommand:  String    // re-create instruction

    public let forest: StumpForest

    enum CodingKeys: String, CodingKey {
        case schemaVersion  = "schema_version"
        case deriveSource   = "derive_source"
        case rebuildCommand = "rebuild_command"
        case forest
    }

    public init(forest: StumpForest) {
        self.schemaVersion  = "tos.app.stump_forest.v0"
        self.deriveSource   = ["user_input", "meta_suggestion"]
        self.rebuildCommand = "Re-create via the ops log: replay add/prune/reactivate calls in order."
        self.forest         = forest
    }
}

// MARK: - StumpStore

/// Reads and writes StumpForests as JSON files under TuringOS/stump_forests/.
///
/// All writes are atomic (temp file + rename) to prevent torn reads.
/// One file per projectId; filename = "\(projectId).json".
public enum StumpStore {

    // MARK: - Paths

    public static var forestsDirectory: URL {
        Workspace.supportDir.appendingPathComponent("stump_forests", isDirectory: true)
    }

    public static func fileURL(for projectId: String) -> URL {
        forestsDirectory.appendingPathComponent("\(projectId).json")
    }

    // MARK: - Save

    /// Persist a StumpForest as an envelope.  Creates parent directory if needed.
    /// Atomic write: write to a temp file first, then rename.
    ///
    /// - Returns: the URL the forest was written to.
    @discardableResult
    public static func save(_ forest: StumpForest, projectId: String) throws -> URL {
        let envelope = StumpForestEnvelope(forest: forest)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(envelope)

        let dir = forestsDirectory
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)

        let dest = fileURL(for: projectId)
        let tmp  = dest.deletingLastPathComponent()
            .appendingPathComponent(".\(projectId).json.tmp")
        try data.write(to: tmp, options: .atomic)
        _ = try FileManager.default.replaceItemAt(dest, withItemAt: tmp)
        return dest
    }

    // MARK: - Load

    /// Load a previously saved StumpForest.
    /// - Returns: the StumpForest, or nil if no forest exists for this projectId.
    public static func load(projectId: String) throws -> StumpForest? {
        let url = fileURL(for: projectId)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let envelope = try JSONDecoder().decode(StumpForestEnvelope.self, from: data)
        return envelope.forest
    }

    // MARK: - Load envelope (for tests / three-piece verification)

    /// Load the full envelope (forest + three-piece declaration).
    public static func loadEnvelope(projectId: String) throws -> StumpForestEnvelope? {
        let url = fileURL(for: projectId)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(StumpForestEnvelope.self, from: data)
    }

    // MARK: - Delete

    /// Remove a forest file.  Silently succeeds if the file does not exist.
    public static func delete(projectId: String) throws {
        let url = fileURL(for: projectId)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - List

    /// Return the projectIds of all stored forests.
    public static func listProjectIds() throws -> [String] {
        let dir = forestsDirectory
        guard FileManager.default.fileExists(atPath: dir.path) else { return [] }
        let contents = try FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil)
        return contents
            .filter { $0.pathExtension == "json" && !$0.lastPathComponent.hasPrefix(".") }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }
}

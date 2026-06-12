// FileTapeSink.swift — A1_31: shell-side JSONL TapeSink implementation.
//
// Constitutional anchors:
//   - docs/01_KERNEL_CONTRACTS.md I8 — every ModelCall must enter tape;
//     this sink makes the append DURABLE (FileHandle write to disk) before
//     returning without error, per the TapeSink protocol contract.
//   - contracts/model_call.schema.json — each line is one ModelCallRecord
//     covering all 14 required keys (sortedKeys, single line, \n terminated).
//
// SHELL-SIDE TAPE ENVELOPE DISCIPLINE: this is the SHELL OBSERVATION RECORD
// of model traffic (contracts/model_call.schema.json). Canonical ChainTape
// semantics live in runtime/ (UPSTREAM_CONTRACT) — this sink does NOT
// advance Q, does NOT record ratifications. It is an append-only observation
// log, not the constitutional tape.
//
// APPEND-ONLY: never truncate, never rewrite. The file only ever grows;
// each append seeks to end and writes one line. Earlier lines are immutable.

import Foundation

// MARK: - FileTapeSink

/// Append-only JSONL sink for ModelCallRecord entries.
///
/// One record = one line of sortedKeys JSON + "\n". The file is created on
/// first append; the parent directory is created if missing. Concurrent
/// appends are serialized by an NSLock (whole-line writes — no interleaving).
public final class FileTapeSink: TapeSink, @unchecked Sendable {

    /// Tape file location (injected — tests use a temp directory).
    public let fileURL: URL

    /// Serializes appends so concurrent callers never interleave lines.
    private let lock = NSLock()

    /// Designated initialiser. The path is injected; no I/O happens here.
    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// Default production sink: Workspace support dir + "model_calls.jsonl"
    /// (same Application Support pattern as Workspace.registryURL).
    public static func defaultSink() -> FileTapeSink {
        FileTapeSink(fileURL: Workspace.supportDir.appendingPathComponent("model_calls.jsonl"))
    }

    // MARK: - TapeSink

    /// Append one record as a single JSONL line. Durable before return:
    /// the FileHandle write has handed the bytes to the filesystem when this
    /// method returns without throwing (I8: record-then-return upstream).
    public func append(_ record: ModelCallRecord) throws {
        lock.lock()
        defer { lock.unlock() }

        // Encode as single-line JSON (sortedKeys for stable key order) + newline.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var line = try encoder.encode(record)
        line.append(0x0A) // "\n"

        // Create parent directory + file if missing (first append).
        let fm = FileManager.default
        try fm.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if !fm.fileExists(atPath: fileURL.path) {
            fm.createFile(atPath: fileURL.path, contents: nil)
        }

        // APPEND-ONLY: seek to end, write, close. Never truncate or rewrite.
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
    }
}

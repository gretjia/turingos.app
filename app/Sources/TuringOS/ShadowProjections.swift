// ShadowProjections.swift — A1_27: ViewIR projections for shadow workspace state.
//
// Governing law: WHITEPAPER §13.3 (Class-1 staging substrate projections).
// ADR-003: UI is a derived projection of tape state.
//
// Design contract:
//   • Pure functions — same input always produces byte-identical output.
//   • Uses ONLY existing ViewIR block types (ViewIR.swift UNCHANGED).
//   • Every document carries non-empty derive_source (ADR-003 / P1 predicate).
//   • derive_source cites staging id + "shadow_workspace:v1".
//   • No FileManager writes, no git invocations, no model calls, no network.

import Foundation

// MARK: - ShadowProjections

public enum ShadowProjections {

    // MARK: - stagedDiffDocument

    /// Deterministic factory: produces a ViewIRDocument showing the staged diff
    /// for a shadow workspace.
    ///
    /// Block layout:
    ///   1. summary_card — staging id, diff line count, status summary
    ///   2. diff_view    — references the staging id as worktree_id, provenance=PARTIAL
    ///                     (shadow copy is app-owned; not a real repo governance unit)
    ///
    /// - Parameters:
    ///   - stagingId: the shadow workspace id (used as worktree_id in diff_view).
    ///   - diffText: the raw git diff --cached output (may be empty).
    ///   - deriveSource: caller-provided source tag (appended alongside the
    ///     canonical shadow_workspace:v1 source).
    /// - Returns: A ViewIRDocument using only existing block types from ViewIR.swift.
    public static func stagedDiffDocument(
        stagingId: String,
        diffText: String,
        deriveSource: String
    ) -> ViewIRDocument {
        let lineCount = diffText.isEmpty ? 0 : diffText.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ).count

        let body: String
        if diffText.isEmpty {
            body = """
            Staging ID: \(stagingId)
            Status: no staged changes
            """
        } else {
            body = """
            Staging ID: \(stagingId)
            Status: \(lineCount) diff lines staged

            Use discard() to clear or restore(ref:) to roll back.
            """
        }

        let summaryCard = SummaryCardPayload(
            title: "Shadow Workspace — Staged Changes",
            body: body,
            tapeRef: "shadow:\(stagingId)"
        )

        // diff_view block:
        //   diff_ref  = "shadow:<stagingId>:cached" (logical reference; no push outside copy)
        //   worktree_id = stagingId (this copy IS the worktree)
        //   provenance = PARTIAL (app-owned copy, not under real repo governance)
        let diffView = DiffViewPayload(
            diffRef: "shadow:\(stagingId):cached",
            worktreeId: stagingId,
            provenance: "PARTIAL"
        )

        return ViewIRDocument(
            kind: "shadow_workspace_diff",
            deriveSource: [
                "shadow_workspace:v1:\(stagingId)",
                deriveSource,
            ],
            blocks: [
                .summaryCard(summaryCard),
                .diffView(diffView),
            ]
        )
    }

    // MARK: - discardedDocument

    /// Deterministic factory: produces a ViewIRDocument confirming a discard
    /// operation completed within the staging copy.
    ///
    /// - Parameters:
    ///   - stagingId: the shadow workspace id.
    ///   - deriveSource: caller-provided source tag.
    public static func discardedDocument(
        stagingId: String,
        deriveSource: String
    ) -> ViewIRDocument {
        let card = SummaryCardPayload(
            title: "Shadow Workspace — Staged Changes Discarded",
            body: """
            Staging ID: \(stagingId)
            Status: staged changes discarded (restored to baseline)

            The staging copy is clean. The user's real repository is unchanged.
            """,
            tapeRef: "shadow:\(stagingId)"
        )

        return ViewIRDocument(
            kind: "shadow_workspace_discard",
            deriveSource: [
                "shadow_workspace:v1:\(stagingId)",
                deriveSource,
            ],
            blocks: [.summaryCard(card)]
        )
    }

    // MARK: - restorePointDocument

    /// Deterministic factory: produces a ViewIRDocument confirming a restore
    /// point was captured in the staging copy.
    ///
    /// - Parameters:
    ///   - stagingId: the shadow workspace id.
    ///   - ref: the stash ref returned by ShadowWorkspace.restorePoint().
    ///   - deriveSource: caller-provided source tag.
    public static func restorePointDocument(
        stagingId: String,
        ref: String,
        deriveSource: String
    ) -> ViewIRDocument {
        let card = SummaryCardPayload(
            title: "Shadow Workspace — Restore Point Captured",
            body: """
            Staging ID: \(stagingId)
            Restore ref: \(ref)

            Restore the staging copy at any time by calling restore(ref: "\(ref)").
            The user's real repository is unchanged.
            """,
            tapeRef: "shadow:\(stagingId):restore:\(ref)"
        )

        return ViewIRDocument(
            kind: "shadow_workspace_restore_point",
            deriveSource: [
                "shadow_workspace:v1:\(stagingId)",
                deriveSource,
            ],
            blocks: [.summaryCard(card)]
        )
    }
}

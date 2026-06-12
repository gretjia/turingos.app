// StagedEdit.swift — A1_27: value model for a single staged edit in a
// shadow workspace.
//
// Governing law: WHITEPAPER §13.3 (Class-1 reversible-local action staging
// substrate). ADR-002 (git semantics).
//
// CRITICAL SAFETY BOUNDARY:
//   StagedEdit deliberately has NO method that writes outside the staging
//   root or promotes content to the real file system. "promote-to-real"
//   (applying staged edits to a user's actual repository) is gated on the
//   approval ceremony = gated on runtime tape, and is therefore OUT OF SCOPE
//   for this type.
//
//   The absence of any apply/promote method is TYPE-LEVEL ENFORCEMENT of the
//   boundary stated in WHITEPAPER §13.3 and the atom scope card.

import Foundation

// MARK: - StagedEdit.Status

/// Lifecycle status of a staged edit.
public enum StagedEditStatus: String, Sendable, Equatable, Codable, CaseIterable {
    /// The edit has been written to the staging copy and git-added.
    case staged
    /// The edit has been discarded (git checkout / clean within copy).
    case discarded
}

// MARK: - StagedEdit

/// Immutable value type representing one staged edit in a shadow workspace.
///
/// A StagedEdit records which file was edited, in which staging workspace,
/// and whether a restore point was captured. It carries no real-file path
/// and exposes no method that touches anything outside the staging root.
///
/// SAFETY NOTE: There is intentionally no `applyToReal`, `promote`, or
/// `write(to:)` method on this type. Promoting staged changes to the user's
/// actual repository requires the approval ceremony (runtime tape gating)
/// which is OUT OF SCOPE for this atom (A1_27). Any future promotion path
/// must be added in a separate atom with a full approval-ceremony integration.
public struct StagedEdit: Sendable, Equatable {
    /// The staging workspace this edit belongs to.
    public let stagingId: String

    /// Path relative to the staging root (e.g. "Sources/Foo/Bar.swift").
    public let relativePath: String

    /// Stash ref returned by ShadowWorkspace.restorePoint(), or nil if no
    /// restore point has been captured for this edit.
    public let restorePointRef: String?

    /// Current lifecycle status of this edit.
    public let status: StagedEditStatus

    public init(
        stagingId: String,
        relativePath: String,
        restorePointRef: String? = nil,
        status: StagedEditStatus
    ) {
        self.stagingId = stagingId
        self.relativePath = relativePath
        self.restorePointRef = restorePointRef
        self.status = status
    }

    /// Returns a copy of this edit with the given status.
    public func withStatus(_ newStatus: StagedEditStatus) -> StagedEdit {
        StagedEdit(
            stagingId: stagingId,
            relativePath: relativePath,
            restorePointRef: restorePointRef,
            status: newStatus
        )
    }

    /// Returns a copy of this edit with a restore point ref recorded.
    public func withRestorePointRef(_ ref: String) -> StagedEdit {
        StagedEdit(
            stagingId: stagingId,
            relativePath: relativePath,
            restorePointRef: ref,
            status: status
        )
    }

    // MARK: - derive_source tag

    /// Derive-source tag for tape / projection traceability.
    /// Format: "shadow_workspace:v1:<stagingId>:<relativePath>"
    public var deriveSourceTag: String {
        "shadow_workspace:v1:\(stagingId):\(relativePath)"
    }
}

// ApprovalEnvelopeDraft.swift — Codable model for approval_envelope.schema.json (A1_23).
//
// TYPE NAME RATIONALE:
//   The suffix "Draft" is deliberate and load-bearing.  An ApprovalEnvelopeDraft
//   carries all 20 required schema fields but has NOT been recorded with a signature.
//   A ratification is a kernel-side tape event (approval_envelope + signature_receipt
//   kind); recording one here would violate UPSTREAM_CONTRACT iron law 1
//   ("外壳不复制 canonical state logic") and the A1_23 governing law
//   ("recording a ratification is forbidden until runtime tape exists").
//
// ATOM SCOPE (A1_23 — construction only):
//   No persistence, no signing API, no ceremony.  This struct is pure data — it can
//   be constructed, serialised, compared, and inspected, nothing more.
//
// Constitutional anchors:
//   - contracts/approval_envelope.schema.json — 20 required fields + 2 optional
//   - docs/01_KERNEL_CONTRACTS.md §4 — ApprovalEnvelope field semantics
//   - docs/01_KERNEL_CONTRACTS.md §4.2 — Tier-2 reserved slot rules
//   - WHITEPAPER.md §9 — signature nodes + visible_card_hash
//   - WHITEPAPER.md §9.1 — Hostile Host model / T3 reserved

import Foundation

// MARK: - RequiredSignatureLevel

/// Maps to `required_signature_level` enum in approval_envelope.schema.json.
///
/// v0.x stamping rule (enforced by ApprovalEnvelopeBuilder):
///   ApprovalEnvelopeBuilder ALWAYS writes `.appApproval` — touch_id_se and
///   external_anchor are capabilities not yet present in v0.x and therefore
///   not claimable (WHITEPAPER.md §9, §18 roadmap).
public enum RequiredSignatureLevel: String, Codable, Sendable, Equatable {
    case appApproval    = "app_approval"
    case touchIdSe      = "touch_id_se"
    case externalAnchor = "external_anchor"
}

// MARK: - HostThreatLevel

/// Maps to `host_threat_level` enum in approval_envelope.schema.json.
///
/// T3 is Tier-2 reserved (docs/01_KERNEL_CONTRACTS.md §4.2):
///   v0.x does not implement T3.  ApprovalEnvelopeBuilder refuses to build an
///   envelope with hostThreatLevel == .t3 with BuildRefusal.refused (§9.1).
public enum HostThreatLevel: String, Codable, Sendable, Equatable {
    case t0 = "T0"
    case t1 = "T1"
    case t2 = "T2"
    case t3 = "T3"
}

// MARK: - Reversibility

/// Maps to `reversibility` enum in approval_envelope.schema.json.
public enum Reversibility: String, Codable, Sendable, Equatable {
    case reversible   = "reversible"
    case draft        = "draft"
    case irreversible = "irreversible"
}

// MARK: - ApprovalEnvelopeDraft

/// Codable model mirroring ALL 20 required keys of approval_envelope.schema.json
/// plus the 2 optional keys.
///
/// ## Why "Draft"
/// An envelope without a recorded signature is a draft.  It cannot be promoted to a
/// ratification without the runtime tape (ChainTape / signature_receipt) which arrives
/// in a later atom (M2 — signing media).  Type-level naming enforces this: there is no
/// `ApprovalEnvelope` type (without "Draft") in v0.x, so call sites cannot confuse
/// a draft for a ratified envelope.
///
/// ## Tier-2 reserved slots (docs/01_KERNEL_CONTRACTS.md §4.2)
/// `externalAnchorId` and `auditRoot` are optional; they are nil in all v0.x builds.
/// `hostThreatLevel` is required; v0.x writes T0–T2 only (never T3).
///
/// ## CodingKeys
/// All snake_case to match the schema exactly.
public struct ApprovalEnvelopeDraft: Codable, Sendable, Equatable {

    // MARK: - Required fields (20 of them — exactly mirrors schema "required" array)

    /// Const: "tos.app.approval_envelope.v0"
    public let schemaVersion: String

    /// Unique envelope identifier.
    public let envelopeId: String

    /// Signature node number 1–8 (§9 table).
    public let signatureNode: Int

    /// Action class 0–4.
    public let actionClass: Int

    /// Agent or human principal ID.
    public let actor: String

    /// Project identifier.
    public let projectId: String

    /// SHA-256 hash of the active Spec.
    public let specHash: String

    /// SHA-256 hash of the active budget contract.
    public let budgetHash: String

    /// SHA-256 hash of the active policy.
    public let policyHash: String

    /// SHA-256 hash of the approved action payload (e.g. WorkOrderPackage).
    public let payloadHash: String

    /// SHA-256 hash of the canonical rendered card content (red line 2 / 操守 3).
    /// Derived by ApprovalEnvelopeBuilder from ApprovalCardContent.visibleCardHash().
    /// The caller cannot supply an arbitrary value — the builder derives it structurally.
    public let visibleCardHash: String

    /// Human-readable summary for the ritual screen.
    public let humanReadableSummary: String

    /// Consequence statement: what irreversible effect this approval will produce.
    public let consequenceStatement: String

    /// Reversibility: "reversible" | "draft" | "irreversible"
    public let reversibility: String

    /// SHA-256 hash of the target resource being acted on.
    public let targetResourceHash: String

    /// ISO 8601 expiry: "YYYY-MM-DDTHH:MM:SSZ"
    public let expiryUtc: String

    /// Replay-resistance nonce.
    public let nonce: String

    /// SHA-256 hash of the tape head at time of construction (binds signature to chain position).
    public let prevTapeHead: String

    /// Required signature level — always "app_approval" in v0.x (see builder).
    public let requiredSignatureLevel: String

    /// Host threat level T0–T2 in v0.x (T3 is Tier-2 reserved).
    public let hostThreatLevel: String

    // MARK: - Optional fields (2 Tier-2 reserved slots)

    /// External Sudo-Anchor ID — nil in all v0.x builds; semantically required when T3 (§9.1).
    public let externalAnchorId: String?

    /// External audit chain root hash — nil in all v0.x builds (Tier-2 roadmap).
    public let auditRoot: String?

    // MARK: - CodingKeys (snake_case, exact schema names)

    enum CodingKeys: String, CodingKey {
        case schemaVersion          = "schema_version"
        case envelopeId             = "envelope_id"
        case signatureNode          = "signature_node"
        case actionClass            = "action_class"
        case actor
        case projectId              = "project_id"
        case specHash               = "spec_hash"
        case budgetHash             = "budget_hash"
        case policyHash             = "policy_hash"
        case payloadHash            = "payload_hash"
        case visibleCardHash        = "visible_card_hash"
        case humanReadableSummary   = "human_readable_summary"
        case consequenceStatement   = "consequence_statement"
        case reversibility
        case targetResourceHash     = "target_resource_hash"
        case expiryUtc              = "expiry_utc"
        case nonce
        case prevTapeHead           = "prev_tape_head"
        case requiredSignatureLevel = "required_signature_level"
        case hostThreatLevel        = "host_threat_level"
        case externalAnchorId       = "external_anchor_id"
        case auditRoot              = "audit_root"
    }

    // MARK: - Initialiser (internal — use ApprovalEnvelopeBuilder)

    init(
        envelopeId: String,
        signatureNode: Int,
        actionClass: Int,
        actor: String,
        projectId: String,
        specHash: String,
        budgetHash: String,
        policyHash: String,
        payloadHash: String,
        visibleCardHash: String,
        humanReadableSummary: String,
        consequenceStatement: String,
        reversibility: String,
        targetResourceHash: String,
        expiryUtc: String,
        nonce: String,
        prevTapeHead: String,
        requiredSignatureLevel: String,
        hostThreatLevel: String,
        externalAnchorId: String? = nil,
        auditRoot: String? = nil
    ) {
        self.schemaVersion          = approvalEnvelopeSchemaVersion
        self.envelopeId             = envelopeId
        self.signatureNode          = signatureNode
        self.actionClass            = actionClass
        self.actor                  = actor
        self.projectId              = projectId
        self.specHash               = specHash
        self.budgetHash             = budgetHash
        self.policyHash             = policyHash
        self.payloadHash            = payloadHash
        self.visibleCardHash        = visibleCardHash
        self.humanReadableSummary   = humanReadableSummary
        self.consequenceStatement   = consequenceStatement
        self.reversibility          = reversibility
        self.targetResourceHash     = targetResourceHash
        self.expiryUtc              = expiryUtc
        self.nonce                  = nonce
        self.prevTapeHead           = prevTapeHead
        self.requiredSignatureLevel = requiredSignatureLevel
        self.hostThreatLevel        = hostThreatLevel
        self.externalAnchorId       = externalAnchorId
        self.auditRoot              = auditRoot
    }
}

/// Canonical schema version constant for ApprovalEnvelope v0.
public let approvalEnvelopeSchemaVersion = "tos.app.approval_envelope.v0"

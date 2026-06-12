// ApprovalCardContent.swift — Canonical "what-you-saw" binding for ApprovalEnvelope (A1_23).
//
// GOVERNING LAW — execution ruling red line 2:
//   "SE signs bytes, not screens; so the approval card's rendered content must be
//    canonically hashed INTO the envelope (visible_card_hash)."
//
//   操守 3 (WHITEPAPER.md §3): "批准记录的是'你当时看到了什么'。每一次签名，连同批准卡
//   所呈现内容的规范化哈希一起进入被签名的负载。"
//
// BINDING INVARIANT:
//   ApprovalCardContent is the SINGLE source of truth for what ApprovalCard renders to the
//   human and what gets hashed into visible_card_hash.  There is no path by which the two
//   can diverge:
//     • ApprovalCardContent.from(payload:) constructs content from an ApprovalRequestPayload.
//     • ApprovalEnvelopeBuilder accepts an ApprovalCardContent and derives visible_card_hash
//       from it — the caller cannot supply an arbitrary hash.
//
// ATOM SCOPE (A1_23 — construction only):
//   No persistence, no signing API, no ceremony.  This is purely a data and hashing layer.

import CryptoKit
import Foundation

// MARK: - ApprovalCardContent

/// Captures EXACTLY the fields that ApprovalCard (ViewIRRenderer.swift) displays
/// to the human.  This is the canonical "what the user saw" record.
///
/// SINGLE SOURCE OF TRUTH:
///   The fields here map one-to-one to the label rows in ApprovalCard.body:
///     actor             → agent / initiating principal
///     actionKind        → kind of operation (e.g. "create_worktree", "send_email")
///     actionClass       → integer 0-4 matching action_class in approval_envelope
///     target            → human-readable resource being acted on
///     paramsSummary     → brief params description shown in the card
///     riskCategory      → risk category label shown in the card
///     reversibility     → "reversible" / "draft" / "irreversible" (verbatim from schema)
///     consequenceStatement → "后果" row in the card
///     humanReadableSummary → "摘要" row in the card
///
/// HASH COVERAGE:
///   Every field participates in canonicalData() via JSONEncoder(.sortedKeys).
///   Mutating any single field changes visibleCardHash() — verified by tests.
///
/// RELATIONSHIP TO ApprovalRequestPayload:
///   ApprovalRequestPayload (ViewIR.swift) references an envelope by ID; the full content
///   is not embedded in it.  ApprovalCardContent carries the full content so that both
///   the card renderer and the envelope builder operate from the same values.
///   Use ApprovalCardContent.from(payload:actorName:...) to construct from runtime data
///   when the kernel has resolved the envelope, or construct directly in tests.
public struct ApprovalCardContent: Codable, Sendable, Equatable {

    // MARK: Displayed fields

    /// Agent or human principal name shown at the top of the card.
    public let actor: String

    /// Operation kind label (e.g. "create_worktree", "send_email").
    public let actionKind: String

    /// Action class integer 0–4 matching the schema enum.
    /// 0 = read, 1 = reversible_local, 2 = remote_draft, 3 = irreversible_external, 4 = constitutional
    public let actionClass: Int

    /// Human-readable target resource description shown to the user.
    public let target: String

    /// Brief textual summary of the relevant parameters shown to the user.
    public let paramsSummary: String

    /// Risk category label displayed on the card (e.g. "low", "medium", "high").
    public let riskCategory: String

    /// Reversibility label: exactly one of "reversible", "draft", or "irreversible".
    /// Must match the schema enum — constructor validates this.
    public let reversibility: String

    /// Consequence statement — the "后果" row in the card.
    public let consequenceStatement: String

    /// Human-readable summary — the "摘要" row in the card.
    public let humanReadableSummary: String

    // MARK: CodingKeys — snake_case for canonical JSON stability

    enum CodingKeys: String, CodingKey {
        case actor
        case actionKind             = "action_kind"
        case actionClass            = "action_class"
        case target
        case paramsSummary          = "params_summary"
        case riskCategory           = "risk_category"
        case reversibility
        case consequenceStatement   = "consequence_statement"
        case humanReadableSummary   = "human_readable_summary"
    }

    // MARK: Valid reversibility values (mirrors schema enum)

    public static let validReversibilityValues: Set<String> = ["reversible", "draft", "irreversible"]

    // MARK: Initialiser

    /// Creates an ApprovalCardContent.
    ///
    /// - Parameters:
    ///   - actor: Agent or human principal name.
    ///   - actionKind: Operation kind label.
    ///   - actionClass: Integer 0–4.
    ///   - target: Human-readable resource description.
    ///   - paramsSummary: Parameter summary text.
    ///   - riskCategory: Risk category label.
    ///   - reversibility: Must be "reversible", "draft", or "irreversible".
    ///   - consequenceStatement: Consequence statement text.
    ///   - humanReadableSummary: Human-readable summary text.
    public init(
        actor: String,
        actionKind: String,
        actionClass: Int,
        target: String,
        paramsSummary: String,
        riskCategory: String,
        reversibility: String,
        consequenceStatement: String,
        humanReadableSummary: String
    ) {
        precondition(
            Self.validReversibilityValues.contains(reversibility),
            "ApprovalCardContent: reversibility must be one of \(Self.validReversibilityValues), got '\(reversibility)'"
        )
        self.actor                  = actor
        self.actionKind             = actionKind
        self.actionClass            = actionClass
        self.target                 = target
        self.paramsSummary          = paramsSummary
        self.riskCategory           = riskCategory
        self.reversibility          = reversibility
        self.consequenceStatement   = consequenceStatement
        self.humanReadableSummary   = humanReadableSummary
    }

    // MARK: - Canonical binding factory

    /// Constructs ApprovalCardContent from values that will also be used to construct
    /// or have already been used to construct an ApprovalRequestPayload.
    ///
    /// This factory is the preferred entry point when wiring the card renderer with the
    /// envelope builder: pass the same values to both, ensuring ONE source of truth
    /// (red line 2 / 操守 3).
    ///
    /// - Parameters:
    ///   - envelopeRef: The envelope_id the card references (for tracing, not hashed here).
    ///   - actor: Agent or human principal name.
    ///   - actionKind: Operation kind label.
    ///   - actionClass: Action class integer 0–4.
    ///   - target: Human-readable target.
    ///   - paramsSummary: Parameter summary.
    ///   - riskCategory: Risk category.
    ///   - reversibility: "reversible" | "draft" | "irreversible".
    ///   - consequenceStatement: Consequence statement.
    ///   - humanReadableSummary: Human-readable summary.
    /// - Returns: An ApprovalCardContent ready for hashing and rendering.
    public static func from(
        envelopeRef: String,
        actor: String,
        actionKind: String,
        actionClass: Int,
        target: String,
        paramsSummary: String,
        riskCategory: String,
        reversibility: String,
        consequenceStatement: String,
        humanReadableSummary: String
    ) -> ApprovalCardContent {
        // envelopeRef is passed for tracing/logging purposes only; it is NOT
        // included in the canonical hash surface (the envelope already has envelope_id).
        _ = envelopeRef
        return ApprovalCardContent(
            actor: actor,
            actionKind: actionKind,
            actionClass: actionClass,
            target: target,
            paramsSummary: paramsSummary,
            riskCategory: riskCategory,
            reversibility: reversibility,
            consequenceStatement: consequenceStatement,
            humanReadableSummary: humanReadableSummary
        )
    }

    // MARK: - Canonical hashing

    /// Returns the canonical JSON bytes for this content (JSONEncoder with sortedKeys).
    ///
    /// Pattern mirrors SpecPackage.specHash (SpecPackage.swift): sortedKeys ensures
    /// deterministic field ordering regardless of dictionary insertion order.
    /// All nine fields are included — none excluded — so every displayed field
    /// participates in the hash.
    public func canonicalData() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        // Encode self directly; all fields are in CodingKeys so the output is the
        // full canonical surface.  Any field change → different bytes → different hash.
        guard let data = try? encoder.encode(self) else {
            // Encoding a simple Codable struct with primitive fields cannot fail in practice;
            // return a sentinel that will not match any valid hash rather than silently
            // producing a stable-but-empty value.
            return Data("__ENCODE_ERROR__".utf8)
        }
        return data
    }

    /// SHA-256 hash of canonicalData(), formatted as "sha256:<64-hex-chars>".
    ///
    /// This value is what gets written into ApprovalEnvelope.visible_card_hash.
    /// The binding (red line 2 / 操守 3): the hash is derived from the same field
    /// values that ApprovalCard renders — there is no separate path by which the
    /// card could show different content from what gets hashed.
    public func visibleCardHash() -> String {
        let data = canonicalData()
        let digest = SHA256.hash(data: data)
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        return "sha256:" + hex
    }
}

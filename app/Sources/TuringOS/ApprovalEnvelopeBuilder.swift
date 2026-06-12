// ApprovalEnvelopeBuilder.swift — Pure static builder for ApprovalEnvelopeDraft (A1_23).
//
// GOVERNING LAW — execution ruling red line 2:
//   "The approval card's rendered content must be canonically hashed INTO the envelope
//    (visible_card_hash)."
//
//   操守 3 (WHITEPAPER.md §3): "每一次签名，连同批准卡所呈现内容的规范化哈希一起进入
//   被签名的负载。事后回看时，你看到的不只是'批准了'，而是'基于什么批准的'。"
//
// DESIGN CONTRACT:
//   1. All injected parameters (nonce, expiryUtc) come from the caller — the builder
//      does NOT call Date() or UUID() internally.  This keeps the builder pure and
//      deterministic: same inputs → same output (verified by test 5).
//
//   2. visible_card_hash is derived from ApprovalCardContent INSIDE the builder.
//      The caller cannot supply an arbitrary hash.  This is the structural binding
//      that enforces red line 2: what the card shows IS what gets hashed.
//
//   3. required_signature_level is NOT a parameter.  The builder stamps "app_approval"
//      ALWAYS in v0.x.  touch_id_se and external_anchor are capabilities not present
//      in v0.x and are therefore not claimable (WHITEPAPER.md §9 "过渡说明" / §18).
//
//   4. All refusals are FAIL-CLOSED: the builder returns .failure(.refused(...)) rather
//      than silently degrading.  Caller must inspect the result before using the draft.
//
// ATOM SCOPE (A1_23 — construction only):
//   No persistence, no signing, no ceremony.  Pure data construction.

import CryptoKit
import Foundation

// MARK: - BuildRefusal

/// Reason an ApprovalEnvelopeBuilder.build call was refused.
///
/// Refusals are FAIL-CLOSED — the caller must handle them explicitly.
/// There is no silent fallback or default degradation.
public enum BuildRefusal: Error, Equatable, Sendable {
    /// T3 host threat level is Tier-2 reserved; v0.x does not implement it.
    /// Reference: docs/01_KERNEL_CONTRACTS.md §4.2 / WHITEPAPER.md §9.1
    case hostThreatLevelT3NotSupported(reason: String)

    /// signatureNode is outside the valid range 1...8 (WHITEPAPER.md §9 table).
    case signatureNodeOutOfRange(node: Int)

    /// action_class 3 requires at least signature node 4 (SignatureNode.class3Minimum).
    /// Reference: WHITEPAPER.md §9 / §10 / FailClosedClassifier.minimumSignatureNode
    case class3RequiresNodeAtLeast4(actualNode: Int)
}

// MARK: - ApprovalEnvelopeBuilder

/// Pure static builder that constructs an ApprovalEnvelopeDraft from well-typed inputs.
///
/// ## FAIL-CLOSED refusals
/// The builder returns `.failure(.refused(...))` for any of these conditions:
///   - hostThreatLevel == .t3 (Tier-2 reserved; v0.x does not claim T3 coverage)
///   - signatureNode outside 1...8
///   - actionClass == 3 with signatureNode < 4
///
/// ## visible_card_hash binding
/// `visible_card_hash` is computed from `content` inside this builder.
/// The caller passes an `ApprovalCardContent` — the same struct that the renderer
/// uses to populate ApprovalCard's label rows.  The builder calls
/// `content.visibleCardHash()` and writes the result into the draft.
/// There is no parameter for `visibleCardHash` on the `build` function: this is the
/// structural guarantee of red line 2 / 操守 3.
///
/// ## required_signature_level
/// Always stamped as "app_approval" in v0.x.  touch_id_se / external_anchor are
/// declared in the schema for future atoms (M2) but are not implemented in v0.x;
/// claiming them would violate the honest capability boundary (WHITEPAPER.md §9
/// "过渡说明": "v0.x 早期版本以应用内明确批准门控（非生物识别）").
///
/// ## Injected nonce / expiry
/// `nonce` and `expiryUtc` are caller-supplied — the builder never calls Date() or
/// UUID() internally, keeping the function pure.  envelope_id is derived as a
/// deterministic hash of content + nonce so two calls with different nonces produce
/// different envelope IDs even with identical content.
public enum ApprovalEnvelopeBuilder {

    // MARK: - build

    /// Constructs an ApprovalEnvelopeDraft.
    ///
    /// - Parameters:
    ///   - content: The ApprovalCardContent displayed to the human by ApprovalCard.
    ///             `visible_card_hash` is derived from this value inside the builder —
    ///             the caller cannot supply an arbitrary hash (red line 2 binding).
    ///   - signatureNode: Signature node number 1–8 (WHITEPAPER.md §9 table).
    ///   - projectId: Project identifier.
    ///   - specHash: SHA-256 hash of the active Spec ("sha256:<hex>").
    ///   - budgetHash: SHA-256 hash of the active budget contract.
    ///   - policyHash: SHA-256 hash of the active policy.
    ///   - payloadHash: SHA-256 hash of the approved action payload.
    ///   - targetResourceHash: SHA-256 hash of the target resource.
    ///   - prevTapeHead: SHA-256 hash of the tape head at construction time.
    ///   - nonce: Replay-resistance nonce (injected; not generated here).
    ///   - expiryUtc: ISO 8601 expiry string "YYYY-MM-DDTHH:MM:SSZ" (injected).
    ///   - hostThreatLevel: T0/T1/T2 only — T3 is refused (§9.1 Tier-2 reserved).
    ///
    /// - Returns: `.success(ApprovalEnvelopeDraft)` or `.failure(BuildRefusal)`.
    public static func build(
        content: ApprovalCardContent,
        signatureNode: Int,
        projectId: String,
        specHash: String,
        budgetHash: String,
        policyHash: String,
        payloadHash: String,
        targetResourceHash: String,
        prevTapeHead: String,
        nonce: String,
        expiryUtc: String,
        hostThreatLevel: HostThreatLevel
    ) -> Result<ApprovalEnvelopeDraft, BuildRefusal> {

        // REFUSAL 1: T3 is Tier-2 reserved (docs/01_KERNEL_CONTRACTS.md §4.2 / WHITEPAPER.md §9.1).
        // v0.x does not implement the Hostile Host two-tier architecture; claiming T3 coverage
        // would be dishonest (the Hostile Host Axiom: "TuringOS 不得宣称 AGI 级 sudo 安全").
        if hostThreatLevel == .t3 {
            return .failure(.hostThreatLevelT3NotSupported(
                reason: "v0.x does not implement Tier-2 Hostile Host architecture (WHITEPAPER.md §9.1); " +
                        "T3 requires external_anchor_id + audit_root + external signing hardware, " +
                        "none of which are present in v0.x.  Refusing to build envelope with T3."
            ))
        }

        // REFUSAL 2: signature node outside valid range 1...8.
        guard let node = SignatureNode(signatureNode) else {
            return .failure(.signatureNodeOutOfRange(node: signatureNode))
        }

        // REFUSAL 3: action_class 3 requires at least signature node 4.
        // Reuses SignatureNode.class3Minimum from FailClosedClassifier.swift (A1_21).
        if content.actionClass == 3 && node < SignatureNode.class3Minimum {
            return .failure(.class3RequiresNodeAtLeast4(actualNode: signatureNode))
        }

        // BINDING: derive visible_card_hash from content.
        // The caller cannot supply this value — the hash is structurally coupled to
        // whatever the card displays (red line 2 / 操守 3).
        let visibleCardHash = content.visibleCardHash()

        // required_signature_level: always "app_approval" in v0.x.
        // touch_id_se and external_anchor are defined in the schema for future atoms
        // (M2 — signing media) but CANNOT be claimed in v0.x because the capability
        // is not present.  Claiming a capability you don't have violates 操守 3 (honest
        // record of what actually happened).
        let requiredSignatureLevel = RequiredSignatureLevel.appApproval.rawValue

        // envelope_id: deterministic hash of content bytes + nonce.
        // This means two builds with different nonces produce different IDs,
        // and the ID is fully reproducible given the same inputs.
        // We do NOT call UUID() — the builder is pure.
        let envelopeId = deriveEnvelopeId(contentData: content.canonicalData(), nonce: nonce)

        let draft = ApprovalEnvelopeDraft(
            envelopeId: envelopeId,
            signatureNode: signatureNode,
            actionClass: content.actionClass,
            actor: content.actor,
            projectId: projectId,
            specHash: specHash,
            budgetHash: budgetHash,
            policyHash: policyHash,
            payloadHash: payloadHash,
            visibleCardHash: visibleCardHash,
            humanReadableSummary: content.humanReadableSummary,
            consequenceStatement: content.consequenceStatement,
            reversibility: content.reversibility,
            targetResourceHash: targetResourceHash,
            expiryUtc: expiryUtc,
            nonce: nonce,
            prevTapeHead: prevTapeHead,
            requiredSignatureLevel: requiredSignatureLevel,
            hostThreatLevel: hostThreatLevel.rawValue,
            externalAnchorId: nil,   // Tier-2 reserved; always nil in v0.x
            auditRoot: nil            // Tier-2 reserved; always nil in v0.x
        )

        return .success(draft)
    }

    // MARK: - Private helpers

    /// Derives a deterministic envelope_id from canonical content bytes + nonce.
    ///
    /// Format: "env_<sha256-prefix-32-hex-chars>" — unique per (content, nonce) pair,
    /// reproducible, no external entropy needed.
    private static func deriveEnvelopeId(contentData: Data, nonce: String) -> String {
        var hasher = SHA256()
        hasher.update(data: contentData)
        hasher.update(data: Data(nonce.utf8))
        let digest = hasher.finalize()
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        return "env_" + String(hex.prefix(32))
    }
}

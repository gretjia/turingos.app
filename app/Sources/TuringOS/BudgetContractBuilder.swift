// BudgetContractBuilder.swift — Bridges BudgetContract → ApprovalEnvelopeDraft (A1_19).
//
// CONSTITUTIONAL BOUNDARY (docs/UPSTREAM_CONTRACT.md):
//   This builder constructs an ApprovalEnvelopeDraft (signature_node==2) from a
//   BudgetContract.  It does NOT write to tape, does NOT record a ratification,
//   and does NOT advance project state.  Tape genesis requires runtime import
//   (A1_9_01 / A1_9_02 lane).
//
//   "仪式不可用就是不可用" — same pattern as A1_18 (SpecPackage), A1_21
//   (FailClosedClassifier.deny), and A1_22 (GatewayError.tapeUnavailable).
//
// OUTPUT CONTRACT:
//   Successful result: ApprovalEnvelopeDraft with signatureNode==2 and
//   budgetHash == contract.budgetHash (sha256: + 64 hex chars).
//   Failure result: BuildRefusal forwarded from ApprovalEnvelopeBuilder (A1_23).

import Foundation

// MARK: - BudgetContractBuilder

/// Pure static builder: BudgetContract → ApprovalEnvelopeDraft (signature #2).
///
/// Composes with the existing ApprovalEnvelopeBuilder (A1_23) rather than
/// reimplementing envelope construction.  The caller supplies all non-deterministic
/// inputs (nonce, expiryUtc, prevTapeHead) to preserve pure-function contract.
public struct BudgetContractBuilder {

    private init() {}

    /// Build an ApprovalEnvelopeDraft for signature #2 (budget approval).
    ///
    /// - Parameters:
    ///   - contract:        Sealed BudgetContract (typically status == .awaitingRatification).
    ///   - specHash:        Hash of the associated SpecPackage (approval_envelope.spec_hash).
    ///   - prevTapeHead:    Most recent tape node hash (approval_envelope.prev_tape_head).
    ///   - nonce:           Caller-supplied nonce — builder does NOT call UUID().
    ///   - expiryUtc:       ISO-8601 expiry string — builder does NOT call Date().
    ///   - policyHash:      Hash of the current policy document (default v0 placeholder).
    ///   - hostThreatLevel: T0–T2 only; T3 is Tier-2 reserved (returns .failure).
    ///   - capability:      Signer capability probe result (A1_25).
    ///
    /// - Returns: `.success(draft)` where draft.signatureNode == 2, or
    ///            `.failure(refusal)` forwarded from ApprovalEnvelopeBuilder.
    public static func buildEnvelope(
        contract: BudgetContract,
        specHash: String,
        prevTapeHead: String,
        nonce: String,
        expiryUtc: String,
        policyHash: String = "sha256:policy_v0_placeholder",
        hostThreatLevel: HostThreatLevel = .t0,
        capability: SignerCapability = .appApprovalOnly
    ) -> Result<ApprovalEnvelopeDraft, BuildRefusal> {

        let budgetHash = contract.budgetHash

        // Summarise the contract limits into human-readable rows for the approval card.
        let paramsSummary = [
            "tokens:\(contract.limits.tokenLimit)",
            "wall:\(contract.limits.wallClockSecs)s",
            "ci:\(contract.limits.ciCyclesLimit)",
            "retry:\(contract.autonomy.maxRetryBeforeHalt)",
        ].joined(separator: " ")

        let content = ApprovalCardContent(
            actor: "user",
            actionKind: "budget_approval",
            actionClass: 1,         // reversible_local — budget draft is reversible before tape genesis
            target: "project:\(contract.projectId)",
            paramsSummary: paramsSummary,
            riskCategory: "low",
            reversibility: "draft", // draft until tape genesis; irreversible after
            consequenceStatement: "Sets spending limits and autonomy constraints for the project lifecycle. " +
                "Stop loss: \(contract.limits.stopLossLine).",
            humanReadableSummary: "Budget contract for project '\(contract.projectId)': " +
                "\(contract.limits.tokenLimit) tokens / \(contract.limits.wallClockSecs)s wall clock / " +
                "\(contract.limits.ciCyclesLimit) CI cycles."
        )

        return ApprovalEnvelopeBuilder.build(
            content: content,
            signatureNode: 2,
            projectId: contract.projectId,
            specHash: specHash,
            budgetHash: budgetHash,
            policyHash: policyHash,
            payloadHash: budgetHash,    // payload IS the budget contract
            targetResourceHash: budgetHash,
            prevTapeHead: prevTapeHead,
            nonce: nonce,
            expiryUtc: expiryUtc,
            hostThreatLevel: hostThreatLevel,
            capability: capability
        )
    }
}

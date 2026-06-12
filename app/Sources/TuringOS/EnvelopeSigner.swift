// EnvelopeSigner.swift — SE-P256 signer capability abstractions (A1_25).
//
// GOVERNING LAW: capability vs ceremony separation.
//   Building a working signer = lawful v0.5 §9/§13.2 content.
//   RECORDING a ratification on tape = still blocked (runtime absent).
//   The signer signs and RETURNS a receipt-shaped value; nothing persists.
//
// ADR-013 (daemon/src/signer.rs) M2 MIRROR — fail-closed semantics:
//   Signing medium unavailable MUST surface as SignerError.unavailable.
//   There is NO silent fallback, NO nil return, NO degradation to a weaker signer.
//   The Rust SignError enum is mirrored here exactly: Unavailable(String) →
//   unavailable(String), Rejected(String) → rejected(String).
//
// SignerAvailability probe:
//   probe() returns a SignerCapability enum value indicating what the current
//   runtime can deliver.  The value drives required_signature_level in
//   ApprovalEnvelopeBuilder — the CALLER cannot pass a level directly.

import Foundation

// MARK: - SignerError

/// Typed error for signing failures. Mirrors daemon/src/signer.rs `SignError`.
///
/// ADR-013 M2 fail-closed: any code path that cannot sign MUST throw one of these.
/// Callers are required to handle both cases explicitly — no silent fallback permitted.
public enum SignerError: Error, Equatable, Sendable {
    /// Signing medium is structurally unavailable (SE absent, no provisioning,
    /// biometry not enrolled, CI runner, etc.).  The associated string contains
    /// the OSStatus or system error description for forensic tracing.
    case unavailable(String)

    /// Signing medium is present but the operation was explicitly rejected
    /// (user cancelled Touch ID, access control denied, etc.).
    case rejected(String)
}

// MARK: - SignerCapability

/// What the current runtime can deliver.  Derived by SignerAvailability.probe().
/// This enum is the ONLY authorised source for required_signature_level in
/// ApprovalEnvelopeBuilder.build(capability:...) — callers cannot pass a level string
/// directly; the mapping is deterministic and centralised here.
public enum SignerCapability: Equatable, Sendable {
    /// App-level approval only (no SE or biometry available).  Maps to
    /// required_signature_level "app_approval".
    case appApprovalOnly

    /// SE-resident P-256 key + biometric access control available.  Maps to
    /// required_signature_level "touch_id_se".
    case secureEnclaveBiometric
}

extension SignerCapability {
    /// The required_signature_level string for this capability.
    /// Single mapping point — ApprovalEnvelopeBuilder reads this.
    public var requiredSignatureLevel: String {
        switch self {
        case .appApprovalOnly:        return RequiredSignatureLevel.appApproval.rawValue
        case .secureEnclaveBiometric: return RequiredSignatureLevel.touchIdSe.rawValue
        }
    }
}

// MARK: - SignerAvailability

/// Probe protocol: ask the runtime what signing capability is available
/// without triggering any interactive prompt.
public protocol SignerAvailability: Sendable {
    func probe() -> SignerCapability
}

// MARK: - EnvelopeSigner

/// Protocol for all signer implementations.  Mirrors the `Signer` trait in
/// daemon/src/signer.rs (ADR-013).
///
/// Implementations:
///   - SecureEnclaveSigner: real SE-P256 + biometry (production).
///   - MockSigner: deterministic test double.
///
/// ADR-013 M2 fail-closed contract (enforced here, not just documented):
///   - Every failure path MUST throw SignerError.unavailable or .rejected.
///   - No implementation may return Data from sign() on failure — only throws.
///   - No implementation may silently substitute a weaker algorithm.
public protocol EnvelopeSigner: Sendable {
    /// Key kind string — must match a value in signature_receipt.schema.json key_kind enum.
    var keyKind: String { get }

    /// SHA-256 hex fingerprint of the public key external representation.
    /// Stable: re-derives on each access but does not change across calls for the same key.
    var fingerprint: String { get }

    /// Signs the canonical payload bytes.
    ///
    /// Implementations MUST NOT transform the payload — canonicalization happens
    /// upstream (EnvelopeSigningService) and is hash-anchored in the receipt.
    ///
    /// - Throws: `SignerError.unavailable` if the medium is not accessible.
    ///           `SignerError.rejected` if the operation was denied.
    func sign(payload: Data) throws -> Data
}

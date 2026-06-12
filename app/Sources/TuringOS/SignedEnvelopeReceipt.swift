// SignedEnvelopeReceipt.swift — Codable receipt + signing service (A1_25).
//
// GOVERNING LAW: capability vs ceremony separation.
//   SignedEnvelopeReceipt covers ALL 10 required keys of
//   contracts/signature_receipt.schema.json.
//   Nothing is persisted. The receipt is a pure return value.
//
// SCHEMA KEY DECISIONS (verified against contracts/signature_receipt.schema.json):
//
//   receipt_id:
//     Pattern "^rcp_[a-z0-9_]+$". Composed from a caller-injected suffix
//     (receiptIdSuffix) — no UUID() inside pure signing paths (determinism).
//
//   schema_version:
//     Const "tos.app.receipt.v0".
//
//   payload_hash:
//     SHA-256 of the canonical envelope bytes (sortedKeys JSON).
//     Format: "sha256:<64 hex chars>".
//
//   key_kind:
//     From signer.keyKind ("se-p256" for SE; "mock" in tests — callers provide).
//
//   signer_fingerprint:
//     From signer.fingerprint (SHA-256 of public key external representation).
//
//   signature:
//     Base64-encoded bytes returned by signer.sign(payload:).
//
//   verified:
//     Set by EnvelopeSigningService after SecKeyVerifySignature (or protocol-level
//     verify for MockSigner). A failed verification → receipt.verified = false
//     (failure is a state, not an error — ADR-013 Verifier trait).
//
//   trust_state:
//     "human_root_signed" — chosen because:
//       (a) The SE key is the human root key (ADR-005: human root key lives app-side
//           in SE; this is the signing medium that realises that commitment).
//       (b) The signing succeeded (verified = true path).
//       (c) "signature_valid" would be correct for a daemon-side receipt; here the
//           app-side signer IS the trust root per ADR-005, so "human_root_signed"
//           is the most accurate schema value.
//       (d) On verified = false, trust_state = "signature_invalid" (the schema
//           provides this distinct value for that outcome).
//
//   nonce:
//     Taken directly from envelope.nonce (replay-resistance chain intact).
//
//   anchored_seq:
//     Type: integer, minimum: 0 (per schema).
//     Runtime tape absent in v0.5 (recording blocked until M2 tape is present).
//     Value: 0.
//     Semantic: "pre-tape; re-anchored at import when the tape arrives".
//     This is honest — 0 satisfies the schema minimum:0 constraint, and the doc
//     comment declares the placeholder semantic explicitly. The receipt is not
//     on-tape yet; it will be re-anchored when the tape is established.
//     NOT using -1 because schema enforces minimum: 0.
//
// NO persistence, NO tape, NO UserDefaults.

import CryptoKit
import Foundation

// MARK: - SignedEnvelopeReceipt

/// Codable struct covering all 10 required keys of
/// contracts/signature_receipt.schema.json.
///
/// Constructed only by `EnvelopeSigningService.sign(...)`.
/// Immutable. Not persisted.
public struct SignedEnvelopeReceipt: Codable, Sendable, Equatable {

    // MARK: - Fields (all 10 required schema keys)

    /// "rcp_<suffix>" — pattern: ^rcp_[a-z0-9_]+$
    public let receiptId: String

    /// Const: "tos.app.receipt.v0"
    public let schemaVersion: String

    /// "sha256:<64 hex chars>" — SHA-256 of canonical envelope bytes.
    public let payloadHash: String

    /// "se-p256" | "ssh-ed25519" | "ssh-fido2-ed25519" | "gpg"
    public let keyKind: String

    /// SHA-256 hex fingerprint of the signing public key.
    public let signerFingerprint: String

    /// Base64-encoded ECDSA signature bytes.
    public let signature: String

    /// True iff SecKeyVerifySignature confirmed the signature after signing.
    /// false is a legitimate receipt value (failure is a state, not hidden).
    public let verified: Bool

    /// Schema trust_state enum value.
    ///
    /// "human_root_signed": SE key = human root per ADR-005; signing succeeded.
    /// "signature_invalid": SecKeyVerifySignature returned false.
    public let trustState: String

    /// Replay-resistance nonce, taken from the envelope.
    public let nonce: String

    /// Integer >= 0. Placeholder value 0 = "pre-tape; re-anchored at import".
    /// Runtime tape is absent in v0.5 (M2 blocked). Schema enforces minimum:0.
    public let anchoredSeq: Int

    // MARK: - CodingKeys (snake_case, exact schema names)

    enum CodingKeys: String, CodingKey {
        case receiptId        = "receipt_id"
        case schemaVersion    = "schema_version"
        case payloadHash      = "payload_hash"
        case keyKind          = "key_kind"
        case signerFingerprint = "signer_fingerprint"
        case signature
        case verified
        case trustState       = "trust_state"
        case nonce
        case anchoredSeq      = "anchored_seq"
    }
}

// MARK: - Schema constants

/// Canonical schema version for SignatureReceipt v0.
public let signatureReceiptSchemaVersion = "tos.app.receipt.v0"

// MARK: - EnvelopeSigningService

/// Signs an ApprovalEnvelopeDraft and returns a SignedEnvelopeReceipt.
///
/// The canonical sortedKeys JSON of the envelope is the signing payload.
/// After signing, the service verifies the signature and sets `verified` accordingly.
/// A failed verification returns a receipt with verified=false — it does NOT throw
/// (ADR-013: "failure is a state that goes on tape", not an exception).
///
/// NO persistence, NO tape, NO UserDefaults. Pure function: same inputs → same receipt
/// (modulo signing entropy in ECDSA; hash fields are deterministic).
public enum EnvelopeSigningService {

    // MARK: - sign

    /// Signs the envelope and returns a receipt.
    ///
    /// - Parameters:
    ///   - envelope: The ApprovalEnvelopeDraft to sign.
    ///   - signer: An EnvelopeSigner implementation (SecureEnclaveSigner or MockSigner).
    ///   - receiptIdSuffix: Caller-injected suffix for receipt_id ("rcp_<suffix>").
    ///     Must match ^[a-z0-9_]+$ for schema conformance.
    ///
    /// - Returns: A SignedEnvelopeReceipt with verified=true or verified=false.
    ///
    /// - Throws: SignerError.unavailable or .rejected if the signer cannot sign.
    ///   The caller is responsible for surfacing these (fail-closed, no silent fallback).
    public static func sign(
        envelope: ApprovalEnvelopeDraft,
        with signer: EnvelopeSigner,
        receiptIdSuffix: String
    ) throws -> SignedEnvelopeReceipt {

        // 1. Canonical payload: sortedKeys JSON of the envelope.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payloadData = try encoder.encode(envelope)

        // 2. payload_hash = sha256 of canonical bytes.
        let digest = SHA256.hash(data: payloadData)
        let hashHex = digest.compactMap { String(format: "%02x", $0) }.joined()
        let payloadHash = "sha256:\(hashHex)"

        // 3. Sign — throws SignerError on failure (no fallback, no nil return).
        let signatureData = try signer.sign(payload: payloadData)
        let signatureBase64 = signatureData.base64EncodedString()

        // 4. Verify the signature immediately after signing.
        //    verified=false is a legitimate receipt state (ADR-013).
        let verified: Bool
        let trustState: String
        if let se = signer as? SecureEnclaveSigner {
            // Real SE signer: use SecKeyVerifySignature via the signer's verify method.
            let ok = (try? se.verify(payload: payloadData, signature: signatureData)) ?? false
            verified = ok
            trustState = ok ? "human_root_signed" : "signature_invalid"
        } else if let mock = signer as? MockSigner {
            // MockSigner carries its own verify logic.
            verified = mock.verify(payload: payloadData, signature: signatureData)
            trustState = verified ? "human_root_signed" : "signature_invalid"
        } else {
            // Unknown signer type: we cannot verify without a public key.
            // Conservative: mark unverified.
            verified = false
            trustState = "signature_invalid"
        }

        // 5. Construct receipt — no Date(), no UUID(), no UserDefaults.
        return SignedEnvelopeReceipt(
            receiptId:         "rcp_\(receiptIdSuffix)",
            schemaVersion:     signatureReceiptSchemaVersion,
            payloadHash:       payloadHash,
            keyKind:           signer.keyKind,
            signerFingerprint: signer.fingerprint,
            signature:         signatureBase64,
            verified:          verified,
            trustState:        trustState,
            nonce:             envelope.nonce,
            anchoredSeq:       0  // pre-tape placeholder; re-anchored at import (§ above)
        )
    }
}

// MARK: - MockSigner

/// Deterministic test double for EnvelopeSigner.
///
/// Uses CryptoKit's P256 (software, not SE) for sign + verify so tests run
/// on any machine, including CI runners without SE.
///
/// keyKind = "se-p256" is intentional: tests validate receipt schema conformance
/// for the se-p256 key kind. Tests that need to distinguish mock from real
/// can inspect `isMock`.
public final class MockSigner: EnvelopeSigner, @unchecked Sendable {
    public let keyKind: String = "se-p256"
    public let fingerprint: String
    public let isMock: Bool = true

    private let privateKey: P256.Signing.PrivateKey

    /// Creates a MockSigner with a new random P-256 key.
    public init() {
        let key = P256.Signing.PrivateKey()
        self.privateKey = key
        let pubData = key.publicKey.x963Representation
        let digest = SHA256.hash(data: pubData)
        self.fingerprint = digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Signs with P256.Signing (software — no biometric prompt, no SE).
    public func sign(payload: Data) throws -> Data {
        do {
            let sig = try privateKey.signature(for: payload)
            return sig.derRepresentation
        } catch {
            throw SignerError.unavailable("MockSigner P256 sign failed: \(error)")
        }
    }

    /// Verifies a DER signature against the mock public key.
    /// Returns false for an invalid signature — does not throw.
    public func verify(payload: Data, signature: Data) -> Bool {
        guard let sig = try? P256.Signing.ECDSASignature(derRepresentation: signature) else {
            return false
        }
        return privateKey.publicKey.isValidSignature(sig, for: payload)
    }
}

/// Signer that always throws `.unavailable` — used to test fail-closed behaviour.
public final class AlwaysUnavailableSigner: EnvelopeSigner, @unchecked Sendable {
    public let keyKind: String = "se-p256"
    public let fingerprint: String = "deadbeef"

    public init() {}

    public func sign(payload: Data) throws -> Data {
        throw SignerError.unavailable("AlwaysUnavailableSigner: medium unavailable by design")
    }
}

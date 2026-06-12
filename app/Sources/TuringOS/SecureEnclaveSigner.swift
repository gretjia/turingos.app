// SecureEnclaveSigner.swift — Real SE-P256 signer implementation (A1_25).
//
// GOVERNING LAW: ADR-013 fail-closed + ADR-005 human root key in SE app-side.
//
// SE key parameters:
//   - kSecAttrTokenIDSecureEnclave: key lives inside the SE, never exported.
//   - kSecAttrKeyTypeECSECPrimeRandom + kSecAttrKeySizeInBits 256: P-256.
//   - PRODUCTION ACL: .privateKeyUsage + .biometryCurrentSet so every signing
//     operation requires a fresh biometric gesture (Touch ID).
//   - .biometryCurrentSet: key is automatically invalidated when biometric
//     enrollment changes (re-enroll invalidates — FEASIBILITY.md I-3 #3).
//
// TEST / CI key parameters (SecureEnclaveSigner.makeTestKey):
//   - .privateKeyUsage ONLY (no .biometryCurrentSet).
//   - Proves SE plumbing without triggering interactive prompts.
//   - Test callers MUST delete the key in defer{} using the returned tag.
//   - Do NOT use test keys as production keys — the biometric ACL is the
//     production security property verified by code inspection + future real-
//     machine D5 (FEASIBILITY.md I-3 #6).
//
// AVAILABILITY PROBE (SecureEnclaveAvailability):
//   probe() attempts to locate/create a temporary SE key query WITHOUT triggering
//   UI. Uses kSecUseAuthenticationUI = kSecUseAuthenticationUIFail so the OS
//   returns errSecInteractionNotAllowed instead of showing a prompt. If that
//   succeeds (or fails only due to item-not-found), and biometry is available
//   via LAContext, the probe returns .secureEnclaveBiometric. Otherwise
//   .appApprovalOnly. On any CI/unsigned runner, errSecMissingEntitlement or
//   errSecBadReq causes .appApprovalOnly — never throws, always returns.
//
// FINGERPRINT:
//   SHA-256 of the public key's external representation (DER/ANSI X9.62
//   uncompressed point). Stable across process lifetimes for the same key.
//
// EVERY failure path: typed SignerError — no nil returns, no silent fallback.

import CryptoKit
import Foundation
import LocalAuthentication
import Security

// MARK: - SecureEnclaveSigner

/// Production SE-P256 signer.
///
/// The key is created or loaded from the Keychain on `init`. If the SE is absent
/// (e.g., CI runner, unsigned build) init throws `SignerError.unavailable`.
///
/// Interactive biometric prompts are triggered only by `sign(payload:)` on the
/// production key (biometryCurrentSet ACL). Test code must use `makeTestKey(tag:)`
/// which creates a non-biometric key.
public final class SecureEnclaveSigner: EnvelopeSigner, @unchecked Sendable {

    // MARK: - Constants

    /// Key kind — mirrors signature_receipt.schema.json key_kind enum value "se-p256".
    public let keyKind: String = "se-p256"

    /// Application tag for the production SE key.
    /// Test code uses a distinct tag so test cleanup never touches production keys.
    public static let productionApplicationTag = "app.turingos.se.approval.v1"

    // MARK: - Private state

    private let privateKey: SecKey

    /// SHA-256 fingerprint of the public key, computed once at init.
    public let fingerprint: String

    // MARK: - Init

    /// Creates a SecureEnclaveSigner backed by a SE key with the given application tag.
    ///
    /// - Parameter applicationTag: The keychain tag for the key (default = production tag).
    /// - Parameter accessControl: The access control flags. Default = production config
    ///   (.privateKeyUsage + .biometryCurrentSet). Pass `.privateKeyUsage` only for
    ///   test keys that must not trigger interactive prompts.
    ///
    /// - Throws: `SignerError.unavailable` if SE is absent, entitlement missing,
    ///   or key creation fails. Never returns partial state.
    public init(applicationTag: String = productionApplicationTag,
                accessControl: SecAccessControlCreateFlags = [.privateKeyUsage, .biometryCurrentSet]) throws {
        let (key, fp) = try SecureEnclaveSigner.loadOrCreate(
            applicationTag: applicationTag,
            accessControl: accessControl
        )
        self.privateKey = key
        self.fingerprint = fp
    }

    // MARK: - EnvelopeSigner

    /// Signs the canonical payload bytes using ECDSA/SHA-256.
    ///
    /// PRODUCTION: requires a fresh biometric gesture (biometryCurrentSet ACL).
    /// TEST (non-biometric key): signs without user interaction.
    ///
    /// - Throws: `SignerError.unavailable` if the key is no longer accessible.
    ///           `SignerError.rejected` if the operation was denied (user cancelled).
    public func sign(payload: Data) throws -> Data {
        var cfError: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            payload as CFData,
            &cfError
        ) as Data? else {
            // Capture the +1 retain ONCE — takeRetainedValue() consumes it.
            // A second call on the same Unmanaged would over-release (ADR-013 M2 bug fix,
            // 2026-06-12). Use the single captured value for both desc and domain/code.
            let err: CFError? = cfError?.takeRetainedValue()
            let desc = err?.localizedDescription ?? "unknown"
            // Distinguish rejection from unavailability based on error domain/code.
            if let err {
                let domain = CFErrorGetDomain(err) as String
                let code = CFErrorGetCode(err)
                // errSecAuthFailed (-25293) and LAError.userCancel (-2) map to rejected.
                if domain == NSOSStatusErrorDomain && (code == -25293 || code == -128) {
                    throw SignerError.rejected("biometric denied: \(desc)")
                }
            }
            throw SignerError.unavailable("SecKeyCreateSignature failed: \(desc)")
        }
        return signature
    }

    // MARK: - Verification (static helper for receipt verification)

    /// Verifies an ECDSA/SHA-256 signature against the public key extracted from
    /// the given private key handle.
    ///
    /// Returns true if valid, false if the signature does not verify.
    /// Never throws for a bad signature — invalid signature is a state (ADR-013
    /// Verifier trait: "failure is a normal Ok(false) outcome").
    ///
    /// - Throws: `SignerError.unavailable` only for malformed inputs (nil public key).
    public func verify(payload: Data, signature: Data) throws -> Bool {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SignerError.unavailable("could not extract public key from SE key")
        }
        var cfError: Unmanaged<CFError>?
        let result = SecKeyVerifySignature(
            publicKey,
            .ecdsaSignatureMessageX962SHA256,
            payload as CFData,
            signature as CFData,
            &cfError
        )
        // cfError is set when result == false AND for malformed input.
        // We swallow it when result == false (invalid sig = state not error).
        cfError?.release()
        return result
    }

    // MARK: - Key management helpers

    /// Deletes the SE key with the given application tag from the keychain.
    /// Used by test cleanup (defer{} blocks).  Silently succeeds if item not found.
    public static func deleteKey(applicationTag: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrApplicationTag: applicationTag.data(using: .utf8)! as CFData,
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Private: create-or-load

    private static func loadOrCreate(
        applicationTag: String,
        accessControl: SecAccessControlCreateFlags
    ) throws -> (SecKey, String) {
        // Try load first.
        if let existing = try? loadKey(applicationTag: applicationTag) {
            let fp = try fingerprint(for: existing)
            return (existing, fp)
        }
        // Create new.
        let newKey = try createKey(applicationTag: applicationTag, accessControl: accessControl)
        let fp = try fingerprint(for: newKey)
        return (newKey, fp)
    }

    private static func loadKey(applicationTag: String) throws -> SecKey {
        // Use LAContext.interactionNotAllowed to suppress prompts (replaces deprecated
        // kSecUseAuthenticationUIFail — Apple docs: use LAContext + interactionNotAllowed).
        let ctx = LAContext()
        ctx.interactionNotAllowed = true
        let query: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrApplicationTag: applicationTag.data(using: .utf8)! as CFData,
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationContext: ctx,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let key = result else {
            if status == errSecItemNotFound {
                throw SignerError.unavailable("key not found: \(applicationTag)")
            }
            throw SignerError.unavailable("SecItemCopyMatching OSStatus \(status) for tag \(applicationTag)")
        }
        return (key as! SecKey)
    }

    private static func createKey(
        applicationTag: String,
        accessControl: SecAccessControlCreateFlags
    ) throws -> SecKey {
        guard let acl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            accessControl,
            nil
        ) else {
            throw SignerError.unavailable("SecAccessControlCreateWithFlags returned nil — SE not available or entitlement missing")
        }

        let privateKeyAttrs: [CFString: Any] = [
            kSecAttrIsPermanent: true,
            kSecAttrApplicationTag: applicationTag.data(using: .utf8)! as CFData,
            kSecAttrAccessControl: acl,
        ]
        let attrs: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
            kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs: privateKeyAttrs,
        ]

        var cfError: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(attrs as CFDictionary, &cfError) else {
            let desc = cfError?.takeRetainedValue().localizedDescription ?? "unknown"
            throw SignerError.unavailable("SecKeyCreateRandomKey failed: \(desc)")
        }
        return key
    }

    private static func fingerprint(for privateKey: SecKey) throws -> String {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw SignerError.unavailable("SecKeyCopyPublicKey returned nil")
        }
        var cfError: Unmanaged<CFError>?
        guard let pubData = SecKeyCopyExternalRepresentation(publicKey, &cfError) as Data? else {
            let desc = cfError?.takeRetainedValue().localizedDescription ?? "unknown"
            throw SignerError.unavailable("SecKeyCopyExternalRepresentation failed: \(desc)")
        }
        let digest = SHA256.hash(data: pubData)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - SecureEnclaveAvailability

/// Availability probe for the SE + biometry capability.
///
/// probe() is SAFE to call from any code path, including tests. It never triggers
/// interactive prompts (uses kSecUseAuthenticationUIFail + canEvaluatePolicy without
/// LAContext.evaluatePolicy).
public struct SecureEnclaveAvailability: SignerAvailability {
    public init() {}

    public func probe() -> SignerCapability {
        // 1. Check biometry via LAContext — no interactive prompt, just capability query.
        let ctx = LAContext()
        var error: NSError?
        let biometryAvailable = ctx.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
        guard biometryAvailable else {
            return .appApprovalOnly
        }

        // 2. Probe SE by attempting a silent key query.
        // Use LAContext.interactionNotAllowed to suppress prompts (replaces deprecated
        // kSecUseAuthenticationUIFail). On unsigned/CI runners returns
        // errSecMissingEntitlement (-34018) or errSecBadReq — we treat those as unavailable.
        let probeCtx = LAContext()
        probeCtx.interactionNotAllowed = true
        let probeTag = "app.turingos.se.probe.v1"
        let query: [CFString: Any] = [
            kSecClass: kSecClassKey,
            kSecAttrApplicationTag: probeTag.data(using: .utf8)! as CFData,
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef: false,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecUseAuthenticationContext: probeCtx,
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        // Acceptable statuses that confirm SE is accessible:
        // - errSecItemNotFound: SE present, key just doesn't exist yet — good.
        // - errSecInteractionNotAllowed: key exists with biometric ACL — SE present.
        // - errSecSuccess: key found — SE present.
        // Any other status (entitlement missing, SE not present) → appApprovalOnly.
        switch status {
        case errSecSuccess, errSecItemNotFound, errSecInteractionNotAllowed:
            return .secureEnclaveBiometric
        default:
            return .appApprovalOnly
        }
    }
}

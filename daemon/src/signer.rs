//! ADR-013: the signing abstraction layer. Business code depends on these
//! traits only - concrete algorithms/media (SE-P256, ssh-ed25519, FIDO2
//! tokens, external HSMs, future SignerSet members) plug in as new
//! implementations with a new key_kind value. Zero refactor by construction.
//!
//! No implementations live here yet (M1: first real callers arrive in P2 -
//! SE-P256 and ssh-ed25519 are the first two, making the trait earn its
//! existence with a second caller on day one).

/// Open enumeration - mirrors contracts/signature_receipt.schema.json
/// key_kind. Adding a value is a minor, backward-compatible contract change.
pub type KeyKind = &'static str;

#[derive(Debug)]
pub enum SignError {
    /// Signing medium unavailable (device absent, biometric refused...).
    /// Fail-closed: callers must surface this, never fall back silently (M2).
    Unavailable(String),
    Rejected(String),
}

pub trait Signer {
    fn key_kind(&self) -> KeyKind;
    fn fingerprint(&self) -> String;
    /// Signs the canonical payload bytes. Implementations must not transform
    /// the payload - canonicalization happens upstream and is hash-anchored.
    fn sign(&self, canonical_payload: &[u8]) -> Result<Vec<u8>, SignError>;
    /// Hardware attestation evidence, where the medium provides it.
    /// Receipt schema carries this as an optional field.
    fn attestation(&self) -> Option<Vec<u8>> {
        None
    }
}

pub trait Verifier {
    fn key_kind(&self) -> KeyKind;
    /// Verification is total: an invalid signature is a normal `Ok(false)`
    /// outcome (failure is a state that goes on tape), errors are for
    /// malformed inputs only.
    fn verify(
        &self,
        canonical_payload: &[u8],
        signature: &[u8],
        public_key: &[u8],
    ) -> Result<bool, SignError>;
}

//! turingosd core. ADR-005: the daemon is the only kernel; every UI is a
//! projection consumer. ADR-003: nothing here is canonical truth - canonical
//! truth lives in Git-backed ChainTape/CAS upstream; the daemon derives,
//! projects, and reconciles.

pub mod events;
pub mod signer;
pub mod snapshot;

// Placeholders wired in later atoms (kept out of the tree until then - M1:
// no module exists before its first real caller):
//   uds       - A1_03 event subscription server + resident aggregate projection
//   watch     - A1_04 fs-watch dirty signals (notify crate spike)

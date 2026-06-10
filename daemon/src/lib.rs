//! turingosd core. ADR-005: the daemon is the only kernel; every UI is a
//! projection consumer. ADR-003: nothing here is canonical truth - canonical
//! truth lives in Git-backed ChainTape/CAS upstream; the daemon derives,
//! projects, and reconciles.

pub mod events;
pub mod projection;
pub mod signer;
pub mod snapshot;
pub mod uds;
pub mod watch;

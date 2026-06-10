//! turingosd entrypoint. A1_01 scope: report identity and exit - the daemon
//! earns long-running behavior in A1_03 (UDS event subscription).

fn main() {
    println!(
        "turingosd {} (scaffold) - schema {}",
        env!("CARGO_PKG_VERSION"),
        turingosd::events::EVENT_SCHEMA_VERSION
    );
}

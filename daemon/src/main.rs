//! turingosd entrypoint. A1_02 scope: `turingosd snapshot <repo-path>` emits
//! one read-only contract event stream (JSONL) for any local git repository.
//! Long-running behavior arrives in A1_03 (UDS event subscription).

use std::path::Path;
use std::process::ExitCode;

fn main() -> ExitCode {
    let mut args = std::env::args().skip(1);
    match args.next().as_deref() {
        Some("snapshot") => {
            let Some(repo) = args.next() else {
                eprintln!("usage: turingosd snapshot <repo-path>");
                return ExitCode::from(2);
            };
            let path = Path::new(&repo);
            let project_id = path
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("project");
            let snap = match turingosd::snapshot::snapshot_repo(project_id, path) {
                Ok(s) => s,
                Err(e) => {
                    eprintln!("snapshot failed: {e}");
                    return ExitCode::FAILURE;
                }
            };
            let ts = turingosd::snapshot::utc_now_iso();
            for ev in turingosd::snapshot::to_events(&snap, 0, &ts) {
                println!(
                    "{}",
                    serde_json::to_string(&ev).expect("envelope serializes")
                );
            }
            ExitCode::SUCCESS
        }
        _ => {
            // CLI_ABI law #2 discipline applies daemon-side too: stdout is
            // machine JSONL only; identity/usage prose goes to stderr.
            eprintln!(
                "turingosd {} - schema {} (commands: snapshot <repo-path>)",
                env!("CARGO_PKG_VERSION"),
                turingosd::events::EVENT_SCHEMA_VERSION
            );
            ExitCode::from(2)
        }
    }
}

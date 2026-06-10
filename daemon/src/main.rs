//! turingosd entrypoint.
//! - `turingosd snapshot <repo-path>`: one read-only contract event stream
//!   (JSONL on stdout) for any local git repository (A1_02).
//! - `turingosd serve <repo-path> <socket-path>`: resident daemon - UDS
//!   JSONL subscription endpoint + periodic reconciliation loop (A1_03).

use std::path::Path;
use std::process::ExitCode;
use std::sync::Arc;

fn main() -> ExitCode {
    let mut args = std::env::args().skip(1);
    match args.next().as_deref() {
        Some("serve") => {
            let (Some(first), Some(second)) = (args.next(), args.next()) else {
                eprintln!("usage: turingosd serve <repo-path> <socket-path> | serve --registry <projects.json> <socket-path>");
                return ExitCode::from(2);
            };
            // Registry mode (A1_06): N projects driven by projects.json.
            if first == "--registry" {
                let registry = Path::new(&second).to_path_buf();
                let Some(socket) = args.next() else {
                    eprintln!("usage: turingosd serve --registry <projects.json> <socket-path>");
                    return ExitCode::from(2);
                };
                return serve_registry(registry, socket);
            }
            let repo = Path::new(&first).to_path_buf();
            let socket = second;
            let project_id = repo
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("project")
                .to_string();
            let hub = turingosd::uds::EventHub::new(&project_id);

            let rt = match tokio::runtime::Runtime::new() {
                Ok(rt) => rt,
                Err(e) => {
                    eprintln!("runtime: {e}");
                    return ExitCode::FAILURE;
                }
            };
            let result: std::io::Result<()> = rt.block_on(async {
                // Bind FIRST (single-threaded moment, so bind_socket's brief
                // umask tightening cannot race other file creation), then
                // start reconciliation.
                let listener = turingosd::uds::bind_socket(Path::new(&socket))?;
                eprintln!("turingosd serving {project_id} on {socket}");

                // fs-watch hints (A1_04): best-effort pulse + early tick.
                // Failure degrades VISIBLY to periodic-only reconciliation;
                // the contract does not change (R1 design brief D4).
                let (poke_tx, poke_rx) = std::sync::mpsc::channel::<()>();
                let poke_rx = Arc::new(std::sync::Mutex::new(poke_rx));
                let watch_hub = hub.clone();
                let _watcher = match turingosd::watch::watch_dirty(
                    &repo,
                    turingosd::watch::WatchConfig::default(),
                    move |batch| {
                        let payload = batch.to_payload(watch_hub.project_id());
                        watch_hub.publish_hint(payload);
                        let _ = poke_tx.send(()); // wake the reconciler now
                    },
                ) {
                    Ok(w) => Some(w),
                    Err(e) => {
                        eprintln!("fs-watch unavailable, periodic reconciliation only: {e}");
                        None
                    }
                };

                // Reconciliation on a SUPERVISED blocking thread (git
                // spawns): a panic inside the loop must be loudly visible
                // and survivable, never a silently frozen projection
                // (S-stage critique). A poisoned hub lock re-panics every
                // restart - repeated stderr is the visible failure state.
                // Ticks fire every 2s OR immediately on a watch poke.
                let recon_hub = hub.clone();
                let recon_repo = repo.clone();
                let recon_pid = project_id.clone();
                std::thread::spawn(move || loop {
                    let hub = recon_hub.clone();
                    let repo = recon_repo.clone();
                    let pid = recon_pid.clone();
                    let poke = poke_rx.clone();
                    let worker = std::thread::spawn(move || {
                        let mut reconciler = turingosd::uds::Reconciler::new(&pid, &repo);
                        loop {
                            if let Err(e) = reconciler.tick(&hub) {
                                eprintln!("reconcile failed (next tick retries): {e}");
                            }
                            let _ = poke
                                .lock()
                                .expect("poke lock")
                                .recv_timeout(std::time::Duration::from_secs(2));
                        }
                    });
                    if worker.join().is_err() {
                        eprintln!(
                            "reconciler thread panicked; restarting in 2s (projection may be stale)"
                        );
                    } else {
                        eprintln!("reconciler loop exited unexpectedly; restarting in 2s");
                    }
                    std::thread::sleep(std::time::Duration::from_secs(2));
                });

                turingosd::uds::serve(listener, hub, Arc::new(turingosd::uds::SameUid)).await
            });
            match result {
                Ok(()) => ExitCode::SUCCESS,
                Err(e) => {
                    eprintln!("serve failed: {e}");
                    ExitCode::FAILURE
                }
            }
        }
        Some("snapshot") => {
            let Some(repo) = args.next() else {
                eprintln!("usage: turingosd snapshot <repo-path>");
                return ExitCode::from(2);
            };
            // (single-shot mode unchanged below)
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
                "turingosd {} - schema {} (commands: snapshot <repo-path> | serve <repo-path> <socket-path> | serve --registry <projects.json> <socket-path>)",
                env!("CARGO_PKG_VERSION"),
                turingosd::events::EVENT_SCHEMA_VERSION
            );
            ExitCode::from(2)
        }
    }
}

/// Registry mode (A1_06): one hub, N projects from projects.json with hot
/// reload every cycle. A bad registry read is a VISIBLE retry that keeps
/// the previous generation of reconcilers alive (M2: never silently empty
/// the workspace). Per-repo fs-watch hints are a registered P1-close-out
/// debt; the 2s periodic tick is canonical discovery regardless (ADR-010).
fn serve_registry(registry: std::path::PathBuf, socket: String) -> ExitCode {
    let hub = turingosd::uds::EventHub::new("workspace");
    let rt = match tokio::runtime::Runtime::new() {
        Ok(rt) => rt,
        Err(e) => {
            eprintln!("runtime: {e}");
            return ExitCode::FAILURE;
        }
    };
    let result: std::io::Result<()> = rt.block_on(async {
        let listener = turingosd::uds::bind_socket(Path::new(&socket))?;
        eprintln!(
            "turingosd serving registry {} on {socket}",
            registry.display()
        );

        let recon_hub = hub.clone();
        std::thread::spawn(move || loop {
            let hub = recon_hub.clone();
            let reg = registry.clone();
            let worker = std::thread::spawn(move || {
                let mut runner = turingosd::registry::RegistryRunner::new(&reg);
                loop {
                    match runner.tick(&hub) {
                        Err(e) => eprintln!(
                            "registry reload failed (previous generation keeps running): {e}"
                        ),
                        Ok(stats) if stats.reconcile_errors > 0 => eprintln!(
                            "registry: {}/{} local project(s) failed to reconcile this cycle",
                            stats.reconcile_errors, stats.projects_local
                        ),
                        Ok(_) => {}
                    }
                    std::thread::sleep(std::time::Duration::from_secs(2));
                }
            });
            if worker.join().is_err() {
                eprintln!("registry runner panicked; restarting in 2s (projection may be stale)");
            } else {
                eprintln!("registry runner exited unexpectedly; restarting in 2s");
            }
            std::thread::sleep(std::time::Duration::from_secs(2));
        });

        turingosd::uds::serve(listener, hub, Arc::new(turingosd::uds::SameUid)).await
    });
    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("serve failed: {e}");
            ExitCode::FAILURE
        }
    }
}

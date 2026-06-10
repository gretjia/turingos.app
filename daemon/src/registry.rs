//! A1_06: project registry - the multi-repo driver (四次裁决反向塑形).
//!
//! `projects.json` is app-written, daemon-read configuration (NOT canonical
//! truth - git remains that, ADR-003). Each tick the runner re-reads the
//! file (hot reload: add/remove repos without a restart), reconciles every
//! local project through its own A1_02/A1_03 Reconciler, and projects
//! remote-only entries as visible placeholder registrations (gray in the
//! UI - selected on GitHub but no local clone yet). A corrupt registry is
//! a visible error that keeps the previous generation running; it never
//! silently empties the workspace (M2).
//!
//! Registry-mode scope note (card 留痕): per-repo fs-watch hints are
//! deferred to P1 close-out; the 2s periodic tick is the canonical
//! discovery lane regardless (ADR-010).

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};

use crate::events::{EventKind, EventSource, TrustState};
use crate::snapshot::SnapshotError;
use crate::uds::{EventHub, Reconciler};

#[derive(Debug, Clone, serde::Deserialize, serde::Serialize, PartialEq, Eq)]
pub struct RegistryEntry {
    pub project_id: String,
    /// Local clone path; absent or missing on disk == remote-only entry.
    #[serde(default)]
    pub path: Option<PathBuf>,
    /// Normalized remote identity (e.g. "github.com/owner/repo").
    #[serde(default)]
    pub remote: Option<String>,
}

#[derive(Debug, Clone, serde::Deserialize, serde::Serialize)]
pub struct RegistryFile {
    pub version: u32,
    pub projects: Vec<RegistryEntry>,
}

#[derive(Debug)]
pub enum RegistryError {
    Io(std::io::Error),
    Parse(serde_json::Error),
    Invalid(String),
}

impl std::fmt::Display for RegistryError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            RegistryError::Io(e) => write!(f, "registry io: {e}"),
            RegistryError::Parse(e) => write!(f, "registry parse: {e}"),
            RegistryError::Invalid(e) => write!(f, "registry invalid: {e}"),
        }
    }
}

impl std::error::Error for RegistryError {}

/// Load + validate: version pinned, project_ids unique, existing paths
/// canonicalized (R1_memo §2.a: compare real paths, never strings).
pub fn load_registry(path: &Path) -> Result<Vec<RegistryEntry>, RegistryError> {
    let body = std::fs::read(path).map_err(RegistryError::Io)?;
    let file: RegistryFile = serde_json::from_slice(&body).map_err(RegistryError::Parse)?;
    if file.version != 1 {
        return Err(RegistryError::Invalid(format!(
            "unsupported registry version {}",
            file.version
        )));
    }
    let mut seen = std::collections::BTreeSet::new();
    let mut seen_paths = std::collections::BTreeSet::new();
    let mut out = Vec::with_capacity(file.projects.len());
    for mut entry in file.projects {
        if entry.project_id.is_empty() {
            return Err(RegistryError::Invalid("empty project_id".into()));
        }
        if !seen.insert(entry.project_id.clone()) {
            return Err(RegistryError::Invalid(format!(
                "duplicate project_id {}",
                entry.project_id
            )));
        }
        if let Some(p) = entry.path.as_ref() {
            // canonicalize when the clone exists; a vanished path demotes
            // the entry to remote-only VISIBLY (local=false in the event).
            entry.path = p.canonicalize().ok();
        }
        // Path uniqueness over CANONICAL paths (S-stage A1_06 blocker: two
        // ids on one worktree path collide on path-derived worktree_ids in
        // the global ledger, breaking rollup == Σ buckets and letting one
        // project's retire poison the survivor's counts).
        if let Some(p) = entry.path.as_ref() {
            if !seen_paths.insert(p.clone()) {
                return Err(RegistryError::Invalid(format!(
                    "duplicate path {} (two project_ids on one clone)",
                    p.display()
                )));
            }
        }
        out.push(entry);
    }
    Ok(out)
}

/// Drives N reconcilers off the registry file. Owns nothing canonical:
/// dropping it loses no truth (git + the registry file remain).
pub struct RegistryRunner {
    registry_path: PathBuf,
    reconcilers: BTreeMap<String, Reconciler>,
    /// Last published ProjectRegistered payload per id (dedup: re-publish
    /// only when the entry's visible identity changes).
    announced: BTreeMap<String, serde_json::Value>,
}

pub struct RegistryTickStats {
    pub projects_local: u64,
    pub projects_remote_only: u64,
    pub reconcile_errors: u64,
}

impl RegistryRunner {
    pub fn new(registry_path: &Path) -> Self {
        RegistryRunner {
            registry_path: registry_path.to_path_buf(),
            reconcilers: BTreeMap::new(),
            announced: BTreeMap::new(),
        }
    }

    /// One cycle: reload registry -> announce identity changes -> retire
    /// removed projects (their worktrees get WorktreeRemoved, the bucket
    /// retires) -> reconcile every local project. Per-project reconcile
    /// errors degrade that project visibly and never abort the cycle.
    pub fn tick(&mut self, hub: &EventHub) -> Result<RegistryTickStats, RegistryError> {
        let entries = load_registry(&self.registry_path)?;

        // Retire projects that left the registry.
        let live_ids: std::collections::BTreeSet<&str> =
            entries.iter().map(|e| e.project_id.as_str()).collect();
        let gone: Vec<String> = self
            .reconcilers
            .keys()
            .filter(|id| !live_ids.contains(id.as_str()))
            .cloned()
            .collect();
        for id in gone {
            if let Some(rec) = self.reconcilers.remove(&id) {
                rec.retire(hub);
            }
            hub.retire_project(&id); // no ghost bucket (S-stage blocker)
            self.announced.remove(&id);
        }

        let mut stats = RegistryTickStats {
            projects_local: 0,
            projects_remote_only: 0,
            reconcile_errors: 0,
        };
        for entry in &entries {
            let local = entry.path.as_deref().is_some_and(Path::is_dir);
            let announcement = serde_json::json!({
                "project_id": entry.project_id,
                "path": entry.path.as_ref().map(|p| p.to_string_lossy()),
                "remote": entry.remote,
                "local": local,
            });
            if self.announced.get(&entry.project_id) != Some(&announcement) {
                hub.publish(
                    EventKind::ProjectRegistered,
                    EventSource::Daemon,
                    TrustState::ObservedUnsigned,
                    announcement.clone(),
                );
                self.announced
                    .insert(entry.project_id.clone(), announcement);
            }

            if local {
                stats.projects_local += 1;
                let path = entry.path.clone().expect("local implies path");
                // Repoint detection (S-stage blocker: or_insert_with kept
                // the OLD path's reconciler forever when an id moved to a
                // new clone - announcement said B while data stayed A).
                // A path change retires the old binding before rebinding.
                let stale = self
                    .reconcilers
                    .get(&entry.project_id)
                    .is_some_and(|r| r.repo_path() != path);
                if stale {
                    if let Some(old) = self.reconcilers.remove(&entry.project_id) {
                        old.retire(hub);
                    }
                    hub.retire_project(&entry.project_id);
                }
                let rec = self
                    .reconcilers
                    .entry(entry.project_id.clone())
                    .or_insert_with(|| Reconciler::new(&entry.project_id, &path));
                if let Err(e) = rec.tick(hub) {
                    stats.reconcile_errors += 1;
                    visible_reconcile_error(&entry.project_id, &e);
                }
            } else {
                stats.projects_remote_only += 1;
                // A clone that vanished mid-flight: retire its rows so the
                // radar shows the truth instead of a frozen ghost.
                if let Some(rec) = self.reconcilers.remove(&entry.project_id) {
                    rec.retire(hub);
                    hub.retire_project(&entry.project_id);
                }
            }
        }
        Ok(stats)
    }
}

fn visible_reconcile_error(project_id: &str, e: &SnapshotError) {
    eprintln!("registry: reconcile {project_id} failed (next tick retries): {e}");
}

//! A1_47: registry-hub branch poller — makes every repo's GitHub branches
//! visible in the galaxy.
//!
//! For each registry entry with a `remote`, shells the user's already-authed
//! `gh` (zero new credential surface; the token stays in gh's keyring) to read
//! the default branch + the branch list, and publishes a `BranchObserved` event
//! per branch (provenance=github_api). Branches gone since the last poll emit
//! `BranchRemoved`. Runs on its OWN slow-cadence supervised thread (F1/F3) so it
//! never blocks the 2s reconcile tick. gh failure degrades VISIBLY (stderr) and
//! emits nothing for that repo — never a crash, never a fake event.
//!
//! First cut: branch NODES (ref + head_sha + is_default). ahead/behind/merged
//! enrichment (fork-distance, merged-green) is a follow-up.

use std::collections::{BTreeMap, BTreeSet};
use std::path::{Path, PathBuf};
use std::process::Command;

use crate::events::{EventKind, EventSource, TrustState};
use crate::registry::load_registry;
use crate::uds::EventHub;

/// gh invocation seam (LiveGhClient shells the real binary; tests use the pure
/// functions below and never touch the network).
pub trait GhClient: Send + Sync {
    fn run(&self, args: &[&str]) -> Result<String, String>;
}

pub struct LiveGhClient;

impl GhClient for LiveGhClient {
    fn run(&self, args: &[&str]) -> Result<String, String> {
        let bin = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"]
            .iter()
            .find(|p| Path::new(p).is_file())
            .ok_or_else(|| "gh binary not found".to_string())?;
        let out = Command::new(bin)
            .args(args)
            .output()
            .map_err(|e| format!("gh spawn: {e}"))?;
        if !out.status.success() {
            return Err(format!(
                "gh exit {:?}: {}",
                out.status.code(),
                String::from_utf8_lossy(&out.stderr).trim()
            ));
        }
        Ok(String::from_utf8_lossy(&out.stdout).into_owned())
    }
}

/// Parse `github.com/owner/repo` into (owner, repo).
pub fn owner_repo(remote: &str) -> Option<(String, String)> {
    let rest = remote.strip_prefix("github.com/")?;
    let mut parts = rest.split('/');
    let owner = parts.next()?;
    let repo = parts.next()?;
    if owner.is_empty() || repo.is_empty() {
        return None;
    }
    Some((owner.to_string(), repo.to_string()))
}

/// Pure: GitHub `branches` JSON array + default branch name -> BranchObserved
/// payloads. One payload per branch.
pub fn parse_branches(
    branches_json: &str,
    default_branch: &str,
    project_id: &str,
) -> Result<Vec<serde_json::Value>, String> {
    let value: serde_json::Value =
        serde_json::from_str(branches_json).map_err(|e| format!("branches json: {e}"))?;
    let items = value.as_array().ok_or("branches json is not an array")?;
    let mut out = Vec::with_capacity(items.len());
    for it in items {
        let name = it
            .get("name")
            .and_then(serde_json::Value::as_str)
            .ok_or("branch entry missing name")?;
        let sha = it
            .get("commit")
            .and_then(|c| c.get("sha"))
            .and_then(serde_json::Value::as_str)
            .unwrap_or("");
        out.push(serde_json::json!({
            "project_id": project_id,
            "branch_ref": format!("refs/heads/{name}"),
            "head_sha": sha,
            "is_default": name == default_branch,
            "provenance": "github_api",
            "merge_status": "unknown",
            "merged_into_default": false,
        }));
    }
    Ok(out)
}

/// Pure: refs present last poll but gone now (→ BranchRemoved).
pub fn diff_removed(prev: &BTreeSet<String>, current: &BTreeSet<String>) -> Vec<String> {
    prev.difference(current).cloned().collect()
}

/// Registry-hub branch poller. Owns nothing canonical; dropping it loses no
/// truth (GitHub + the registry remain).
pub struct BranchPoller {
    registry_path: PathBuf,
    /// project_id -> last-seen branch refs (for BranchRemoved diffing).
    seen: BTreeMap<String, BTreeSet<String>>,
}

impl BranchPoller {
    pub fn new(registry_path: &Path) -> Self {
        BranchPoller {
            registry_path: registry_path.to_path_buf(),
            seen: BTreeMap::new(),
        }
    }

    /// One poll cycle over every registry entry that has a remote. Panic-free by
    /// construction (every failure path is a visible eprintln, never an unwrap).
    pub fn poll(&mut self, hub: &EventHub, gh: &dyn GhClient) {
        let entries = match load_registry(&self.registry_path) {
            Ok(e) => e,
            Err(e) => {
                eprintln!("branch poller: registry read failed: {e}");
                return;
            }
        };
        for entry in &entries {
            let Some(remote) = entry.remote.as_deref() else {
                continue;
            };
            let Some((owner, repo)) = owner_repo(remote) else {
                eprintln!(
                    "branch poller: unparseable remote {remote} for {}",
                    entry.project_id
                );
                continue;
            };
            let slug = format!("{owner}/{repo}");

            let default_branch =
                match gh.run(&["api", &format!("repos/{slug}"), "-q", ".default_branch"]) {
                    Ok(s) => s.trim().to_string(),
                    Err(e) => {
                        eprintln!("branch poller: {slug} default_branch failed: {e}");
                        continue;
                    }
                };
            // ?per_page=100 returns a single JSON array (no --paginate
            // concatenation); 100 covers every repo here (max=72).
            let branches_json =
                match gh.run(&["api", &format!("repos/{slug}/branches?per_page=100")]) {
                    Ok(s) => s,
                    Err(e) => {
                        eprintln!("branch poller: {slug} branches failed: {e}");
                        continue;
                    }
                };
            let payloads = match parse_branches(&branches_json, &default_branch, &entry.project_id)
            {
                Ok(p) => p,
                Err(e) => {
                    eprintln!("branch poller: {slug} parse failed: {e}");
                    continue;
                }
            };

            let mut current: BTreeSet<String> = BTreeSet::new();
            for p in &payloads {
                if let Some(r) = p.get("branch_ref").and_then(serde_json::Value::as_str) {
                    current.insert(r.to_string());
                }
                hub.publish(
                    EventKind::BranchObserved,
                    EventSource::Github,
                    TrustState::ObservedUnsigned,
                    p.clone(),
                );
            }
            if let Some(prev) = self.seen.get(&entry.project_id) {
                for gone in diff_removed(prev, &current) {
                    hub.publish(
                        EventKind::BranchRemoved,
                        EventSource::Github,
                        TrustState::ObservedUnsigned,
                        serde_json::json!({"project_id": entry.project_id, "branch_ref": gone}),
                    );
                }
            }
            self.seen.insert(entry.project_id.clone(), current);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn owner_repo_parses_normalized_remote() {
        assert_eq!(
            owner_repo("github.com/gretjia/turingosv4"),
            Some(("gretjia".into(), "turingosv4".into()))
        );
        assert_eq!(owner_repo("gitlab.com/a/b"), None);
        assert_eq!(owner_repo("github.com/onlyowner"), None);
    }

    #[test]
    fn parse_branches_one_payload_per_branch_with_default_flag() {
        let json = r#"[
            {"name":"main","commit":{"sha":"aaa111"}},
            {"name":"claude/livefc1-lean","commit":{"sha":"bbb222"}}
        ]"#;
        let out = parse_branches(json, "main", "turingosv4").unwrap();
        assert_eq!(out.len(), 2);
        assert_eq!(out[0]["branch_ref"], "refs/heads/main");
        assert_eq!(out[0]["head_sha"], "aaa111");
        assert_eq!(out[0]["is_default"], true);
        assert_eq!(out[0]["provenance"], "github_api");
        assert_eq!(out[1]["branch_ref"], "refs/heads/claude/livefc1-lean");
        assert_eq!(out[1]["is_default"], false);
    }

    #[test]
    fn parse_branches_rejects_non_array() {
        assert!(parse_branches("{\"message\":\"Not Found\"}", "main", "p").is_err());
    }

    #[test]
    fn diff_removed_finds_gone_refs() {
        let prev: BTreeSet<String> = ["refs/heads/a", "refs/heads/b", "refs/heads/c"]
            .iter()
            .map(|s| s.to_string())
            .collect();
        let current: BTreeSet<String> = ["refs/heads/a", "refs/heads/c"]
            .iter()
            .map(|s| s.to_string())
            .collect();
        assert_eq!(
            diff_removed(&prev, &current),
            vec!["refs/heads/b".to_string()]
        );
    }
}

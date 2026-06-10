# R1.9 Port-Readiness Audit — Inventory (runbook §2)

- Audit target: scratch CLONE `/Users/zephryj/work/.audit-scratch/turingosv4-main`
- Anchor commit: `1f00012d5326d08f0e6ffe05f6ecec6a391c4896` (branch main, committed 2026-05-29 16:19:58 +0800)
  - cmd: `git log -1 --format='%H %h %ci'`
- Method note: tokei/cloc not used; plain `wc -l` (counts physical lines incl. blanks/comments, NOT logical LOC). All commands run from clone root.

---

## 1. Rust LOC by file (src/)

Method: `find src -name "*.rs" | xargs wc -l | sort -rn`

- TOTAL: **124541** lines across **226** `.rs` files
  - cmd: `find src -name "*.rs" | wc -l` → 226
  - cmd: `find src -name "*.rs" | xargs wc -l | sort -rn | tail -1` → `124541 total`

Top 30 largest files:

| LOC | File |
|-----|------|
| 9592 | src/state/sequencer.rs |
| 5633 | src/state/typed_tx.rs |
| 4066 | src/runtime/audit_assertions.rs |
| 3598 | src/bin/audit_dashboard.rs |
| 3099 | src/bin/turingos/cmd_generate.rs |
| 2732 | src/web/spec.rs |
| 2549 | src/bin/turingos/cmd_llm.rs |
| 2474 | src/bottom_white/ledger/transition_ledger.rs |
| 1813 | src/bin/turingos/cmd_spec.rs |
| 1775 | src/runtime/adapter.rs |
| 1692 | src/bottom_white/cas/store.rs |
| 1421 | src/top_white/predicates/registry.rs |
| 1336 | src/runtime/attempt_telemetry.rs |
| 1321 | src/runtime/autopsy_capsule.rs |
| 1265 | src/runtime/chain_derived_run_facts.rs |
| 1186 | src/runtime/mod.rs |
| 1170 | src/bottom_white/ledger/system_keypair.rs |
| 1145 | src/runtime/real5_roles.rs |
| 1142 | src/state/price_index.rs |
| 1138 | src/state/q_state.rs |
| 1113 | src/ledger.rs |
| 1067 | src/bin/cybench_security_sandbox_current_kernel.rs |
| 1055 | src/economy/monetary_invariant.rs |
| 1038 | src/bin/osworld_computer_use_current_kernel.rs |
| 1031 | src/bin/mind2web_browser_action_current_kernel.rs |
| 1021 | src/runtime/librarian_broadcast.rs |
| 1005 | src/bin/webarena_web_agent_current_kernel.rs |
| 997 | src/web/welcome.rs |
| 981 | src/tdma_runner.rs |
| 971 | src/bin/toolbench_api_tool_use_current_kernel.rs |

Notes for porter: the two largest files — `src/state/sequencer.rs` (9592) and
`src/state/typed_tx.rs` (5633) — are both §6 RESTRICTED Class-4 trust-root
surfaces (sequencer admission + typed tx wire schema). They dominate the LOC
distribution and are the highest-risk port surfaces.

---

## 2. Workspace structure

Method: `Read Cargo.toml`; `grep -E '^(name|edition|version)' spike/gix_capability/Cargo.toml`

- This is a **Cargo workspace with 2 members** (NOT single crate):
  - `members = [".", "spike/gix_capability"]`
  - `exclude = ["experiments/minif2f_v4"]`
- Member 1 (root): crate `turingosv4`, version `0.1.0`, edition `2021`
  - description: "Silicon-Native Microkernel for LLM Formal Verification Swarm"
- Member 2: crate `gix_capability_spike`, version `0.0.1`, edition `2021` (path `spike/gix_capability`)

Features: `web = ["axum", "tower-http", "tokio-tungstenite"]`

Top-level `[dependencies]` (names only, root crate):
argon2, axum (optional, web), bincode, chacha20poly1305, ed25519-dalek, flate2,
getrandom, git2 (default-features=false), libc, env_logger, log, rand,
reqwest (default-features=false, rustls-tls), secrecy, serde, serde_json, sha2,
tokio, toml (default-features=false), tokio-tungstenite (optional, web),
tower-http (optional, web), zeroize.
(22 declared deps; 3 are web-feature-gated optional: axum, tokio-tungstenite, tower-http.)

`[dev-dependencies]`: tempfile, tokio-test.

Port-relevant flags: `reqwest` and `git2` both use `default-features=false`
(rustls-tls for reqwest; git2 likely vendoring off / system libgit2 — verify on
target platform). `toml` uses parse-only. `libc` direct dep = some platform-native
syscall surface to expect.

---

## 3. Bin target inventory + discrepancy

Method:
- `grep -c '^\[\[bin\]\]' Cargo.toml` → **1** explicit `[[bin]]`
- `find src/bin -maxdepth 1 -name "*.rs" | wc -l` → **36** top-level `.rs` (auto-discovered bin candidates)
- `find src/bin -mindepth 2 -name "*.rs" | wc -l` → **31** nested module files (NOT bin targets)
- `find src/bin -name "*.rs" | wc -l` → **67** total `.rs` under src/bin

### Reconciliation

Cargo auto-discovers one bin per top-level `.rs` in `src/bin/`. Subdir files
(`src/bin/turingos/*`) are modules of the `turingos` bin, not separate targets.

- **Effective bin target count: 36** (= 36 top-level src/bin .rs files; Cargo
  auto-discovery convention).
- Only **1** of those 36 is explicitly declared `[[bin]]` in Cargo.toml:
  `turingos_web` (path `src/bin/turingos_web.rs`, `required-features = ["web"]`).
- DISCREPANCY FLAG: the explicit `[[bin]]` count (1) != actual bin targets (36).
  This is EXPECTED, not a defect — `turingos_web` needs an explicit block only
  because it is gated behind `required-features = ["web"]`; the other 35 bins
  rely on Cargo's `src/bin/*.rs` auto-discovery. Porter implication: any build
  system that does NOT replicate Cargo's auto-discovery (e.g. a manual
  Bazel/Buck target list) must enumerate all 36 bins explicitly, and must wire
  the `web` feature gate for `turingos_web`.

### The 36 top-level bin targets
(cmd: `find src/bin -maxdepth 1 -name "*.rs" | sort`)
audit_dashboard, audit_tape, audit_tape_tamper, boot_cli_current_kernel_fresh,
cybench_security_sandbox_current_kernel, fc3_governance_reinit_current_kernel,
full_system_augment_current_kernel, full_system_participation_current_kernel,
gaia_general_assistant_current_kernel, gen_run_summary, generate_markov_capsule,
gpqa_science_reasoning_current_kernel, market_external_agent_current_kernel,
math_competition_reasoning_current_kernel, mind2web_browser_action_current_kernel,
osworld_computer_use_current_kernel, real14_e2_candidate_verifier,
real15_role_differentiation_verifier, real16_market_performance_verifier,
resume_preflight, swebench_live_coding_repair_current_kernel,
tb_18r_compute_invariant, tb_g_persistence_report, tdma_proof_current_kernel,
tdma_rc1_deepseek_nesbitt, tdma_rc1_deepseek_putnam_2025_b3,
tdma_rc1_deepseek_putnam_a1, tdma_rc1_distiller_stress, tdma_rc1_nesbitt_stress,
tdma_rc1_real_evidence, tdma_rc1_zero_gain_demo,
toolbench_api_tool_use_current_kernel, turingos, turingos_web, verify_chaintape,
webarena_web_agent_current_kernel.

Nested dir: `src/bin/turingos/` (31 module files: chat_client, cmd_agent,
cmd_audit_dashboard, cmd_audit_tamper, cmd_audit_tape, cmd_batch, cmd_config,
cmd_export_evidence, cmd_generate, cmd_init, cmd_llm, cmd_preflight, cmd_render,
cmd_replay, cmd_report_bankruptcy, cmd_report_markov, cmd_report_positions,
cmd_report_run, cmd_report_wallet, cmd_spec, cmd_spec_audit, cmd_tape_migrate,
cmd_task_open, cmd_task_tick, cmd_task_view, cmd_tdma, cmd_verify_chaintape,
cmd_verify_e2_candidate, cmd_welcome, cmd_wizard, common) — these belong to the
`turingos` bin, NOT separate targets.

---

## 4. Non-Rust surface relevant to a port

Method: `ls -1 .`; `du -sh frontend`; per-dir `find ... -type f | wc -l`;
`find frontend -type f | sed 's/.*\.//' | sort | uniq -c`

- frontend/: **432K**, **41 files**.
  - File types: 33 .ts, 4 .json, 2 .css, 1 .html, 1 .gitignore
  - Subdirs: frontend/src (src/types, src/components), frontend/test, frontend/design-reference
  - Note: TypeScript frontend, NO bundled node_modules in clone; no .js/.jsx —
    pure .ts source. Port-relevant: this is a separate build toolchain from cargo.
- scripts/: **74 files** (cmd: `find scripts -type f | wc -l`). Includes the
  constitution-gate scripts (`run_constitution_gates.sh`) and git hooks the
  harness depends on — porter must carry these or reimplement.
- docs/: **7 files** (cmd: `find docs -type f | wc -l`). Small; most docs live
  at repo root (HARNESS.md, HARNESS_PLAYBOOK.md, constitution.md, etc.) and
  under handover/.
- contracts / schema files present (cmd: find for `schema|contract` names):
  - `experiments/tisr_ui_spike/ui_ir_schema.json` (UI IR JSON schema)
  - `rules/active/R-013_format_contract.yaml`
  - `genesis_payload.toml` (root — genesis/economy payload)
  - `constitution.md` (axiom layer — Tier-1 truth)
  - Several `tests/*contract*.rs` and `tests/fixtures/real_task_hygiene/.../contract.txt`
    (test-scaffold contracts, not runtime schemas)
- Other top-level port-relevant dirs observed: `build.rs` (build script present),
  `docker/`, `Makefile` (`make constitution` gate path), `Cargo.lock` (pinned),
  `tests/`, `assets/`, `experiments/` (one excluded from workspace:
  experiments/minif2f_v4), `spike/` (member 2 lives here), `traces/`, `cases/`,
  `tools/`, `research/`, `routines/`, `rules/`, `incidents/`, `handover/`.

---

## Commands ledger (reproducibility)

```
git log -1 --format='%H %h %ci'
find src -name "*.rs" | xargs wc -l | sort -rn          # LOC by file + total
find src -name "*.rs" | wc -l                            # 226
grep -c '^\[\[bin\]\]' Cargo.toml                        # 1
grep -A2 '^\[\[bin\]\]' Cargo.toml                       # turingos_web block
find src/bin -maxdepth 1 -name "*.rs" | wc -l            # 36 bin targets
find src/bin -mindepth 2 -name "*.rs" | wc -l            # 31 nested modules
find src/bin -name "*.rs" | wc -l                        # 67 total
ls -1 .                                                  # top-level dirs
du -sh frontend ; find frontend -type f | wc -l          # 432K / 41
find frontend -type f | sed 's/.*\.//' | sort | uniq -c  # type breakdown
find scripts -type f | wc -l                             # 74
find docs -type f | wc -l                                # 7
grep -E '^(name|edition|version)' spike/gix_capability/Cargo.toml
```

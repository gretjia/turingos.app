# CLI_ABI Conformance Precheck — turingosv4 main @ 1f00012d

R1.9 port-readiness audit. Prober: CLI_ABI conformance agent, 2026-06-11.
Target clone: `/Users/zephryj/work/.audit-scratch/turingosv4-main` (read-only).
Binary: `target/debug/turingos` (v0.1.0, prebuilt). All probes run from clone root,
read-only/diagnostic subcommands only. Problems recorded, nothing fixed.

Contract under test: the Seven Laws of `turingos.app docs/CLI_ABI.md`.

## 0. Architecture finding (shapes every verdict)

`turingos` is a thin dispatcher (`src/bin/turingos.rs:106-254`, manual argv parsing, no clap).
12 of 29 subcommands are shell-out wrappers via `common::run_external`
(`src/bin/turingos/common.rs:99-154`) that inherit the backend binary's stdout/stderr 1:1.
There is **no shared `--json` parser** in `common.rs` (grep for `--json|"json"`: zero hits).
JSON behavior is therefore per-backend, inconsistent, and in 6 cases the backend
(`lean_market`, defined in `experiments/minif2f_v4/src/bin/lean_market.rs`, NOT part of the
main workspace build) is absent from `target/debug/` — those commands exit 2 with a prose
"backend binary not available" message (live probe F below).

## 1. Subcommand registry (29 entries, src/bin/turingos.rs:106-254)

| # | Subcommand | --json | Evidence |
|---|------------|--------|----------|
| 1 | `init` | N | `cmd_init.rs:447-448` prose stdout ("Scaffold files created:"); no json grep hit |
| 2 | `report run` | PARTIAL | wrapper `cmd_report_run.rs:36` → `gen_run_summary`; backend emits JSON-by-default to stdout (`src/bin/gen_run_summary.rs:59`) but **rejects `--json`** (probe B: exit 2, "unknown arg") |
| 3 | `report wallet` | N | `cmd_report_wallet.rs:45` → `lean_market` (no `--json` in `experiments/minif2f_v4/src/bin/lean_market.rs`, rg exit 1); backend not built (probe F) |
| 4 | `report positions` | N | `cmd_report_positions.rs:50` → `lean_market`; same as #3 |
| 5 | `report bankruptcy` | N | `cmd_report_bankruptcy.rs:51` → `lean_market`; same as #3 |
| 6 | `report markov` | N | `cmd_report_markov.rs:42` → `generate_markov_capsule`; stderr-only messaging, writes capsule file (`src/bin/generate_markov_capsule.rs:200-238`) |
| 7 | `verify chaintape` | PARTIAL | `cmd_verify_chaintape.rs:48` → `verify_chaintape`; pretty-JSON report to stdout by default (`src/bin/verify_chaintape.rs:48-59`, probe E pure JSON exit 0) but **rejects `--json`** (probe C: exit 2) |
| 8 | `verify e2-candidate` | PARTIAL | `cmd_verify_e2_candidate.rs:71` → `real14_e2_candidate_verifier`; JSON verdict to stdout by default or `--json-out <path>` file (`src/bin/real14_e2_candidate_verifier.rs:41-42,93-99`); no `--json` stdout flag |
| 9 | `audit dashboard` | **Y** | `cmd_audit_dashboard.rs:49` → `audit_dashboard`; real `--json` flag parsed at `src/bin/audit_dashboard.rs:98` (`"--json" => json = true`), help at :33 |
| 10 | `audit tape` | PARTIAL | `cmd_audit_tape.rs:44` → `audit_tape`; JSON verdict written to **mandatory `--out` file** (`src/bin/audit_tape.rs:152,268`), stdout gets prose summary line (:275-276) |
| 11 | `audit tamper` | PARTIAL | `cmd_audit_tamper.rs:64` → `audit_tape_tamper`; JSON report to `--out` file (`src/bin/audit_tape_tamper.rs:392-394`), stdout prose "detected N/3" (:398-401) |
| 12 | `preflight` | PARTIAL | `cmd_preflight.rs:64` → `resume_preflight`; bare JSON verdict `{"verdict":"Ok"}` to stdout by default (`src/bin/resume_preflight.rs:55`); no `--json` flag, no envelope |
| 13 | `replay` | N | default mode → `lean_market` (`cmd_replay.rs:72`, backend missing); `--offline` mode prints **mixed prose + JSON** lines: `session_id=...`, `step[N]={json}` (`cmd_replay.rs:125-132`) |
| 14 | `task open` | N | `cmd_task_open.rs:56` → `lean_market`; same as #3 |
| 15 | `task view` | N | `cmd_task_view.rs:40` → `lean_market`; same as #3 |
| 16 | `task tick` | N | `cmd_task_tick.rs:43` → `lean_market`; same as #3 |
| 17 | `config` | N | native; prose stdout `set {key} = {value:?}` (`cmd_config.rs:126`), raw value print (:138) |
| 18 | `agent` | N | native; prose stdout `deployed {id} ({role})` (`cmd_agent.rs:176`), table at :203; doc says hand-rolled serializer, "no external serde_json" (:37) |
| 19 | `batch` | N | native; prose stdout "Created batch scaffold: ..." (`cmd_batch.rs:209-216`) |
| 20 | `export evidence` | N | native; prose stdout `exported {src} -> {out}: N files, M bytes` (`cmd_export_evidence.rs:234-240`) |
| 21 | `render` | PARTIAL | native; `--format text|json` passed through to python renderer (`cmd_render.rs:32,38`); JSON only for UI-IR fixtures, requires python3 on PATH (:161-163) |
| 22 | `welcome` | N | native; prose onboarding status (`cmd_welcome.rs:147-151`) |
| 23 | `llm` | PARTIAL | native; `llm config`/`llm show` are prose (`cmd_llm.rs:372-400`); `llm complete` prints a JSON envelope to stdout always — `CompleteOk`/`CompleteErr {ok:false, error:{kind,detail}}` (`cmd_llm.rs:628-668,1008,1522`); no `schema_version` field |
| 24 | `spec` | N | native; prose stdout "Spec interview complete." (`cmd_spec.rs:375`), progress on stderr (:336). (`schema_version: 1` at :1198/:1518 is a CAS capsule field, not a CLI envelope) |
| 25 | `generate` | N | native; prose/stderr progress (`cmd_generate.rs:488`); JSONL written to side-channel files only (see Law 6) |
| 26 | `spec audit` | N | native; verdict lines on **stderr** incl. `spec audit: FAIL — dangling CID references:` (`cmd_spec_audit.rs:95-102`) |
| 27 | `wizard` | N | native interactive ANSI TUI, Chinese prompts (`cmd_wizard.rs:165-210`); explicitly stateful — help-only per audit rules |
| 28 | `tdma` | N | native LLM driver; help/prose (`cmd_tdma.rs:285-296,370-374`); no stream/json flags (rg exit 1). (`schema_version` at :197 is the LLM tdma-state-update protocol, not CLI output) |
| 29 | `tape-migrate` | N | native; prose/help (`cmd_tape_migrate.rs:71-87`) |

**Tally: 29 subcommands — json Y: 1, PARTIAL: 8, N: 20.**

## 2. Live probe transcripts (verbatim, cwd = clone root)

### Probe A — `target/debug/turingos --help`
exit=0. Starts cleanly, no trust-root panic. stdout = human help listing all 29 subcommands
(prose, expected for --help). stderr empty.

### Probe B — `target/debug/turingos report run --json`
```
exit=2
stdout: (empty)
stderr:
gen_run_summary: unknown arg: --json
usage: gen_run_summary --repo <runtime_repo> --cas <cas> --run-id <id> [--failed-branch-count <n>] [--rollback-count <n>] [--out <path>]
```
Verdict: `--json` REJECTED. Error = untyped prose on stderr. stdout clean. No JSON error object. No panic.

### Probe C — `target/debug/turingos verify chaintape --json`
```
exit=2
stdout: (empty)
stderr:
verify_chaintape: unknown arg: --json
usage: verify_chaintape --repo <runtime_repo_path> --cas <cas_path> [--run-id <id>] [--out <path>]
```
Same shape as B.

### Probe D1 — `target/debug/turingos report run --json --nonexistent-flag-xyz`
```
exit=2
stdout: (empty)
stderr:
gen_run_summary: unknown arg: --json
usage: gen_run_summary --repo <runtime_repo> --cas <cas> --run-id <id> [--failed-branch-count <n>] [--rollback-count <n>] [--out <path>]
```
First unknown arg wins; untyped prose on stderr; exit 2. NOT a typed JSON error, NOT a panic.

### Probe D2 — `target/debug/turingos verify chaintape --repo /nonexistent/repo --cas /nonexistent/cas`
```
exit=2
stdout: (empty)
stderr:
verify_chaintape: bootstrap failed: pinned_pubkeys.json not found at "/nonexistent/repo/pinned_pubkeys.json"
```

### Probe D3 — `target/debug/turingos audit dashboard --repo /nonexistent/repo --cas /nonexistent/cas --json`
```
exit=2
stdout: (empty)
stderr:
audit_dashboard: build failed: verify_chaintape: PinnedPubkeysMissing("/nonexistent/repo/PinnedPubkeysMissing...")
```
Even the ONE command with `--json` emits its errors as prose on stderr, not a JSON error object.

### Probe E — happy path: `target/debug/turingos verify chaintape --repo handover/evidence/tb_6_chaintape_smoke_2026-05-01 --cas handover/evidence/tb_6_chaintape_smoke_2026-05-01/cas`
```
exit=0
stderr: (empty)
stdout (first 22 lines, full output is one JSON object):
{
  "l4_entries": 0,
  "l4e_entries": 1,
  "ledger_root_verified": true,
  "system_signatures_verified": true,
  "state_reconstructed": true,
  "economic_state_reconstructed": true,
  "cas_payloads_retrievable": true,
  "agent_signatures_verified": true,
  "proposal_telemetry_cas_retrievable": true,
  "run_id": "tb6-smoke-2026-05-01",
  "epoch": 1,
  "detail": {
    "final_state_root_hex": "00000000...",
    "final_ledger_root_hex": "00000000...",
    "head_commit_oid_hex": null,
    "l4e_last_hash_hex": "39dc75cb2a34fe16cd1380bfffeae98c601a09dcf9581cc5f115074b3decfd34",
    "replay_failure": null,
    "initial_q_state_loaded_from_disk": false
  }
}
```
stdout IS pure JSON on the happy path — but **NO `schema_version` field**.

### Probe F — `target/debug/turingos report wallet` (lean_market backend missing)
```
exit=2
stdout: (empty)
stderr:
turingos: a required backend binary for this command is not available.
  Resolution paths:
    1. Build all workspace binaries (recommended):
         cargo build --workspace
    ...
```
6 commands (report wallet/positions/bankruptcy, task open/view/tick, replay default mode)
depend on `lean_market`, which lives in the separate `experiments/minif2f_v4` crate and is
not produced by the main workspace build. Note: `cargo build --workspace` as suggested by
the message would NOT build it either (different crate) — the guidance itself is stale.

### Probe G — `target/debug/turingos -V`
exit=0, stdout `turingos 0.1.0`.

## 3. Per-law verdicts

| Law | Verdict | Evidence |
|-----|---------|----------|
| 1. every command supports `--json` | **FAIL** | 1/29 has the flag (`audit_dashboard.rs:98`). Probes B/C: `report run --json` and `verify chaintape --json` exit 2 "unknown arg". 20/29 have no JSON path at all. |
| 2. stdout machine-JSON only | **FAIL (partial islands)** | Happy paths of `verify chaintape` (probe E), `report run`, `preflight`, `verify e2-candidate`, `llm complete` are pure JSON. But init/config/agent/batch/welcome/export/spec/generate print prose to stdout (table refs), and `replay --offline` MIXES prose and JSON on stdout (`cmd_replay.rs:125-132`). |
| 3. stderr diagnostics only | **PARTIAL** | All probed errors land on stderr, stdout stays clean (probes B-D3, F) — good. But `spec audit` emits its business verdict (FAIL + dangling-CID list) on stderr (`cmd_spec_audit.rs:95-102`), and `audit tape`/`audit tamper` put the human verdict summary on stdout while the JSON goes to a file (`audit_tape.rs:275`, `audit_tape_tamper.rs:398`). |
| 4. `schema_version` in every response | **FAIL** | Zero CLI stdout envelopes carry `schema_version`. Probe E output has none; `resume_preflight` prints bare `{"verdict":"Ok"}` (`resume_preflight.rs:11-12,55`). The string `tos.app.cli` appears nowhere in the repo (rg exit 1). The only `schema_version` hits in the CLI are capsule-file payloads (`cmd_spec.rs:1198,1518`) and the LLM tdma-state-update protocol (`cmd_tdma.rs:197`, `cmd_generate.rs:1427`) — different layer. |
| 5. typed JSON error codes | **FAIL** | Probes B/C/D1/D2/D3: every error is untyped prose on stderr + coarse exit 2. No `{"error":{"code":...}}` shape exists. Closest: `llm complete` failure prints `{"ok":false,"error":{"kind":"...","detail":"..."}}` to stdout (`cmd_llm.rs:640-668`) — typed-ish but field is `kind` not `code`, no schema_version, unique to one sub-action. Exit-code taxonomies exist per-backend (0/1/2 documented in `cmd_verify_chaintape.rs:31-35`) but are not JSON-typed. |
| 6. event JSONL stream / receipt polling for long tasks | **PARTIAL** | No `--follow`/`--events`/`--stream`/`--watch` flag on any subcommand (rg over cmd_tdma/cmd_generate/cmd_batch/cmd_task_tick: exit 1). `generate` writes a side-channel per-session `generate_progress.jsonl` designed for web read-endpoint polling (`cmd_generate.rs:1624-1665`) plus opt-in `--emit-transcript` → `generate_transcript.jsonl` (:147). That file IS a usable receipt-polling substrate for the port, but it is not a CLI contract: stdout still blocks until done for `generate`/`llm complete`/`tdma run`. |
| 7. fixture transcripts `fixtures/cli_transcripts/<command>.jsonl` | **FAIL** | No `fixtures/` at repo root (`ls: No such file or directory`); `find -type d -name cli_transcripts` → zero hits. Existing fixture dirs are `tests/fixtures/` (grill prompt eval, liveness, task hygiene) and `experiments/tisr_ui_spike/fixtures/` (UI IR view samples) — neither is a CLI transcript corpus. |

## 4. Headline gaps for the port adapter

1. **No uniform JSON ABI exists.** 1/29 commands accepts `--json`; the adapter whitelist under Law 1 as written would admit only `audit dashboard`. The practical whitelist candidates are the 5 JSON-by-default commands (`report run`, `verify chaintape`, `verify e2-candidate`, `preflight`, `llm complete`) — but each must be admitted on "JSON-by-default" grounds, not flag support, and `--json` must NOT be passed (it hard-fails with exit 2).
2. **No `schema_version` anywhere** → under Law 4 every single response fail-closes at the adapter parse step today. The port needs either an upstream envelope patch or an adapter-side wrapping layer that injects `schema_version` and treats raw backend JSON as payload.
3. **No typed error codes** — all failures are prose-on-stderr + exit 2. Adapter must synthesize error codes from (exit code, stderr regex), which is brittle.
4. **Backend split-brain**: 6 commands (all `task *`, `report wallet/positions/bankruptcy`, `replay` default) shell out to `lean_market` which the main build does not produce; the built-in remediation hint ("cargo build --workspace") would not fix it. Port adapter must either build `experiments/minif2f_v4` or exclude these commands from the whitelist.
5. **`replay --offline` mixes prose and JSON on one stdout stream** — unparseable as JSONL without line-prefix stripping.
6. **No CLI transcript fixtures** — Law 7 corpus must be created from scratch (the probe transcripts in this report can seed it).
7. Positive note: the dispatcher itself is robust — no panics observed in any probe, trust-root checks do not block `--help`/`-V`, stdout/stderr separation is clean on all error paths, and exit codes are consistent (0 ok / 1 indicator-fail / 2 cannot-start, documented at `cmd_verify_chaintape.rs:31-35`).

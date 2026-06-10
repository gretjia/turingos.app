# Critic B — cli_generate port-readiness audit

Module: `src/bin/turingos/cmd_generate.rs` (3099 LOC), anchor main 1f00012d.
Clean context; no other auditor output consulted. Read-only. Advisory only — no verdicts.

## Scored dimensions (1-5)

### 1. boundary_wrappability — 3/5
The intentional public surface is tight: only `pub(crate) fn run` (251), `SHORT_HELP`/`FULL_HELP`
consts (127/131), `pub(crate) struct PolymarketEmitSummary` (2195), and two `pub(crate) fn`
helpers `polymarket_task_id_for_session` (2842) / `find_root_workspace` (2864). All parsing,
LLM, CAS, and chain-emit internals are private (`fn parse_emitted_files` 1501, `fn
chat_with_tdma_bounded` 1144, `fn emit_polymarket_market_for_session` etc.), so a lib facade
could wrap `run` without leaking internals. Penalty: the CLI exposes TWO divergent machine
contracts. The CLI itself emits an ad-hoc `key=value` line to **stdout** — `println!("artifact_bundle_cid={}", bundle_cid)` (854) — while the structured JSON contract (`GenerateResponse`
with `#[serde(skip_serializing_if)]` on `status`/`artifact_bundle_cid`) lives in a *separate*
module `src/web/generate.rs` (116-134), not here. A port consuming "this CLI as an API" must
scrape stdout text lines (854, 1087-1120) plus split CID lines across stdout/stderr (706 stderr
vs 854 stdout) — there is no single typed result object returned from `run_inner`, only
`Result<(), GenError>` (271). Wrappable, but the boundary is string-scraping, not a value.

### 2. error_discipline — 4/5
Strong typed-error spine: `enum GenError` (191) carries semantic variants (`MissingFlag`,
`WorkspaceNotFound`, `NoSpec`, `NoFilesParsed`, `TooManyFiles{found,max}`, `WithFooter`),
implements `Display` (211) and `From<LlmError>`/`From<CapsuleError>` (238/244). `run_inner`
threads `Result<(), GenError>` end-to-end (271-1126); `run` maps it to `ExitCode::from(2)` on
any error (266) and `ExitCode::SUCCESS` on Ok (257) — a single non-zero exit code for all
failure classes. Deductions: (a) panic-on-`unwrap` at 1277 `attempts_inner.into_iter().last().unwrap()`
— guarded by the `is_empty()` early-return at 1269 so currently unreachable, but it is a latent
panic if that guard is ever moved; (b) four `unreachable!()` on `AttemptOutcome::Success` arms
(715, 726, 2091) and two `unreachable!("...returns Work"/"...returns Verify")` (2574, 2681) —
logically sound but they convert an invariant break into a process abort rather than a typed
error; (c) pervasive silent error-swallowing on evidence/UI side paths: `let _ = fs::write(&raw_path...)`
(567), `let _ = fs::write(&path, out)` for the transcript (1083), and `.ok().flatten()` on CID
lookups (368-369, 838-839). Most swallows are deliberately best-effort (progress markers,
transcript) but the port cannot distinguish "evidence write failed" from "succeeded".

### 3. invariant_documentation — 4/5
Unusually well-documented invariants for a CLI handler. The module doc (1-23) states the
Class-1 / no-CAS-write / pure-derivation invariant ("artifacts can be regenerated from the spec
capsule + same model_id + same seed"). KILL-gen-3 reproducibility invariant (prompt_hash must
match the FINAL accepted attempt) is documented at 1139-1143 and re-asserted at 520-522. The
append-only / one-directional UI-evidence invariant for `generate_progress.jsonl` is spelled
out at 1626-1640 ("economic / replay / market-state logic NEVER reads it"). The Polymarket
durable-chain invariant (no ephemeral ledger) is documented at 62-76. Some invariants are
ASSERTED in tests not just narrated: `DEFAULT_MARKET_SEED_MICRO == DEFAULT_BOUNTY_MICRO / 10`
is both commented (120) and asserted (`polymarket_constants_satisfy_invariants`, 2941-2948).
Gap: the determinism claim ("same seed → same artifact") is documented but `model_seed: None`
is hardcoded in the capsule (656) and `Some(0.2)` temperature is passed (475, 1997), so the
"deterministic derivation" invariant is documentary, not enforced — no assertion binds it.

### 4. test_depth — 4/5
Real golden assertions, not tautologies. In-module `#[cfg(test)]` (2930-3098): the system-prompt
gates assert exact parser-compatible tokens — `prompt.contains("tdma-state-update/v1")` and a
NEGATIVE assertion `!prompt.contains("\"state_update\":{")` to forbid the wrapper shape (3025,
3056), plus a positional check that "before/first" appears within 300 chars of "state_update"
(3081-3097). `find_root_workspace` has happy + walk-up + none-within-depth cases (2951-2980).
Integration surface is broad (28 test files reference the module). `cli_web_generate_response_shape_stable.rs`
asserts EXACT JSON field presence/absence for both None and Some (`assert!(val.get("status").is_none())`
36-49) — true golden. `failed_generate_cids_after_error_message.rs` (193 LOC) spins a real
mock 400 server and asserts (i) `stderr.contains("[failed run]")`, (ii) `!stdout.contains("[failed run]")`,
(iii) error message appears BEFORE the CID lines via `find` index comparison (153-160), and
(iv) `!stdout.contains("artifact_bundle_cid=")` on early 4xx (188-191) — these test the actual
stdout/stderr contract a port depends on. Deduction: the file-write traversal defense
(`sanitize_relative_path`) and `parse_emitted_files` fence-parsing have no visible direct unit
test in the in-module block; coverage of the parser's malformed-fence branches is unproven here.

### 5. concurrency_safety — 4/5
Blocking points are explicit and the threading model is conservative. The only async is a
**single-threaded** tokio runtime: `Builder::new_current_thread().enable_all().build()` (2345)
with `rt.block_on(async move { ... })` (2350) — no work-stealing, no cross-thread Send/Sync
surprises inside the module. Shared chain state is accessed through `RwLock` whose poison is
handled as a typed error, not unwrapped: `rejection_writer.read().map_err(|e| format!("...poison: {e}"))?`
(2412-2414). `bundle.sequencer.clone()` / `bundle.rejection_writer.clone()` (2404-2405) are
`Arc`-style handle clones. No raw `thread::spawn`, `Mutex::lock().unwrap()`, or detached
threads in the module (the only spawn in the tree is in a TEST mock server, not production).
The "--n-parallel-workers" fan-out (162-167) is sequential candidate generation, not real
parallelism — `generate_additional_worker_candidate` (1960) is called in a loop, so there is
no data race to reason about. Deduction: the in-text comment at 2698 ("submit is sync about
queue-admission but async about ...") flags a subtle settlement-polling timing dependence
(`POLYMARKET_SETTLEMENT_POLL_BUDGET_MS = 30_000`, 124) that is not asserted anywhere visible.

### 6. dead_code_density — 5/5
Near-zero dead code for a 3099-LOC file. Whole-file scan for `TODO|FIXME|XXX|HACK|allow(dead_code)|allow(unused)`
and commented-out statement blocks returns exactly: one `TODO(genesis_payload)` at 103 (a
documented follow-up to move inline constants to a manifest, scope-justified), one
`#[allow(clippy::too_many_arguments)]` at 1959 (a lint allow, not dead code). No
`#[allow(dead_code)]`, no `unimplemented!`/`todo!` macros, no large commented-out logic blocks.
All `//`-prefixed lines sampled are genuine explanatory comments, not disabled code. The
legacy single-pass path was DELETED rather than `#[cfg]`-gated out (276-289, "legacy single-pass
code path is DELETED outright").

## RiskFindings (JSONL)

{"finding_id":"rsk_dual_output_contract_split","schema_version":"tos.app.riskfinding.v0","severity":"attention","finding":"The port consumes this CLI as an API but there is no single typed result. cmd_generate.rs prints a machine token to STDOUT as ad-hoc text (`println!(\"artifact_bundle_cid={}\", bundle_cid)` at src/bin/turingos/cmd_generate.rs:854) interleaved with human prose (\"Generated N file(s)...\", \"Open the entry file...\" at 1086-1121), while the structured JSON contract GenerateResponse (with skip_serializing_if on status/artifact_bundle_cid) lives in a SEPARATE module src/web/generate.rs:116-134. A consumer must scrape stdout text and additionally split CID lines across streams (generation_attempt_cid goes to STDERR at 706, artifact_bundle_cid to STDOUT at 854). Porting against this requires reproducing the exact print formatting; any wording change silently breaks the consumer.","author":"critic_B"}
{"finding_id":"rsk_guarded_unwrap_latent_panic","schema_version":"tos.app.riskfinding.v0","severity":"info","finding":"src/bin/turingos/cmd_generate.rs:1277 `let (final_hash, final_result) = attempts_inner.into_iter().last().unwrap();` is a panic point currently made safe only by the `if attempts_inner.is_empty() { return ... }` guard immediately above at 1269. The safety is positional, not structural — if the empty-check is ever refactored away or the vector is consumed between the two lines, the CLI aborts the process instead of returning a GenError. A defensive `match last()` would remove the latent abort.","author":"critic_B"}
{"finding_id":"rsk_determinism_invariant_unenforced","schema_version":"tos.app.riskfinding.v0","severity":"attention","finding":"The module doc at src/bin/turingos/cmd_generate.rs:18-23 claims artifacts are a pure derivation reproducible from 'spec capsule CID + model_id + same seed', but model_seed is hardcoded None in the GenerationAttemptCapsule (656) and a non-zero temperature Some(0.2) is passed to canonical_chat_request_bytes (475, 1997). No assertion or gate binds the documented determinism invariant; with temperature>0 and no seed pin, identical inputs can yield different artifacts, so a port that assumes reproducible regeneration (e.g. --from-capsule replay) may observe drift. The invariant is documentary only.","author":"critic_B"}
{"finding_id":"rsk_silent_evidence_write_swallow","schema_version":"tos.app.riskfinding.v0","severity":"info","finding":"Several evidence/diagnostic writes are best-effort with discarded errors: `let _ = fs::write(&raw_path, &result.content)` for the raw LLM response at src/bin/turingos/cmd_generate.rs:567, `let _ = fs::write(&path, out)` for generate_transcript.jsonl at 1083, and `.ok().flatten()` on prior-bundle CID lookups at 838-839. These are intentional (a UI/transcript write failure must not fail the run), but a port that relies on generate_transcript.jsonl or the raw-response artifact existing has no signal when those writes silently fail. Document which artifacts are guaranteed vs best-effort at the API boundary.","author":"critic_B"}
{"finding_id":"rsk_parser_untested_traversal_branch","schema_version":"tos.app.riskfinding.v0","severity":"info","finding":"parse_emitted_files (src/bin/turingos/cmd_generate.rs:1501) returns raw LLM-supplied paths WITHOUT sanitization; the path-traversal defense sanitize_relative_path (1544) is correctly applied only at the write sites (598, 1701). The defense itself (rejecting absolute paths, `..`, root/prefix) has no visible direct unit test in the in-module #[cfg(test)] block (2930-3098), and the fence-parser's malformed-input branches (unterminated fence break at 1517-1519, missing closer) are likewise untested there. The protection is present and structurally sound, but its correctness is unproven by an executable assertion a port could rely on.","author":"critic_B"}

## Summary

cmd_generate.rs is a large but disciplined CLI handler: a well-typed GenError spine threads
Result through run_inner, invariants (KILL-gen-3 prompt-hash, append-only progress evidence,
durable-chain Polymarket, Class-1 no-CAS-write) are documented in-line and several are asserted
in tests, dead code is essentially nil (one scoped TODO, one clippy allow), and concurrency is
conservatively single-threaded with poison handled as typed errors rather than unwrapped. The
test surface is genuinely golden — exact JSON field presence/absence, a real mock-400 server
that pins the stdout-vs-stderr CID ordering, parser-schema negative assertions. The main
port-readiness friction is the boundary shape, not safety: the CLI's machine-readable output is
ad-hoc `key=value` text split across stdout/stderr and interleaved with human prose, while the
typed JSON GenerateResponse lives in a different module (src/web/generate.rs), so a consumer of
"this CLI as an API" must string-scrape rather than receive a value. Secondary concerns are
advisory: a positionally-guarded `.unwrap()` at 1277, a determinism invariant that is documented
but unenforced (temperature 0.2, seed None), and best-effort evidence writes whose failure is
silent. None are correctness defects in the happy or error paths I traced; they are interface and
latent-robustness items the port should pin before treating the CLI as a stable contract.

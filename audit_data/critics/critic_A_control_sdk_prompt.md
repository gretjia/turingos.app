# Critic A — control_sdk_prompt (src/sdk/prompt.rs) — R1.9 port-readiness audit

Repo: /Users/zephryj/work/.audit-scratch/turingosv4-main (anchor main 1f00012d, read-only)
Module: `src/sdk/prompt.rs` (663 LOC: 1 pub fn + 2 private helpers + #[cfg(test)] of 18 tests)
Author: critic_A (clean context; no other auditor output seen)

## Method actually executed

- Full read of src/sdk/prompt.rs (663 lines).
- Caller search: `rg "build_agent_prompt|sdk::prompt|use crate::sdk::prompt"` over src/, tools/, experiments/, tests/, scripts/.
- Panic surface: `rg "unwrap\(|expect\(|panic!|unreachable!"` — hits only at prompt.rs:514, 610 (test-side lock expects).
- Dead-code markers: `rg "TODO|FIXME|allow\(dead_code\)"` — zero hits in the file.
- Lock/spawn surface: `rg "Mutex|RwLock|spawn|thread"` — only test-side ENV_LOCK at prompt.rs:511.
- Integration gates read: tests/constitution_g5_action_menu.rs, tests/constitution_real12_task_market_action.rs, tests/constitution_g3_your_position_prompt.rs:185-239, tests/constitution_g2p_pending_peer_reviews.rs:231-248, tests/constitution_shielding_gate.rs:24-54, tests/constitution_obligation_repair_reconciliation.rs:60-119.
- Liveness fixture: tests/fixtures/liveness/production_module_liveness.toml:503-518.
- prompt_guard.rs header (claimed defense pairing) + repo-wide search for `test_no_pput_in_agent_prompt` and `assert_no_metric_leak` call sites.

## Scores (1-5)

### 1. boundary_wrappability — 3

- Pro: the pub surface is exactly one pure function returning `String` — `pub fn build_agent_prompt(...) -> String` (prompt.rs:48-59); helpers `current_prompt_variant` (prompt.rs:27) and `inject_variant_pre_output` (prompt.rs:338) are private. No internal types leak; trivially callable from a CLI/lib facade.
- Con: the signature is 10 positional parameters, 8 of them `&str` (prompt.rs:48-59) — argument swaps compile silently, and the boundary is frozen by source-text-scanning gates (tests/constitution_g3_your_position_prompt.rs:194-196 asserts `src.contains("your_position: &str")`; tests/constitution_g2p_pending_peer_reviews.rs:243-246 asserts `pending_peer_reviews: &str` exists), i.e. the shape grows one positional string per feature wave (G2P added the 9th, G3 the 10th).
- Con: behavior depends on 4 ambient env vars read inside the function — `TURINGOS_PROMPT_VARIANT` (prompt.rs:28), `TURING_STEP_ONLY` (prompt.rs:192), `TURINGOS_DISABLE_MARKET_TOOLS` (prompt.rs:259), `TURINGOS_REAL12_TASK_MARKET_AFFORDANCE` (prompt.rs:309). A wrapper cannot make output a function of its arguments; env coupling leaks through any facade.

### 2. error_discipline — 4

- The production path is infallible string assembly: zero `unwrap`/`expect`/`panic!` outside `#[cfg(test)]` (only test-lock expects at prompt.rs:514 and prompt.rs:610). Nothing to wrap in `Result`; nothing panics on adversarial input.
- Env read failure handled by explicit default: `std::env::var(...).ok().map(to_lowercase).filter(matches!(... "v0"|"v1"|"v2"|"v3"|"v4")).unwrap_or_else(|| "v0".into())` (prompt.rs:28-33).
- Demerit: that same construct is a silent fallback — a typo'd or whitespace-padded `TURINGOS_PROMPT_VARIANT` silently runs the v0 control arm with no warning channel; the fallback is codified as intended by `unknown_variant_falls_back_to_default` (prompt.rs:600-606) but nothing surfaces the misconfiguration to the experimenter.

### 3. invariant_documentation — 3

- Pro: contracts are written down unusually thoroughly: variant catalogue + "All variants are additive + opt-in; default behavior is bit-identical to the pre-session-#34 prompt" (prompt.rs:24-26); the empty-string-suppresses-block contract is documented at prompt.rs:44-47, 126-128, 144-145, 161-162 and asserted (prompt.rs:466-476 `test_empty_econ_position_suppresses_block`; tests/constitution_g3_your_position_prompt.rs:232-238).
- Con: the "bit-identical" claim (prompt.rs:25-26) is never asserted at that strength — coverage is substring-based (`v0_default_lists_legacy_tools`, prompt.rs:524-534), no byte-exact golden snapshot exists.
- Con: stale invariant claims. prompt.rs:396-399 states "The B5 conformance test `test_no_pput_in_agent_prompt` scans this file specifically" — no test by that name exists anywhere under tests/ or src/ in this tree (only comments at prompt.rs:397 and prompt_guard.rs:6,9,17 name it). The doc at prompt.rs:42-44 (and src/sdk/mod.rs:41, src/sdk/market_context.rs:10) names the caller as "evaluator.rs", which does not exist under src/.
- Con: v3 variant text bakes in "1 of 200 budgeted attempts" (prompt.rs:356) — a stated LAW not derived from or asserted against any actual budget configuration.

### 4. test_depth — 4

- 18 in-module tests + 4 dedicated integration gate files actually read. Real negative assertions, not tautologies:
  - exact truncation boundary: `test_prompt_truncates_errors_to_3` asserts "error 2" present AND "error 3" absent (prompt.rs:479-485);
  - suppression negatives: prompt.rs:466-476; tests/constitution_g3_your_position_prompt.rs:232-238;
  - full variant matrix incl. unknown-variant fallback (prompt.rs:600-606) and market-tools opt-out both states (prompt.rs:621-642);
  - integration: 8-tool action-menu enumeration (tests/constitution_g5_action_menu.rs:8-23); REAL-12 affordance opt-in with anti-coercion negatives `!contains("must trade")` (tests/constitution_real12_task_market_action.rs:101-120).
- Con: the `TURING_STEP_ONLY=1` branch (prompt.rs:192-224, ~33 lines emitting a distinct step/verify_peer schema) has zero coverage — `rg TURING_STEP_ONLY` over tests/, src/, scripts/ matches only prompt.rs itself.
- Con: all assertions are substring checks; no golden byte-exact prompt despite the documented bit-identical default contract (prompt.rs:25-26).

### 5. concurrency_safety — 3

- Production: stateless pure function, no locks, no spawns, trivially Send/Sync — but it reads 4 process-global env vars per call (prompt.rs:28, 192, 259, 309), so output is racy against concurrent `set_var` and nondeterministic across env mutation mid-run.
- Tests show real awareness: the comment at prompt.rs:504-506 explicitly flags `set_var`/`remove_var` as "NOT thread-safe under cargo test" and serializes variant tests through `static ENV_LOCK: Mutex<()>` (prompt.rs:511).
- Con (a): the parent-module tests (prompt.rs:405-501) call `build_agent_prompt` WITHOUT taking ENV_LOCK while variant tests mutate `TURINGOS_PROMPT_VARIANT` under it — under default parallel test threads a parent test can observe a variant env mid-flight (latent flake; today's assertions happen not to collide with variant text).
- Con (b): `with_variant` (prompt.rs:513-521) runs `body();` then `remove_var` with no drop guard — a panicking body skips cleanup, leaks the env var, and poisons ENV_LOCK, cascading `.expect("env lock")` panics (prompt.rs:514, 610) across remaining variant tests.

### 6. dead_code_density — 3

- In-file hygiene is excellent: zero `TODO`/`FIXME`/`allow(dead_code)` and zero commented-out code blocks (rg over the file exits 1). Score for the file body alone would be 5.
- Con (module liveness): `sdk::prompt::build_agent_prompt` has NO production caller — `rg "sdk::prompt|prompt::build_agent_prompt|use super::prompt"` over src/, tools/, experiments/ returns nothing; only constitution-gate tests and its own unit tests invoke it. The liveness fixture classifies its group `agent_prompt_model_boundary` as `status = "historical_real_world_candidate"` (tests/fixtures/liveness/production_module_liveness.toml:504-506). OBLIGATIONS.md:47 records that a deletion PR ("wave1-pr-e-build-agent-prompt-retire") was superseded and the surface retained because gates cover it — retention rationale is test coverage, not production wiring.
- Con: an unrelated private `fn build_agent_prompt(event_task_id: &str)` exists at src/bin/market_external_agent_current_kernel.rs:423 — name shadowing of a pub SDK symbol invites caller confusion during a port.

## RiskFindings (advisory channel, JSONL)

{"finding_id":"rsk_prompt_builder_no_production_caller","schema_version":"tos.app.riskfinding.v0","severity":"attention","finding":"src/sdk/prompt.rs:48 pub fn build_agent_prompt has zero production call sites: rg over src/, tools/, experiments/ for sdk::prompt imports or qualified calls returns nothing; only constitution-gate tests (tests/constitution_g5_action_menu.rs:8, tests/constitution_real12_task_market_action.rs:87, tests/constitution_g3_your_position_prompt.rs:213) and its own #[cfg(test)] block invoke it. Doc comments name a consumer 'evaluator.rs' (src/sdk/prompt.rs:43-44, src/sdk/mod.rs:41, src/sdk/market_context.rs:10) that does not exist under src/. tests/fixtures/liveness/production_module_liveness.toml:504-506 classifies the owning group agent_prompt_model_boundary as status=historical_real_world_candidate, and OBLIGATIONS.md:47 records that a retirement PR was superseded with the surface retained because gates cover it. Port-readiness implication: porting this module ports a test-pinned but production-orphaned prompt surface; the wrapper design should decide explicitly whether this is the canonical prompt builder or a museum piece.","author":"critic_A"}
{"finding_id":"rsk_pput_static_gate_missing","schema_version":"tos.app.riskfinding.v0","severity":"attention","finding":"src/sdk/prompt.rs:396-399 documents a defense-in-depth pairing: a STATIC B5 conformance test named test_no_pput_in_agent_prompt that 'scans this file specifically', plus the RUNTIME gate in src/sdk/prompt_guard.rs. Neither layer is wired at anchor main: no test named test_no_pput_in_agent_prompt (or any pput scan of prompt.rs) exists under tests/ or src/ — the name appears only in comments (src/sdk/prompt.rs:397, src/sdk/prompt_guard.rs:6,9,17) — and prompt_guard.rs:50 assert_no_metric_leak has no call site outside its own module, despite prompt_guard.rs:19-23 claiming it scans 'the FINAL ASSEMBLED prompt at every LLM-call boundary'. The Goodhart/PPUT-context-leak shield documented in the module is therefore currently documentation-only on both layers. (The separate stderr-shielding gate tests/constitution_shielding_gate.rs:41-53 does still scan prompt.rs and passes on substance.)","author":"critic_A"}
{"finding_id":"rsk_step_only_branch_untested","schema_version":"tos.app.riskfinding.v0","severity":"attention","finding":"The TURING_STEP_ONLY=1 branch of build_agent_prompt (src/sdk/prompt.rs:192-224) emits a distinct ~33-line step/verify_peer schema block, but rg for TURING_STEP_ONLY across tests/, src/, and scripts/ matches only prompt.rs itself: no test sets it, no script exports it, no other source reads it; references exist only in April-2026 handover documents. The branch is both untested and apparently unreachable by any in-repo runner — during a port it is impossible to distinguish load-bearing behavior from fossil without external evidence.","author":"critic_A"}
{"finding_id":"rsk_variant_env_silent_fallback","schema_version":"tos.app.riskfinding.v0","severity":"info","finding":"current_prompt_variant (src/sdk/prompt.rs:27-33) lowercases TURINGOS_PROMPT_VARIANT but does not trim, and silently maps any value outside {v0..v4} to the v0 control arm via filter + unwrap_or_else. A typo or trailing-whitespace misconfiguration in an experiment launch silently runs control instead of treatment with no log or warning; prompt.rs:600-606 (unknown_variant_falls_back_to_default) codifies the fallback as intended but nothing surfaces the misconfiguration. Classic silent-fallback-arm trap for experiment harnesses.","author":"critic_A"}
{"finding_id":"rsk_env_test_race_and_lock_poison","schema_version":"tos.app.riskfinding.v0","severity":"info","finding":"In src/sdk/prompt.rs the parent-module unit tests (lines 405-501) call build_agent_prompt without acquiring ENV_LOCK, while variant_tests (lines 507-662) mutate TURINGOS_PROMPT_VARIANT under that lock (static Mutex at line 511); under cargo's default parallel test threads a parent test can observe a variant env var mid-flight — a latent flake that today's substring assertions happen to dodge. Additionally with_variant (lines 513-521) and with_market_tools_env (lines 609-618) call body() with no drop guard: a panicking assertion skips remove_var (env leaks to subsequent tests) and poisons ENV_LOCK, cascading .expect(\"env lock\") panics at lines 514/610 across the remaining serialized tests, masking the root failure.","author":"critic_A"}
{"finding_id":"rsk_hardcoded_budget_and_truncation_params","schema_version":"tos.app.riskfinding.v0","severity":"info","finding":"src/sdk/prompt.rs hardcodes behavior parameters into prompt text: v3 variant LAW 1 asserts '1 of 200 budgeted attempts' (line 356) with no derivation from actual run budget configuration — if the configured budget differs, the prompt states a false law to the agent; truncation counts take(3)/take(5)/take(3) at lines 100, 112, 384 are likewise inline magic numbers. CLAUDE.md §4 lists 'hardcoded behavior parameter' as forbidden; these are prompt-layer parameters where drift between stated and actual values is a name-lie class risk.","author":"critic_A"}
{"finding_id":"rsk_bin_shadow_function_name","schema_version":"tos.app.riskfinding.v0","severity":"info","finding":"src/bin/market_external_agent_current_kernel.rs:423 defines a private fn build_agent_prompt(event_task_id: &str) unrelated to the pub SDK symbol of the same name in src/sdk/prompt.rs:48; the binary even hashes its own prompt (line 478 sha256_hex(build_agent_prompt(...))). Identical names for two different prompt builders in one crate invites wrong-symbol citation in audits and wrong-target edits during a port; any facade naming should disambiguate.","author":"critic_A"}

## Summary

src/sdk/prompt.rs is a clean, panic-free, well-commented pure string assembler whose unit and constitution-gate tests are genuinely better than average (exact truncation boundaries, suppression negatives, full variant matrix with an unknown-variant fallback case). Its problems are all boundary- and liveness-shaped rather than logic-shaped: the single pub function takes 10 positional mostly-&str parameters whose shape is pinned by source-text-grep gates, its behavior is steered by four ambient env vars that leak through any facade (one of which, TURING_STEP_ONLY, gates a ~33-line schema branch with zero coverage anywhere in the tree), and — most significant for port-readiness — the function has no production caller at all: doc comments cite a nonexistent evaluator.rs, the liveness fixture files it as a historical real-world candidate, and OBLIGATIONS.md shows a retirement PR that was superseded in favor of retention-by-gate-coverage. The documented PPUT defense-in-depth (static B5 test + runtime guard at LLM boundary) is unwired on both layers at this anchor. None of this blocks wrapping it — it blocks deciding what wrapping it means.

Scores: boundary_wrappability=3, error_discipline=4, invariant_documentation=3, test_depth=4, concurrency_safety=3, dead_code_density=3.

# Critic A — cli_generate (src/bin/turingos/cmd_generate.rs, ~3099 LOC)

R1.9 port-readiness audit, repo anchor main 1f00012d, scratch clone
/Users/zephryj/work/.audit-scratch/turingosv4-main. All file:line references below are
from that clone; the module path is `src/bin/turingos/cmd_generate.rs` unless stated.
Clean-context: no other auditor output was read.

## Scored dimensions

### 1. boundary_wrappability — 3

- The pub surface is tightly disciplined: every exported item is `pub(crate)` —
  `SHORT_HELP` (:127), `FULL_HELP` (:131), `run` (:251), `PolymarketEmitSummary` (:2195),
  `polymarket_task_id_for_session` (:2842), `find_root_workspace` (:2864). Nothing leaks
  outside the bin crate; the binary's dispatch table registers `cmd_generate::SHORT_HELP`
  / `cmd_generate::run` in `src/bin/turingos.rs`, and `cmd_wizard.rs:264` reuses it
  in-process ("cmd_generate::run expects only flags").
- BUT because the module lives in the bin target, the lib-side web code cannot import it
  and instead hand-mirrors contracts: `src/web/market_view.rs:183-185` — "Mirror
  cmd_generate.rs `polymarket_task_id_for_session`" with a literal
  `format!("pr1-{session_id}")`; `src/web/generate.rs` shells out to the CLI
  (`SanitizedCommand` + `spawn_blocking`, src/web/generate.rs:334-344). The port will
  inherit this subprocess-only wrapping plus the duplicated `pr1-` constant.
- IO channels are hardcoded (`println!`/`eprintln!` throughout, e.g. :854, :1086-1121);
  no injectable writer, no `--json` output mode; `run_inner` is a ~850-line monolith
  (:271-1126) entangling arg parsing, LLM calls, CAS writes and chain admission. Facade
  wrapping is possible only at the process boundary.

### 2. error_discipline — 4

- `Result` is threaded end-to-end: `run_inner(args) -> Result<(), GenError>` (:271) with
  a semantic `GenError` enum (`MissingFlag`, `WorkspaceNotFound`, `NoSpec`, `Llm`,
  `Capsule`, `NoFilesParsed`, `TooManyFiles`, `WithFooter`, :191-209), `Display` impls
  (:211-236) and `From<LlmError>`/`From<CapsuleError>` (:238-248). Every failure class
  additionally lands as a typed CAS `GenerateRejectionCapsule` with a `RejectClass`
  and a `retryable` bit (:730-743, :873-886).
- Panic surface is minimal and guarded: the only production `unwrap()` at :1277 is
  preceded by an `is_empty()` early-return at :1269-1271; `unreachable!()` at :715/:726/
  :2091 sits in match arms statically excluded by the `outcome != Success` guard
  (:709, :2085); :2574/:2681 carry contract messages ("make_real_worktx_signed_by
  returns Work"). `tests/user_error_does_not_leak_panic.rs:51-63` gates that user errors
  never print "panicked at"/backtraces.
- Deductions: `GenError::Io(String)` is a stringly catch-all reused for non-IO failures
  (arg validation :302/:324/:327-330, sequencer admission :1036-1038, candidate test
  pipeline :2131); the entire polymarket layer returns `Result<_, String>`
  (`emit_polymarket_market_for_session` :2293-2298, `write_polymarket_proposal_telemetry`
  :2220-2228); and `run()` collapses every error to exit code 2 (:266) — the rich
  internal taxonomy is invisible to an exit-code-reading consumer.

### 3. invariant_documentation — 4

- Written invariants are unusually thorough: module header documents the Class-1
  posture and the "pure derivation, no Class-3 evidence anchor" regeneration invariant
  (:18-23); KILL-gen-3 pins "prompt_hash records the canonical bytes of the FINAL
  accepted attempt" (:520-522 and doc :1139-1143); the `pr1-` task-id prefix is
  declared FROZEN because it is chain-resident (:2838-2841); `append_generate_progress`
  documents the derived-evidence contract — wall-clock excluded from canonical facts,
  "economic / replay / market-state logic NEVER reads it", best-effort writes "must
  NEVER fail the generate run" (:1628-1640); the pre-computed state-root sequence
  explains the async-apply race it avoids (:2489-2495); historical finalized markets are
  explicitly "not retroactively rewritten" (:2467-2470).
- Assertions exist for some of these: `polymarket_constants_satisfy_invariants` asserts
  `MarketSeed = bounty/10` and stake positivity (:2941-2948);
  `polymarket_task_id_for_session_is_stable` golden-pins the frozen prefix
  (:2934-2938); the two `blackbox_system_prompt` tests (:3020-3098) assert the
  parser-contract coupling (schema_version/status/action token presence + "before code
  body" anchor scan).
- Deduction: several documented invariants have no assertion anywhere in the module —
  e.g. the append-only nature of `generate_progress.jsonl` (:1660-1667) and the implicit
  invariant that the judge's parser and the writer's parser accept the same bodies (see
  finding rsk_dual_fence_parser_drift) are prose-only.

### 4. test_depth — 4

- In-module tests (9, :2930-3099) are real, not tautological: golden exact values for
  task-id derivation (:2936-2937); arithmetic invariants on constants (:2943-2947);
  `find_root_workspace` covered happy/walk-up/negative (:2950-2980);
  `polymarket_workers_for_preseed` covered for full roster and degraded old-workspace
  (:2982-3007); prompt tests assert exact parser-facing strings and the absence of the
  known-bad wrapper shape `"state_update":{` (:3055-3061).
- Integration depth is strong: `tests/failed_generate_emits_error_before_cids.rs`
  spins a real mock 401 HTTP server, captures stdout and stderr separately, and asserts
  line-INDEX ordering of error-before-CID plus "stdout must NOT contain [failed run]"
  (:131-186 of that file); `tests/generated_artifact_has_bundle_manifest.rs:83-92`
  pins the `artifact_bundle_cid=` stdout key=value contract;
  `tests/generate_noparseable_error_includes_retry_hint.rs` asserts non-zero exit +
  retry hint; `tests/cli_web_generate_response_shape_stable.rs:34-49` golden-pins the
  web JSON shape including field ABSENCE (`art.get("cid").is_none()`).
- Deductions: the two security/correctness-critical private helpers in THIS module —
  `parse_emitted_files` (:1501) and `sanitize_relative_path` (:1544) — have zero direct
  unit tests; traversal/parsing tests exist only against the parallel implementation in
  `src/judges/generate_judge.rs` (its in-file tests at :263-275 cover
  `../../etc/passwd`) and against the web file-serve layer
  (`tests/artifact_bundle_file_serve_rejects_traversal.rs`). No worker-roster error-case
  test (preseed without worker-alpha → Err, :2898-2901 untested).

### 5. concurrency_safety — 4

- The module spawns no threads and holds no module-level locks (rg for
  `Mutex|RwLock|spawn|thread::|channel` inside the file: zero hits). Async is confined
  to one `tokio::runtime::Builder::new_current_thread()` + `block_on`
  (:2345-2350); the blocking LLM call is named `chat_complete_blocking` (:1220).
- Lock interactions with shared sequencer state are explicit and poison-aware:
  `rejection_writer.read().map_err(|e| format!("rejection_writer pre-read poison: {e}"))`
  (:2412-2415) and the post-read twin (:2805-2808); `seq.set_agent_pubkeys(Arc::new(...))`
  maps the already-set case to an error (:2693-2694). The FIFO submit + pre-computed
  `*_accept_state_root` pattern is documented as the fix for "the driver's async apply
  would race the next q_snapshot() read" (:2489-2495), and `bundle.shutdown()` drains
  before the post-drain snapshot (:2737-2750).
- `RefCell<Vec<(String, ChatResult)>>` for attempt capture (:1201, :1235) is safe under
  the current single-threaded closure usage but is an implicit !Sync constraint with no
  comment stating it.
- Deduction: no cross-process exclusion. Two concurrent `turingos generate` runs on one
  workspace share `<root>/runtime_repo` + `cas` (:2366-2372) with only logical dedupe
  (existing-market check :2421-2487, rejection-count snapshot :2410-2416) — no flock.
  Whether outer layers serialize per session is UNVERIFIED from this module.

### 6. dead_code_density — 4

- Very low for 3099 LOC: exactly one TODO, and it carries a rationale and a follow-up
  plan ("TODO(genesis_payload): move these defaults to genesis_payload.toml ... For this
  PR they stay inline so the diff stays surgical", :103-106); exactly one allow
  attribute (`#[allow(clippy::too_many_arguments)]`, :1959); no commented-out code
  blocks found (heavy comments are documentation, not disabled code).
- Deductions: `let _ = format_test_run_summary(&test_results);` (:2148) computes and
  discards the candidate-path test summary — dead call, likely a lost `eprintln!`
  (the primary path prints the same summary at :870); two silent best-effort writes
  `let _ = fs::write(...)` (:567 raw response, :1083 the user-requested
  `--emit-transcript` output) of which only the progress-marker swallow is documented
  (:1639-1640).

## RiskFindings (advisory channel)

{"finding_id":"rsk_dual_fence_parser_drift","schema_version":"tos.app.riskfinding.v0","severity":"risk","finding":"Two independent implementations parse the same LLM output format and check path safety, and they already diverge. Writer side: src/bin/turingos/cmd_generate.rs:1501 parse_emitted_files accepts lowercase '### file:' (:1509) and strips backticks around the path (:1511), and sanitize_relative_path (:1544) checks std::path Components (ParentDir/RootDir/Prefix). Judge side: src/judges/generate_judge.rs:83 parse_file_fences is case-sensitive '### File:' only and does not strip backticks, and path_unsafe (:122) additionally rejects empty segments and backslash-separated '..' which the writer's Unix Component walk treats as one ordinary filename. In the default TDMA path the judge gates acceptance inside the retry loop, then cmd_generate re-parses the accepted body with the looser parser at materialization (:564 and :782) — a judge-accepted body can produce a different file set (or paths) at write time. Only the judge's parser has unit tests (generate_judge.rs tests :235-301 incl. ../../etc/passwd); parse_emitted_files and sanitize_relative_path have zero direct tests. For the port, this is a single-source-of-truth break on the artifact admission boundary.","author":"critic_A"}
{"finding_id":"rsk_unknown_flags_silently_ignored","schema_version":"tos.app.riskfinding.v0","severity":"attention","finding":"The argument loop in src/bin/turingos/cmd_generate.rs ends with a silent catch-all '_ => {}' (:338): any unrecognized flag — a typo, a removed flag, or a future flag passed by a newer caller — is ignored without error, and its value token is likewise skipped as another unknown arg. A port consuming this CLI as an API gets successful-looking runs with silently dropped options (e.g. a misspelled --max-files leaves the default 20 in force). There is no test pinning rejection of unknown flags.","author":"critic_A"}
{"finding_id":"rsk_single_exit_code_collapses_error_taxonomy","schema_version":"tos.app.riskfinding.v0","severity":"attention","finding":"src/bin/turingos/cmd_generate.rs run() maps every failure to ExitCode::from(2) (:266) while the module internally distinguishes MissingFlag/WorkspaceNotFound/NoSpec/Llm/NoFilesParsed/TooManyFiles (:191-209) and a RejectClass taxonomy with a retryable bit (:730-743). A CLI-as-API consumer cannot branch on exit code between 'retry the LLM' (transient, retryable=true) and 'fix your workspace' (fatal); the typed information is only recoverable by reading CAS rejection capsules or scraping stderr prose. Machine-readable keys are also split across streams: artifact_bundle_cid= goes to stdout (:854) but generation_attempt_cid= and test_run_cid= go to stderr even on success (:706, :868), per the X1/B3 comment (:702-704). There is no --json mode.","author":"critic_A"}
{"finding_id":"rsk_genesis_constitution_hash_cwd_dependent","schema_version":"tos.app.riskfinding.v0","severity":"attention","finding":"When the polymarket flow creates a missing genesis_report.json, src/bin/turingos/cmd_generate.rs:2377-2381 resolves constitution.md from std::env::current_dir() ('.../constitution.md'), not from the workspace root or a pinned location. GenesisReport::hash_constitution_md (src/runtime/genesis_report.rs:217-222) returns None when the file is unreadable, so a generate invoked from any CWD that lacks constitution.md (the web server's CWD, a port calling the binary from elsewhere) silently writes constitution_hash=None into the workspace's genesis report. The hash anchor of the report is therefore invocation-CWD-dependent rather than workspace-deterministic.","author":"critic_A"}
{"finding_id":"rsk_duplicated_bundle_entry_construction","schema_version":"tos.app.riskfinding.v0","severity":"info","finding":"Artifact-bundle entry construction (sha256 hashing, mime guess, Entrypoint/Source/Asset role classification, CAS put) is implemented twice in src/bin/turingos/cmd_generate.rs: inline in run_inner for the primary worker (:793-834) and again in write_artifact_bundle_for_candidate for beta/gamma candidates (:1700-1738). The two copies also differ behaviorally by design (primary writes files to <workspace>/artifacts/ at :594-624; candidates are CAS-only). A change to role rules or hashing in one path can drift from the other with no test that compares them.","author":"critic_A"}
{"finding_id":"rsk_discarded_test_summary_in_candidate_path","schema_version":"tos.app.riskfinding.v0","severity":"info","finding":"src/bin/turingos/cmd_generate.rs:2148 in the failed-candidate branch computes and immediately discards the human-readable test summary: 'let _ = format_test_run_summary(&test_results);'. The primary path prints the same summary to stderr (:870, comment 'B4: print human-readable test summary'). Worker-beta/gamma candidates that fail spec-derived tests therefore leave no visible test detail in CLI output — the call is dead code that looks like a lost eprintln.","author":"critic_A"}
{"finding_id":"rsk_no_cross_process_workspace_lock","schema_version":"tos.app.riskfinding.v0","severity":"info","finding":"emit_polymarket_market_for_session in src/bin/turingos/cmd_generate.rs resumes the shared root chain (<root>/runtime_repo + cas, :2366-2374, resume_existing_chain: true) and dedupes logically via the existing-market check (:2421-2487) and a pre/post rejection-count snapshot (:2410-2416), but takes no file lock. Two concurrent `turingos generate` processes on the same workspace would interleave sequencer admissions and CAS writes; generate_progress.jsonl appends from both would also interleave (:1660-1667). Whether the web layer serializes invocations per session is UNVERIFIED from this module.","author":"critic_A"}
{"finding_id":"rsk_transcript_flag_overwrites_and_swallows_errors","schema_version":"tos.app.riskfinding.v0","severity":"info","finding":"The user-requested --emit-transcript output in src/bin/turingos/cmd_generate.rs:1080-1083 is written with 'let _ = fs::write(&path, out);' — a failure to persist an explicitly requested artifact is silent (unlike the documented best-effort progress markers at :1639-1640, this swallow has no rationale comment). fs::write also truncates, so generate_transcript.jsonl — a name implying an append-only log — retains only the latest attempt; a retried session clobbers the prior transcript.","author":"critic_A"}
{"finding_id":"rsk_session_id_fallback_collision","schema_version":"tos.app.riskfinding.v0","severity":"info","finding":"Session-id derivation in src/bin/turingos/cmd_generate.rs:404-416 only treats the workspace as a session when its parent directory is literally named 'sessions'; otherwise (and for non-UTF8 dir names, via unwrap_or(\"default\") at :412) the session_id silently becomes 'default'. All direct-CLI invocations on arbitrary workspace paths share the 'default' session namespace for retry_index chaining (:419-445), tape-relay feedback (:451) and the frozen chain task_id 'pr1-default' (:2842-2844) — distinct logical runs in one root workspace can therefore cross-contaminate retry lineage and market identity.","author":"critic_A"}

## Summary

cmd_generate.rs is the best-documented large module I have audited in this repo: the
Class-1 evidence posture, the KILL-gen-3 final-prompt-hash invariant, the frozen `pr1-`
task-id prefix and the derived-evidence progress contract are all written down at the
point of use and several are golden-tested in-module; error handling is genuinely
Result-threaded with a typed GenError plus CAS-resident RejectClass capsules, and the
panic surface is four guarded unreachable!() arms and one length-guarded unwrap. The
port-readiness weaknesses are concentrated at the boundary, exactly where the port will
consume it: a single undifferentiated exit code 2, machine keys split across
stdout/stderr with no JSON mode, silently ignored unknown flags, and — because the
module is bin-crate pub(crate) — lib-side web code that hand-mirrors the `pr1-` contract
instead of importing it. The one finding I rate `risk` is the dual fence-parser /
path-safety implementation split between the TDMA judge and the writer: admission and
materialization are decided by different, already-divergent parsers, and the writer's
copy (including its path-traversal sanitizer) has no direct tests. Dead code is nearly
absent; concurrency discipline inside the process is explicit and poison-aware, with
cross-process workspace locking the only open gap.

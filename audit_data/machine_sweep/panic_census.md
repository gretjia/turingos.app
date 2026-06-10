# Panic-Surface Census — turingosv4 (R1.9 port-readiness audit, runbook §2)

- Audit target: /Users/zephryj/work/.audit-scratch/turingosv4-main @ anchor commit 1f00012d5326d08f0e6ffe05f6ecec6a391c4896 (main)
- Generated: 2026-06-11 01:21:45 CST
- Patterns: `.unwrap()` | `.expect(` | `panic!(` | `todo!(` | `unimplemented!(`
- Tool note: `rg` is NOT installed on this machine; `grep` here is **ugrep** (PCRE via -P). All counts are **matching lines** (same semantics as `rg -c`).

## Totals

```
$ grep -rcP '\.unwrap\(\)|\.expect\(|panic!\(|todo!\(|unimplemented!\(' --include='*.rs' src/   | awk -F: '{s+=$NF} END {print s}'
src/ raw total (incl. cfg(test) mods inside src): 1235
$ grep -rcP '...same pattern...' --include='*.rs' tests/ | awk -F: '{s+=$NF} END {print s}'
tests/ total: 5924
```

| scope | matching lines |
|---|---|
| src/ implementation only (cfg(test)-gated modules excluded) | 112 |
| src/ inside #[cfg(test)] / #[cfg(all(feature="web", test))] modules | 1123 |
| src/ raw total | 1235 |
| tests/ dir total | 5924 |

**Headline: only 112 of 1235 src/ panic-pattern lines are real implementation code; 91% of the src/ hits live in cfg(test) unit-test modules embedded in src files. tests/ adds 5924 more (expected, idiomatic).**

## Per-file table — src/ raw counts (sorted desc)

Command:
```
grep -rcP '\.unwrap\(\)|\.expect\(|panic!\(|todo!\(|unimplemented!\(' --include='*.rs' src/ | grep -v ':0$' | sort -t: -k2 -rn
```

```
src/bottom_white/cas/store.rs:188
src/state/sequencer.rs:166
src/state/typed_tx.rs:43
src/runtime/evidence_capsule.rs:42
src/bottom_white/ledger/transition_ledger.rs:42
src/runtime/markov_capsule.rs:33
src/runtime/agent_keypairs.rs:32
src/economy/money.rs:30
src/economy/ledger.rs:28
src/boot.rs:25
src/ledger.rs:24
src/runtime/agent_keystore.rs:22
src/economy/escrow_vault.rs:22
src/top_white/predicates/registry.rs:21
src/runtime/attempt_telemetry.rs:21
src/runtime/agent_audit_trail.rs:21
src/runtime/autopsy_capsule.rs:19
src/web/spec.rs:18
src/runtime/embedded_prompts.rs:17
src/bus.rs:17
src/runtime/proposal_telemetry.rs:16
src/runtime/mod.rs:16
src/runtime/bootstrap.rs:16
src/runtime/batch_orchestrator.rs:15
src/runtime/chain_derived_run_facts.rs:14
src/runtime/peer_verify_coverage.rs:13
src/runtime/adapter.rs:13
src/bin/turingos/cmd_generate.rs:13
src/state/q_state.rs:12
src/runtime/spec_synthesis.rs:12
src/runtime/genesis_report.rs:11
src/runtime/benchmark_manifest.rs:11
src/git_tape_ledger.rs:11
src/bottom_white/tools/registry.rs:11
src/state/price_index.rs:10
src/runtime/aggregate_report.rs:10
src/runtime/wilson_ci.rs:9
src/runtime/verification_result.rs:9
src/runtime/spec_capsule.rs:9
src/runtime/audit_assertions.rs:9
src/runtime/prompt_capsule.rs:7
src/economy/monetary_invariant.rs:7
src/bottom_white/cas/schema.rs:7
src/web/session_snapshot.rs:6
src/tdma_runner.rs:6
src/state_update.rs:6
src/kernel.rs:6
src/bottom_white/ledger/system_keypair.rs:6
src/bin/tb_18r_compute_invariant.rs:6
src/state/router_quote.rs:5
src/runtime/run_summary.rs:5
src/runtime/market_decision_trace_summary.rs:5
src/bottom_white/ledger/rejection_evidence.rs:5
src/bin/turingos/cmd_llm.rs:5
src/web/store.rs:4
src/top_white/predicates/visibility.rs:4
src/sdk/protocol.rs:4
src/runtime/resume_preflight.rs:4
src/runtime/prompt_promotion.rs:4
src/runtime/chain_tape_lease.rs:4
src/judges/swebench_test_judge.rs:4
src/web/market_view.rs:3
src/web/fixtures.rs:3
src/state/head_t_witness.rs:3
src/sdk/pending_peer_reviews.rs:3
src/runtime/batch_continuation_manifest.rs:3
src/rtool.rs:3
src/memory_kernel.rs:3
src/bin/turingos_web.rs:3
src/web/verify.rs:2
src/token_budget.rs:2
src/sdk/prompt_guard.rs:2
src/sdk/prompt.rs:2
src/sdk/market_context.rs:2
src/sdk/actor.rs:2
src/runtime/test_scenario.rs:2
src/runtime/test_run.rs:2
src/runtime/cid_hex.rs:2
src/web/preview.rs:1
src/web/artifact_bundle.rs:1
src/web/artifact.rs:1
src/sdk/snapshot.rs:1
src/runtime/verify.rs:1
src/runtime/predicate_registry_loader.rs:1
src/runtime/market_decision_trace.rs:1
src/main.rs:1
src/drivers/llm_http.rs:1
src/distiller.rs:1
src/bin/turingos/cmd_tdma.rs:1
src/bin/tdma_rc1_nesbitt_stress.rs:1
```

## Per-file table — src/ IMPLEMENTATION-ONLY counts (cfg(test) modules excluded, sorted desc)

Method: awk state machine per file — once a `#[cfg(test)]` or `#[cfg(all(... test ...))]` attribute (possibly followed by more attribute lines) is followed by a `mod` declaration, everything to EOF is treated as test code (test mods are trailing in this codebase; verified for all top-10 files). A `#[cfg(test)]` on a non-mod item (e.g. sequencer.rs:5151 test-only fn, evidence_capsule.rs:30 thread_local) does NOT trigger exclusion of following code; those snippets were manually verified to contain 0 matches. The only non-plain gate variant in src/ is `#[cfg(all(feature = "web", test))]` (7 files under src/web/, found via: grep -rnP '#\[cfg\([^)]*test' --include='*.rs' src/).

Command:
```
find src -name '*.rs' -print0 | xargs -0 -I{} awk '
{
  if (pend) {
    if ($0 ~ /^[[:space:]]*(pub[[:space:]]+)?mod[[:space:]]/) intest=1
    if ($0 !~ /^[[:space:]]*#\[/) pend=0
  }
  if ($0 ~ /^[[:space:]]*#\[cfg\((test\)|all\([^)]*test\))/) pend=1
  if (!intest && $0 ~ /\.unwrap\(\)|\.expect\(|panic!\(|todo!\(|unimplemented!\(/) n++
}
END { if (n>0) print FILENAME ": " n }
' {} | sort -t: -k2 -rn
```

```
src/state/sequencer.rs: 38
src/boot.rs: 7
src/bin/tb_18r_compute_invariant.rs: 6
src/top_white/predicates/registry.rs: 5
src/git_tape_ledger.rs: 5
src/bin/turingos/cmd_llm.rs: 5
src/runtime/audit_assertions.rs: 4
src/bottom_white/tools/registry.rs: 4
src/web/store.rs: 3
src/web/spec.rs: 3
src/web/fixtures.rs: 3
src/bin/turingos_web.rs: 3
src/sdk/prompt_guard.rs: 2
src/sdk/actor.rs: 2
src/runtime/embedded_prompts.rs: 2
src/runtime/autopsy_capsule.rs: 2
src/runtime/agent_audit_trail.rs: 2
src/ledger.rs: 2
src/web/preview.rs: 1
src/web/artifact_bundle.rs: 1
src/web/artifact.rs: 1
src/state/typed_tx.rs: 1
src/state/head_t_witness.rs: 1
src/runtime/predicate_registry_loader.rs: 1
src/runtime/batch_continuation_manifest.rs: 1
src/runtime/agent_keypairs.rs: 1
src/rtool.rs: 1
src/main.rs: 1
src/bottom_white/cas/schema.rs: 1
src/bin/turingos/cmd_tdma.rs: 1
src/bin/turingos/cmd_generate.rs: 1
src/bin/tdma_rc1_nesbitt_stress.rs: 1
```

## Top-10 files (by raw count) — classification of dominant panic sites

Split verification command (per file; mod-tests boundary cross-checked against the awk method above):
```
cfg=$(grep -nP '^\s*#\[cfg\(test\)\]' "$f" | head -1 | cut -d: -f1)   # then verified the attribute is followed by `mod tests {`
grep -nP '\.unwrap\(\)|\.expect\(|panic!\(|todo!\(|unimplemented!\(' "$f" | awk -F: -v c="$cfg" '$1 < c' | wc -l
```

| # | file | raw | impl | in test mod | dominant classification | example (file:line) |
|---|------|-----|------|-------------|------------------------|---------------------|
| 1 | src/bottom_white/cas/store.rs | 188 | 0 | 188 | test-only module inside src (mod tests @591) | store.rs:597 `let tmp = TempDir::new().unwrap();` |
| 2 | src/state/sequencer.rs | 166 | 38 | 128 | **hot path** (per-tx sequencing/hashing) — see breakdown below | sequencer.rs:874 `Err(e) => panic!("CAS integrity error during rejection-class refinement: {e}"),` |
| 3 | src/state/typed_tx.rs | 43 | 1 | 42 | test-only module inside src (mod tests @4242); 1 hot-path residual | typed_tx.rs:968 `let body = canonical_encode(value).expect("canonical_encode of signing payload");` (per-tx signing) |
| 4 | src/runtime/evidence_capsule.rs | 42 | 0 | 42 | test-only module inside src (mod tests @481; cfg(test) snippets @30/@215 contain 0 matches) | evidence_capsule.rs:492 `let max_bytes = value.parse::<u64>().expect("test max bytes is u64");` |
| 5 | src/bottom_white/ledger/transition_ledger.rs | 42 | 0 | 42 | test-only module inside src (mod tests @1759) | transition_ledger.rs:1860 `.expect("clean chain replays");` |
| 6 | src/runtime/markov_capsule.rs | 33 | 0 | 33 | test-only module inside src (mod tests @462) | markov_capsule.rs:472 `let bytes = canonical_encode(&c).expect("encode");` |
| 7 | src/runtime/agent_keypairs.rs | 32 | 1 | 31 | test-only module inside src (mod tests @589); 1 runtime invariant-backed residual | agent_keypairs.rs:398 `Ok(self.keypairs.get(agent_id).expect("just inserted"))` |
| 8 | src/economy/money.rs | 30 | 0 | 30 | test-only module inside src (mod tests @184) | money.rs:190 `let m = MicroCoin::from_coin(5).unwrap();` |
| 9 | src/economy/ledger.rs | 28 | 0 | 28 | test-only module inside src (mod tests @381) | ledger.rs:439 `let e1 = l.append_accepted(&fixture_work_tx(1)).unwrap();` |
| 10 | src/boot.rs | 25 | 7 | 18 | **startup path** (genesis/trust-root parse at boot; process dies early) | boot.rs:177 `let sv = get("schema_version").unwrap();` (presence pre-checked against required_keys list at boot.rs:160-171) |

### sequencer.rs implementation breakdown (38 sites; THE hot-path concentration)
- 26x `h.update(canonical_encode(tx).expect("TypedTx is canonical-encodable"));` (lines 84-497) — per-transaction hash functions; fires on every tx the sequencer touches.
- 3x `panic!`: line 874 `panic!("CAS integrity error during rejection-class refinement: {e}")` — unconditional, mid-run, on CAS read failure; lines 962 & 985 are TB-18R R3 invariant panics gated `#[cfg(debug_assertions)]` (release builds `log::warn!` + fall back instead — release-safe).
- 9x invariant-backed `.expect("verified at step N" / "pool existence checked...")` (lines 2538, 3179, 3192, 3311, 4144, 4423, 4455, 4458, 6764) — inside the sequencer apply pipeline; checked-then-unwrap pattern, but any drift between check and use panics mid-run.

### boot.rs implementation breakdown (7 sites; startup path)
- 6x `get("...").unwrap()` (lines 177-229) on genesis constitution_root keys whose presence is verified against a required_keys list immediately above (boot.rs:160-171) — checked-then-unwrap during trust-root boot; process dies at startup, not mid-run.
- 1x `write!(out, "{b:02x}").unwrap()` (line 386) — write! into String, infallible.

## Port-readiness reading
1. Real panic surface in implementation code is small (112 lines) and heavily concentrated: src/state/sequencer.rs alone holds 38/112 (34%), and they are hot-path (per-tx hashing + CAS-integrity panic + invariant expects in the apply pipeline). This is the file a port must treat as the panic-risk center.
2. The only unconditional mid-run `panic!` found in the top files is sequencer.rs:874 (CAS integrity during rejection-class refinement). The neighboring TB-18R panics (962/985) are debug-only.
3. 8 of the top 10 raw-count files are pure test-module noise; raw `rg -c` on src/ overstates the panic surface by ~11x for this codebase. Any port-readiness gate should use the cfg(test)-excluded count.
4. tests/ panic density (5924) is idiomatic test code; no action.

UNVERIFIED/limits: the cfg(test)-exclusion awk assumes test mods are trailing (verified true for all top-10 files and the 7 web-feature-gated files; not line-by-line verified for the remaining ~80 files with <=6 matches each). Counts are matching lines, not call sites (a line with two `.unwrap()` counts once).

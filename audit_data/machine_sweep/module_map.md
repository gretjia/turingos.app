# turingosv4 — Source Architecture Map (R1.9 port-readiness audit)

- Audit target: `/Users/zephryj/work/.audit-scratch/turingosv4-main` (read-only clone)
- Anchor commit: `1f00012d5326d08f0e6ffe05f6ecec6a391c4896` (2026-05-29, "Merge pull request #212 from gretjia/claude/swebench-tdma-judge-20260528"), branch main, clean tree
  - Verified by: `git log -1 --format='%H %ci %s' && git status --short`
- Date: 2026-06-11
- Method: file reads + grep/find only. No cargo command run (baseline build owns the lock). Bin-target enumeration is derived from Cargo.toml + Cargo's documented auto-discovery rules, NOT from `cargo metadata` — marked accordingly below.

## 1. Crate roots (authoritative, per Cargo.toml + src/lib.rs)

- Library crate root: `src/lib.rs` (package `turingosv4`, edition 2021).
- Default bin: `src/main.rs` → implicit bin `turingosv4` (Trust Root verify only: calls `turingosv4::boot::verify_trust_root`, panics `TRUST_ROOT_TAMPERED` on mismatch).
- Workspace: members `[".", "spike/gix_capability"]`, excludes `experiments/minif2f_v4`.
- Feature `web` gates axum/tower-http/tokio-tungstenite and the `turingos_web` bin.
- NOTE: `src/web/` is NOT in `src/lib.rs`. It is mounted from `src/bin/turingos_web.rs:22-23` via `#[path = "../web/mod.rs"] mod web;` (lib.rs is a DO-NOT-TOUCH Trust-Root surface per Phase 7 §7). Same pattern in `src/bin/turingos.rs`: all `cmd_*` submodules mounted via `#[path = "turingos/..."]`.

### lib.rs module tree (verbatim order, src/lib.rs:1-37)

boot, bottom_white, bus, drivers, economy, kernel, ledger, memory_kernel,
runtime, sdk, state, state_update, tokenizer, token_budget, distiller,
charter_core, rtool, judges, tdma_runner, git_tape_ledger, top_white

## 2. src/ top-level structure

Counts via:
- `find src -name '*.rs' | wc -l` → 226 .rs files total
- per-dir: `for d in src/*/; do find "$d" -name '*.rs' | wc -l; done`
- LOC: `find src/<d> -name '*.rs' -exec cat {} + | wc -l` (raw line count incl. comments/tests)
- top-level files: `wc -l src/*.rs` → 7098 total (15 files)

| Module | Files | Raw LOC | Purpose (from module doc headers) |
|---|---|---|---|
| src/lib.rs + main.rs | 2 | 55 | crate roots; main.rs = trust-root-verify bin |
| src/boot.rs | 1 | 586 | Trust Root + Boot freeze (FC3-S3 readonly subgraph); `verify_trust_root` |
| src/bus.rs | 1 | 703 | Tier 4 TSP Event Bus — SKILL lifecycle serial reactor (restricted surface §6) |
| src/kernel.rs | 1 | 144 | Tier 1 pure topology DAG, zero domain knowledge (restricted surface §6) |
| src/ledger.rs | 1 | 1113 | Tier 0 append-only tape with tamper detection (`ImmutableTapeLedger`, `TapeNode`, `CommitRequest`) |
| src/git_tape_ledger.rs | 1 | 618 | real-git (libgit2) substrate for the TDMA tape; implements `ImmutableTapeLedger` commit semantics |
| src/memory_kernel.rs | 1 | 653 | TDMA-Bounded memory kernel (FC1a-Q_t/FC1b-Q_{t+1}) |
| src/state_update.rs | 1 | 325 | state-first prefix parser (`tdma-state-update/v1` header) |
| src/tokenizer.rs | 1 | 107 | 4-chars-per-token heuristic tokenizer |
| src/token_budget.rs | 1 | 543 | hard-budget constants + type-aware token enforcer |
| src/distiller.rs | 1 | 599 | TDMA distiller (FC1a-rtool_input + FC3-replay) |
| src/charter_core.rs | 1 | 340 | bounded content-addressed constitution distillation (FC2-Q_0) |
| src/rtool.rs | 1 | 331 | kernel read-side O(1) checkout (FC1a-rtool) |
| src/tdma_runner.rs | 1 | 981 | TDMA-Bounded shared runner library |
| src/bottom_white/ | 11 | 7692 | deterministic append-only substrate: cas/ (schema, store, git_chain), ledger/ (transition_ledger, system_keypair, rejection_evidence), tools/ |
| src/top_white/ | 4 | 1533 | accept/reject predicate layer (predicates/registry, visibility) |
| src/state/ | 7 | 18166 | L4 state machine: sequencer.rs (9592), typed_tx.rs (5633), q_state.rs (1138), price_index.rs (1142), router_quote.rs (332), head_t_witness.rs |
| src/economy/ | 5 | 2427 | RSP-1 economy: money.rs (integer MicroCoin), escrow_vault.rs, ledger.rs (AcceptedLedger), monetary_invariant.rs |
| src/runtime/ | 71 | 36367 | production ChainTape runtime: evaluator adapters, replay/verify, agent keys, market traces, capsules, telemetry, reports |
| src/sdk/ | 15 | 3362 | agent-facing SDK: actor, prompt, protocol, market_context, tools/wallet.rs (restricted §6) |
| src/judges/ | 8 | 2595 | JudgeAI predicates (math step, putnam, swebench-test, generate, injected) |
| src/drivers/ | 2 | 197 | llm_http.rs HTTP LLM driver (+ llm_proxy.py non-Rust) |
| src/web/ | 21 | 11192 | Phase 7 Web MVP HTTP/WS server (feature `web`; mounted only by turingos_web bin) |
| src/bin/ | 67 | 33912 | bin targets: turingos CLI (turingos.rs + 31 submodules in turingos/), turingos_web, verify_chaintape, audit_*, benchmark `*_current_kernel` runners, tdma_rc1_* evidence runners |

## 3. Bin targets

Cargo.toml explicit `[[bin]]` sections: **1**
- `turingos_web` → `src/bin/turingos_web.rs` (`required-features = ["web"]`)

Actual bin-target surface (edition 2021 → autobins=true; derived from layout, NOT from cargo metadata — see method note):
- `src/main.rs` → implicit bin `turingosv4` (1)
- every `src/bin/*.rs` file is an auto-discovered bin (36 files, incl. turingos_web.rs already counted explicit)
- `src/bin/turingos/` contains NO main.rs → it is NOT a bin; its 31 files are `#[path]` submodules of `src/bin/turingos.rs`

**Total bin targets = 37** (1 explicit + 35 auto-discovered src/bin/*.rs + 1 implicit src/main.rs).
Enumeration command: `find src/bin -maxdepth 1 -name '*.rs' | sort` (36) + `src/main.rs`.

Full src/bin/*.rs list (each = one bin, name = file stem):
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
tdma_rc1_real_evidence, tdma_rc1_zero_gain_demo, toolbench_api_tool_use_current_kernel,
turingos, turingos_web, verify_chaintape, webarena_web_agent_current_kernel

## 4. Six audited module groups (code-evidence located)

### a. Replay verification (re-executing/validating a ChainTape)
Paths:
- `src/runtime/verify.rs` (708 LOC) — `pub fn verify_chaintape` at :230; module doc :1-33: re-opens runtime_repo + cas + pinned_pubkeys.json, replays L4 chain entry-by-entry through `replay_full_transition`, reconstructs QState+EconomicState from L4 alone, verifies every entry's system_signature; emits 7-indicator `ReplayReport` (:118).
- `src/runtime/replay.rs` (340 LOC) — `pub fn reconstruct_session` at :70; offline CAS replay of build sessions, zero network/LLM, verifies cross-CID references.
- `src/bottom_white/ledger/transition_ledger.rs` — `replay_full_transition` :767, `replay_full_transition_with_predicate_binding(_and_l4e)` :787/:812, `replay_chain_integrity` :1165 (the I-DETHASH witness used by verify.rs).
- CLI wrappers: `src/bin/verify_chaintape.rs` (thin wrapper, doc :1-15), `src/bin/turingos/cmd_replay.rs` (7-indicator default + `--offline` reconstruct_session mode).
Evidence commands: `grep -n "pub fn" src/runtime/verify.rs`, `sed -n '1,40p' src/runtime/verify.rs`, `grep -n "replay_full_transition\|replay_chain_integrity" src/bottom_white/ledger/transition_ledger.rs`.

### b. Signature verification (signer/verifier, key handling)
Paths:
- `src/bottom_white/ledger/system_keypair.rs` (1170 LOC) — ed25519_dalek import :15; `Ed25519Keypair` :325; `SystemSignature` :91; `PinnedSystemPubkeys` :298; `pub fn verify_system_signature` :586; `verify_epoch_rotation_proof` :605; `verify_system_pubkeys` :617. System-side signing of L4 entries.
- `src/runtime/agent_keypairs.rs` (776 LOC) — `AgentKeypair` :95 (`sign_digest` :149), `AgentKeypairRegistry` :183, `AgentPubkeyManifest` :471, `pub fn verify_agent_signature` :501.
- `src/runtime/agent_keystore.rs` (501 LOC) — encrypted-at-rest agent Ed25519 secrets (Argon2id KDF + ChaCha20-Poly1305 AEAD, magic `TOS4AGTKEY1`).
- Consumption sites: `src/state/sequencer.rs:1124,1130` calls `verify_system_signature`; :5251-5289 calls `verify_agent_signature` on market txs (mint/redeem/seed/merge). `src/state/typed_tx.rs` holds canonical signing payloads — per-tx `canonical_digest()` (12+ impls, e.g. :991-:1173) + `to_signing_payload()` pattern excluding the signature field (doc :279-:281, :875).
Evidence command: `grep -rln "ed25519\|SigningKey\|VerifyingKey" src` and per-file greps above.

### c. Tape / CAS append (append-only event log + content-addressed store)
Paths:
- `src/bottom_white/cas/store.rs` (1692 LOC) — `CasStore` :253, `pub fn put` :404, `get` :493, `merkle_root` :586; CID = sha256(content) per cas/schema.rs (`Cid`, `ObjectType`, `CasObjectMetadata`).
- `src/bottom_white/cas/git_chain.rs` (778 LOC) — Git-backed CAS commit chain: upgrades `refs/chaintape/cas` to a strict git2 commit chain recording CAS metadata + Merkle root.
- `src/bottom_white/ledger/transition_ledger.rs` (2474 LOC) — `LedgerEntry` :197, `LedgerEntrySigningPayload` :236, `canonical_digest` :250, `pub fn append(parent_root, signing_digest) -> Hash` :299 (root-fold append), `trait LedgerWriter` :474, `CHAINTAPE_CAS_REF` const.
- `src/bottom_white/ledger/rejection_evidence.rs` (846 LOC) — L4.E append-only JSONL with `prev_hash → hash` chain validation on open (`ChainBroken` error).
- Second (TDMA) tape lineage: `src/ledger.rs` (1113 LOC, Tier-0 append-only tape, `ImmutableTapeLedger`/`TapeNode`/`CommitRequest`) + `src/git_tape_ledger.rs` (618 LOC, libgit2 substrate impl: `commit`, `count_nodes`, `latest_node`, `verified_head`, `derive_latest_belief_state_from_tape`).
Evidence commands: `grep -n "pub fn\|pub struct\|pub trait" src/bottom_white/cas/store.rs src/bottom_white/ledger/transition_ledger.rs`; headers of git_chain.rs / git_tape_ledger.rs.

### d. Sequencer
Paths:
- `src/state/sequencer.rs` (9592 LOC — largest file in crate) — `pub struct Sequencer` :4981 (`new` :5056, `new_at_logical_t` :5099); module doc :1-18: "L4 Sequencer + dispatch_transition", single-writer per (runtime_repo, run_id), apply path = snapshot → dispatch → CAS put → sign → root fold → commit → Q_t mutation. Per-tx-kind `*_accept_state_root` fns :103-:493 (worktx, task_open, escrow_lock, verify, challenge, finalize_reward, cpmm_pool/swap, complete_set_mint/redeem/merge, market_seed, buy_with_coin_router, …). `SubmissionReceipt` :4569, `SystemEmitCommand` :4638, `SequencerError` :4934. Admission signature checks at :1124, :5251-5289.
- Supporting: `src/state/typed_tx.rs` (typed transaction wire schema + discriminants), `src/state/q_state.rs` (`EconomicState` :172), `src/state/head_t_witness.rs`, `advance_head_t` sequencer.rs:4555.
- AGENTS.md §6 lists `src/state/sequencer.rs` + `src/state/typed_tx.rs` as Class-4-candidate restricted surfaces.
Evidence command: `grep -n "pub fn\|pub struct\|pub enum" src/state/sequencer.rs`.

### e. Market (pricing / bidding / payout)
Paths:
- `src/economy/` (5 files, 2427 LOC) — `money.rs`: `MicroCoin(i64)` integer-only money :36; `escrow_vault.rs`: `EscrowVault` :153, `lock_escrow` :186, `release_escrow` :222 (payout side); `ledger.rs`: `AcceptedLedger` (`append_accepted` :201, `verify_chain` :236, `reconstruct_state` :287); `monetary_invariant.rs`: 基本法 1 coin-conservation + Inv 4 no-post-init-mint guards.
- `src/state/price_index.rs` (1142 LOC) — PriceIndex v0 derived view over `EconomicState` (`node_positions_t` + `conditional_share_balances_t`), integer-rational u128, "price is signal, not truth".
- `src/state/router_quote.rs` (332 LOC) — CPMM Mint-and-Swap router quote, pure over `(&CpmmPool, MicroCoin)`; `CpmmPool`/`PoolStatus` live in `src/state/q_state.rs` (:720 area).
- Market tx execution: `src/state/sequencer.rs` `cpmm_pool_accept_state_root` :453, `cpmm_swap_accept_state_root` :471, `complete_set_mint/redeem/merge` :390/:405/:435, `market_seed` :420, `buy_with_coin_router` :493.
- Agent-facing: `src/sdk/market_context.rs` (top-K CPMM pool prompt block), `src/sdk/tools/wallet.rs` (`WalletTool::balance` over `EconomicState`).
- Trace/report layer (derived views, not truth): 9 `src/runtime/market_*.rs` files (`ls src/runtime | grep -i market`).
Evidence commands: greps shown inline; `sed -n '1,20p' src/state/price_index.rs`.

### f. CLI layer (`turingos` bin command surface)
Paths:
- `src/bin/turingos.rs` (363 LOC) — entry; manual `std::env::args` parsing (no clap, preserves Trust Root); append-only `const SUBCOMMANDS` registry :106-:253 with **29 subcommands** (count: `sed -n '/const SUBCOMMANDS/,/^];/p' src/bin/turingos.rs | grep -c "name:"`):
  init, report run, report wallet, report positions, report bankruptcy, report markov, verify chaintape, verify e2-candidate, audit dashboard, audit tape, audit tamper, preflight, replay, task open, task view, task tick, config, agent, batch, export evidence, render, welcome, llm, spec, generate, spec audit, wizard, tdma, tape-migrate
- `src/bin/turingos/` — 31 submodule files (`cmd_*.rs` ×28 + `chat_client.rs` + `common.rs`), each mounted via `#[path = "turingos/..."]` in turingos.rs; `common.rs` holds `run_external`/`TASK_RUNNER_BIN` (several cmds shell out to task-runner bins).
- `src/bin/turingos_web.rs` — Phase 7 web bin, binds 127.0.0.1:8080 HARD, mounts `src/web/` via `#[path]`.
Key files: src/bin/turingos.rs, src/bin/turingos/common.rs, src/bin/turingos/cmd_replay.rs.

## 5. Commands used (full list)

```
git log -1 --format='%H %ci %s'; git status --short
cat Cargo.toml
ls src src/bin src/state src/bottom_white src/top_white src/runtime src/economy src/drivers src/sdk src/judges src/web src/bin/turingos
find src -name '*.rs' | wc -l
for d in src/*/; do find "$d" -name '*.rs' | wc -l; done
for d in <dirs>; do find src/$d -name '*.rs' -exec cat {} + | wc -l; done
find src/bin -maxdepth 1 -name '*.rs' | sort | wc -l
wc -l src/*.rs
wc -l <16 key files>   # see §4 per-file LOC
grep -rn "pub mod web\|mod web;" src --include='*.rs'
grep -rln "ed25519\|SigningKey\|VerifyingKey\|verify_strict\|Signature" src --include='*.rs'
grep -n "pub fn\|pub struct\|pub enum" src/runtime/replay.rs src/runtime/verify.rs src/state/sequencer.rs src/bottom_white/cas/store.rs src/bottom_white/ledger/transition_ledger.rs src/bottom_white/ledger/system_keypair.rs src/runtime/agent_keypairs.rs src/economy/*.rs src/sdk/tools/wallet.rs
grep -n "verify_agent_signature\|verify_system_signature" src/state/sequencer.rs
grep -n "fn to_signing_payload\|fn canonical_digest" src/state/typed_tx.rs
sed -n '/const SUBCOMMANDS/,/^];/p' src/bin/turingos.rs | grep -c "name:"   # → 29
sed -n '1,60p' src/bin/turingos_web.rs; sed -n '1,80p' src/bin/turingos.rs
ls src/runtime | grep -i market   # → 9 files
```

UNVERIFIED items: none material. Caveat: bin-target total (37) derived from Cargo layout rules (edition 2021 autobins=true), not from `cargo metadata` (cargo forbidden during concurrent baseline build); the 1 explicit [[bin]] is read directly from Cargo.toml.

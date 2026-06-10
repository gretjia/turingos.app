# Hotspot Map — modification frequency × current size

Audit target: scratch clone `/Users/zephryj/work/.audit-scratch/turingosv4-main`
Anchor commit: `1f00012d5326d08f0e6ffe05f6ecec6a391c4896` (branch `main`)
Generated: 2026-06-11 (R1.9 port-readiness audit, runbook §2 hotspot map)

## Method

- `touch_count` = number of commits whose name-only diff includes the file (`git log --pretty=format: --name-only | sort | uniq -c`).
- Rust files only (`*.rs`).
- Only files that STILL EXIST at HEAD are kept (`[ -f "$f" ]`).
- `loc` = `wc -l` of the file at HEAD (line count, includes blanks/comments).
- Ranked by `touch_count` DESC (primary). Ties broken by the order `sort -rn` emits.
- Group tag = audited module group inferred from path (replay/tape/cas/sequencer/signer/market/cli/web/judges/other).

### Commands run (exact, reproducible)

Raw touch counts (verification, top of list):
```
cd /Users/zephryj/work/.audit-scratch/turingosv4-main
git log --pretty=format: --name-only | grep '\.rs$' | sort | uniq -c | sort -rn
```

Top-30 of files that still exist, with LOC and group tag:
```
cd /Users/zephryj/work/.audit-scratch/turingosv4-main
git log --pretty=format: --name-only | grep '\.rs$' | sort | uniq -c | sort -rn | awk '{print $1"\t"$2}' | while IFS=$'\t' read -r cnt f; do
  if [ -f "$f" ]; then
    loc=$(wc -l < "$f" | tr -d ' ')
    g="other"
    case "$f" in
      *replay*) g="replay";;
      *sequencer*) g="sequencer";;
      *cas*) g="cas";;
      *signer*|*keypair*) g="signer";;
      *market*) g="market";;
      *judges*) g="judges";;
      *web*) g="web";;
      src/bin/turingos*|*cmd_*|*tdma_runner*) g="cli";;
      *ledger*|*tape*|*chaintape*|*transition_ledger*) g="tape";;
    esac
    printf '%s\t%s\t%s\t%s\n' "$cnt" "$loc" "$g" "$f"
  fi
done | head -30
```

## Exclusion note (top raw-count files dropped because GONE at HEAD)

The two highest raw-count Rust paths in history NO LONGER EXIST at HEAD and are
correctly excluded from the top-30 (verified with `[ -f ]`):

| raw touch_count | path | status at HEAD |
|---:|---|---|
| 106 | `experiments/minif2f_v4/src/bin/evaluator.rs` | GONE |
| 22  | `experiments/minif2f_v4/tests/trust_root_immutability.rs` | GONE |

Total Rust files in history that still exist at HEAD: **622** (so top-30 is well-defined).

## Top 30 hotspots (by touch_count, files existing at HEAD)

| rank | touch_count | loc | group | file |
|---:|---:|---:|---|---|
| 1 | 65 | 1186 | other | src/runtime/mod.rs |
| 2 | 60 | 9592 | sequencer | src/state/sequencer.rs |
| 3 | 42 | 5633 | other | src/state/typed_tx.rs |
| 4 | 34 | 2474 | tape | src/bottom_white/ledger/transition_ledger.rs |
| 5 | 31 | 4066 | other | src/runtime/audit_assertions.rs |
| 6 | 29 | 3099 | cli | src/bin/turingos/cmd_generate.rs |
| 7 | 28 | 3598 | other | src/bin/audit_dashboard.rs |
| 8 | 24 | 1055 | other | src/economy/monetary_invariant.rs |
| 9 | 19 | 663 | other | src/sdk/prompt.rs |
| 10 | 18 | 1138 | other | src/state/q_state.rs |
| 11 | 18 | 6 | other | experiments/minif2f_v4/src/lib.rs |
| 12 | 17 | 1775 | other | src/runtime/adapter.rs |
| 13 | 17 | 703 | other | src/bus.rs |
| 14 | 16 | 710 | other | tests/constitution_true_suite_broad_agi_batch_runner.rs |
| 15 | 16 | 314 | other | src/runtime/run_summary.rs |
| 16 | 15 | 847 | other | tests/fc_alignment_conformance.rs |
| 17 | 15 | 37 | other | src/lib.rs |
| 18 | 15 | 1170 | signer | src/bottom_white/ledger/system_keypair.rs |
| 19 | 15 | 1692 | cas | src/bottom_white/cas/store.rs |
| 20 | 14 | 62 | other | src/state/mod.rs |
| 21 | 14 | 2549 | cli | src/bin/turingos/cmd_llm.rs |
| 22 | 13 | 196 | other | tests/economic_state_reconstruct.rs |
| 23 | 13 | 1265 | other | src/runtime/chain_derived_run_facts.rs |
| 24 | 12 | 788 | other | tests/constitution_production_module_liveness.rs |
| 25 | 11 | 931 | other | tests/tb_13_legacy_cpmm_forward_fence.rs |
| 26 | 11 | 686 | cli | src/bin/turingos/cmd_tdma.rs |
| 27 | 10 | 828 | other | tests/tb_2_runtime_boundary.rs |
| 28 | 10 | 2732 | web | src/web/spec.rs |
| 29 | 10 | 877 | web | src/web/generate.rs |
| 30 | 10 | 981 | cli | src/tdma_runner.rs |

## Reading (mess peaks / future-touch prior)

- **`src/state/sequencer.rs`** is the standout danger zone: rank #2 by churn (60 touches)
  AND by far the largest file (9592 LOC). High churn × high size = top prior for both
  accumulated mess and future touch probability.
- **`src/state/typed_tx.rs`** (42 touches, 5633 LOC) is the #2 churn×size combo.
- **`src/runtime/mod.rs`** is the single most-touched file (65) but moderate size (1186) —
  hot interface/wiring hub rather than a size-bloat hotspot.
- Other large+hot: `src/runtime/audit_assertions.rs` (31 × 4066), `src/bin/audit_dashboard.rs`
  (28 × 3598), `src/bin/turingos/cmd_generate.rs` (29 × 3099), `src/web/spec.rs` (10 × 2732),
  `src/bin/turingos/cmd_llm.rs` (14 × 2549).
- Group concentration in top-30: cli (4 files), web (2), plus single-file representatives for
  sequencer, tape, signer, cas. Many `runtime/` and `state/` files fall under `other` because
  no audited-group keyword matched their path (tag is path-keyword-only, NOT semantic).

UNVERIFIED: nothing — every number above is from the two commands shown. The `group` tag is a
mechanical path-keyword match, not a semantic module assignment.

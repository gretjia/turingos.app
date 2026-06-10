# Constitution-Gate Census — R1.9 Port-Readiness Audit

- **Audit target:** scratch clone `/Users/zephryj/work/.audit-scratch/turingosv4-main`
- **Anchor commit:** `1f00012d5326d08f0e6ffe05f6ecec6a391c4896` (branch main, "Merge pull request #212 from gretjia/claude/swebench-tdma-judge-20260528")
- **Date:** 2026-06-11
- **Scope:** runbook §2 constitution-gate census — PORT ACCEPTANCE BASELINE NUMBER

All numbers below are reproducible from the exact commands shown. Commands were run with cwd = the clone root.

---

## 1. Physical form — how the gates are materialized

The "164 gates" are materialized as **164 integration-test files** `tests/constitution_*.rs`, each authorized by a **1:1 matching entry** in a TOML manifest `scripts/constitution_gates.manifest.toml`. A bash runner auto-discovers the test files, cross-checks them against the manifest, then runs them all in a **single** `cargo test` invocation.

Components:

- **`tests/constitution_*.rs`** — one Rust integration-test file per gate. Each file basename (minus `.rs`) is the gate name. Count = 164.
- **`scripts/constitution_gates.manifest.toml`** — authorization manifest. TOML array of `[[gate]]` tables; each has `name = "..."`, `authority = "..."`, `added = "..."`. The header comments state the binding rule: "Discovered gates (`tests/constitution_*.rs`) MUST exist in this manifest" and "Missing tests for manifest entries cause CI failure". Count of `^name = "..."` = 164.
- **`scripts/run_constitution_gates.sh`** — the runner. `set -euo pipefail`. Discovers gates from filenames, extracts names from the manifest, runs the two cross-checks (both directions), then a single serialized `cargo test`. Writes reports to `target/constitution_gate_report.{json,md}` and `target/constitution_gates_output.txt`.
- **`Makefile` target `constitution`** — `@bash scripts/run_constitution_gates.sh` (the local one-click entry). There is also `constitution-watch` which `cargo watch`-runs only 8 named core gates (FC1/FC2/FC3/predicate/shielding/economy/tape-canonical/no-parallel-ledger) — that is a dev convenience, NOT the full 164-gate path.
- **`.github/workflows/constitution_gates.yml`** — the CI gate (the only workflow referencing "constitution").

Runner discovery vs manifest extraction (exact lines from `run_constitution_gates.sh`):
```
DISCOVERED=$(ls tests/constitution_*.rs 2>/dev/null | xargs -n1 basename | sed 's/\.rs$//' | sort)
MANIFEST=$(grep -oP '^name = "\K[^"]+' scripts/constitution_gates.manifest.toml | sort)
```

---

## 2. Count check

### (a) manifest `name = ` entries

```
$ grep -cP '^name = "[^"]+"' scripts/constitution_gates.manifest.toml
164
$ grep -cE '^name = ' scripts/constitution_gates.manifest.toml
164
```
Both the strict (matches runner's `^name = "\K`) and loose anchored counts agree: **164**. No deeper-indented `name = ` lines exist that the anchored regex would silently miss:
```
$ grep -nP '^\s+name = ' scripts/constitution_gates.manifest.toml
(no output)
```
No duplicate names in manifest:
```
$ grep -oP '^name = "\K[^"]+' scripts/constitution_gates.manifest.toml | sort | uniq -d
(no output)
```

### (b) `tests/constitution_*.rs` file count

```
$ ls tests/constitution_*.rs 2>/dev/null | wc -l
164
```
No duplicate basenames:
```
$ ls tests/constitution_*.rs | xargs -n1 basename | sed 's/\.rs$//' | sort | uniq -d
(no output)
```

### (c) set-diff manifest names vs test-file basenames, BOTH directions

Reproduces the runner's exact extraction (`comm` over two sorted lists):
```
$ DISCOVERED=$(ls tests/constitution_*.rs 2>/dev/null | xargs -n1 basename | sed 's/\.rs$//' | sort)
$ MANIFEST=$(grep -oP '^name = "\K[^"]+' scripts/constitution_gates.manifest.toml | sort)

# ONLY_DISC = discovered but NOT in manifest  (runner: comm -23 -> exit 1 if nonempty)
$ comm -23 <(echo "$DISCOVERED") <(echo "$MANIFEST")
(empty)

# ONLY_MANI = in manifest but test file MISSING  (runner: comm -13 -> exit 1 if nonempty)
$ comm -13 <(echo "$DISCOVERED") <(echo "$MANIFEST")
(empty)

# counts
discovered: 164
manifest:   164
common:     164   (comm -12)
```

**Result: PERFECT 1:1 BIJECTION.** Both set-diffs are EMPTY (verbatim: no lines printed in either direction). 164 discovered = 164 manifest = 164 common. The baseline number 164 is confirmed and internally consistent.

---

## 3. How CI runs them + local one-click entry

**CI workflow file:** `.github/workflows/constitution_gates.yml` (workflow name: "TB-C0 Constitution Gates"). It is the only workflow that mentions "constitution".

**Trigger:** `pull_request` to `main` (path-filtered on `src/**/*.rs`, `tests/constitution_*.rs`, `tests/**/*.rs`, `Cargo.toml`, `Cargo.lock`, `constitution.md`, `scripts/run_constitution_gates.sh`, the two matrix docs, and the workflow file itself); also `push` to `main` and `workflow_dispatch`.

**Job that runs the gates:** job id `constitution_gates` (display name "Constitution gate suite"), `runs-on: ubuntu-latest`, `timeout-minutes: 60`. Steps:
1. checkout (fetch-depth 0)
2. install Rust (dtolnay/rust-toolchain@stable)
3. cache cargo
4. **Build constitution test binaries** — builds only 8 named core gates (`--test constitution_no_parallel_ledger`, `constitution_economy_gate`, `constitution_predicate_gate`, `constitution_fc1_runtime_loop`, `constitution_fc2_boot`, `constitution_fc3_meta`, `constitution_shielding_gate`, `constitution_tape_canonical_gate`). NOTE: this pre-build step names only 8 of the 164 gates; the actual full run is the next step.
5. **Run constitution gates** (id `gates`): `set -eo pipefail; RUST_TEST_THREADS=1 bash scripts/run_constitution_gates.sh` — this is the real all-164 invocation.
6. upload report artifact (`if: always()`, `if-no-files-found: error`)
7. **Enforce closure conditions** (`if: success()`): asserts `handover/alignment/CONSTITUTION_EXECUTION_MATRIX.md` and `handover/alignment/TRACE_FLOWCHART_MATRIX.md` exist, then runs `cargo test --test constitution_closure_3_no_trivial_asserts -- --test-threads=1` (no-trivial-assert scanner).

A second job `freeze_check` (display "Feature freeze check", PR-only) rejects branch/PR-title patterns like `TB-19`, `TB-20`, `NodeMarket`, `Polymarket-LIVE`, `real-world-readiness`, `M1-public-benchmark`. Unrelated to the gate count.

**Local one-click entry:** `make constitution` → `@bash scripts/run_constitution_gates.sh`. Equivalent direct call: `bash scripts/run_constitution_gates.sh`. CI invokes the same script, prefixing `RUST_TEST_THREADS=1` (the script itself also forces `RUST_TEST_THREADS=1` on the cargo line), so local and CI share the same single-threaded isolation guarantee.

---

## 4. Does the runner hard-fail on manifest/test mismatch?

**YES — fail-closed in both directions, before any test runs.** `run_constitution_gates.sh` has `set -euo pipefail`. Exact triggers for nonzero exit:

- **Gate discovered (test file present) but missing from manifest** → lines 21-26:
  ```
  ONLY_DISC=$(comm -23 <(echo "$DISCOVERED") <(echo "$MANIFEST"))
  if [ -n "$ONLY_DISC" ]; then
    echo "[k-1-5] FAIL: gates discovered but not in manifest:" >&2
    echo "$ONLY_DISC" >&2
    exit 1
  fi
  ```
  `exit 1` if the discovered-minus-manifest set is non-empty.

- **Gate in manifest but test file missing** → lines 29-34:
  ```
  ONLY_MANI=$(comm -13 <(echo "$DISCOVERED") <(echo "$MANIFEST"))
  if [ -n "$ONLY_MANI" ]; then
    echo "[k-1-5] FAIL: gates in manifest but test file missing:" >&2
    echo "$ONLY_MANI" >&2
    exit 1
  fi
  ```
  `exit 1` if the manifest-minus-discovered set is non-empty.

- **Any gate test fails** → lines 50-55 capture `FAIL` = count of `test result: FAILED` lines (min 1 if cargo returns nonzero); the script's final line 73 is `[ "$FAIL" -eq 0 ]`, so a nonzero `FAIL` makes the script exit nonzero.

Caveats on the hard-fail (UNVERIFIED-by-real-run, read from source only — no cargo run permitted under audit rules):
- The two cross-checks are **name-set** checks: they prove a 1:1 name bijection between filenames and `^name = "..."` manifest entries. They do NOT verify the `authority`/`added` fields, nor that each `[[gate]]` table is well-formed TOML, nor that a test file actually contains a failing-capable test (the `assert!(true)`-stub problem is handled separately and only in CI by the `constitution_closure_3_no_trivial_asserts` step, NOT by this script).
- The manifest extraction relies on a `name = "..."` line being column-0 anchored. A `name` key written with leading whitespace would be silently dropped from `MANIFEST` (verified: no such indented `name =` lines exist at this anchor, so not an active defect here).
- The pre-build step in CI only compiles 8 of 164 gates; compile failures in the other 156 surface during the run step (`cargo test --test <each>`), which `set -eo pipefail` + the `FAIL` capture will turn into nonzero exit. The runner relies on cargo to compile all 164 at run time.

---

## 5. Reproduction environment notes

- `grep` on this host is ugrep (supports `-P` PCRE); `-cP`/`-oP` used above behave as GNU-grep-compatible for these patterns.
- `comm`/`sed`/`ls`/`xargs` are the system BSD/macOS versions; the runner is written for the same `comm`/`sed` semantics and the diffs reproduce identically.
- No cargo/build command was run (baseline build owns the cargo lock); all findings are from file reads + git read-only + rg/grep/comm/sed.

## Verdict for port-acceptance baseline

**164 is CONFIRMED and consistent**: 164 `tests/constitution_*.rs` files ⇔ 164 manifest `name =` entries, empty set-diff both directions, zero duplicates, runner hard-fails fail-closed on any mismatch. Single CI workflow (`constitution_gates.yml`, job `constitution_gates`) and single local entry (`make constitution` → `bash scripts/run_constitution_gates.sh`).

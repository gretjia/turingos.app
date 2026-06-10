# Test-Structure Census — turingosv4

Audit target: scratch clone `/Users/zephryj/work/.audit-scratch/turingosv4-main`
Anchor commit: `1f00012d5326d08f0e6ffe05f6ecec6a391c4896` (branch main)
Run date: 2026-06-11
Tool note: `rg` is shimmed and emits `command not found: rg` (even via `command rg`), so all
counts below were taken with ugrep `grep`/`find`/`wc`/`awk`. Any earlier `rg` attempts that
returned blank are FALSE NEGATIVES and were re-run with grep.

All commands were run with CWD = `/Users/zephryj/work/.audit-scratch/turingosv4-main`.

---

## 1. Test LOC vs implementation LOC

### tests/ directory
```
find tests -maxdepth 1 -name '*.rs' | wc -l           # 374  (top-level test .rs files)
find tests -name '*.rs' | wc -l                        # 377  (recursive)
find tests -maxdepth 1 -name '*.rs' -exec wc -l {} + | tail -1   # 93507 total LOC (top-level)
find tests -name '*.rs' -exec wc -l {} + | tail -1               # 94090 total LOC (recursive)
```
- Top-level `tests/*.rs`: **374 files, 93,507 LOC**
- Recursive under `tests/`: 377 files, 94,090 LOC (3 extra files / 583 LOC in subdirs)

### src/ directory
```
find src -name '*.rs' | wc -l                          # 226 files
find src -name '*.rs' -exec wc -l {} + | tail -1        # 124541 total LOC
```
- All `src/**/*.rs`: **226 files, 124,541 LOC** (this includes in-file `#[cfg(test)]` modules)

### In-file test modules under src/
```
grep -rlP '#\[cfg\(test\)\]' --include='*.rs' src | wc -l                         # 97 files
grep -rcP '#\[cfg\(test\)\]' --include='*.rs' src | awk -F: '{s+=$NF} END{print s}'  # 108 occurrences
```
- **97 of 226 src files** contain at least one `#[cfg(test)]` (108 total occurrences).

### Non-test vs mixed src split (file-level, by presence of #[cfg(test)])
```
grep -rLP '#\[cfg\(test\)\]' --include='*.rs' src | tr '\n' '\0' | xargs -0 wc -l | tail -1   # 46063 total
grep -rlP '#\[cfg\(test\)\]' --include='*.rs' src | tr '\n' '\0' | xargs -0 wc -l | tail -1   # 78478 total
```
- src files with NO in-file test module: 129 files, **46,063 LOC** (pure impl)
- src files WITH an in-file test module: 97 files, **78,478 LOC** (impl + inline tests, NOT split)
- NOTE: a precise "non-test src LOC" requires per-`mod tests` byte slicing, which was not done
  (read-only, no parsing tool). The 46,063 figure is a strict lower bound on pure-impl LOC; the
  true non-test impl LOC lies between 46,063 and 124,541. Marked UNVERIFIED for an exact split.

### Test-LOC ratio (defensible bounds)
- Dedicated test LOC (tests/ top-level): 93,507
- vs total src LOC: 124,541  → ratio ≈ **0.75 : 1** (tests/ alone vs all src)
- Inline src test LOC additionally exists inside the 97 mixed files (exact LOC UNVERIFIED).

### Test-function counts
```
grep -rcP '#\[test\]|#\[tokio::test\]' --include='*.rs' tests | awk -F: '{s+=$NF} END{print s}'  # 1881
```
- **1,881** `#[test]`/`#[tokio::test]` functions across `tests/`.

---

## 2. Property testing (proptest / quickcheck)

```
grep -rlP 'proptest|quickcheck' --include='*.rs' --exclude-dir=target . | sort   # (no output)
grep -rlP 'proptest|quickcheck' --include='*.rs' --exclude-dir=target . | wc -l  # 0
grep -nP 'proptest|quickcheck' Cargo.toml                                        # NONE
```
- **ZERO** files reference `proptest` or `quickcheck`.
- Root `Cargo.toml` declares NO proptest/quickcheck dependency.
- (The runbook's `command rg -l 'proptest|quickcheck'` returns blank ONLY because the rg shim is
  broken; the grep result above is the authoritative negative.)
- Property-based testing is ABSENT from this repo. All testing is example-based.

---

## 3. Integration test files & constitution_*.rs

```
find tests -maxdepth 1 -name '*.rs' | wc -l                      # 374  (all integration test files)
find tests -maxdepth 1 -name 'constitution_*.rs' | wc -l         # 164  (constitution gate files)
# test-fn count inside constitution_*.rs:
total=0; for f in tests/constitution_*.rs; do c=$(grep -cP '#\[test\]|#\[tokio::test\]' "$f"); total=$((total+c)); done; echo $total   # 868
```
- Integration test files in `tests/` (top-level): **374**
- Of those, `constitution_*.rs` files: **164**
- `#[test]`/`#[tokio::test]` functions inside the 164 constitution files: **868**
- constitution files are ~44% of all integration test files and ~46% of all integration test fns.

---

## Summary table

| Metric | Value | Verified |
|---|---|---|
| tests/*.rs files (top-level) | 374 | yes |
| tests/ LOC (top-level) | 93,507 | yes |
| tests/ files (recursive) | 377 | yes |
| tests/ LOC (recursive) | 94,090 | yes |
| src/**/*.rs files | 226 | yes |
| src/ total LOC | 124,541 | yes |
| src files with #[cfg(test)] | 97 | yes |
| src #[cfg(test)] occurrences | 108 | yes |
| src pure-impl LOC (no inline tests) | 46,063 | yes (lower bound) |
| exact non-test impl LOC | between 46,063 and 124,541 | UNVERIFIED (no byte-split) |
| #[test]/#[tokio::test] fns in tests/ | 1,881 | yes |
| proptest/quickcheck files | 0 | yes |
| integration test files (tests/ top-level) | 374 | yes |
| constitution_*.rs files | 164 | yes |
| test fns in constitution_*.rs | 868 | yes |

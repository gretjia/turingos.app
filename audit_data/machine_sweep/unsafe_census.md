# Unsafe Census — turingosv4 R1.9 Port-Readiness Audit (§2)

- **Audit target:** scratch clone `/Users/zephryj/work/.audit-scratch/turingosv4-main`
- **Anchor commit:** `1f00012d` (branch `main`) — `Merge pull request #212 from gretjia/claude/swebench-tdma-judge-20260528`
- **Scanner run date:** 2026-06-11
- **Note on tooling:** `rg` was shimmed to invoke the claude binary and no real ripgrep/ugrep binary was on PATH, so the runbook's `command rg` could not run. Substituted BSD grep (`grep (BSD grep, GNU compatible) 2.6.0-FreeBSD`) with `-rn -E`. BSD grep lacks `-P`; `-E` (ERE) was used where regexes were needed. Exclusions applied via piped `grep -v` for `/tests/` and `/target/`.

---

## Exact commands run (reproducible)

### 1. Primary census (unsafe in Rust impl code, tests excluded)
```
command grep -rn 'unsafe' --include='*.rs' . | command grep -v '/tests/' | command grep -v '/target/'
```
(run from `/Users/zephryj/work/.audit-scratch/turingosv4-main`)

### 2. `unsafe_code` lint-config sweep (Cargo.toml / lib.rs / any .rs)
```
command grep -rn 'unsafe_code' --include='*.rs' --include='*.toml' . | command grep -v '/target/'
command grep -rln 'unsafe_code' --include='*.rs' --include='*.toml' . | command grep -v '/target/' | wc -l
command grep -rn '\[lints' --include='Cargo.toml' . | command grep -v '/target/'
```

### 3. Real `unsafe` block / declaration confirmation
```
command grep -rn -E 'unsafe[[:space:]]+(fn|impl|trait)' --include='*.rs' . | command grep -v '/target/'
command grep -rn -E '\bunsafe[[:space:]]*\{' --include='*.rs' . | command grep -v '/target/'
command grep -rn 'unsafe' --include='*.rs' . | command grep '/tests/' | command grep -v '/target/'
```

### 4. Anchor + corpus size
```
git log --oneline -1            # -> 1f00012d ...
find . -name '*.rs' -not -path '*/target/*' | wc -l   # -> 622
```

---

## RAW OUTPUT — primary census (command 1)

```
./src/bin/turingos/cmd_llm.rs:1568:// edits cascade unpredictably, so v2 → v1 promotion is unsafe without a
./src/bin/full_system_augment_current_kernel.rs:691:            "ArchitectAI proposes no unsafe kernel write; runtime evidence remains tape-bound"
./src/bin/cybench_security_sandbox_current_kernel.rs:230:    unsafe_exploit_attempt: bool,
./src/bin/cybench_security_sandbox_current_kernel.rs:548:        "unsafe_live_target_contact"
./src/bin/cybench_security_sandbox_current_kernel.rs:553:        Some("unsafe_exploit_attempt".to_string())
./src/bin/cybench_security_sandbox_current_kernel.rs:759:        unsafe_exploit_attempt: live_target_contacted,
./src/web/artifact.rs:70:                "artifact name {:?} contains invalid or unsafe characters",
./src/runtime/market_review.rs:23:/// default, barriered async is scaffold-only, full async is unsafe research.
./src/runtime/market_review.rs:32:    /// TRACE_MATRIX FC1: guards unrestricted full async behind unsafe research.
./src/runtime/market_review.rs:33:    pub const fn requires_unsafe_research(self) -> bool {
./src/runtime/attempt_telemetry.rs:167:    /// Candidate contained a forbidden `sorry` (or equivalent unsafe
./src/runtime/chain_tape_lease.rs:295:    let rc = unsafe { libc::kill(pid, 0) };
./src/runtime/chain_tape_lease.rs:312:    unsafe { *libc::__errno_location() }
./src/runtime/chain_tape_lease.rs:318:    unsafe { *libc::__error() }
./src/judges/generate_judge.rs:122:fn path_unsafe(path: &str) -> bool {
./src/judges/generate_judge.rs:182:            if path_unsafe(path) {
./src/judges/generate_judge.rs:185:                        reason: format!("unsafe path: {}", path),
./src/top_white/predicates/registry.rs:629:                    "unsafe".to_string(),
./src/bottom_white/ledger/system_keypair.rs:1118:    unsafe { libc::mlock(ptr.cast(), len) == 0 }
```
Total textual hits: **19**.

## RAW OUTPUT — command 2 (unsafe_code lint config)
```
(no matches; grep exit code 1)
unsafe_code line-count: 0
[lints] in Cargo.toml: (no matches)
```

## RAW OUTPUT — command 3 (real unsafe blocks / declarations)
```
unsafe fn|impl|trait : (no matches; grep exit code 1)
unsafe { ... } blocks :
./src/runtime/chain_tape_lease.rs:295:    let rc = unsafe { libc::kill(pid, 0) };
./src/runtime/chain_tape_lease.rs:312:    unsafe { *libc::__errno_location() }
./src/runtime/chain_tape_lease.rs:318:    unsafe { *libc::__error() }
./src/bottom_white/ledger/system_keypair.rs:1118:    unsafe { libc::mlock(ptr.cast(), len) == 0 }
tests/ hits (excluded from impl census, all identifier/string mentions):
./tests/constitution_real13b_market_review_window.rs:93:fn full_async_mode_is_explicitly_unsafe_only() {
./tests/constitution_real13b_market_review_window.rs:94:    assert!(MarketReviewMode::FullAsyncExperimental.requires_unsafe_research());
./tests/constitution_real13b_market_review_window.rs:95:    assert!(!MarketReviewMode::SequentialRound.requires_unsafe_research());
./tests/constitution_real13b_market_review_window.rs:96:    assert!(!MarketReviewMode::BarrieredAsync.requires_unsafe_research());
./tests/constitution_real16_market_performance.rs:292:fn real16_runner_forbids_unsafe_or_scripted_e4_inputs() {
```

---

## KEY FINDINGS

- **Real `unsafe` blocks in implementation code: 4** — all are single-expression FFI calls into `libc` (POSIX). No `unsafe fn`, `unsafe impl`, or `unsafe trait` anywhere in the tree.
- **SAFETY comments adjacent: 1 of 4** (only `system_keypair.rs:1118`). The 3 blocks in `chain_tape_lease.rs` have explanatory *doc comments* on the enclosing fn but NO `// SAFETY:`-style comment adjacent to the `unsafe` block.
- **`#![forbid(unsafe_code)]` / `deny(unsafe_code)` / `[lints]` config: NOT PRESENT.** Zero `unsafe_code` occurrences in any `.rs` or `.toml`. The crate does not forbid or deny unsafe at the lint level. (UNVERIFIED whether any workspace-level lint is inherited from a parent — see caveat below; no parent `[workspace.lints]` found in scanned Cargo.toml.)
- Remaining 14 textual hits are non-`unsafe`-keyword: identifiers (`path_unsafe`, `requires_unsafe_research`, `unsafe_exploit_attempt`), string literals (`"unsafe"` forbidden-pattern, error messages), and comments.

---

## PER-HIT TABLE (all 19 textual hits)

| # | file:line | enclosing context (1-2 lines) | kind | SAFETY adjacent? |
|---|-----------|-------------------------------|------|------------------|
| 1 | src/bin/turingos/cmd_llm.rs:1568 | `// edits cascade unpredictably, so v2 → v1 promotion is unsafe without a` | comment | n/a |
| 2 | src/bin/full_system_augment_current_kernel.rs:691 | `"ArchitectAI proposes no unsafe kernel write; runtime evidence remains tape-bound"` | string literal | n/a |
| 3 | src/bin/cybench_security_sandbox_current_kernel.rs:230 | `unsafe_exploit_attempt: bool,` (struct field) | identifier | n/a |
| 4 | src/bin/cybench_security_sandbox_current_kernel.rs:548 | `"unsafe_live_target_contact"` | string literal | n/a |
| 5 | src/bin/cybench_security_sandbox_current_kernel.rs:553 | `Some("unsafe_exploit_attempt".to_string())` | string literal | n/a |
| 6 | src/bin/cybench_security_sandbox_current_kernel.rs:759 | `unsafe_exploit_attempt: live_target_contacted,` | identifier (field init) | n/a |
| 7 | src/web/artifact.rs:70 | `"artifact name {:?} contains invalid or unsafe characters",` | string literal | n/a |
| 8 | src/runtime/market_review.rs:23 | `/// default, barriered async is scaffold-only, full async is unsafe research.` | doc comment | n/a |
| 9 | src/runtime/market_review.rs:32 | `/// TRACE_MATRIX FC1: guards unrestricted full async behind unsafe research.` | doc comment | n/a |
| 10 | src/runtime/market_review.rs:33 | `pub const fn requires_unsafe_research(self) -> bool {` | identifier (fn name) | n/a |
| 11 | src/runtime/attempt_telemetry.rs:167 | `/// Candidate contained a forbidden `sorry` (or equivalent unsafe` | doc comment | n/a |
| 12 | **src/runtime/chain_tape_lease.rs:295** | `let rc = unsafe { libc::kill(pid, 0) };` (in `fn is_pid_alive`) | **REAL unsafe block (FFI)** | **n** (doc comment on fn, no `// SAFETY:` on block) |
| 13 | **src/runtime/chain_tape_lease.rs:312** | `unsafe { *libc::__errno_location() }` (in `fn last_errno`, linux cfg) | **REAL unsafe block (FFI)** | **n** (group doc comment above, no `// SAFETY:`) |
| 14 | **src/runtime/chain_tape_lease.rs:318** | `unsafe { *libc::__error() }` (in `fn last_errno`, macos cfg) | **REAL unsafe block (FFI)** | **n** (group doc comment above, no `// SAFETY:`) |
| 15 | src/judges/generate_judge.rs:122 | `fn path_unsafe(path: &str) -> bool {` | identifier (fn name) | n/a |
| 16 | src/judges/generate_judge.rs:182 | `if path_unsafe(path) {` | identifier (call) | n/a |
| 17 | src/judges/generate_judge.rs:185 | `reason: format!("unsafe path: {}", path),` | string literal | n/a |
| 18 | src/top_white/predicates/registry.rs:629 | `"unsafe".to_string(),` (forbidden-pattern list entry) | string literal | n/a |
| 19 | **src/bottom_white/ledger/system_keypair.rs:1118** | `unsafe { libc::mlock(ptr.cast(), len) == 0 }` (in `fn mlock_os_best_effort`) | **REAL unsafe block (FFI)** | **y** (lines 1116-1117: `// SAFETY: ptr and len come from a live boxed private-key byte slice ... mlock does not take ownership and failure is non-fatal.`) |

---

## Detailed context for the 4 real `unsafe` blocks

### src/runtime/chain_tape_lease.rs:295  (`fn is_pid_alive`)
```rust
/// POSIX `kill -0 <pid>` — return true if the pid corresponds to a
/// live process or a zombie awaiting reaping; false otherwise. On
/// Linux/macOS this uses `libc::kill(pid, 0)` and treats `ESRCH` as
/// dead. Any other errno (e.g. `EPERM` on a foreign-uid process) is
/// treated as alive — over-conservative refuses to steal the lease.
fn is_pid_alive(pid: i32) -> bool {
    if pid <= 0 { return false; }
    let rc = unsafe { libc::kill(pid, 0) };   // <-- line 295
    ...
}
```
SAFETY comment adjacent to the block: **NO** (function has a descriptive doc comment but no `// SAFETY:` annotation on/above the unsafe block).

### src/runtime/chain_tape_lease.rs:312 (linux) and :318 (macos)  (`fn last_errno`)
```rust
// Thread-local errno accessor. glibc exposes it via `__errno_location`,
// Darwin via `__error`; both return a `*mut c_int` with identical
// semantics. ...
#[cfg(target_os = "linux")]
#[inline]
fn last_errno() -> i32 {
    unsafe { *libc::__errno_location() }   // <-- line 312
}
#[cfg(target_os = "macos")]
#[inline]
fn last_errno() -> i32 {
    unsafe { *libc::__error() }            // <-- line 318
}
```
SAFETY comment adjacent: **NO** for both (a shared explanatory comment precedes the cfg group; no `// SAFETY:` annotation).

### src/bottom_white/ledger/system_keypair.rs:1118  (`fn mlock_os_best_effort`)
```rust
#[cfg(unix)]
fn mlock_os_best_effort(ptr: *const u8, len: usize) -> bool {
    // SAFETY: `ptr` and `len` come from a live boxed private-key byte slice in
    // `Ed25519Keypair`; mlock does not take ownership and failure is non-fatal.
    unsafe { libc::mlock(ptr.cast(), len) == 0 }   // <-- line 1118
}
```
SAFETY comment adjacent: **YES** (lines 1116-1117 directly above the block).

---

## Caveats / UNVERIFIED

- Tooling substitution (BSD grep for `command rg`) means the runbook's exact `rg` invocation was NOT reproducible on this host; the substitute commands above are what actually ran. Search semantics are equivalent for plain-substring `unsafe` matching.
- `target/` was excluded to avoid vendored/build-artifact noise; no `examples/` or `benches/` dirs surfaced any `unsafe`.
- No workspace-root `[workspace.lints]` inheriting `unsafe_code` was found in scanned Cargo.toml files; whether a parent workspace (outside this clone root) injects such a lint is **UNVERIFIED** (scan was scoped to the clone tree).

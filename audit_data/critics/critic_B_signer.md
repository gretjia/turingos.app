# R1.9 port-readiness audit — critic_B — module: signer

Module under review: `src/bottom_white/ledger/system_keypair.rs` (1170 LOC, scratch clone anchor main 1f00012d at `/Users/zephryj/work/.audit-scratch/turingosv4-main`).
Clean-context independent review. Advisory channel only — no verdicts, no fixes proposed.

Consulted in addition to the module: `src/bottom_white/ledger/mod.rs`, `src/bottom_white/mod.rs`,
`tests/system_keypair_sign_only_from_runner.rs`, `tests/system_keypair_verify_correctness.rs`,
`tests/system_keypair_load_and_decrypt.rs`, `tests/system_keypair_rotation_proof.rs`,
caller greps over `src/state/sequencer.rs`, `src/runtime/mod.rs`, `src/bottom_white/ledger/transition_ledger.rs`,
`src/boot.rs`, and `scripts/constitution_gates.manifest.toml` (which has NO entry naming
system_keypair — the four dedicated tests are plain integration tests, not manifest-governed
constitution gates; the manifest header scopes itself to `tests/constitution_*.rs`).

---

## Scored dimensions (1–5)

### 1. boundary_wrappability — 4
- Signing authority is correctly capability-scoped: all signers live in `pub(crate)` modules —
  `pub(crate) mod predicate_runner` (system_keypair.rs:627), `pub(crate) mod terminal_summary_emitter`
  (:663), `pub(crate) mod transition_ledger_emitter` (:840) — and route through one private
  `sign_system_message_inner` (:859). No public signing function exists; the public face is
  verify-only (`verify_system_signature` :586, `verify_epoch_rotation_proof` :605) plus typed
  value types with `from_bytes`/`as_bytes` accessors. A structural gate pins this
  (tests/system_keypair_sign_only_from_runner.rs:5–23).
- `Ed25519Keypair` deliberately has no `Debug` derive (only `Zeroize, ZeroizeOnDrop`, :324) —
  confirmed intentional by src/state/sequencer.rs:4977–4978 ("no Debug derive ... intentional").
  Secrets cannot leak through a facade's logging.
- Deductions: the pub face is broad (38 `pub`/`pub(crate)` item declarations by grep) and a large
  slice of it is dormant — `default_system_keystore_path` (:455), `generate_or_load_system_keypair`
  (:467), `load_existing_keypair` (:482) have zero `src/` callers (rg over src/ returns only the
  definitions); a CLI/lib facade must wrap or consciously hide unwired surface. Ambient env-var
  config leaks through any wrapper: `TURINGOS_KEYSTORE_PATH` (:456) and `TURINGOS_KDF_MEMORY_KIB`/
  `TURINGOS_KDF_ITER`/`TURINGOS_KDF_LANES` (:960–962). `verify_system_pubkeys` couples this ledger
  module to `crate::boot::TrustRootError` (:11, :617).

### 2. error_discipline — 4
- `Result` is carried end-to-end with a semantic error taxonomy: `KeypairError` has 7 documented
  variants — Io/Entropy/KdfParam/Kdf/Crypto/InvalidFormat/HomeUnavailable (:409–425) — with
  `Display` (:427–441), `std::error::Error` (:443), and `From<std::io::Error>` (:445–449).
- Zero panic surface in production code: `rg 'unwrap\(|expect\(|panic!|unreachable!'` hits only
  the `#[cfg(test)]` block (:1132, :1135, :1149–1150, :1159, :1161). Parsing is fail-closed with
  bounds-checked cursor reads (`Cursor::read` checked_add + length check, :1052–1063;
  "trailing bytes" rejection :1030–1031).
- Deductions: verification collapses all failure causes to `bool` via let-else (:592–596) — unknown
  epoch vs malformed pinned key vs bad signature are indistinguishable to callers and operators
  (fail-closed, but diagnostics-free). On the decrypt-failure path the derived key is NOT zeroized:
  `cipher.decrypt(...).map_err(...)?` (:491–496) early-returns before `key.zeroize()` (:497) —
  error-path hygiene is weaker than the happy path.

### 3. invariant_documentation — 4
- The governing invariants are written down at the point of enforcement: module doc pins the
  external spec `handover/specs/SYSTEM_KEYPAIR_SECURITY_v1_2026-04-27.md` plus KDF defaults
  (:1–7); the "all sign goes through CanonicalMessage" invariant is stated verbatim (:252–253);
  domain separation is explicit (`h.update(b"turingosv4.system_keypair.v1")`, :504) with per-variant
  tag strings (:507–579) and length-prefixed string hashing (`update_len_prefixed`, :1080–1083).
- Wire-determinism of the 64-byte signature serde is documented (":85–91 'deterministic,
  platform-stable'" and :99–105 explaining the no-length-prefix tuple encoding); the single
  `unsafe` block carries a SAFETY comment (:1116–1118). The sign-scope invariant is asserted by a
  dedicated test (tests/system_keypair_sign_only_from_runner.rs:5–31).
- Deductions: enforcement of that invariant is source-text `contains()` matching, and its last
  clause (`!src.contains("&[u8]") || src.contains("canonical_digest(message)")`, test :29) is
  near-tautological. The zeroize/mlock secrecy invariants (:323, :1116–1118) are documented but
  asserted nowhere. Digest determinism has no golden-vector assertion anywhere (see test_depth).

### 4. test_depth — 3
- The dedicated integration tests do test beyond happy path with real negative assertions:
  wrong-epoch lookup rejected (tests/system_keypair_verify_correctness.rs:27–32), tampered
  message rejected (:34–42); wrong password fails authenticated decryption
  (tests/system_keypair_load_and_decrypt.rs:59–63, with disciplined EnvGuard/env_lock hygiene
  :8–34); swapped rotation signature rejected (tests/system_keypair_rotation_proof.rs:37–44).
- Deductions: the in-module `#[cfg(test)]` block holds only 2 happy-path round trips
  (system_keypair.rs:1130–1169). All verification tests are sign-then-verify against the same
  code — no golden/known-answer digest or signature vector pins `canonical_digest` (:502–583)
  across versions/platforms, despite the doc claiming "deterministic, platform-stable" (:88–89);
  a digest-definition change would pass every existing test. The keystore binary parser
  `EncryptedKeypair::decode` (:1011–1039) — bad magic, bad version, truncation, trailing bytes —
  has zero negative tests, and `read_env_u32`'s three error branches (:967–983: non-u32, zero,
  non-unicode) are untested.

### 5. concurrency_safety — 4
- The module is lock-free and immutable-after-construction by design: `rg 'Mutex|RwLock|spawn'`
  inside the module returns nothing; every `Ed25519Keypair` operation is `&self`, and
  `sign_digest` copies the secret to a stack array per call then zeroizes (:386–393) —
  re-entrant with no interior mutability. Shared in production as `Arc<Ed25519Keypair>`
  (src/state/sequencer.rs:4995, src/runtime/mod.rs:773), so Send+Sync is compiler-enforced via
  the auto traits of `Box<[u8]>` + copy types.
- Deductions: no explicit Send/Sync documentation or static assertion exists in the module.
  Blocking points are undocumented: Argon2id at m=64 MiB, t=3 (:27–29, :907–911) makes
  `load_existing_keypair` a long CPU+memory-bound call unsuitable for an async executor thread,
  flagged nowhere. Env-var coupling (`KdfParams::from_env` :958–964) is process-global state;
  the burden it pushes onto callers is visible in the integration test having to build its own
  `env_lock()` mutex to serialize tests (tests/system_keypair_load_and_decrypt.rs:8–11).

### 6. dead_code_density — 4
- By the literal rubric the file is clean: zero `allow(dead_code)`, zero commented-out code
  blocks (the only `//` block comments are explanatory traceability notes, :179–184), and exactly
  one TODO in 1170 LOC (`TODO(CO1.7)`, :621–622).
- Deductions: that one TODO is load-bearing — `verify_system_pubkeys` (:617–624) is a fail-open
  stub (details in findings), and its private helpers `has_toml_section` (:1085–1093) +
  `strip_comment` (:1095–1105) are transitively dead, reachable only through the uncalled stub,
  and duplicate an existing `strip_comment` in src/boot.rs:366. Beyond rubric: substantial pub
  surface is dormant (keystore-at-rest lifecycle :451–499 + :866–1078, `EpochRotationProof`
  surface :186–223/:605–614, `predicate_runner` scope :627–651 — none has a production caller;
  runtime generates per-run in-memory keypairs instead, src/runtime/mod.rs:782 and :1011).

---

## RiskFindings (advisory JSONL)

{"finding_id":"rsk_verify_system_pubkeys_fail_open_stub","schema_version":"tos.app.riskfinding.v0","severity":"risk","finding":"src/bottom_white/ledger/system_keypair.rs:617-624 — pub fn verify_system_pubkeys is named as a verifier but unconditionally returns Ok(()): when no [system_pubkeys] section exists it returns Ok, and when the section IS present it hits TODO(CO1.7) (line 621-622) and still returns Ok without parsing or verifying any creator signature. It currently has zero callers anywhere (rg over src/, tests/, scripts/ returns only the definition), so nothing is broken today, but it is a publicly exported fail-open gate with a verification name — any future boot wiring that calls it will silently pass unverified genesis pubkey sections. This is exactly the name-lie-gate class the repo's own forensic gates target.","author":"critic_B"}
{"finding_id":"rsk_load_path_secret_not_zeroized","schema_version":"tos.app.riskfinding.v0","severity":"attention","finding":"src/bottom_white/ledger/system_keypair.rs:482-499 — load_existing_keypair leaves secret material in freed heap on both success and failure paths. The decrypted plaintext Vec (line 491-496) contains the 32-byte private key and is never zeroized before drop, in contrast to encrypt_at_rest which zeroizes its plaintext (line 883). Additionally, the derived ChaCha20 key is only zeroized at line 497 AFTER the decrypt call; the `.map_err(...)?` on lines 491-496 early-returns on authentication failure, skipping key.zeroize() — so a wrong-password attempt leaves the Argon2-derived key un-scrubbed. The encrypt path (lines 866-893) handles both correctly, making the load path an asymmetric hygiene gap.","author":"critic_B"}
{"finding_id":"rsk_kdf_header_unauthenticated_dos","schema_version":"tos.app.riskfinding.v0","severity":"attention","finding":"src/bottom_white/ledger/system_keypair.rs:866-893 + 1011-1039 — the keystore header (KDF memory_kib/iterations/lanes, salt, nonce) is not bound into the AEAD as associated data: cipher.encrypt at line 881 covers only the plaintext, and decode at lines 1019-1023 trusts header-supplied KDF params before any authentication. A locally tampered keystore file can therefore set memory_kib to u32::MAX (~4 TiB Argon2 memory request) and drive derive_key (lines 895-913) into pre-authentication resource exhaustion at load time; integrity is only checked after the full KDF runs. Tampering with salt/nonce/params otherwise only yields a clean Crypto('keystore authentication failed') error, so this is a DoS-at-load concern, not a confidentiality break.","author":"critic_B"}
{"finding_id":"rsk_dormant_keystore_and_rotation_surface","schema_version":"tos.app.riskfinding.v0","severity":"info","finding":"src/bottom_white/ledger/system_keypair.rs — a large fraction of the module's pub surface has no production caller: the entire encrypted keystore-at-rest lifecycle (default_system_keystore_path :455, generate_or_load_system_keypair :467, load_existing_keypair :482, encrypt_at_rest/write_keystore_0600/KdfParams/EncryptedKeypair/Cursor :866-1078), the epoch-rotation surface (EpochRotationProof :186-223, verify_epoch_rotation_proof :605-614, sign_epoch_rotation_proof :815-823), and the predicate_runner signing scope (:627-651) are exercised only by tests. Production runtime instead generates a fresh in-memory per-run keypair (src/runtime/mod.rs:782 and :1011) and pins it via pinned_pubkeys.json. For the port: the live load-bearing surface is canonical_digest + verify_system_signature + Ed25519Keypair::generate_with_secure_entropy + terminal_summary_emitter (src/state/sequencer.rs:5518-5767) + transition_ledger_emitter (src/state/sequencer.rs:7033); the rest is spec-complete but unwired and should be ported as dormant capability, not assumed active.","author":"critic_B"}
{"finding_id":"rsk_mlock_silent_and_no_munlock","schema_version":"tos.app.riskfinding.v0","severity":"info","finding":"src/bottom_white/ledger/system_keypair.rs:1107-1124 — mlock_os_best_effort locks the private-key page (unsafe libc::mlock, line 1118, with a proper SAFETY comment) but the module never calls munlock (rg 'munlock' returns nothing), so pages stay locked for process lifetime even after the keypair drops, and since the Box<[u8]> is 32 bytes the lock covers a full page of unrelated heap. The boolean result is silently discarded at both call sites (lines 343 and 374), so RLIMIT_MEMLOCK failures (lock not actually applied; key swappable) leave no trace in logs or telemetry. Best-effort semantics are documented (lines 1116-1117), so this is informational, but the port target should decide whether 'silently maybe-locked' is acceptable for its threat model.","author":"critic_B"}
{"finding_id":"rsk_structural_gate_substring_false_pass","schema_version":"tos.app.riskfinding.v0","severity":"info","finding":"tests/system_keypair_sign_only_from_runner.rs:1-32 — the gate protecting the 'no public free-form signing API' invariant is implemented as substring matching over include_str! of the source file. Its final clause (line 29: assert !src.contains(\"&[u8]\") || src.contains(\"canonical_digest(message)\")) is satisfied by the mere presence of the literal text 'canonical_digest(message)' anywhere in the file — even inside a comment — so a future public byte-slice signer would not trip it. The earlier clauses (lines 5-23) are similarly evadable by renaming or reformatting (e.g. 'pub fn sign_system_message' with an extra space or a re-export under a different name). Grep-style conformance gates of this class are known to false-pass; a compile-visibility or trybuild-style check would actually bind the invariant.","author":"critic_B"}
{"finding_id":"rsk_zero_default_signature_footgun","schema_version":"tos.app.riskfinding.v0","severity":"info","finding":"src/bottom_white/ledger/system_keypair.rs:93-97 — SystemSignature implements Default as all-zero 64 bytes. Combined with Default-deriving transaction structs in src/state/typed_tx.rs (multiple #[derive(.., Default)] rows around lines 4357-4746 use explicit from_bytes fills in tests, but struct-update syntax `..Default::default()` is pervasive in the codebase), a forgotten signing step yields a well-typed, plausible-looking signature value that only fails at verify time — and only if the path actually verifies. Fail-closed verification (verify_system_signature returns false for it) bounds the blast radius, so informational: the footgun is silent-construction, not silent-acceptance.","author":"critic_B"}

---

## Summary

system_keypair.rs is one of the most disciplined modules a critic could ask for at the
crypto-core: signing authority is locked behind `pub(crate)` capability modules funneling
through a single private signer (:627/:663/:840 → :859), the error enum is semantic and
Result-carried with a panic surface of exactly zero outside `#[cfg(test)]`, domain-separated
digesting is explicit and length-prefixed (:504, :1080), zeroize-on-drop plus best-effort mlock
covers the in-memory key, and the four dedicated integration tests assert real negatives
(wrong epoch, tampered message, wrong password, swapped rotation signature). The weaknesses
cluster at the edges, and they matter for a port: a publicly exported fail-open verifier stub
(`verify_system_pubkeys`, :617–624) that nothing calls yet; an asymmetric secret-hygiene gap on
the decrypt path (plaintext Vec and error-path derived key never zeroized, :491–497, vs. the
clean encrypt path :879–884); an unauthenticated KDF header enabling pre-auth Argon2 memory
DoS on a tampered keystore; no golden digest vector pinning the "deterministic, platform-stable"
claim (all tests are self-referential sign-then-verify); an untested binary keystore parser
(:1011–1039); and the fact that roughly a third of the pub surface — the entire at-rest keystore
lifecycle, epoch rotation, and the predicate_runner scope — is dormant spec-completion with no
production caller (runtime uses fresh per-run keys, src/runtime/mod.rs:782/:1011). The
sign-scope invariant's only enforcement is a substring-matching gate that can false-pass. Net:
a strong wrap-ready core whose live surface is small and clean, surrounded by dormant capability
that the port must consciously classify rather than blindly carry.

Scores: boundary_wrappability 4 · error_discipline 4 · invariant_documentation 4 · test_depth 3 · concurrency_safety 4 · dead_code_density 4

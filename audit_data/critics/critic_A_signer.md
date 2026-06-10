# Critic A — signer module (src/bottom_white/ledger/system_keypair.rs)

R1.9 port-readiness audit. Clean context. Repo: scratch clone at anchor main 1f00012d
(`/Users/zephryj/work/.audit-scratch/turingosv4-main`). Module: 1170 LOC. All line
numbers below were read directly from the clone; nothing is inferred from other
auditors' output.

Context established before scoring:

- Module is trust-root-pinned: `genesis_payload.toml:347` pins the file's SHA-256
  ("src/bottom_white/ledger/system_keypair.rs" = "32703a2a…"), and
  `genesis_payload.toml:354-358` pin all five dedicated integration test files.
- Five dedicated integration tests exist: `tests/system_keypair_generation.rs` (80 LOC),
  `tests/system_keypair_load_and_decrypt.rs` (64), `tests/system_keypair_verify_correctness.rs` (43),
  `tests/system_keypair_rotation_proof.rs` (45), `tests/system_keypair_sign_only_from_runner.rs` (32).
  None of these match the `tests/constitution_*.rs` discovery pattern in
  `scripts/run_constitution_gates.sh:15`, so they run under `cargo test --workspace`
  but are NOT in the constitution gate manifest (`scripts/constitution_gates.manifest.toml`
  has no `system_keypair` entry — verified by grep).
- Direct callers in src/: 13 files including `src/state/sequencer.rs` and
  `src/runtime/mod.rs` (keypair held as `Arc<Ed25519Keypair>`, sequencer.rs:4995,
  runtime/mod.rs:773).

## 1. boundary_wrappability — 4/5

Strong, intentional surface. Deduction for hidden env-var inputs and one dead pub stub.

Evidence:
- Signing is crate-only by construction: `pub(crate) mod predicate_runner` (line 627),
  `pub(crate) mod terminal_summary_emitter` (line 663), `pub(crate) mod
  transition_ledger_emitter` (line 840); the only root signer is the private
  `fn sign_system_message_inner` (line 859). A facade can expose verify + keystore
  lifecycle without ever leaking a signing capability.
- All struct fields are private with accessor methods: e.g. `SystemPublicKey` exposes
  only `from_bytes`/`as_bytes`/`fingerprint_sha256` (lines 68-83); `EpochRotationProof`
  fields private with `old_epoch()`/`new_epoch()` accessors (lines 196-223).
- Cross-module coupling is deliberately severed via opaque digests: "this variant only
  carries the 32-byte digest into the typed sign API … avoids a circular
  `system_keypair ↔ state` module dependency" (lines 233-236; same pattern lines 249-254).
- Scope is gate-tested: `tests/system_keypair_sign_only_from_runner.rs:13-16` asserts
  `!src.contains("pub fn sign_system_message")` ("root public sign_system_message must
  not be exported").
- Deductions: (a) configuration enters via process env, not parameters —
  `TURINGOS_KEYSTORE_PATH` override (line 456) and `TURINGOS_KDF_MEMORY_KIB`/`ITER`/`LANES`
  (lines 960-962); a lib/CLI facade cannot inject KDF cost without mutating global env.
  (b) `pub fn verify_system_pubkeys` (line 617) is a no-op stub with zero callers
  repo-wide (rg over src/, tests/, scripts/ finds only the definition) sitting on the
  public surface. (c) `KeypairError` (line 410) is not `#[non_exhaustive]`, so adding a
  variant breaks downstream matches — minor for a port.

## 2. error_discipline — 5/5

Result-typed end to end with a semantic error taxonomy; zero panic surface in
production code.

Evidence:
- `rg 'unwrap\(|expect\(|panic!'` over the module hits ONLY the `#[cfg(test)]` block
  (lines 1132, 1135, 1149, 1150, 1159, 1161). No production unwrap/expect/panic.
- `KeypairError` is a 7-variant semantic enum — `Io / Entropy / KdfParam / Kdf / Crypto /
  InvalidFormat / HomeUnavailable` (lines 410-425) — with `fmt::Display` giving
  distinct prefixed messages (lines 427-441, e.g. "system keypair keystore invalid: {msg}"),
  `impl std::error::Error` (line 443), and `From<std::io::Error>` (lines 445-449).
- Crypto failures are mapped, not unwrapped: AEAD decrypt failure becomes
  `KeypairError::Crypto("keystore authentication failed")` (line 496); cipher-key error
  becomes `Crypto("bad cipher key")` (line 490).
- Input validation is fail-closed with named reasons: `from_plaintext` rejects mismatched
  halves with `InvalidFormat("public key does not match private key")` (lines 362-367);
  `read_env_u32` rejects zero ("must be non-zero", line 974) and non-unicode env values
  (lines 979-981); `decode` rejects bad magic / bad version / truncation / trailing bytes
  (lines 1014, 1017, 1058, 1031).
- Minor (not score-affecting): `verify_system_signature` returns bare `bool`
  (lines 586-602), flattening "epoch not pinned" vs "bad signature" — a deliberate
  verifier pattern, but diagnostics-poor; and `KeypairError` does not implement
  `source()` chaining.

## 3. invariant_documentation — 4/5

Key invariants are written down and mostly mechanically enforced; the determinism
invariant lacks a pinned assertion (see test_depth / RiskFinding).

Evidence:
- Module doc binds to a spec: "Runtime system keypair lifecycle per
  `handover/specs/SYSTEM_KEYPAIR_SECURITY_v1_2026-04-27.md`" with KDF defaults
  documented "m=64 MiB, t=3, p=4" (lines 1-7).
- Wire-determinism invariant written at the type: serde adapter doc states
  "deterministic, platform-stable" 64 raw bytes under bincode fixed_int_encoding
  (lines 88-89, 99-101).
- The central signing invariant is stated twice and enforced: "preserving the 'all sign
  goes through CanonicalMessage' invariant" (line 253); "No raw digest signer escapes
  this module" (lines 838-839); enforced by `tests/system_keypair_sign_only_from_runner.rs`
  (lines 5-31) and by trust-root file-hash pinning (`genesis_payload.toml:347`).
- Domain separation is implemented, not just claimed: `canonical_digest` prefixes
  `b"turingosv4.system_keypair.v1"` (line 504) plus a per-variant tag, and string fields
  are length-prefixed via `update_len_prefixed` (lines 1080-1083).
- Format invariants asserted at decode: magic (line 1013), version (line 1016),
  exact-consumption "trailing bytes" check (lines 1030-1031); keypair consistency
  asserted at load (lines 362-367).
- The single `unsafe` block carries a SAFETY comment: "ptr and len come from a live
  boxed private-key byte slice … failure is non-fatal" (lines 1116-1118).
- Deduction: the digest/encoding determinism invariant is documented but never pinned
  to a golden value anywhere in tests (all checks are round-trips), and the mlock
  best-effort result is silently discarded (lines 343, 374) despite the function
  returning `bool` for observability.

## 4. test_depth — 4/5

Genuinely non-tautological negatives and one independent-reconstruction test; gaps in
format-parser error paths and no golden vectors.

Evidence (tests actually read):
- `tests/system_keypair_verify_correctness.rs` builds the signature with raw
  `ed25519_dalek::SigningKey` directly (lines 9, 19-20) — NOT through the module's sign
  path — then asserts verify passes (line 24), fails for the wrong epoch
  (lines 27-32), and fails for a tampered message (lines 34-42). Cross-implementation,
  not a round-trip tautology.
- `tests/system_keypair_load_and_decrypt.rs:59-63`: wrong password must fail
  authenticated decryption (negative path on AEAD).
- `tests/system_keypair_generation.rs:56-61`: property check that the public key bytes
  do not appear in the at-rest envelope ("public key is inside authenticated ciphertext,
  not cleartext envelope") via a 32-byte sliding-window scan; lines 63-72 assert exact
  0600 mode on unix.
- `tests/system_keypair_rotation_proof.rs:37-44`: rotation proof rejected when the new
  signature is forged with the old key.
- In-module `#[cfg(test)]` (lines 1126-1170): two happy-path round-trips only.
- Gaps: (a) no golden/pinned expected value for `canonical_digest` or any signature —
  every digest test is sign-then-verify through the same encoding code, so an encoding
  drift (tag rename, field reorder) keeps all tests green while invalidating every
  historical on-tape signature; (b) `EncryptedKeypair::decode` error branches
  (lines 1014, 1017, 1031, 1058) have no corrupted-keystore test; (c) `read_env_u32`
  zero/garbage rejection (lines 967-983) untested; (d) tests run KDF at floor params
  (`TURINGOS_KDF_MEMORY_KIB=64`, ITER=1 — generation.rs:45-47), so production defaults
  are never exercised (acceptable for speed, noted for completeness).

## 5. concurrency_safety — 4/5

No locks needed by design; shared-state hazards are at the env and filesystem
boundaries, both handled fail-closed but undocumented as blocking points.

Evidence:
- `Ed25519Keypair` is immutable after construction; signing takes `&self` and copies the
  secret to a stack buffer that is zeroized after use (lines 386-393). No interior
  mutability → auto `Send + Sync` is sound, and callers rely on it:
  `Arc<Ed25519Keypair>` in `src/state/sequencer.rs:4995` and `src/runtime/mod.rs:773`.
- Keystore creation is race-fail-closed: `options.write(true).create_new(true)`
  (line 921) means a concurrent creator gets `Io(AlreadyExists)` rather than
  overwriting key material. However there IS a TOCTOU between
  `keystore_path.exists()` (line 471) and the `create_new` write — the losing
  first-boot gets a raw Io error instead of falling back to loading the winner's key.
- Process-global env is read at runtime: `KdfParams::from_env` (lines 958-964) and
  `default_system_keystore_path` (lines 456-459). Integration tests acknowledge the
  hazard with a per-binary `static ENV_LOCK: OnceLock<Mutex<()>>`
  (tests/system_keypair_generation.rs:8-11) — the discipline lives in the tests, not in
  the module's docs.
- Blocking points are real but unmarked: Argon2id at default m=64 MiB / t=3 / p=4
  (lines 27-29, 907-911) is a heavy synchronous call on the load path, and
  `file.sync_all()` (line 925) blocks on fsync; neither is documented as
  "do not call on a latency-sensitive thread".

## 6. dead_code_density — 4/5

Nearly clean; one TODO attached to a dead, fail-open pub stub.

Evidence:
- Exactly one TODO in 1170 lines: "TODO(CO1.7): parse genesis_payload.toml
  [system_pubkeys] entries and verify creator PGP signatures" (lines 621-622), inside
  `pub fn verify_system_pubkeys` (line 617) which has zero callers repo-wide and
  returns `Ok(())` on both branches (lines 618-623).
- `rg 'allow\(dead_code\)|#\[allow|FIXME'` over the module: zero hits. No
  commented-out code blocks observed in the full read.
- Cosmetic only: line 9 nests a `///` marker inside the `//!` module doc
  ("//! /// TRACE_MATRIX FC1-Sig+FC3-Sig: …"). The dense TRACE_MATRIX annotations
  throughout are traceability metadata, not dead code.

## RiskFindings (advisory channel)

{"finding_id":"rsk_verify_system_pubkeys_fail_open_stub","schema_version":"tos.app.riskfinding.v0","severity":"attention","finding":"src/bottom_white/ledger/system_keypair.rs:617-624: pub fn verify_system_pubkeys is a name-lie fail-open stub — it returns Ok(()) unconditionally (early Ok when the [system_pubkeys] section is absent, and Ok after the TODO(CO1.7) comment when it IS present), performing no verification whatsoever. It has zero callers across src/, tests/, and scripts/ (grep-verified), and genesis_payload.toml currently has no [system_pubkeys] section, so nothing is broken today; but any future boot wiring that calls this function by its name will silently believe creator-PGP verification happened. For the port, either implement, rename to a check_-nothing placeholder, or drop it from the public surface.","author":"critic_A"}
{"finding_id":"rsk_canonical_digest_no_golden_vector","schema_version":"tos.app.riskfinding.v0","severity":"attention","finding":"src/bottom_white/ledger/system_keypair.rs:502-583 (canonical_digest) defines the wire-level domain-separated digest for all 17 CanonicalMessage variants (prefix b\"turingosv4.system_keypair.v1\" at line 504 plus per-variant tags), and these digests are what get signed onto ChainTape. No test anywhere pins an exact expected digest or signature byte vector — tests/system_keypair_verify_correctness.rs and the in-module tests (lines 1130-1169) are all sign-then-verify round-trips through the same encoding code. A refactor that renames a tag, reorders EpochRotationProof fields (lines 525-532), or changes the length-prefix scheme (update_len_prefixed, lines 1080-1083) would keep every test green while invalidating all historical on-tape signatures. A golden-vector test (fixed key, fixed message, exact digest+signature bytes) is the standard guard and is cheap; the port should add one before re-anchoring evidence.","author":"critic_A"}
{"finding_id":"rsk_sign_scope_gate_is_textual","schema_version":"tos.app.riskfinding.v0","severity":"attention","finding":"tests/system_keypair_sign_only_from_runner.rs enforces the constitutional 'signing is crate-only' invariant by include_str! + substring contains over the source (lines 3-31). The checks are bypassable without tripping: (a) `pub use self::terminal_summary_emitter;` does not contain the checked string \"pub use terminal_summary_emitter\" (line 19-21 checks lack the self:: form); (b) a new `pub fn sign_anything(...)` in the same file calling the private sign_system_message_inner (src/bottom_white/ledger/system_keypair.rs:859) would pass because only the exact name \"pub fn sign_system_message\" is forbidden (line 14). Mitigating controls exist — the file hash is trust-root-pinned in genesis_payload.toml:347 so any edit is a Class-4 event — but the gate itself is textual, and this test is not in scripts/constitution_gates.manifest.toml (it runs only under cargo test --workspace, not the constitution gate runner whose discovery pattern is tests/constitution_*.rs per scripts/run_constitution_gates.sh:15). The port should consider a compile-time visibility test (e.g., a trybuild fail case importing the signer from outside the crate) and/or promoting the gate into the manifest namespace.","author":"critic_A"}
{"finding_id":"rsk_kdf_header_unauthenticated_unbounded","schema_version":"tos.app.riskfinding.v0","severity":"attention","finding":"src/bottom_white/ledger/system_keypair.rs: the keystore header fields (kdf memory_kib/iterations/lanes, salt, nonce — written at lines 1001-1005) are stored OUTSIDE the AEAD and are not bound as associated data; decode trusts them verbatim (lines 1019-1027) and derive_key runs Argon2id at whatever cost the file claims (lines 895-913). Consequences: (1) decrypt-time resource exhaustion — an attacker or corruption that sets memory_kib near u32::MAX forces a multi-TiB allocation attempt on load before any authentication check (tampering with salt/nonce/params can only cause decrypt failure or DoS, not key disclosure, since the derived key changes); (2) no lower floor at encrypt time — read_env_u32 rejects only zero (line 974), so TURINGOS_KDF_MEMORY_KIB=1 silently produces a keystore far below the documented OWASP defaults (module doc lines 4-7), and the integration tests themselves run at m=64 KiB / t=1 (tests/system_keypair_generation.rs:45-47), proving the floor is reachable. The port should cap header KDF params at decode and enforce a sane minimum (or warn) at encrypt.","author":"critic_A"}
{"finding_id":"rsk_keystore_decode_error_paths_untested","schema_version":"tos.app.riskfinding.v0","severity":"info","finding":"src/bottom_white/ledger/system_keypair.rs: EncryptedKeypair::decode's rejection branches — bad magic (line 1014), bad version (line 1017), truncated keystore (line 1058), trailing bytes (line 1031), offset overflow (line 1056) — have no test exercising corrupted or truncated keystore bytes; the only decode-adjacent negative is the wrong-password AEAD failure in tests/system_keypair_load_and_decrypt.rs:59-63, which never reaches the format parser's error arms. EncryptedKeypair is a private type, so the only test route is feeding a mangled file to load_existing_keypair — a few byte-flip/truncation cases would cover all five branches.","author":"critic_A"}
{"finding_id":"rsk_mlock_result_ignored_no_munlock","schema_version":"tos.app.riskfinding.v0","severity":"info","finding":"src/bottom_white/ledger/system_keypair.rs: mlock_private_key_best_effort returns bool (line 403) but both call sites discard it (lines 343 and 374) with no log/telemetry, so an operator never learns the private key is swappable (e.g., RLIMIT_MEMLOCK exhausted). Additionally there is no munlock pairing on drop: the unsafe libc::mlock at line 1118 locks the page containing the boxed secret, and when Ed25519Keypair drops (ZeroizeOnDrop, line 324) the allocation is freed while the page may remain locked — across repeated epoch rotations (new keypair per epoch, src/runtime/mod.rs:1010-1015) locked-page accounting can accumulate. Best-effort is documented in the SAFETY comment (lines 1116-1117), so this is hygiene, not a defect; the port should surface the bool and add munlock-on-drop.","author":"critic_A"}
{"finding_id":"rsk_first_boot_toctou_and_dir_durability","schema_version":"tos.app.riskfinding.v0","severity":"info","finding":"src/bottom_white/ledger/system_keypair.rs: (a) generate_or_load_system_keypair checks keystore_path.exists() (line 471) and later writes with create_new(true) (line 921); two concurrent first-boots race fail-closed (no key overwrite), but the loser receives a raw Io(AlreadyExists) error instead of falling back to load_existing_keypair — a one-line retry-as-load would make first boot idempotent. (b) write_keystore_0600 fsyncs the file (file.sync_all(), line 925) but never fsyncs the parent directory created at lines 916-918, so on a crash right after first boot the directory entry can be lost while the in-memory key has already signed ledger entries — leaving on-tape signatures from a key whose keystore no longer exists. For a signing-key store this durability gap is worth closing in the port.","author":"critic_A"}

## Summary

The signer module is one of the more disciplined surfaces I have audited in this repo:
production code is panic-free with a semantic 7-variant error enum, the signing
capability is structurally confined to three pub(crate) emitter modules behind a typed
CanonicalMessage enum, secrets are zeroized and best-effort mlocked with a proper
SAFETY comment, the keystore write path is 0600 + create_new fail-closed, and the file
plus its five integration tests are trust-root hash-pinned in genesis_payload.toml.
Test quality is above tautology level — wrong-password, wrong-epoch, tampered-message,
and forged-rotation negatives all exist, and one test reconstructs signatures with raw
ed25519_dalek independently of the module's sign path. The residual problems are
characteristic rather than severe: a fail-open verify_system_pubkeys stub with zero
callers sits on the pub surface; the canonical-digest wire invariant has no golden
vector, so encoding drift would pass every existing test while orphaning historical
on-tape signatures; the crate-only-signing gate is a bypassable textual grep that is
not even in the constitution gate manifest; keystore KDF header fields are
unauthenticated and unbounded (decrypt-time DoS, no encrypt-time floor); and KDF/path
configuration enters via hidden process env rather than parameters, which is the main
friction a CLI/lib facade will feel when porting. Scores: boundary 4, errors 5,
invariants 4, tests 4, concurrency 4, dead code 4.

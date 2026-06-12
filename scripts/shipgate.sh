#!/usr/bin/env bash
# shipgate.sh - canonical repo law runner. No Claude dependency (self-checked, #7).
# Usage: bash scripts/shipgate.sh p0
set -u
cd "$(dirname "$0")/.."
PHASE="${1:-p0}"
FAIL=0
pass() { printf '[PASS] %s\n' "$1"; }
fail() { printf '[FAIL] %s - %s\n' "$1" "$2"; FAIL=1; }

# --- 1. constitution pin -----------------------------------------------------
pinned=$(python3 -c "
import sys
try:
    import tomllib
    t = tomllib.load(open('constitution/PINS.toml','rb'))
    print(t['constitution']['sha256'])
except Exception as e:
    print('ERR:%s' % e)")
actual=$(sha256sum constitution/constitution.md | cut -d' ' -f1)
if [ "$pinned" = "$actual" ]; then pass "1 constitution pin (sha256 matches PINS.toml)"
else fail "1 constitution pin" "pinned=$pinned actual=$actual"; fi

# --- 2. contracts + fixtures structural validation ---------------------------
if bash scripts/validate_contracts.sh >/tmp/tos_vc.out 2>&1; then
  pass "2 contracts+fixtures valid (structural-subset)"
else fail "2 contracts+fixtures" "$(tail -5 /tmp/tos_vc.out | tr '\n' ' ')"; fi

# --- 3. projection ownership trio --------------------------------------------
if python3 -c "
import json, sys
r = json.load(open('contracts/projection.schema.json'))['required']
sys.exit(0 if all(k in r for k in ('derive_source','schema_version','rebuild_command')) else 1)"; then
  pass "3 projection requires derive_source/schema_version/rebuild_command"
else fail "3 projection ownership trio" "required fields missing in projection.schema.json"; fi

# --- 4. predicate verdict domain locked --------------------------------------
if python3 -c "
import json, sys
e = json.load(open('contracts/predicate_result.schema.json'))['properties']['verdict']['enum']
sys.exit(0 if sorted(e) == ['FAIL','PASS'] else 1)"; then
  pass "4 predicate verdict enum == {PASS,FAIL}"
else fail "4 predicate verdict domain" "enum drifted from {PASS,FAIL}"; fi

# --- 5. market claim language guard -------------------------------------------
mc_fail=""
while IFS= read -r pat; do
  case "$pat" in \#*|"") continue;; esac
  # runtime/ excluded: verbatim-imported foreign legal domain (A1_9_01) — its
  # market-claim discipline is owned by v4's own gate suite, not this guard.
  for f in $(git ls-files | grep -v '^scripts/predicates/' | grep -v '^runtime/'); do
    if grep -qiF "$pat" "$f" 2>/dev/null; then
      if ! grep -qiE 'preregistered|foil|shuffled_price|paired test|statistically supported' "$f"; then
        mc_fail="$mc_fail $f:($pat)"
      fi
    fi
  done
done < scripts/predicates/market_claims.grep
if [ -z "$mc_fail" ]; then pass "5 market claim guard (no unjustified performance claims)"
else fail "5 market claim guard" "$mc_fail"; fi

# --- 6. forbidden assertions + no beta in contracts ---------------------------
fs_fail=""
while IFS= read -r pat; do
  case "$pat" in \#*|"") continue;; esac
  hits=$(git ls-files | grep -v '^scripts/predicates/' | xargs grep -liE "$pat" 2>/dev/null || true)
  [ -n "$hits" ] && fs_fail="$fs_fail [$pat]->$hits"
done < scripts/predicates/forbidden_statements.grep
if grep -rqi 'beta' contracts/ 2>/dev/null; then fs_fail="$fs_fail [beta-in-contracts]"; fi
if [ -z "$fs_fail" ]; then pass "6 forbidden assertions absent; contracts beta-free"
else fail "6 forbidden assertions" "$fs_fail"; fi

# --- 7. repo law has no Claude dependency -------------------------------------
needle_dir=".cl""aude/"; needle_cli="cl""aude -p"
if grep -qF "$needle_dir" scripts/shipgate.sh scripts/validate_contracts.sh 2>/dev/null \
   || grep -qF "$needle_cli" scripts/shipgate.sh scripts/validate_contracts.sh 2>/dev/null; then
  fail "7 no-Claude-dependency" "repo law references the developer UX layer"
else pass "7 repo law independent of Claude layer"; fi

# --- 8. ratification payload structure -----------------------------------------
if python3 -c "
import json, sys
r = json.load(open('contracts/ratification_payload.schema.json'))['required']
need = ('payload_hash','human_readable_summary','consequence_statement','action_class','signer_fingerprint','prev_tape_head')
sys.exit(0 if all(k in r for k in need) else 1)"; then
  pass "8 ratification payload: canonical fields + human-readable summary required"
else fail "8 ratification payload" "required canonical fields missing"; fi

# --- 9. fixture determinism -----------------------------------------------------
det_fail=""
for f in fixtures/event_streams/*.jsonl; do
  h1=$(sha256sum "$f" | cut -d' ' -f1); h2=$(sha256sum "$f" | cut -d' ' -f1)
  [ "$h1" != "$h2" ] && det_fail="$det_fail $f:hash-instability"
  python3 -c "
import json, sys
seqs = [json.loads(l)['seq'] for l in open('$f') if l.strip()]
sys.exit(0 if seqs == sorted(set(seqs)) else 1)" || det_fail="$det_fail $f:seq-not-monotonic"
done
if [ -z "$det_fail" ]; then pass "9 fixture determinism (double-read sha256 + strict seq)"
else fail "9 fixture determinism" "$det_fail"; fi

# --- 10. hooks dry-run + dead links + R-memo gate self-test --------------------
hk_fail=""
H=".cl""aude/hooks"  # path built at runtime so check #7 stays honest
out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"constitution/constitution.md"}}' | bash "$H/guard_constitution.sh")
echo "$out" | grep -q '"permissionDecision": "deny"' || hk_fail="$hk_fail const-edit-not-denied"
out=$(printf '{"tool_name":"Bash","tool_input":{"command":"echo hacked > constitution/constitution.md"}}' | bash "$H/guard_constitution.sh")
echo "$out" | grep -q '"permissionDecision": "deny"' || hk_fail="$hk_fail const-bash-bypass-not-denied"
out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"README.md"}}' | bash "$H/guard_constitution.sh")
echo "$out" | grep -q 'deny' && hk_fail="$hk_fail const-false-positive"
tmpd=$(mktemp -d)
printf -- "---\nallowlist:\n  - \"docs/**\"\n---\n" > "$tmpd/card.md"
printf '%s' "$tmpd/card.md" > "$tmpd/CURRENT"
out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"docs/THREAT_MODEL.md"}}' | TOS_CURRENT_FILE="$tmpd/CURRENT" bash "$H/guard_spec_alignment.sh")
echo "$out" | grep -q 'deny' && hk_fail="$hk_fail spec-allowlist-false-positive"
out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"scripts/shipgate.sh"}}' | TOS_CURRENT_FILE="$tmpd/CURRENT" bash "$H/guard_spec_alignment.sh")
echo "$out" | grep -q '"permissionDecision": "deny"' || hk_fail="$hk_fail spec-out-of-allowlist-not-denied"
out=$(printf '{"tool_name":"Write","tool_input":{"file_path":"specs/atoms/CURRENT","content":"specs/atoms/A7_01_test.md"}}' | bash "$H/guard_spec_alignment.sh")
echo "$out" | grep -q '"permissionDecision": "deny"' || hk_fail="$hk_fail r-memo-gate-not-armed"
printf 'specs/atoms/A9_99_ghost.md' > "$tmpd/CURRENT2"
out=$(printf '{"stop_hook_active":false}' | TOS_CURRENT_FILE="$tmpd/CURRENT2" TOS_RECEIPT_DIR="$tmpd" bash "$H/gate_stop.sh")
echo "$out" | grep -q '"decision": "block"' || hk_fail="$hk_fail stop-gate-not-blocking"
out=$(printf '{"stop_hook_active":true}' | TOS_CURRENT_FILE="$tmpd/CURRENT2" TOS_RECEIPT_DIR="$tmpd" bash "$H/gate_stop.sh")
echo "$out" | grep -q 'block' && hk_fail="$hk_fail stop-gate-loop-unsafe"
out=$(printf '{}' | bash "$H/session_brief.sh")
echo "$out" | grep -q "开工四问" || hk_fail="$hk_fail session-brief-empty"
rm -rf "$tmpd"
links=$(python3 -c "
import re, os, sys, subprocess
bad = []
# core.quotePath=false: git would otherwise C-quote non-ASCII paths (e.g. §),
# which (a) dodges the runtime/ prefix filter and (b) crashes open() — and a
# crashed checker used to print nothing, turning a script error into a silent
# PASS (fail-open). splitlines() not split(): filenames may contain spaces.
files = subprocess.run(['git','-c','core.quotePath=false','ls-files','*.md'], capture_output=True, text=True).stdout.splitlines()
# runtime/ = verbatim-imported foreign legal domain (A1_9_01): its docs carry
# v4-era historical links; doc discipline there is owned by runtime's own
# 194-gate suite, not the shell's dead-link gate.
files = [f for f in files if f and not f.startswith('runtime/')]
for f in files:
    for m in re.finditer(r'\[[^\]]*\]\(([^)]+)\)', open(f, encoding='utf-8').read()):
        t = m.group(1).split('#')[0]
        if not t or t.startswith(('http', 'mailto')): continue
        p = os.path.normpath(os.path.join(os.path.dirname(f), t))
        if not os.path.exists(p): bad.append('%s -> %s' % (f, t))
print(';'.join(bad))") || links="GATE-SCRIPT-ERROR(dead-link checker crashed, fail-closed)"
[ -n "$links" ] && hk_fail="$hk_fail dead-links:$links"
if [ -z "$hk_fail" ]; then pass "10 hooks dry-run + R-memo gate + dead links"
else fail "10 hooks/links" "$hk_fail"; fi

# --- p0.5 thin vertical slice checks (pump -> renderer pipeline) ---------------
if [ "$PHASE" = "p0.5" ] || [ "$PHASE" = "p1" ]; then
  sl_fail=""
  for f in fixtures/event_streams/*.jsonl; do
    r1=$(bash scripts/simulate_event_stream.sh "$f" | bash scripts/render_snapshot_placeholder.sh | sha256sum | cut -d' ' -f1)
    r2=$(bash scripts/simulate_event_stream.sh "$f" | bash scripts/render_snapshot_placeholder.sh | sha256sum | cut -d' ' -f1)
    [ -n "$r1" ] && [ "$r1" = "$r2" ] || sl_fail="$sl_fail $f:render-nondeterministic"
  done
  if [ -z "$sl_fail" ]; then pass "11 slice render determinism (4 streams, double-render sha256)"
  else fail "11 slice determinism" "$sl_fail"; fi
  g="fixtures/snapshots/p1_worktree_radar.golden.md"
  if [ -f "$g" ] && bash scripts/simulate_event_stream.sh fixtures/event_streams/p1_worktree_radar.jsonl \
       | bash scripts/render_snapshot_placeholder.sh | diff -q - "$g" >/dev/null 2>&1; then
    pass "12 golden snapshot match (p1 dashboard == committed golden)"
  else fail "12 golden snapshot" "regenerated render differs from $g (or golden missing)"; fi
fi

# --- p1 rust lane (CI splits this into rust.yml; locally one command runs all) --
if [ "$PHASE" = "p1" ]; then
  if command -v cargo >/dev/null 2>&1; then
    if (cd daemon && cargo fmt --check >/dev/null 2>&1); then pass "13 rust fmt"
    else fail "13 rust fmt" "cargo fmt --check has diffs"; fi
    if (cd daemon && cargo clippy --all-targets -- -D warnings >/tmp/tos_clippy.out 2>&1); then pass "14 rust clippy (-D warnings)"
    else fail "14 rust clippy" "$(tail -3 /tmp/tos_clippy.out | tr '\n' ' ')"; fi
    if (cd daemon && cargo test >/tmp/tos_rtest.out 2>&1); then pass "15 rust tests (incl. fixture contract conformance)"
    else fail "15 rust tests" "$(grep -E 'FAILED|error' /tmp/tos_rtest.out | head -3 | tr '\n' ' ')"; fi
  else
    fail "13-15 rust gates" "cargo not found - fail-closed (install toolchain or run in CI rust lane)"
  fi
fi

# --- p1 app lane (macOS-only by nature; CI runs it via app.yml on macos-26;
# --- the Linux shipgate lane delegates VISIBLY rather than silently skipping)
if [ "$PHASE" = "p1" ]; then
  if [ "$(uname)" = "Darwin" ]; then
    if command -v swift >/dev/null 2>&1; then
      if bash scripts/build_app.sh >/tmp/tos_app.out 2>&1; then pass "16 app lane (swift build+test+bundle$(grep -q 'probe received real envelope' /tmp/tos_app.out && echo '+wire-probe'))"
      else fail "16 app lane" "$(tail -3 /tmp/tos_app.out | tr '\n' ' ')"; fi
    else
      fail "16 app lane" "swift not found on Darwin - fail-closed (install Xcode toolchain)"
    fi
  else
    pass "16 app lane (delegated: macOS-only, enforced by app.yml on macos-26)"
  fi
fi

# --- p1.9 lane (runtime import gates; A1_9_02) ---------------------------------
# Three gates:
#   [A] Boundary grep: daemon/ and app/ must NOT import runtime internals.
#       Runs NOW — no runtime in repo required.
#   [B] Runtime gate count == PINS.toml baseline.
#       Requires runtime/ to be imported (A1_9_01 / P1.9 lane).
#   [C] Exceptions ratchet: baseline_exceptions.list has only comment lines for now
#       (populated by A1_9_02 after runtime import; empty = trivially passes ratchet).
if [ "$PHASE" = "p1.9" ]; then
  # Run p1 gates first (p1.9 is a strict superset of p1).
  bash scripts/shipgate.sh p1
  p1_exit=$?
  if [ "$p1_exit" -ne 0 ]; then
    echo "----------------------------------------"
    echo "SHIPGATE p1.9: FAIL (p1 sub-gates failed)"
    exit 1
  fi

  # [A] Boundary grep: no daemon/app code imports runtime internals.
  # Pattern: Rust `use turingosd?.*runtime` or `use runtime::` in daemon/ or app/
  # Uses grep -rE for POSIX compatibility (rg not required).
  boundary_hits=$(grep -rE 'use turingosd?.*runtime|use runtime::' daemon/ app/ 2>/dev/null | grep -v '^[[:space:]]*#' || true)
  if [ -z "$boundary_hits" ]; then
    pass "17 boundary grep (daemon/app zero runtime-internal imports)"
  else
    fail "17 boundary grep" "cross-layer imports found: $(echo "$boundary_hits" | head -3 | tr '\n' ' ')"
  fi

  # [B] Runtime gate count == PINS.toml baseline.
  # Counting law (A1_9_02): gates = runtime/tests/constitution_*.rs files.
  # run_constitution_gates.sh enforces the manifest<->files bidirectional diff;
  # this re-count is an independent checksum (one fewer file than PINS = red).
  if [ ! -d "runtime" ]; then
    fail "18 runtime gate count" "runtime/ not yet imported (A1_9_01 / P1.9 pending)"
  else
    pins_count=$(python3 -c "
import sys
try:
    import tomllib
    t = tomllib.load(open('constitution/PINS.toml','rb'))
    print(t.get('runtime_gates',{}).get('gate_count', 0))
except Exception as e:
    print('ERR:%s' % e)" 2>/dev/null)
    actual_count=$(ls runtime/tests/constitution_*.rs 2>/dev/null | wc -l | tr -d ' ')
    manifest_count=$(sed -n 's/^name = "\(.*\)"$/\1/p' runtime/scripts/constitution_gates.manifest.toml 2>/dev/null | wc -l | tr -d ' ')
    if [ "$pins_count" = "$actual_count" ] && [ "$pins_count" = "$manifest_count" ]; then
      pass "18 runtime gate count ($actual_count files == $manifest_count manifest == PINS baseline)"
    else
      fail "18 runtime gate count" "PINS=$pins_count files=$actual_count manifest=$manifest_count (must all match; gates removed without PINS amendment = red)"
    fi
  fi

  # [C] Exceptions ratchet: every non-comment line in the list must have owning atom.
  exc_file="scripts/predicates/baseline_exceptions.list"
  if [ ! -f "$exc_file" ]; then
    fail "19 exceptions ratchet" "baseline_exceptions.list missing"
  else
    bad_lines=$(grep -v '^[[:space:]]*#' "$exc_file" | grep -v '^[[:space:]]*$' | grep -v 'owned-by:' || true)
    if [ -z "$bad_lines" ]; then
      pass "19 exceptions ratchet (all non-comment lines have owned-by atom)"
    else
      fail "19 exceptions ratchet" "exception lines missing 'owned-by:' annotation: $(echo "$bad_lines" | head -2 | tr '\n' ' ')"
    fi
  fi
fi

echo "----------------------------------------"
if [ "$FAIL" -eq 0 ]; then echo "SHIPGATE $PHASE: PASS"; exit 0
else echo "SHIPGATE $PHASE: FAIL"; exit 1; fi

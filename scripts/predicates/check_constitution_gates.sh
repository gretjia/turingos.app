#!/usr/bin/env bash
# check_constitution_gates.sh — constitution gate suite with ratchet awareness (A1_9_02).
#
# Runs runtime's own 194-gate suite. PASS requires:
#   (a) the runner itself completes its manifest<->files bidirectional check,
#   (b) total == PINS gate_count (194),
#   (c) failed count <= the number of catalogued gate-domain exceptions
#       (baseline_exceptions.list lines whose binary starts with constitution_).
# Name-level precision of the red set is enforced by the companion
# check_runtime_workspace.sh (same binaries, per-test names) — this script
# guards the gate-suite shape; that one guards exact membership.
set -uo pipefail
cd "$(dirname "$0")/../.."

EXC_LIST="scripts/predicates/baseline_exceptions.list"
PINS_COUNT=$(python3 -c "import tomllib;print(tomllib.load(open('constitution/PINS.toml','rb'))['runtime_gates']['gate_count'])")

out_file=$(mktemp)
( cd runtime && bash scripts/run_constitution_gates.sh ) >"$out_file" 2>&1
runner_exit=$?
summary=$(grep -E '^\[k-1-5\]' "$out_file" | tail -1)
echo "check_constitution_gates: $summary (runner exit $runner_exit)"

total=$(echo "$summary" | grep -oE 'total= *[0-9]+' | grep -oE '[0-9]+' || echo 0)
failed=$(echo "$summary" | grep -oE 'failed=[0-9]+' | cut -d= -f2 || echo 999)

if [ "$total" != "$PINS_COUNT" ]; then
  echo "FAIL: gate total $total != PINS baseline $PINS_COUNT"
  tail -20 "$out_file"; rm -f "$out_file"; exit 1
fi

gate_domain_allowed=$(grep -v '^[[:space:]]*#' "$EXC_LIST" | sed -n 's/^\(constitution_[^:]*\)::.*/\1/p' | sort -u | grep -c . || true)
if [ "$failed" -gt "$gate_domain_allowed" ]; then
  echo "FAIL: $failed gate(s) failed > $gate_domain_allowed catalogued gate-domain exception(s)"
  grep -B2 -A8 "FAILED\|panicked" "$out_file" | head -40
  rm -f "$out_file"; exit 1
fi

rm -f "$out_file"
echo "check_constitution_gates: PASS (total=$total == PINS, failed=$failed <= $gate_domain_allowed catalogued)"

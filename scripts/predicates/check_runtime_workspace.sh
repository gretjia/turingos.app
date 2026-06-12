#!/usr/bin/env bash
# check_runtime_workspace.sh — runtime workspace test ratchet (A1_9_02).
#
# Runs the full runtime cargo workspace and verifies the FAILED set is a
# subset of scripts/predicates/baseline_exceptions.list. The ratchet only
# shrinks: a test leaving the red set is progress (no action needed); ANY
# failure not in the list is a new red and exits 1 with the names printed.
#
# Used by .github/workflows/runtime-gates.yml (ubuntu + macos matrix) and
# runnable locally before shipping runtime-touching atoms.
set -uo pipefail
cd "$(dirname "$0")/../.."

EXC_LIST="scripts/predicates/baseline_exceptions.list"
[ -f "$EXC_LIST" ] || { echo "FAIL: $EXC_LIST missing"; exit 1; }

echo "check_runtime_workspace: running cargo test --workspace --no-fail-fast in runtime/ ..."
out=$(cd runtime && cargo test --workspace --no-fail-fast 2>&1)
test_exit=$?

# Failed test names (bare test fn names, unique).
fails=$(echo "$out" | grep -E '^test .* \.\.\. FAILED$' | sed 's/^test //; s/ \.\.\. FAILED$//' | sort -u)

# Allowed red test names from the exception list (format: binary::test_name:cause # owned-by: atom).
allowed=$(grep -v '^[[:space:]]*#' "$EXC_LIST" | grep -v '^[[:space:]]*$' | sed -n 's/^[^:]*::\([^:]*\):.*/\1/p' | sort -u)

new_reds=$(comm -23 <(echo "$fails") <(echo "$allowed") | grep -v '^$' || true)

passed=$(echo "$out" | awk -F'[ ;]+' '/^test result/ {p+=$4} END {print p}')
fail_count=$(echo "$fails" | grep -c . || true)
echo "check_runtime_workspace: $passed passed, $fail_count failed (allowed reds: $(echo "$allowed" | grep -c .))"

if [ -n "$new_reds" ]; then
  echo "FAIL: new red(s) not in baseline_exceptions.list:"
  echo "$new_reds" | sed 's/^/  /'
  echo "--- failure details ---"
  echo "$out" | grep -B2 -A12 "panicked" | head -60
  exit 1
fi

# Fails all catalogued; also confirm cargo did not die for a non-test reason.
if [ "$test_exit" -ne 0 ] && [ -z "$fails" ]; then
  echo "FAIL: cargo exited $test_exit with no parseable test failures (build error?)"
  echo "$out" | tail -20
  exit 1
fi

echo "check_runtime_workspace: PASS (all failures catalogued, ratchet holds)"

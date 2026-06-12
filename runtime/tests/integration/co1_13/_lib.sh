#!/usr/bin/env bash
# Shared helpers for CO1.13 integration tests.
# Each test sources this file, then calls `enter_tmp_repo` which atomically
# creates a temp dir, cd's into it, asserts isolation from the project root,
# and seeds a minimal git repo. This MUST be called before any git command.
set -euo pipefail

# PROJECT_ROOT derived from this file's own location (tests/integration/co1_13
# -> up 3 = v4 project root). Was `git rev-parse --show-toplevel`, which broke
# after the A1_9_01 subtree import: the git toplevel is now the host repo
# (turingos.app), one level above the v4 root. Script-relative derivation is
# correct in both layouts (standalone v4 clone AND runtime/ subtree).
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPT="$PROJECT_ROOT/scripts/check_trace_matrix.py"

# Hard isolation guard: every git command in tests must run inside a tmp dir,
# never in PROJECT_ROOT. enter_tmp_repo enforces this — sets TMP_DIR global,
# cd's into it, asserts isolation, and seeds a minimal repo. Caller uses
# TMP_DIR with teardown later.
#
# IMPORTANT: callers must invoke enter_tmp_repo unsubshelled (NOT via $(...))
# so the cd persists in the caller scope.
TMP_DIR=""
enter_tmp_repo() {
    TMP_DIR=$(mktemp -d -t r022_test_XXXXXX)
    [ -d "$TMP_DIR" ] || { echo "FATAL: mktemp failed" >&2; exit 1; }
    cd "$TMP_DIR"
    local pwd_real proj_real
    pwd_real=$(realpath -- "$PWD")
    proj_real=$(realpath -- "$PROJECT_ROOT")
    if [ "$pwd_real" = "$proj_real" ] || [ "${pwd_real#$proj_real/}" != "$pwd_real" ]; then
        echo "FATAL: tmp dir resolves inside project root ($pwd_real); aborting to prevent pollution" >&2
        exit 1
    fi
    seed_repo
}

seed_repo() {
    git init -q -b main
    git config user.email "test@example.com"
    git config user.name "test"
    mkdir -p src scripts handover/alignment cases
    cp "$SCRIPT" scripts/check_trace_matrix.py
    chmod +x scripts/check_trace_matrix.py
    cat > handover/alignment/TRACE_MATRIX_v3_2026-04-27.md <<'EOF'
# Test stub
### § J.2 Open orphan rows
| File path | Symbol | Class | Justification ref | Opened atom | Graduation target | Notes |
|---|---|---|---|---|---|---|
| src/orphan.rs | orphan_fn | scaffolding | cases/C-test | CO1.13.2 | — | test |
EOF
    cat > cases/C-test.yaml <<'EOF'
id: C-test
ruling: synthetic test fixture
EOF
    git add .
    git -c commit.gpgsign=false commit -q -m "init"
}

assert_eq() {
    local expected="$1" actual="$2" label="$3"
    if [ "$expected" != "$actual" ]; then
        echo "FAIL [$label]: expected=$expected actual=$actual" >&2
        exit 1
    fi
}

teardown() {
    cd /
    if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
        TMP_DIR=""
    fi
}

#!/usr/bin/env bash
# SessionStart: progressive disclosure - first principle, the four questions,
# and the CURRENT atom card. Not the whole encyclopedia (Art.III.2).
set -u
ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
echo "TuringOS.app - The app is not the truth; it is the sovereign projection and control surface over truth."
echo "开工四问: 1) 第二个调用方? 2) tape 可重建? 3) {0,1} 谓词还是 advisory? 4) 用户看到证据还是黑箱?"
cur_file="$ROOT/specs/atoms/CURRENT"
if [ -f "$cur_file" ]; then
  cur="$(cat "$cur_file" | tr -d '[:space:]')"
  if [ -n "$cur" ] && [ "$cur" != "NONE" ] && [ -f "$ROOT/$cur" ]; then
    echo "--- CURRENT atom card: $cur ---"
    cat "$ROOT/$cur"
  else
    echo "CURRENT atom: NONE. Open one with /atom-open before editing (spec-alignment hook enforces allowlists)."
  fi
fi
echo "Index: CLAUDE.md | Repo law: bash scripts/shipgate.sh p0"

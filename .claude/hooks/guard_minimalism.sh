#!/usr/bin/env bash
# PostToolUse advisory (never blocks): minimalism smells fed back as context.
# RiskFinding channel, strictly separate from predicates (M1/M6).
set -u
input="$(cat)"
printf '%s' "$input" | python3 -c "
import json, sys, os, re
d = json.load(sys.stdin)
ti = d.get('tool_input') or {}
fp = str(ti.get('file_path') or '')
if not fp or not os.path.exists(fp): sys.exit(0)
if not re.search(r'[.](swift|rs|py|ts|js|sh)$', fp): sys.exit(0)
src = open(fp, encoding='utf-8', errors='ignore').read()
smells = []
checks = [
    (r'\b(class|struct|protocol|trait)\s+\w*(Manager|Factory|Provider|Coordinator|Helper)\b',
     'abstraction smell (M1): is there a second caller yet?'),
    (r'catch\s*\{\s*\}|except\s*:\s*pass',
     'silent fallback (M2): fail-closed, let a predicate catch it'),
    (r'\bshared\s*=|\bSingleton\b',
     'global state smell (M3): can this be derived from tape?'),
]
for pat, msg in checks:
    if re.search(pat, src): smells.append(msg)
if smells:
    print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PostToolUse',
        'additionalContext': '[minimalism advisory] ' + '; '.join(smells)}}))
sys.exit(0)
"

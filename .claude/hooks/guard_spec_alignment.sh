#!/usr/bin/env bash
# PreToolUse guard: edits must stay inside the CURRENT atom card allowlist (M5),
# and CURRENT may only point at a phase whose R-stage memo exists (R->D->S gate).
# Test seam: TOS_CURRENT_FILE overrides the CURRENT pointer path.
set -u
input="$(cat)"
printf '%s' "$input" | TOS_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}" python3 -c "
import json, sys, os, re, fnmatch
d = json.load(sys.stdin)
if d.get('tool_name') not in ('Edit', 'Write', 'MultiEdit', 'NotebookEdit'): sys.exit(0)
root = os.path.abspath(os.environ.get('TOS_ROOT', '.'))
ti = d.get('tool_input') or {}
fp = str(ti.get('file_path') or ti.get('notebook_path') or '')
rel = os.path.relpath(os.path.abspath(fp), root) if fp else ''

def deny(reason):
    print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny', 'permissionDecisionReason': reason}}))
    sys.exit(0)

if rel == 'specs/atoms/CURRENT':  # R-stage gate on retargeting CURRENT
    content = str(ti.get('content') or ti.get('new_string') or '')
    m = re.search(r'specs/atoms/A([0-9]+(?:_[0-9])?)_', content)
    if m:
        phase = m.group(1).replace('_', '.')
        memo = os.path.join(root, 'research', 'R%s_memo.md' % phase)
        if not os.path.exists(memo):
            deny('R-stage gate: research/R%s_memo.md missing - research precedes coding (PLAN.md R->D->S).' % phase)
    sys.exit(0)

cur_path = os.environ.get('TOS_CURRENT_FILE', os.path.join(root, 'specs/atoms/CURRENT'))
if not os.path.exists(cur_path): sys.exit(0)  # bootstrap mode (constitution guard still armed)
cur = open(cur_path).read().strip()
if cur in ('', 'NONE'): sys.exit(0)
card = cur if os.path.isabs(cur) else os.path.join(root, cur)
if not os.path.exists(card): deny('CURRENT points to missing atom card: %s' % cur)
allow, in_fm, in_list = [], False, False
for line in open(card):
    s = line.rstrip()
    if s.strip() == '---': in_fm = not in_fm; continue
    if not in_fm: continue
    if s.startswith('allowlist:'): in_list = True; continue
    if in_list:
        t = s.strip()
        if t.startswith('- '): allow.append(t[2:].strip().strip('\"')); continue
        in_list = False
for pat in allow:
    if fnmatch.fnmatch(rel, pat): sys.exit(0)
deny('Out of CURRENT atom allowlist (card: %s). Amend the atom card - that leaves a trace - instead of bypassing (M5).' % cur)
"

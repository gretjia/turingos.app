#!/usr/bin/env bash
# PreToolUse guard: the constitution snapshot is Tier-1 read-only.
# Blocks editor writes AND write-shaped Bash commands touching constitution/
# (closes the R-018 class bypass: cp/mv/tee/sed -i/redirect/python open-w...).
set -u
input="$(cat)"
printf '%s' "$input" | python3 -c "
import json, re, sys
d = json.load(sys.stdin)
tool = d.get('tool_name', '')
ti = d.get('tool_input') or {}

def deny(reason):
    print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny', 'permissionDecisionReason': reason}}))
    sys.exit(0)

if tool in ('Edit', 'Write', 'MultiEdit', 'NotebookEdit'):
    fp = str(ti.get('file_path') or ti.get('notebook_path') or '')
    if fp.endswith('constitution/constitution.md'):
        deny('Tier-1: constitution snapshot is read-only. Amend upstream via Class-4 ratification, then re-pin via PINS.toml (L3 action).')
elif tool == 'Bash':
    cmd = str(ti.get('command', ''))
    if 'constitution/' in cmd:
        write_pat = re.compile(r'(>>?|\btee\b|\bcp\b|\bmv\b|\brm\b|\bsed\b[^|;&]*-i|\btruncate\b|\bchmod\b|\bdd\b|\binstall\b|open\([^)]*[\'\"](w|a))')
        if write_pat.search(cmd):
            deny('Tier-1: write-shaped Bash touching constitution/ blocked (R-018 bypass guard). Read-only (cat/grep/sha256sum) is fine.')
sys.exit(0)
"

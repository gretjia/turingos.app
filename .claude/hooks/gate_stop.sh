#!/usr/bin/env bash
# Stop gate: an open atom (CURRENT != NONE) needs a PASS receipt before the
# session may end. Respects stop_hook_active to avoid loops.
# Test seams: TOS_CURRENT_FILE, TOS_RECEIPT_DIR.
set -u
input="$(cat)"
printf '%s' "$input" | TOS_ROOT="${CLAUDE_PROJECT_DIR:-$PWD}" python3 -c "
import json, sys, os
d = json.load(sys.stdin)
if d.get('stop_hook_active'): sys.exit(0)
root = os.path.abspath(os.environ.get('TOS_ROOT', '.'))
cur_path = os.environ.get('TOS_CURRENT_FILE', os.path.join(root, 'specs/atoms/CURRENT'))
if not os.path.exists(cur_path): sys.exit(0)
cur = open(cur_path).read().strip()
if cur in ('', 'NONE'): sys.exit(0)
atom = os.path.splitext(os.path.basename(cur))[0]
rdir = os.environ.get('TOS_RECEIPT_DIR', os.path.join(root, 'specs/atoms/receipts'))
rp = os.path.join(rdir, atom + '.receipt')
if os.path.exists(rp) and 'PASS' in open(rp).read(): sys.exit(0)
print(json.dumps({'decision': 'block',
    'reason': 'Atom %s is CURRENT but has no PASS receipt at %s. Run /atom-ship (shipgate + receipt), or set CURRENT to NONE with justification in the atom card.' % (atom, rp)}))
sys.exit(0)
"

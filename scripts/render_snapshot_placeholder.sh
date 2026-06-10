#!/usr/bin/env bash
# P0.5 thin vertical slice, stage 2: deterministic snapshot RENDERER.
# stdin: event JSONL (contracts/event_stream.schema.json envelopes)
# stdout: markdown dashboard carrying the projection ownership trio.
# Same input bytes => same output bytes (sorted iteration, no wall clock).
# Placeholder proof for the future SwiftUI Radar: contracts -> events ->
# projection -> human-readable view, end to end.
set -u
python3 -c "
import json, sys

BADGE = {  # trust_state -> semantic word (docs/VISUAL_SEMANTICS.md)
    \"signature_valid\": \"verified\", \"human_adopted\": \"verified\",
    \"manifest_missing\": \"failed\", \"signature_invalid\": \"failed\",
    \"signer_unregistered\": \"failed\", \"signer_revoked\": \"failed\",
    \"capability_missing\": \"attention\",
    \"observed_unsigned\": \"foreign\", \"legacy_pre_rule\": \"foreign\",
    \"manifest_registered\": \"active\",
    \"human_root_signed\": \"constitutional\",
}
events = [json.loads(l) for l in sys.stdin if l.strip()]
events.sort(key=lambda e: e[\"seq\"])
projects, worktrees, sessions, proposals, receipts, ratifs, recon = {}, {}, {}, {}, [], [], None
for e in events:
    k, p, t = e[\"kind\"], e.get(\"payload\") or {}, e.get(\"trust_state\", \"\")
    if k == \"ProjectRegistered\": projects[p[\"project_id\"]] = p.get(\"canonical_path\", \"\")
    elif k == \"WorktreeDiscovered\":
        worktrees[p[\"worktree_id\"]] = {\"branch\": p.get(\"branch\", \"?\"), \"head\": p.get(\"head\", \"?\"),
            \"dirty\": p.get(\"dirty\", False), \"badge\": BADGE.get(t, t), \"note\": \"\"}
    elif k == \"WorktreeRemoved\" and p.get(\"worktree_id\") in worktrees:
        worktrees[p[\"worktree_id\"]][\"note\"] = \"removed\"
    elif k == \"FileChanged\" and p.get(\"worktree_id\") in worktrees:
        worktrees[p[\"worktree_id\"]][\"note\"] = \"activity: %s (hint)\" % p.get(\"path\", \"?\")
    elif k == \"DiffSnapshot\" and p.get(\"worktree_id\") in worktrees:
        worktrees[p[\"worktree_id\"]][\"note\"] = \"diff %s (+%s/-%s)\" % (p.get(\"diff_hash\", \"?\")[:18], p.get(\"insertions\", 0), p.get(\"deletions\", 0))
    elif k in (\"AgentSessionStarted\", \"AgentSessionEnded\"):
        sessions[p.get(\"session_id\", \"?\")] = {\"agent\": p.get(\"agent_id\", \"?\"), \"state\": \"open\" if k.endswith(\"Started\") else \"closed\", \"badge\": BADGE.get(t, t)}
    elif k in (\"ProposalCandidate\", \"ProposalSubmitted\", \"ProposalRejected\", \"ProposalAccepted\"):
        pid = p.get(\"proposal_id\") or p.get(\"candidate_id\", \"?\")
        d = proposals.setdefault(pid, {\"state\": \"\", \"predicate\": \"\", \"veto\": \"\", \"badge\": \"\"})
        d[\"state\"] = k.replace(\"Proposal\", \"\").lower(); d[\"badge\"] = BADGE.get(t, t)
        if k == \"ProposalRejected\": d[\"state\"] += \" (on tape, verified=false)\"
    elif k == \"PredicateResult\":
        proposals.setdefault(p.get(\"proposal_id\", \"?\"), {\"state\": \"\", \"predicate\": \"\", \"veto\": \"\", \"badge\": \"\"})[\"predicate\"] = (p.get(\"result\") or {}).get(\"verdict\", \"?\")
    elif k == \"VetoVerdict\":
        proposals.setdefault(p.get(\"proposal_id\", \"?\"), {\"state\": \"\", \"predicate\": \"\", \"veto\": \"\", \"badge\": \"\"})[\"veto\"] = p.get(\"verdict\", \"?\")
    elif k in (\"SignatureVerified\", \"SignatureRejected\"):
        r = p.get(\"receipt\") or {}
        receipts.append((r.get(\"receipt_id\", \"?\"), r.get(\"key_kind\", \"?\"), r.get(\"verified\", \"?\"), BADGE.get(t, t)))
    elif k.startswith(\"Ratification\"):
        ratifs.append((e[\"seq\"], k, ((p.get(\"ratification\") or {}).get(\"human_readable_summary\") or p.get(\"tag\") or p.get(\"ceremony_id\", \"\"))[:96], BADGE.get(t, t)))
    elif k == \"ReconciliationCompleted\":
        recon = \"seen=%s drift=%s via %s\" % (p.get(\"worktrees_seen\", \"?\"), p.get(\"drift_found\", \"?\"), p.get(\"method\", \"?\"))
out = []
out.append(\"# TuringOS.app - Dashboard Snapshot (placeholder renderer)\")
out.append(\"\")
out.append(\"projection_id: prj_slice_dashboard | schema_version: tos.app.projection.v0\")
out.append(\"derive_source: fixture_event_stream | as_of_seq: %s | events_folded: %s\" % (events[-1][\"seq\"] if events else 0, len(events)))
out.append(\"rebuild_command: bash scripts/simulate_event_stream.sh <fixture> | bash scripts/render_snapshot_placeholder.sh\")
if projects:
    out.append(\"\"); out.append(\"## Projects\"); out.append(\"| project | canonical_path |\"); out.append(\"|---|---|\")
    for k2 in sorted(projects): out.append(\"| %s | %s |\" % (k2, projects[k2]))
if worktrees:
    out.append(\"\"); out.append(\"## Worktrees\"); out.append(\"| worktree | branch | head | dirty | badge | note |\"); out.append(\"|---|---|---|---|---|---|\")
    for k2 in sorted(worktrees):
        w = worktrees[k2]
        out.append(\"| %s | %s | %s | %s | %s | %s |\" % (k2, w[\"branch\"], w[\"head\"], w[\"dirty\"], w[\"badge\"], w[\"note\"]))
if sessions:
    out.append(\"\"); out.append(\"## Agent Sessions\"); out.append(\"| session | agent | state | badge |\"); out.append(\"|---|---|---|---|\")
    for k2 in sorted(sessions):
        s = sessions[k2]; out.append(\"| %s | %s | %s | %s |\" % (k2, s[\"agent\"], s[\"state\"], s[\"badge\"]))
if proposals:
    out.append(\"\"); out.append(\"## Proposals\"); out.append(\"| proposal | state | predicate | veto | badge |\"); out.append(\"|---|---|---|---|---|\")
    for k2 in sorted(proposals):
        d = proposals[k2]; out.append(\"| %s | %s | %s | %s | %s |\" % (k2, d[\"state\"], d[\"predicate\"], d[\"veto\"], d[\"badge\"]))
if receipts:
    out.append(\"\"); out.append(\"## Signature Receipts\"); out.append(\"| receipt | key_kind | verified | badge |\"); out.append(\"|---|---|---|---|\")
    for r in receipts: out.append(\"| %s | %s | %s | %s |\" % r)
if ratifs:
    out.append(\"\"); out.append(\"## Ratification Timeline\"); out.append(\"| seq | step | summary | badge |\"); out.append(\"|---|---|---|---|\")
    for r in ratifs: out.append(\"| %s | %s | %s | %s |\" % r)
if recon:
    out.append(\"\"); out.append(\"## Reconciliation\"); out.append(\"- last: %s\" % recon)
out.append(\"\")
out.append(\"_Badges are semantic words from docs/VISUAL_SEMANTICS.md; colors bind in the SwiftUI design-tokens phase._\")
print(\"\n\".join(out))
"

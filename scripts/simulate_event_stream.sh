#!/usr/bin/env bash
# P0.5 thin vertical slice, stage 1: event PUMP.
# Replays a fixture event stream to stdout (JSONL), one event per line.
# The pump never generates data - fixtures are the single source of event
# truth (M3); pacing is presentational only.
#
# Usage: simulate_event_stream.sh [fixture.jsonl] [delay-seconds-per-event]
set -u
cd "$(dirname "$0")/.."
FIX="${1:-fixtures/event_streams/p1_worktree_radar.jsonl}"
DELAY="${2:-0}"
if [ ! -f "$FIX" ]; then
  echo "simulate_event_stream: no such fixture: $FIX" >&2
  exit 1
fi
while IFS= read -r line || [ -n "$line" ]; do
  [ -z "$line" ] && continue
  printf '%s\n' "$line"
  if [ "$DELAY" != "0" ]; then sleep "$DELAY"; fi
done < "$FIX"

#!/usr/bin/env bash
# App lane of repo law: build + test the SwiftUI shell, assemble the .app
# bundle, and - when the daemon binary is present - run the real UDS probe
# end-to-end (app binary connects to a live turingosd and must receive a
# contract envelope) plus the registry coupling probe (Swift-written
# projects.json -> registry-mode daemon load). macOS only by nature; the
# Linux shipgate lane delegates this check to the macOS CI job (visible
# delegation, not a silent skip).
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname)" != "Darwin" ]]; then
  echo "build_app: requires macOS (delegated to macos CI lane)" >&2
  exit 2
fi

# Local convenience: prefer the Xcode 27 beta SDK when present (ADR-008 dev
# lane) unless the caller already pinned DEVELOPER_DIR. CI uses its default.
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app
fi
echo "build_app: swift = $(swift --version 2>&1 | head -1)"

cd app
swift build -c debug

# Forensic test gate (S-stage critique: `| tail -3` showed only the empty
# Swift-Testing summary - a green receipt indistinguishable from zero
# executed assertions). Capture everything, demand the XCTest pass line AND
# a minimum executed-test count so silent runner drift turns the gate red.
MIN_TESTS=262  # raised 2026-06-12 A1_34: 262 tests now passing (was 254; +8 facilitator dialogue tests)
TEST_OUT="$(swift test 2>&1)" || { echo "$TEST_OUT" | tail -20; exit 1; }
echo "$TEST_OUT" | grep -q "Test Suite 'All tests' passed" \
  || { echo "build_app: XCTest pass summary missing"; echo "$TEST_OUT" | tail -20; exit 1; }
EXECUTED="$(echo "$TEST_OUT" | grep -Eo 'Executed [0-9]+ tests' | grep -Eo '[0-9]+' | sort -n | tail -1)"
if [[ "${EXECUTED:-0}" -lt "$MIN_TESTS" ]]; then
  echo "build_app: executed ${EXECUTED:-0} tests < required $MIN_TESTS (runner drift?)"
  exit 1
fi
echo "build_app: XCTest executed $EXECUTED tests, 0 failures"

# --- assemble the .app bundle -------------------------------------------
BIN=".build/debug/TuringOS"
APP="dist/TuringOS.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TuringOS"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>app.turingos.shell</string>
    <key>CFBundleName</key><string>TuringOS</string>
    <key>CFBundleExecutable</key><string>TuringOS</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
echo "build_app: bundle assembled at app/$APP"

# --- real-wire probe (only when the daemon binary exists) ----------------
DAEMON="../daemon/target/debug/turingosd"
if [[ -x "$DAEMON" ]]; then
  T="$(mktemp -d /tmp/tos_appprobe.XXXXXX)"
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
  git -c user.email=t@t -c user.name=t -c init.defaultBranch=main init -q "$T/repo"
  ( cd "$T/repo" && echo x > f.txt \
    && git -c user.email=t@t -c user.name=t add . \
    && git -c user.email=t@t -c user.name=t commit -qm c )
  "$DAEMON" serve "$T/repo" "$T/d.sock" 2>/dev/null &
  DPID=$!
  trap 'kill "$DPID" 2>/dev/null || true' EXIT
  # 20s window (was 5s): right after the rust gates the machine is still
  # under load and daemon startup can exceed 5s — observed 2026-06-12
  # (gate 16 flaked in full shipgate runs while standalone runs passed).
  for _ in $(seq 1 200); do [[ -S "$T/d.sock" ]] && break; sleep 0.1; done
  [[ -S "$T/d.sock" ]] || echo "build_app: WARN daemon socket not up after 20s" >&2
  LINE="$("$BIN" --probe "$T/d.sock")"
  kill "$DPID" 2>/dev/null || true
  trap - EXIT
  echo "$LINE" | python3 -c '
import json, sys
e = json.loads(sys.stdin.readline())
assert e["schema_version"] == "tos.app.event.v0", e
assert e["kind"] == "WorktreeDiscovered", e
print("build_app: probe received real envelope kind=%s seq=%s" % (e["kind"], e["seq"]))
'

  # --- registry wire probe (A1_07): Swift-written registry -> daemon load --
  # Chain the REAL onboarding coupling: the app binary writes projects.json
  # through its catalog->entries->write path (--onboard-probe), a registry-
  # mode daemon loads that exact file, and the first envelope over the wire
  # must be the daemon ANNOUNCING the Swift-written project (ProjectRegistered
  # precedes reconcile in RegistryRunner::tick, and replay is from seq 0).
  "$BIN" --onboard-probe "$T/repo" "$T/projects.json"
  "$DAEMON" serve --registry "$T/projects.json" "$T/r.sock" 2>/dev/null &
  RPID=$!
  trap 'kill "$RPID" 2>/dev/null || true' EXIT
  for _ in $(seq 1 200); do [[ -S "$T/r.sock" ]] && break; sleep 0.1; done
  [[ -S "$T/r.sock" ]] || echo "build_app: WARN registry socket not up after 20s" >&2
  RLINE="$("$BIN" --probe "$T/r.sock")"
  kill "$RPID" 2>/dev/null || true
  trap - EXIT
  echo "$RLINE" | python3 -c '
import json, os, sys
repo = sys.argv[1]
e = json.loads(sys.stdin.readline())
assert e["schema_version"] == "tos.app.event.v0", e
assert e["kind"] == "ProjectRegistered", e
p = e["payload"]
assert p["project_id"] == "repo", p
assert p["local"] is True, p
assert os.path.realpath(p["path"]) == os.path.realpath(repo), p
print("build_app: registry probe - daemon loaded Swift-written registry (project_id=%s local=%s)" % (p["project_id"], p["local"]))
' "$T/repo"
else
  echo "build_app: daemon binary absent - wire probe skipped (rust lane builds it; run locally for the full check)" >&2
fi

echo "build_app: PASS"

#!/usr/bin/env bash
# App lane of repo law: build + test the SwiftUI shell, assemble the .app
# bundle, and - when the daemon binary is present - run the real UDS probe
# end-to-end (app binary connects to a live turingosd and must receive a
# contract envelope). macOS only by nature; the Linux shipgate lane
# delegates this check to the macOS CI job (visible delegation, not a
# silent skip).
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
MIN_TESTS=11
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
  for _ in $(seq 1 50); do [[ -S "$T/d.sock" ]] && break; sleep 0.1; done
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
else
  echo "build_app: daemon binary absent - wire probe skipped (rust lane builds it; run locally for the full check)" >&2
fi

echo "build_app: PASS"

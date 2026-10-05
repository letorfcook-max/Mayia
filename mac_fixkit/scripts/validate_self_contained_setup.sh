#!/bin/bash
set -euo pipefail
SETUP="${1:-}"
if [[ -z "$SETUP" || ! -d "$SETUP" ]]; then
  echo "Usage: $0 '/path/to/Mayia Setup.app'"
  exit 2
fi
PAYLOAD="$SETUP/Contents/Resources/Payload/Mayia.app"
test -f "$SETUP/Contents/Info.plist"
test -x "$SETUP/Contents/MacOS/Mayia Setup"
test -f "$PAYLOAD/Contents/Info.plist"
BIN="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PAYLOAD/Contents/Info.plist")"
test -x "$PAYLOAD/Contents/MacOS/$BIN"
echo "[OK] Setup executable exists"
echo "[OK] Embedded Mayia.app exists"
echo "[OK] Embedded Mayia executable exists: $BIN"
file "$SETUP/Contents/MacOS/Mayia Setup"
file "$PAYLOAD/Contents/MacOS/$BIN"
codesign --verify --deep --strict --verbose=2 "$SETUP"
echo "[OK] Self-contained Setup validation passed"

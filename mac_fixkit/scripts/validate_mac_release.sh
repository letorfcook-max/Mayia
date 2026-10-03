#!/bin/bash
set -euo pipefail
APP="${1:-}"
if [[ -z "$APP" || ! -d "$APP" ]]; then echo "Usage: $0 /path/to/Mayia.app"; exit 2; fi
PLIST="$APP/Contents/Info.plist"
BIN="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST")"
EXE="$APP/Contents/MacOS/$BIN"
echo "=== Mayia macOS validation ==="
sw_vers
uname -m
file "$EXE"
echo "--- codesign ---"
codesign -dv --verbose=4 "$APP" 2>&1 || true
codesign --verify --deep --strict --verbose=2 "$APP" || true
echo "--- linked architectures ---"
find "$APP/Contents" -type f \( -name '*.dylib' -o -name '*.so' \) -maxdepth 8 -print0 2>/dev/null | while IFS= read -r -d '' f; do file "$f"; done | grep -E 'x86_64|arm64' | head -n 120 || true
echo "--- quarantine metadata ---"
xattr -lr "$APP" 2>/dev/null | head -n 80 || true
echo "=== done ==="

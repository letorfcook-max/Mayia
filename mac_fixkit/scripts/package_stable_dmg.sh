#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-}"
OUT="${2:-$ROOT/dist/Mayia-macOS-arm64.dmg}"
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "Usage: $0 /path/to/Mayia.app [/path/to/output.dmg]"
  exit 2
fi
if [[ ! -f "$APP/Contents/Info.plist" ]]; then
  echo "ERROR: invalid Mayia.app: missing Contents/Info.plist"
  exit 3
fi
BIN="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Contents/Info.plist")"
if [[ ! -x "$APP/Contents/MacOS/$BIN" ]]; then
  echo "ERROR: Mayia executable missing: $APP/Contents/MacOS/$BIN"
  exit 4
fi
mkdir -p "$(dirname "$OUT")" "$ROOT/dist"
SETUP="$ROOT/dist/Mayia Setup.app"
"$ROOT/scripts/build_native_setup.sh" "$SETUP"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
/usr/bin/ditto "$APP" "$STAGE/Mayia.app"
/usr/bin/ditto "$SETUP" "$STAGE/Mayia Setup.app"
ln -s /Applications "$STAGE/Applications"

# Never run hdiutil detach/eject from the installer itself. The DMG is only built here.
IDENTITY="${APPLE_SIGN_IDENTITY:-}"
if [[ -n "$IDENTITY" ]]; then
  codesign --force --deep --options runtime --sign "$IDENTITY" "$STAGE/Mayia.app"
else
  codesign --verify --deep --strict "$STAGE/Mayia.app" >/dev/null 2>&1 || codesign --force --deep --sign - "$STAGE/Mayia.app"
fi
codesign --verify --deep --strict "$STAGE/Mayia Setup.app"

rm -f "$OUT"
hdiutil create -volname "Mayia" -srcfolder "$STAGE" -ov -format UDZO "$OUT"
shasum -a 256 "$OUT" > "$OUT.sha256"
echo "Created: $OUT"
cat "$OUT.sha256"

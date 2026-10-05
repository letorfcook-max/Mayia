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
"$ROOT/scripts/build_native_setup.sh" "$SETUP" "$APP"
"$ROOT/scripts/validate_self_contained_setup.sh" "$SETUP"

STAGE="$(mktemp -d)"
MOUNT="$(mktemp -d)"
cleanup() {
  hdiutil detach "$MOUNT" -quiet >/dev/null 2>&1 || true
  rm -rf "$STAGE" "$MOUNT"
}
trap cleanup EXIT

# M208 DMG contains ONE self-contained installer. No sibling Mayia.app dependency.
/usr/bin/ditto "$SETUP" "$STAGE/Mayia Setup.app"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/READ ME FIRST.txt" <<'TXT'
MAYIA FOR macOS

1. Open "Mayia Setup.app" from this disk image.
2. Click Install Mayia.
3. Setup carries Mayia.app inside itself, so it does not depend on a separate sibling app.

You may copy Mayia Setup.app somewhere else and run it later; the payload stays inside Setup.
TXT

rm -f "$OUT" "$OUT.sha256"
hdiutil create -volname "Mayia Installer" -srcfolder "$STAGE" -ov -format UDZO "$OUT"
shasum -a 256 "$OUT" > "$OUT.sha256"

# Critical M208 regression test: mount the finished DMG and prove the embedded payload is really there.
hdiutil attach "$OUT" -nobrowse -readonly -mountpoint "$MOUNT" -quiet
TEST_SETUP="$MOUNT/Mayia Setup.app"
"$ROOT/scripts/validate_self_contained_setup.sh" "$TEST_SETUP"

# Extra test: copy Setup OUT of the DMG and confirm Mayia.app remains inside it.
COPIED="$(mktemp -d)/Mayia Setup.app"
/usr/bin/ditto "$TEST_SETUP" "$COPIED"
"$ROOT/scripts/validate_self_contained_setup.sh" "$COPIED"
rm -rf "$(dirname "$COPIED")"

echo "Created and regression-tested: $OUT"
cat "$OUT.sha256"

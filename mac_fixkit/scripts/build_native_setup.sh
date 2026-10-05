#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/dist/Mayia Setup.app}"
PAYLOAD="${2:-}"
SRC="$ROOT/native_setup/MayiaSetup.swift"
PLIST="$ROOT/native_setup/Info.plist"

if [[ -z "$PAYLOAD" || ! -d "$PAYLOAD" ]]; then
  echo "Usage: $0 '/path/to/Mayia Setup.app' '/path/to/Mayia.app'"
  exit 2
fi
if [[ ! -f "$PAYLOAD/Contents/Info.plist" ]]; then
  echo "ERROR: payload is not a valid Mayia.app: $PAYLOAD"
  exit 3
fi

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources/Payload"
cp "$PLIST" "$OUT/Contents/Info.plist"

echo "Building native ARM64 Mayia Setup..."
swiftc -O -target arm64-apple-macos13.0 -framework AppKit -framework Foundation "$SRC" -o "$OUT/Contents/MacOS/Mayia Setup"
chmod +x "$OUT/Contents/MacOS/Mayia Setup"

echo "Embedding Mayia.app INSIDE Setup so Setup works even after being copied out of the DMG..."
/usr/bin/ditto "$PAYLOAD" "$OUT/Contents/Resources/Payload/Mayia.app"

if [[ ! -f "$OUT/Contents/Resources/Payload/Mayia.app/Contents/Info.plist" ]]; then
  echo "ERROR: embedded Mayia.app payload was not created"
  exit 4
fi

IDENTITY="${APPLE_SIGN_IDENTITY:--}"
# Sign embedded payload first, then outer Setup.
if [[ "$IDENTITY" != "-" ]]; then
  codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$OUT/Contents/Resources/Payload/Mayia.app"
  codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$OUT"
else
  codesign --verify --deep --strict "$OUT/Contents/Resources/Payload/Mayia.app" >/dev/null 2>&1 || codesign --force --deep --sign - "$OUT/Contents/Resources/Payload/Mayia.app"
  codesign --force --deep --sign - "$OUT"
fi
codesign --verify --deep --strict --verbose=2 "$OUT"

echo "Built self-contained Setup: $OUT"
file "$OUT/Contents/MacOS/Mayia Setup"
du -sh "$OUT"

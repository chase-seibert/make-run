#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/Resources/MakeRun-1024.png"
ICONSET="$ROOT/Resources/MakeRun.iconset"

swift "$ROOT/scripts/GenerateIcon.swift" "$BASE"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

sips -z 16 16 "$BASE" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$BASE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$BASE" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$BASE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$BASE" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$BASE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$BASE" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$BASE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$BASE" --out "$ICONSET/icon_512x512.png" >/dev/null
cp "$BASE" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$ROOT/Resources/MakeRun.icns"
rm -rf "$ICONSET"

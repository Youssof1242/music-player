#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Melody"
DIST="dist"
APP="$DIST/$APP_NAME.app"

echo "==> Building $APP_NAME (release, housekeeping)"
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"

echo "==> Generating app icon"
mkdir -p "$DIST"
swift Tools/MakeIcon.swift "$DIST/icon_1024.png"

echo "==> Creating icns"
rm -rf "$DIST/AppIcon.iconset"
mkdir -p "$DIST/AppIcon.iconset"
MASTER="$DIST/icon_1024.png"
sips -z 16 16     "$MASTER" --out "$DIST/AppIcon.iconset/icon_16x16.png"     >/dev/null
sips -z 32 32     "$MASTER" --out "$DIST/AppIcon.iconset/icon_16x16@2x.png"  >/dev/null
sips -z 32 32     "$MASTER" --out "$DIST/AppIcon.iconset/icon_32x32.png"     >/dev/null
sips -z 64 64     "$MASTER" --out "$DIST/AppIcon.iconset/icon_32x32@2x.png"  >/dev/null
sips -z 128 128   "$MASTER" --out "$DIST/AppIcon.iconset/icon_128x128.png"   >/dev/null
sips -z 256 256   "$MASTER" --out "$DIST/AppIcon.iconset/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$MASTER" --out "$DIST/AppIcon.iconset/icon_256x256.png"   >/dev/null
sips -z 512 512   "$MASTER" --out "$DIST/AppIcon.iconset/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$MASTER" --out "$DIST/AppIcon.iconset/icon_512x512.png"   >/dev/null
cp "$MASTER" "$DIST/AppIcon.iconset/icon_512x512@2x.png"
iconutil -c icns "$DIST/AppIcon.iconset" -o "$DIST/AppIcon.icns"

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$DIST/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || echo "warning: codesign failed (app may still run)"

echo ""
echo "Built $APP"
echo "Launch with:  open \"$APP\"    (or drag it into /Applications)"

#!/bin/bash
set -euo pipefail

BUNDLE_ID="com.ortbasker.keyboardbatterybar"
APP_NAME="Keyboard Battery Bar"
EXEC_NAME="KeyboardBatteryBar"
VERSION="1.2"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$ROOT/build"
APP="${1:-$HOME/Applications/$APP_NAME.app}"

rm -rf "$BUILD"
mkdir -p "$BUILD"

ICNS="$ROOT/resources/AppIcon.icns"
if [ "${REGEN_ICON:-0}" = "1" ] || [ ! -f "$ICNS" ]; then
    echo "==> Rendering icon"
    xcrun swiftc -O "$ROOT/src/icon.swift" -o "$BUILD/make-icon"
    "$BUILD/make-icon" "$BUILD/icon.png"

    ICONSET="$BUILD/AppIcon.iconset"
    mkdir -p "$ICONSET"
    for spec in "16 icon_16x16" "32 icon_16x16@2x" "32 icon_32x32" "64 icon_32x32@2x" \
                "128 icon_128x128" "256 icon_128x128@2x" "256 icon_256x256" \
                "512 icon_256x256@2x" "512 icon_512x512" "1024 icon_512x512@2x"; do
        set -- $spec
        sips -z "$1" "$1" "$BUILD/icon.png" --out "$ICONSET/$2.png"
    done
    mkdir -p "$ROOT/resources"
    iconutil -c icns "$ICONSET" -o "$ICNS"
else
    echo "==> Using checked-in icon"
fi

echo "==> Building CLI"
xcrun swiftc -O "$ROOT/src/cli.swift" -o "$BUILD/keyboard-battery"

echo "==> Building app bundle"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun swiftc -O "$ROOT/src/app.swift" -o "$APP/Contents/MacOS/$EXEC_NAME"
cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleExecutable</key><string>$EXEC_NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

SIGN_ID="${CODESIGN_IDENTITY:--}"
echo "==> Signing with identity: $SIGN_ID"
codesign -s "$SIGN_ID" --force --deep "$APP"
codesign -v "$APP"

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" 2>/dev/null || true

echo "==> Built $APP"
echo "    CLI at $BUILD/keyboard-battery"

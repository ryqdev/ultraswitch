#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="UltraSwitch"
BUNDLE_ID="com.ultraswitch.app"
BUILD_DIR="$PROJECT_ROOT/.build/release"
APP_BUNDLE="$PROJECT_ROOT/$APP_NAME.app"
DMG_PATH="$PROJECT_ROOT/$APP_NAME.dmg"
DMG_STAGING="$PROJECT_ROOT/.build/dmg-staging"

echo "==> Building release binary..."
cd "$PROJECT_ROOT"
swift build -c release

echo "==> Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy icon if it exists
ICON_PATH=$(find "$PROJECT_ROOT" -name "AppIcon.icns" -not -path "*/.build/*" 2>/dev/null | head -1)
if [ -n "$ICON_PATH" ]; then
    cp "$ICON_PATH" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    ICON_ENTRY="<key>CFBundleIconFile</key>
	<string>AppIcon</string>"
    echo "    Found icon: $ICON_PATH"
else
    ICON_ENTRY=""
    echo "    No AppIcon.icns found, skipping icon."
fi

echo "==> Generating Info.plist..."
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>$APP_NAME</string>
	<key>CFBundleDisplayName</key>
	<string>$APP_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleVersion</key>
	<string>1.0</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleExecutable</key>
	<string>$APP_NAME</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	$ICON_ENTRY
</dict>
</plist>
EOF

echo "==> Creating .dmg..."
rm -rf "$DMG_STAGING" "$DMG_PATH"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_STAGING" "$APP_BUNDLE"

echo ""
echo "Done! DMG created at: $DMG_PATH"

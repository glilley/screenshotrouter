#!/bin/bash
set -e

APP_NAME="ScreenshotRouter"
BUNDLE_ID="com.greglilley.ScreenshotRouter"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
DERIVED=$(xcodebuild -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" -configuration Debug -showBuildSettings 2>/dev/null \
  | grep ' BUILT_PRODUCTS_DIR ' | awk '{print $3}')
BUILD_APP="$DERIVED/$APP_NAME.app"
INSTALL_APP="$HOME/Applications/$APP_NAME.app"

echo "→ Killing any running instance..."
pkill -f "$APP_NAME" 2>/dev/null || true
sleep 0.5

echo "→ Building..."
xcodebuild -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" -configuration Debug build \
  | grep -E "(error:|COMPILE|BUILD SUCCEEDED|BUILD FAILED)"

echo "→ Installing to ~/Applications..."
rm -rf "$INSTALL_APP"
cp -R "$BUILD_APP" "$INSTALL_APP"

echo "→ Resetting accessibility permission (you'll need to re-grant it once)..."
tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || true

echo "→ Launching..."
open "$INSTALL_APP"

echo ""
echo "✓ Done. Grant accessibility in:"
echo "  System Settings → Privacy & Security → Accessibility"
echo "  Remove old entry if present, then add ~/Applications/$APP_NAME.app"

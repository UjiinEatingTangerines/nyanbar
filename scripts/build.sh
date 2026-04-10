#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="ClaudeMenuBar"
APP_BUNDLE="$HOME/Applications/${APP_NAME}.app"

echo "==> Building ${APP_NAME}..."
cd "$PROJECT_DIR"
swift build -c release 2>&1

BINARY="$(swift build -c release --show-bin-path)/${APP_NAME}"

if [ ! -f "$BINARY" ]; then
    echo "ERROR: Binary not found at $BINARY"
    exit 1
fi

echo "==> Creating app bundle at ${APP_BUNDLE}..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"

cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClaudeMenuBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.claudecode.menubar</string>
    <key>CFBundleName</key>
    <string>Claude MenuBar</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
PLIST

echo "==> App bundle created: ${APP_BUNDLE}"
echo "==> Run with: open \"${APP_BUNDLE}\""

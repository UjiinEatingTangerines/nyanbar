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

# Read version from package.json
VERSION=$(node -e "console.log(require('${PROJECT_DIR}/package.json').version)" 2>/dev/null || echo "1.0.0")
echo "  Version: ${VERSION}"

cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClaudeMenuBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.claudecode.menubar</string>
    <key>CFBundleName</key>
    <string>NyanBar</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
PLIST

# Ad-hoc code sign (required on macOS to prevent SIGKILL)
codesign --force --sign - "$APP_BUNDLE" 2>/dev/null

echo "==> App bundle created: ${APP_BUNDLE}"
echo "==> Run with: open \"${APP_BUNDLE}\""

#!/bin/bash
set -euo pipefail

APP_NAME="ClaudeMenuBar"
APP_BUNDLE="$HOME/Applications/${APP_NAME}.app"
PLIST_NAME="com.claudecode.menubar"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"

echo "=== Claude Code Menu Bar Uninstaller ==="
echo ""

# Stop the app
echo "[1/4] Stopping app..."
killall "$APP_NAME" 2>/dev/null || true

# Unload LaunchAgent
echo "[2/4] Unloading LaunchAgent..."
launchctl unload "$PLIST_PATH" 2>/dev/null || true
rm -f "$PLIST_PATH"

# Remove app bundle
echo "[3/4] Removing app bundle..."
rm -rf "$APP_BUNDLE"

# Clean up session files
echo "[4/4] Cleaning up session files..."
rm -rf "$HOME/.claude/menubar-sessions"

echo ""
echo "=== Uninstall complete! ==="
echo ""
echo "Note: Hook entries in ~/.claude/settings.json were NOT removed."
echo "They are harmless without the app but you can remove them manually."

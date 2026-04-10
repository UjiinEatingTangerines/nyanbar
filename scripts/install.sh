#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="ClaudeMenuBar"
APP_BUNDLE="$HOME/Applications/${APP_NAME}.app"
PLIST_NAME="com.claudecode.menubar"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"

echo "=== Claude Code Menu Bar Installer ==="
echo ""

# Step 1: Build
echo "[1/5] Building..."
bash "$SCRIPT_DIR/build.sh"

# Step 2: Install Hook script
echo ""
echo "[2/5] Installing hook script..."
mkdir -p "$HOME/.claude/scripts/hooks"
cp "$PROJECT_DIR/Hooks/menubar-session-update.js" "$HOME/.claude/scripts/hooks/menubar-session-update.js"
echo "  -> ~/.claude/scripts/hooks/menubar-session-update.js"

# Step 3: Create LaunchAgent
echo ""
echo "[3/5] Installing LaunchAgent..."

cat > "$PLIST_PATH" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_NAME}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${APP_BUNDLE}/Contents/MacOS/${APP_NAME}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
PLIST

# Step 4: Setup directories
echo ""
echo "[4/5] Setting up..."
mkdir -p "$HOME/.claude/menubar-sessions"

# Step 5: Register hooks in settings.json
echo ""
echo "[5/5] Checking hooks..."

SETTINGS="$HOME/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
    if grep -q "menubar-session-update" "$SETTINGS"; then
        echo "  -> Hooks already registered in settings.json"
    else
        echo "  -> NOTE: You need to manually add hooks to $SETTINGS"
        echo "     See README.md for the hook configuration."
    fi
else
    echo "  -> WARNING: $SETTINGS not found."
    echo "     Create it and add hooks from README.md."
fi

echo ""
echo "=== Installation complete! ==="
echo ""
echo "Next steps:"
echo "  1. Add hooks to ~/.claude/settings.json (see README.md)"
echo "  2. Start the app:    open \"$APP_BUNDLE\""
echo "  3. Auto-start:       launchctl load \"$PLIST_PATH\""
echo ""
echo "To uninstall: bash \"$SCRIPT_DIR/uninstall.sh\""

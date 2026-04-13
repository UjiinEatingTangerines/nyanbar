#!/usr/bin/env node
'use strict';

const { execSync, spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

const APP_NAME = 'ClaudeMenuBar';
const BUNDLE_ID = 'com.claudecode.menubar';
const HOME = os.homedir();
const APP_BUNDLE = path.join(HOME, 'Applications', `${APP_NAME}.app`);
const PLIST_PATH = path.join(HOME, 'Library', 'LaunchAgents', `${BUNDLE_ID}.plist`);
const SESSIONS_DIR = path.join(HOME, '.claude', 'menubar-sessions');
const HOOKS_DIR = path.join(HOME, '.claude', 'scripts', 'hooks');
const PKG_DIR = path.resolve(__dirname, '..');

const HOOK_ENTRIES = {
  SessionStart: {
    matcher: '*',
    hooks: [{
      type: 'command',
      command: `_MENUBAR_EVENT=session-start node "$CLAUDE_PLUGIN_ROOT/scripts/hooks/menubar-session-update.js"`,
      timeout: 5,
      async: true
    }]
  },
  PreToolUse: {
    matcher: '*',
    hooks: [{
      type: 'command',
      command: `_MENUBAR_EVENT=tool-use node "$CLAUDE_PLUGIN_ROOT/scripts/hooks/menubar-session-update.js"`,
      timeout: 5,
      async: true
    }]
  },
  Stop: {
    matcher: '*',
    hooks: [{
      type: 'command',
      command: `_MENUBAR_EVENT=stop node "$CLAUDE_PLUGIN_ROOT/scripts/hooks/menubar-session-update.js"`,
      timeout: 5,
      async: true
    }]
  },
  SessionEnd: {
    matcher: '*',
    hooks: [{
      type: 'command',
      command: `_MENUBAR_EVENT=session-end node "$CLAUDE_PLUGIN_ROOT/scripts/hooks/menubar-session-update.js"`,
      timeout: 5,
      async: true
    }]
  },
  UserPromptSubmit: {
    matcher: '*',
    hooks: [{
      type: 'command',
      command: `_MENUBAR_EVENT=prompt-submit node "$CLAUDE_PLUGIN_ROOT/scripts/hooks/menubar-session-update.js"`,
      timeout: 5,
      async: true
    }]
  }
};

// ─── Helpers ───

function log(msg) { console.log(`  ${msg}`); }
function ok(msg) { console.log(`  ✅ ${msg}`); }
function warn(msg) { console.log(`  ⚠️  ${msg}`); }
function fail(msg) { console.error(`  ❌ ${msg}`); }

function run(cmd, opts = {}) {
  try {
    return execSync(cmd, { encoding: 'utf8', stdio: 'pipe', ...opts }).trim();
  } catch {
    return null;
  }
}

function ensureDir(dir) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

// ─── Commands ───

function install() {
  console.log('\n🐱 NyanBar (Claude Code) Installer\n');

  // Check platform
  if (process.platform !== 'darwin') {
    fail('NyanBar is macOS only.');
    process.exit(1);
  }

  // Check Swift
  const swiftVersion = run('swift --version');
  if (!swiftVersion) {
    fail('Swift not found. Install Xcode Command Line Tools:');
    log('  xcode-select --install');
    process.exit(1);
  }
  ok(`Swift found`);

  // Build
  console.log('\n📦 Building...\n');
  const buildResult = spawnSync('swift', ['build', '-c', 'release'], {
    cwd: PKG_DIR,
    stdio: 'inherit'
  });
  if (buildResult.status !== 0) {
    fail('Build failed.');
    process.exit(1);
  }

  const binPath = run(`swift build -c release --show-bin-path`, { cwd: PKG_DIR });
  if (!binPath) {
    fail('Could not find build output.');
    process.exit(1);
  }

  // Create .app bundle
  console.log('\n📱 Creating app bundle...\n');
  ensureDir(path.join(APP_BUNDLE, 'Contents', 'MacOS'));
  ensureDir(path.join(APP_BUNDLE, 'Contents', 'Resources'));

  fs.copyFileSync(
    path.join(binPath, APP_NAME),
    path.join(APP_BUNDLE, 'Contents', 'MacOS', APP_NAME)
  );
  fs.chmodSync(path.join(APP_BUNDLE, 'Contents', 'MacOS', APP_NAME), 0o755);

  const pkgVersion = require(path.join(PKG_DIR, 'package.json')).version || '1.0.0';
  fs.writeFileSync(path.join(APP_BUNDLE, 'Contents', 'Info.plist'), `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>NyanBar</string>
    <key>CFBundleVersion</key>
    <string>${pkgVersion}</string>
    <key>CFBundleShortVersionString</key>
    <string>${pkgVersion}</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>`);
  // Ad-hoc code sign (required on macOS to prevent SIGKILL)
  run(`codesign --force --sign - "${APP_BUNDLE}"`);
  ok(`App bundle: ${APP_BUNDLE}`);

  // Install hook script
  console.log('\n🪝 Installing hook script...\n');
  ensureDir(HOOKS_DIR);
  fs.copyFileSync(
    path.join(PKG_DIR, 'Hooks', 'menubar-session-update.js'),
    path.join(HOOKS_DIR, 'menubar-session-update.js')
  );
  ok(`Hook: ${HOOKS_DIR}/menubar-session-update.js`);

  // Register hooks in settings.json
  console.log('\n⚙️  Registering hooks...\n');
  const settingsPath = path.join(HOME, '.claude', 'settings.json');
  let settings = {};
  try {
    if (fs.existsSync(settingsPath)) {
      settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
    }
  } catch { /* start fresh */ }

  if (!settings.hooks) settings.hooks = {};

  let hooksAdded = 0;
  for (const [event, entry] of Object.entries(HOOK_ENTRIES)) {
    if (!settings.hooks[event]) settings.hooks[event] = [];

    const exists = settings.hooks[event].some(e =>
      e.hooks?.some(h => h.command?.includes('menubar-session-update'))
    );

    if (!exists) {
      settings.hooks[event].push(entry);
      hooksAdded++;
    }
  }

  if (hooksAdded > 0) {
    fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2), 'utf8');
    ok(`${hooksAdded} hooks registered in settings.json`);
  } else {
    ok('Hooks already registered');
  }

  // Create sessions directory
  ensureDir(SESSIONS_DIR);

  // Install LaunchAgent
  console.log('\n🚀 Installing LaunchAgent...\n');
  ensureDir(path.dirname(PLIST_PATH));
  fs.writeFileSync(PLIST_PATH, `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${BUNDLE_ID}</string>
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
</plist>`);
  run(`launchctl unload "${PLIST_PATH}" 2>/dev/null`);
  run(`launchctl load "${PLIST_PATH}"`);
  ok(`LaunchAgent installed (auto-start on login)`);

  // Start the app
  console.log('\n🎉 Starting NyanBar...\n');
  run(`killall ${APP_NAME} 2>/dev/null`);
  run(`open "${APP_BUNDLE}"`);
  ok('NyanBar is running!');

  console.log('\n───────────────────────────────────');
  console.log('  🐱 NyanBar (Claude Code) installed!');
  console.log('  메뉴바에 고양이가 나타났습니다 냥~');
  console.log('───────────────────────────────────\n');
}

function uninstall() {
  console.log('\n🐱 NyanBar Uninstaller\n');

  run(`killall ${APP_NAME} 2>/dev/null`);
  ok('App stopped');

  run(`launchctl unload "${PLIST_PATH}" 2>/dev/null`);
  try { fs.unlinkSync(PLIST_PATH); } catch {}
  ok('LaunchAgent removed');

  try { fs.rmSync(APP_BUNDLE, { recursive: true, force: true }); } catch {}
  ok('App bundle removed');

  try { fs.rmSync(SESSIONS_DIR, { recursive: true, force: true }); } catch {}
  ok('Session data removed');

  try { fs.unlinkSync(path.join(HOOKS_DIR, 'menubar-session-update.js')); } catch {}
  ok('Hook script removed');

  // Remove hooks from settings.json
  const settingsPath = path.join(HOME, '.claude', 'settings.json');
  try {
    if (fs.existsSync(settingsPath)) {
      const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
      if (settings.hooks) {
        for (const event of Object.keys(HOOK_ENTRIES)) {
          if (settings.hooks[event]) {
            settings.hooks[event] = settings.hooks[event].filter(e =>
              !e.hooks?.some(h => h.command?.includes('menubar-session-update'))
            );
            if (settings.hooks[event].length === 0) delete settings.hooks[event];
          }
        }
        fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2), 'utf8');
        ok('Hooks removed from settings.json');
      }
    }
  } catch {}

  console.log('\n  🐱 NyanBar uninstalled. 안녕히 가세요 냥~\n');
}

function status() {
  console.log('\n🐱 NyanBar Status\n');

  const running = run(`pgrep -l ${APP_NAME}`);
  log(`App: ${running ? '🟢 Running' : '🔴 Not running'}`);
  log(`Bundle: ${fs.existsSync(APP_BUNDLE) ? '✅ Installed' : '❌ Not found'}`);
  log(`LaunchAgent: ${fs.existsSync(PLIST_PATH) ? '✅ Installed' : '❌ Not found'}`);
  log(`Hook: ${fs.existsSync(path.join(HOOKS_DIR, 'menubar-session-update.js')) ? '✅ Installed' : '❌ Not found'}`);

  const sessions = fs.existsSync(SESSIONS_DIR)
    ? fs.readdirSync(SESSIONS_DIR).filter(f => f.endsWith('.json'))
    : [];
  log(`Sessions: ${sessions.length} active`);

  console.log('');
}

function start() {
  if (!fs.existsSync(APP_BUNDLE)) {
    fail('NyanBar not installed. Run: nyanbar install');
    process.exit(1);
  }
  run(`killall ${APP_NAME} 2>/dev/null`);
  run(`open "${APP_BUNDLE}"`);
  ok('NyanBar started 냥~');
}

function stop() {
  run(`killall ${APP_NAME} 2>/dev/null`);
  ok('NyanBar stopped');
}

// ─── CLI ───

const command = process.argv[2] || 'help';

switch (command) {
  case 'install':   install(); break;
  case 'uninstall': uninstall(); break;
  case 'status':    status(); break;
  case 'start':     start(); break;
  case 'stop':      stop(); break;
  case 'help':
  default:
    console.log(`
🐱 NyanBar (Claude Code)

Usage:
  nyanbar install     Build & install everything
  nyanbar uninstall   Remove everything
  nyanbar start       Start the app
  nyanbar stop        Stop the app
  nyanbar status      Check installation status
  nyanbar help        Show this message
`);
}

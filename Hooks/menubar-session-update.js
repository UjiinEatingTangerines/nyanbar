#!/usr/bin/env node
/**
 * Menu Bar Session Update Hook
 *
 * Writes per-session state files to ~/.claude/menubar-sessions/ for the
 * Claude Code Menu Bar app to monitor.
 *
 * Hook IDs:
 *   menubar:session-start  → status: "working"
 *   menubar:tool-use       → status: "working" (debounced)
 *   menubar:stop           → status: "completed"
 *   menubar:session-end    → deletes session file
 *
 * Profiles: minimal, standard, strict
 */

'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

const SESSIONS_DIR = path.join(os.homedir(), '.claude', 'menubar-sessions');
const DEBOUNCE_MS = 3000;
const MAX_MESSAGE_LENGTH = 120;

function ensureDirExists(dirPath) {
  try {
    if (!fs.existsSync(dirPath)) {
      fs.mkdirSync(dirPath, { recursive: true });
    }
  } catch (err) {
    if (err.code !== 'EEXIST') return false;
  }
  return true;
}

/**
 * Get a stable session identifier.
 * Priority:
 *   1. CLAUDE_SESSION_ID env var (official)
 *   2. CMUX_CLAUDE_PID (cmux terminal)
 *   3. process.ppid (parent PID — Claude Code process)
 *   4. cwd-based hash
 */
function getSessionId() {
  const envId = process.env.CLAUDE_SESSION_ID;
  if (envId && envId.trim()) return envId.trim();

  // Fallback: use Claude PID from cmux or parent PID
  const pid = process.env.CMUX_CLAUDE_PID || String(process.ppid || '');
  if (pid) return `pid-${pid}`;

  // Last resort: cwd hash
  const cwd = process.cwd();
  const crypto = require('crypto');
  return `cwd-${crypto.createHash('sha256').update(cwd).digest('hex').slice(0, 12)}`;
}

function getSessionFilePath(sessionId) {
  const safeId = sessionId.replace(/[^a-zA-Z0-9_-]/g, '_');
  return path.join(SESSIONS_DIR, `${safeId}.json`);
}

function getProjectName() {
  try {
    const { execSync } = require('child_process');
    const toplevel = execSync('git rev-parse --show-toplevel', {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
      timeout: 2000
    }).trim();
    return path.basename(toplevel);
  } catch {
    return path.basename(process.cwd()) || 'unknown';
  }
}

function readExistingState(filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    const parsed = JSON.parse(content);
    // Only read files with known schema version
    if (parsed && parsed.schemaVersion === 1) return parsed;
    return null;
  } catch {
    return null;
  }
}

function writeStateAtomic(filePath, data) {
  const tmpPath = filePath + '.tmp';
  try {
    fs.writeFileSync(tmpPath, JSON.stringify(data, null, 2), 'utf8');
    fs.renameSync(tmpPath, filePath);
    return true;
  } catch {
    try { fs.unlinkSync(tmpPath); } catch { /* ignore */ }
    return false;
  }
}

function truncateMessage(msg) {
  if (!msg || typeof msg !== 'string') return null;
  const firstLine = msg.split('\n').map(l => l.trim()).find(l => l.length > 0);
  if (!firstLine) return null;
  return firstLine.length > MAX_MESSAGE_LENGTH
    ? firstLine.slice(0, MAX_MESSAGE_LENGTH) + '...'
    : firstLine;
}

/**
 * Determine event type from:
 *   1. _MENUBAR_EVENT env var (set by hook command prefix)
 *   2. process.argv (when invoked via run-with-flags.js, hookId is argv[2])
 *   3. Infer from stdin content
 */
function getEventType(input) {
  const envEvent = process.env._MENUBAR_EVENT || '';
  if (envEvent) return envEvent;

  for (const arg of process.argv) {
    if (arg.includes('menubar:session-start')) return 'session-start';
    if (arg.includes('menubar:tool-use')) return 'tool-use';
    if (arg.includes('menubar:stop')) return 'stop';
    if (arg.includes('menubar:notification')) return 'notification';
    if (arg.includes('menubar:session-end')) return 'session-end';
  }

  // Infer from stdin content
  if (input && typeof input === 'object') {
    if (input.last_assistant_message !== undefined) return 'stop';
    if (input.tool_name !== undefined) return 'tool-use';
  }

  return 'unknown';
}

function run(raw) {
  try {
    const sessionId = getSessionId();
    if (!sessionId) return raw;

    ensureDirExists(SESSIONS_DIR);

    const filePath = getSessionFilePath(sessionId);
    const now = new Date().toISOString();
    const existing = readExistingState(filePath);

    let input = {};
    try {
      if (raw && raw.trim()) input = JSON.parse(raw);
    } catch { /* ignore parse errors */ }

    const event = getEventType(input);
    const claudePid = parseInt(process.env.CMUX_CLAUDE_PID || '', 10) || process.ppid || null;

    // Capture terminal identifiers for panel focusing
    const cmuxPanelId = process.env.CMUX_PANEL_ID || null;
    const cmuxTabId = process.env.CMUX_TAB_ID || null;
    const cmuxSurfaceId = process.env.CMUX_SURFACE_ID || null;

    // Detect terminal app — cmux takes priority if detected
    const isCmux = !!(process.env.CMUX_PANEL_ID || process.env.CMUX_CLAUDE_PID);
    const terminalApp = isCmux
      ? 'cmux'
      : (process.env.TERM_PROGRAM             // iTerm2, Apple_Terminal, vscode, WarpTerminal
        || process.env.__CFBundleIdentifier    // macOS bundle ID fallback
        || null);

    switch (event) {
      case 'session-start': {
        const state = {
          schemaVersion: 1,
          sessionId,
          status: 'working',
          projectName: getProjectName(),
          workingDirectory: process.cwd(),
          startedAt: now,
          lastUpdatedAt: now,
          workingStartedAt: now,
          lastMessage: null,
          lastToolName: null,
          completedAt: null,
          diedAt: null,
          pid: claudePid,
          terminalApp,
          cmuxPanelId,
          cmuxTabId,
          cmuxSurfaceId
        };
        writeStateAtomic(filePath, state);
        break;
      }

      case 'tool-use': {
        // Debounce: skip if file was recently updated
        if (existing) {
          const lastUpdate = new Date(existing.lastUpdatedAt).getTime();
          if (Date.now() - lastUpdate < DEBOUNCE_MS) return raw;
        }

        const state = existing || {
          schemaVersion: 1,
          sessionId,
          status: 'working',
          projectName: getProjectName(),
          workingDirectory: process.cwd(),
          startedAt: now,
          lastMessage: null,
          completedAt: null,
          diedAt: null,
          pid: claudePid,
          terminalApp,
          cmuxPanelId,
          cmuxTabId,
          cmuxSurfaceId
        };

        // Track when this working cycle started (reset on non-working → working transition)
        const wasWorking = existing && existing.status === 'working';
        if (!wasWorking) {
          state.workingStartedAt = now;
        }

        state.status = 'working';
        state.lastUpdatedAt = now;
        state.lastToolName = input.tool_name || null;
        if (!state.pid) state.pid = claudePid;
        if (!state.terminalApp && terminalApp) state.terminalApp = terminalApp;
        if (!state.cmuxPanelId && cmuxPanelId) state.cmuxPanelId = cmuxPanelId;
        if (!state.cmuxTabId && cmuxTabId) state.cmuxTabId = cmuxTabId;
        if (!state.cmuxSurfaceId && cmuxSurfaceId) state.cmuxSurfaceId = cmuxSurfaceId;

        writeStateAtomic(filePath, state);
        break;
      }

      case 'stop': {
        const state = existing || {
          schemaVersion: 1,
          sessionId,
          status: 'idle',
          projectName: getProjectName(),
          workingDirectory: process.cwd(),
          startedAt: now,
          diedAt: null,
          pid: claudePid,
          terminalApp,
          cmuxPanelId,
          cmuxTabId,
          cmuxSurfaceId
        };

        state.lastUpdatedAt = now;
        state.lastMessage = truncateMessage(input.last_assistant_message) || state.lastMessage;
        if (!state.pid) state.pid = claudePid;
        if (!state.terminalApp && terminalApp) state.terminalApp = terminalApp;
        if (!state.cmuxPanelId && cmuxPanelId) state.cmuxPanelId = cmuxPanelId;

        // Classify stop reason:
        // 1. AskUserQuestion → pending (user must choose)
        const lastTool = existing ? existing.lastToolName : null;
        const isPending = lastTool === 'AskUserQuestion';

        // 2. Check working duration since last working cycle started
        const workingStart = existing?.workingStartedAt
          ? new Date(existing.workingStartedAt).getTime()
          : (existing ? new Date(existing.startedAt).getTime() : 0);
        const workingDuration = (Date.now() - workingStart) / 1000;

        // 3. Check if real work tools were used
        const msg = (input.last_assistant_message || '').toLowerCase();
        const hasQuestionPattern = /할까요|진행할까요|선택해|어떤.*방식|어떻게.*할까|원하시|괜찮으시|confirm|proceed|which|choose/i.test(msg);

        if (isPending || hasQuestionPattern) {
          state.status = 'pending';
        } else if (workingDuration >= 10) {
          state.status = 'completed';
          state.completedAt = now;
        } else {
          state.status = 'idle';
        }

        writeStateAtomic(filePath, state);
        break;
      }

      case 'notification': {
        // Notification = Claude is waiting for user attention
        // This is the definitive "pending" signal
        if (existing) {
          existing.status = 'pending';
          existing.lastUpdatedAt = now;
          if (!existing.pid) existing.pid = claudePid;
          if (!existing.terminalApp && terminalApp) existing.terminalApp = terminalApp;
          if (!existing.cmuxPanelId && cmuxPanelId) existing.cmuxPanelId = cmuxPanelId;
          writeStateAtomic(filePath, existing);
        } else {
          const state = {
            schemaVersion: 1,
            sessionId,
            status: 'pending',
            projectName: getProjectName(),
            workingDirectory: process.cwd(),
            startedAt: now,
            lastUpdatedAt: now,
            lastMessage: null,
            lastToolName: null,
            completedAt: null,
            diedAt: null,
            pid: claudePid,
            terminalApp,
            cmuxPanelId,
            cmuxTabId,
            cmuxSurfaceId
          };
          writeStateAtomic(filePath, state);
        }
        break;
      }

      case 'session-end': {
        try {
          if (fs.existsSync(filePath)) {
            fs.unlinkSync(filePath);
          }
        } catch { /* ignore */ }
        break;
      }

      default:
        // Unknown event — still create/update a working state if nothing exists
        // This ensures sessions are tracked even with unknown event types
        if (!existing) {
          const state = {
            schemaVersion: 1,
            sessionId,
            status: 'working',
            projectName: getProjectName(),
            workingDirectory: process.cwd(),
            startedAt: now,
            lastUpdatedAt: now,
            lastMessage: null,
            lastToolName: null,
            completedAt: null,
            diedAt: null,
            pid: claudePid,
            terminalApp,
            cmuxPanelId,
            cmuxTabId,
            cmuxSurfaceId
          };
          writeStateAtomic(filePath, state);
        }
        break;
    }
  } catch (err) {
    try { process.stderr.write(`[MenuBar] Error: ${err.message}\n`); } catch { /* */ }
  }

  return raw;
}

module.exports = { run };

// Legacy stdin path (when invoked directly)
if (require.main === module) {
  const MAX_STDIN = 1024 * 1024;
  let data = '';
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', chunk => {
    if (data.length < MAX_STDIN) data += chunk.substring(0, MAX_STDIN - data.length);
  });
  process.stdin.on('end', () => {
    const output = run(data);
    if (output) process.stdout.write(output);
  });
}

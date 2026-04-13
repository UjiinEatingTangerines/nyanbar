# 🐱 NyanBar (Claude Code)

> A macOS menu bar app that watches your Claude Code sessions — with a tail-wagging cat loaf and rainbow notifications.

[![npm](https://img.shields.io/npm/v/nyanbar)](https://www.npmjs.com/package/nyanbar) [![GitHub stars](https://img.shields.io/github/stars/UjiinEatingTangerines/nyanbar?style=social)](https://github.com/UjiinEatingTangerines/nyanbar/stargazers) ![macOS](https://img.shields.io/badge/macOS-14.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9+-orange) [![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

```bash
npm install -g nyanbar && nyanbar install
```

> ⭐ **If NyanBar helps you, please give it a star on [GitHub](https://github.com/UjiinEatingTangerines/nyanbar)!**
> It motivates further development and helps other Claude Code users discover the project.

---

## Why NyanBar?

When you work with Claude Code, you often run multiple sessions at once.
Switching to each terminal just to check whether a task is done is tedious.

NyanBar puts a **cat loaf in your menu bar** that watches every Claude Code session in real time.
When work finishes, a **rainbow flashes across the screen** so you know instantly — and one click jumps you to the right terminal.

---

## Features

🍞 **Menu Bar Cat Loaf** — a bread-shaped cat that wags its tail to show what's happening

| State | Cat | Menu Bar Text |
|------|--------|--------------|
| **Idle** | Gentle tail sway + occasional yawn | `🍞 Baking bread..` (30 random meme messages) |
| **Working** | Active S-shaped tail wag | Project name |
| **Pending** | Pulse blink | `🙋 Waiting for input` |
| **Completed** | 🌈 Rainbow cat + sound | `done!` |
| **Sleep** | 💤 Slowly breathing cat | `💤 zzZ...` |

📋 **Session Dashboard** — click the cat to see every session at a glance

- Working / Waiting for Input groups, card-based UI
- Project name, path, elapsed time, terminal app, last message
- Click a card to jump to that terminal

🌈 **Rainbow Notification** — never miss a completed task

- A flowing rainbow gradient bar at the top of the screen
- Mirrored across every connected display
- Stays until you acknowledge it (one click on the icon dismisses)
- Only fires for tasks longer than 10 seconds (short replies are ignored)

📜 **History** — see completed, idle, and crashed sessions

- History tab for past sessions
- Auto-deleted after 24 hours (filesystem scan ensures cleanup)
- "Clear All" button for manual cleanup

⚙️ **Settings**

- 🌐 **Language**: Korean / Japanese / English (live switch)
- 🌓 **Appearance**: System / Light / Dark
- 🎨 **Cat Color**: 12-color palette + reset (auto-switches eye color for contrast)
- 🔊 **Completion Sound**: on/off
- 🌙 **Sleep Mode**: pause every notification
- 💬 **Custom Spinner Text**: add your own messages (toggle + delete)
- ❤️ **Health Check Interval**: 10s / 20s / 30s / 5m / 30m / 1h
- 🔄 **Update Check**: query npm for latest version + one-click update

---

## Installation

### npm (recommended)

```bash
npm install -g nyanbar
nyanbar install
```

### npx (no install)

```bash
npx nyanbar install
```

### Git Clone

```bash
git clone https://github.com/UjiinEatingTangerines/nyanbar.git
cd nyanbar
node bin/nyanbar.js install
```

> **Requirements**: macOS 14.0+, Node.js 18+, [Claude Code CLI](https://claude.ai/code), Xcode Command Line Tools (`xcode-select --install`)

### What `nyanbar install` does

1. Builds the app with Swift (`swift build -c release`)
2. Creates a code-signed bundle at `~/Applications/ClaudeMenuBar.app`
3. Copies the hook script to `~/.claude/scripts/hooks/`
4. Registers 6 hooks in `~/.claude/settings.json` (SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, Stop, SessionEnd)
5. Installs a LaunchAgent (auto-start on login)
6. Launches the app

---

## Commands

```bash
nyanbar install     # Build, install, register hooks, enable auto-start
nyanbar uninstall   # Remove everything
nyanbar start       # Start the app
nyanbar stop        # Stop the app
nyanbar status      # Check installation status
```

---

## Usage

1. The cat loaf appears in your menu bar
2. Start any Claude Code session — NyanBar detects it automatically
3. Click the cat → opens the dashboard (Sessions / History / Settings tabs)
4. Click a session card → jumps to that terminal
5. Task completed → rainbow + sound → click the cat to acknowledge

### Spinner Messages (30 each in 3 languages)

> 🍞 빵 굽는 중.. · 🐾 꾹꾹이 하는 중.. · 😴 골골골.. · 😾 야옹 안 할거다냥 · 🏃 3초후 미친듯이 뜀 · 😸 집사 교육 95% · ...

> 🍞 食パン焼き中.. · 🐾 ふみふみ中.. · 😴 ゴロゴロ.. · 😾 にゃーしないもん · 🏃 3秒後に全力疾走 · 😸 下僕の教育 95% · ...

> 🍞 Baking bread.. · 🐾 Making biscuits.. · 😴 Purring away.. · 😾 Not meowing today · 🏃 Zoomies in 3..2.. · 😸 Hooman training 95% · ...

---

## Smart Detection

| Situation | How it's detected | Result |
|-----------|-------------------|--------|
| Task longer than 10s completes | Stop hook + duration check + 10s time-based fallback | ✅ Rainbow + sound |
| Short reply / error | Stop hook + duration < 10s | idle (no rainbow) |
| AskUserQuestion | Stop hook + tool name check | pending (🙋 waiting for input) |
| Question pattern | Message pattern match | pending |
| Permission prompt | 30s stale-working detection | pending |
| Idle reminder after Stop | Notification only flips `working`/`pending` → `pending` (never overrides `completed`/`idle`) | no phantom pending |
| Real-time tool tracking | Hook tool-use debounce reduced to 500ms + UserPromptSubmit hook fires on new user message | dashboard reflects live tool/turn within ~0.5s |
| Faster session discovery | Process scan runs every 2nd health check (was every 5th) | hookless sessions appear in seconds |
| Animation overhead | NSImage frame cache (NSBitmapImageRep) + skip identical button updates | ~80% fewer image allocations per second |
| Long-running tool heartbeat | PostToolUse hook refreshes `lastUpdatedAt` every tool completion | no false stale-working during long Bash/Edit chains |
| Countdown tick waste | Countdown timer pauses while popover is closed | saves 86,400 ticks/day of SwiftUI re-evaluation |
| Background timer wakes | `Timer.tolerance` on non-critical timers (poll 2s / refresh 5s / health 10%) | macOS coalesces wakes → better battery life |
| Process exited | PID health check | dead |
| cmux tab closed | Surface validity check | dead |
| Session without hook | Process scan (`ps`) | auto-discovered + tracked |
| MacBook woken from sleep | Sleep/Wake notifications + phantom popover reset + full timer restart + button re-validation | auto-recovered |
| UI freeze prevention | Background health check + adaptive FPS (idle 3fps, working 5fps) | CPU ~4%, no main-thread blocking |
| Rapid file changes | DispatchSource events with 0.3s debounce | no reload storms |
| Resource efficiency | Single-pass health-check I/O + 20fps rainbow | reduced CPU & memory |

---

## Supported Terminals

| Terminal | Session Detection | Click to Focus |
|----------|:-:|:-:|
| cmux | ✅ | ✅ (per panel) |
| Ghostty | ✅ | ✅ |
| iTerm2 | ✅ | ✅ |
| Terminal.app | ✅ | ✅ |
| VS Code | ✅ | ✅ |
| Warp | ✅ | ✅ |
| IntelliJ | ✅ | ✅ |

---

## Architecture

```
Claude Code Hooks ──write──→ ~/.claude/menubar-sessions/*.json
                                        │
                               DispatchSource (file watch)
                                        │
                              NyanBar (SwiftUI + AppKit)
                                        │
                     ┌──────────────────┼──────────────────┐
                     │                  │                  │
               Menu Bar Icon     Session Dashboard    Rainbow Overlay
               (cat loaf 🍞)    (NSPopover)          (all screens 🌈)
```

<details>
<summary>Project Structure</summary>

```
nyanbar/
├── package.json              # npm package
├── bin/nyanbar.js            # CLI (install/uninstall/start/stop/status)
├── Package.swift             # Swift Package Manager
├── Sources/ClaudeMenuBar/
│   ├── ClaudeMenuBarApp.swift
│   ├── AppDelegate.swift     # NSStatusItem + NSPopover
│   ├── Core/
│   │   ├── SessionState.swift
│   │   ├── SessionDirectoryWatcher.swift
│   │   ├── RelativeTimeFormatter.swift
│   │   ├── AppLanguage.swift       # i18n (ko/ja/en)
│   │   └── ColorUtils.swift        # NSColor ↔ hex
│   ├── Services/
│   │   ├── MenuBarIconManager.swift  # Cat icon + animations
│   │   ├── HealthCheckService.swift  # PID + surface check
│   │   ├── SettingsStore.swift       # UserDefaults
│   │   ├── TerminalController.swift  # cmux/terminal focus
│   │   ├── UpdateChecker.swift       # npm version check
│   │   └── SoundPlayer.swift         # Completion sound
│   ├── Modules/
│   │   ├── SessionDashboard/
│   │   └── RainbowAnimation/
│   └── Views/
│       ├── PopoverContentView.swift
│       ├── HistoryView.swift
│       └── SettingsView.swift
├── Hooks/
│   └── menubar-session-update.js
└── scripts/
    ├── build.sh
    ├── install.sh
    └── uninstall.sh
```
</details>

---

## Uninstall

```bash
nyanbar uninstall
```

Removes the app, hook script, LaunchAgent, session data, and the hook entries in `settings.json` — clean and complete.

---

## Support the Project

If NyanBar makes your Claude Code workflow a little nicer:

- ⭐ **[Star the repo on GitHub](https://github.com/UjiinEatingTangerines/nyanbar)** — it really helps the project grow
- 🐛 **[Report bugs or suggest features](https://github.com/UjiinEatingTangerines/nyanbar/issues)**
- 🐱 Share it with other Claude Code users

Every star tells me people care about the project — thank you! 냥~

---

## License

[MIT](LICENSE) — Made with 🐾 in Korea.

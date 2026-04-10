# Claude Code Menu Bar 🐱

macOS 메뉴바에서 Claude Code 세션을 모니터링하는 앱입니다.
고양이빵(식빵고양이)이 메뉴바에 앉아서 Claude Code 작업 상태를 알려줍니다.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9+-orange) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **메뉴바 고양이 아이콘** — 식빵고양이가 작업 상태를 표시
  - Idle: 꼬리 살랑살랑 + 랜덤 밈 문구 (30종)
  - Working: 꼬리 활발히 흔들림 + 프로젝트명 표시
  - Completed: 무지개 고양이 + 화면 상단 무지개 오버레이
- **세션 대시보드** — 클릭하면 모든 Claude Code 세션 목록 표시
  - Working / Completed / Crashed / Idle 그룹별 정리
  - 프로젝트명, 경로, 경과시간, 마지막 메시지 표시
- **세션으로 이동** — 세션 카드 클릭 시 해당 터미널로 포커스 (cmux, iTerm2, Terminal.app 등)
- **무지개 알림** — 작업 완료 시 모든 모니터에 무지개 애니메이션 (확인할 때까지 지속)
- **헬스체크** — 세션이 살아있는지 주기적으로 확인 (5분/30분/1시간 설정)
- **자동 시작** — LaunchAgent로 로그인 시 자동 실행
- **멀티 터미널 지원** — cmux, iTerm2, Terminal.app, VS Code, Warp, Ghostty 등

## Requirements

- macOS 14.0 (Sonoma) 이상
- [Claude Code CLI](https://claude.ai/code) 설치 필요
- Swift 5.9+ (빌드 시)

## Installation

### Quick Install (권장)

```bash
# 1. 클론
git clone https://github.com/UjiinEatingTangerines/claude-menubar.git
cd claude-menubar

# 2. 빌드 & 설치
bash scripts/install.sh
```

### Manual Install

```bash
# 1. 빌드
swift build -c release

# 2. 앱 번들 생성
bash scripts/build.sh

# 3. Hook 등록 (Claude Code 연동)
# ~/.claude/settings.json의 hooks에 아래 4개 이벤트 추가
```

### Hook 등록

`~/.claude/settings.json`의 `hooks` 객체에 아래 항목을 추가해야 합니다.
각 이벤트 배열에 기존 hook이 있다면 배열 끝에 추가합니다.

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [{
          "type": "command",
          "command": "_MENUBAR_EVENT=session-start node \"$CLAUDE_PLUGIN_ROOT/scripts/hooks/menubar-session-update.js\"",
          "timeout": 5,
          "async": true
        }]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [{
          "type": "command",
          "command": "_MENUBAR_EVENT=tool-use node \"$CLAUDE_PLUGIN_ROOT/scripts/hooks/menubar-session-update.js\"",
          "timeout": 5,
          "async": true
        }]
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [{
          "type": "command",
          "command": "_MENUBAR_EVENT=stop node \"$CLAUDE_PLUGIN_ROOT/scripts/hooks/menubar-session-update.js\"",
          "timeout": 5,
          "async": true
        }]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "*",
        "hooks": [{
          "type": "command",
          "command": "_MENUBAR_EVENT=session-end node \"$CLAUDE_PLUGIN_ROOT/scripts/hooks/menubar-session-update.js\"",
          "timeout": 5,
          "async": true
        }]
      }
    ]
  }
}
```

Hook 스크립트를 Claude 설정 디렉토리에 복사합니다:

```bash
cp Hooks/menubar-session-update.js ~/.claude/scripts/hooks/
```

### Auto-Start 설정

```bash
# LaunchAgent 등록 (로그인 시 자동 시작)
cp LaunchAgent/com.claudecode.menubar.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.claudecode.menubar.plist
```

## Usage

1. 앱을 실행하면 메뉴바에 고양이빵 아이콘이 나타납니다
2. Claude Code 세션을 시작하면 자동으로 감지됩니다
3. 고양이 아이콘을 클릭하면 세션 대시보드가 열립니다
4. 세션 카드를 클릭하면 해당 터미널로 이동합니다
5. 작업이 완료되면 무지개 알림이 나타납니다 — 아이콘을 클릭하면 확인 처리됩니다

### Menu Bar States

| 상태 | 아이콘 | 텍스트 |
|------|--------|--------|
| Idle | 고양이빵 (꼬리 살랑) | 🍞 빵 굽는 중.. (밈 30종 랜덤) |
| Working | 고양이빵 (꼬리 활발) | 프로젝트명 |
| Completed | 무지개 고양이 | done! |

## Uninstall

```bash
bash scripts/uninstall.sh
```

또는 수동으로:
```bash
# 앱 종료
killall ClaudeMenuBar

# LaunchAgent 제거
launchctl unload ~/Library/LaunchAgents/com.claudecode.menubar.plist
rm ~/Library/LaunchAgents/com.claudecode.menubar.plist

# 앱 번들 삭제
rm -rf ~/Applications/ClaudeMenuBar.app

# 세션 데이터 삭제
rm -rf ~/.claude/menubar-sessions

# Hook 스크립트 삭제
rm ~/.claude/scripts/hooks/menubar-session-update.js
```

## Architecture

```
Claude Code Hooks ──write──→ ~/.claude/menubar-sessions/*.json
                                        │
                               DispatchSource (file watch)
                                        │
                               SwiftUI Menu Bar App
                                        │
                     ┌──────────────────┼──────────────────┐
                     │                  │                  │
               Menu Bar Icon     Session Dashboard    Rainbow Overlay
               (cat loaf)        (NSPopover)          (all screens)
```

### Project Structure

```
claude-menubar/
├── Package.swift
├── Sources/ClaudeMenuBar/
│   ├── ClaudeMenuBarApp.swift      # App entry point
│   ├── AppDelegate.swift           # NSStatusItem + NSPopover
│   ├── Core/
│   │   ├── SessionState.swift      # Data model
│   │   ├── SessionDirectoryWatcher.swift  # File watcher
│   │   └── RelativeTimeFormatter.swift
│   ├── Services/
│   │   ├── MenuBarIconManager.swift    # Cat icon + animations
│   │   ├── HealthCheckService.swift    # PID-based health check
│   │   ├── SettingsStore.swift         # UserDefaults
│   │   └── TerminalController.swift    # cmux/terminal focus
│   ├── Modules/
│   │   ├── SessionDashboard/       # Session cards UI
│   │   └── RainbowAnimation/       # Rainbow overlay
│   └── Views/
│       ├── PopoverContentView.swift
│       └── SettingsView.swift
├── Hooks/
│   └── menubar-session-update.js   # Claude Code hook script
└── scripts/
    ├── build.sh
    ├── install.sh
    └── uninstall.sh
```

## Supported Terminals

| Terminal | Session Detection | Focus (click to jump) |
|----------|:-:|:-:|
| cmux | ✅ | ✅ (panel-level) |
| Ghostty | ✅ | ✅ (app-level) |
| iTerm2 | ✅ | ✅ (app-level) |
| Terminal.app | ✅ | ✅ (app-level) |
| VS Code | ✅ | ✅ (app-level) |
| Warp | ✅ | ✅ (app-level) |

## License

MIT

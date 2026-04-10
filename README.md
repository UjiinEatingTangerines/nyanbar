# NyanBar (Claude Code) 🐱

macOS 메뉴바에서 Claude Code 세션을 모니터링하는 앱입니다.
고양이빵(식빵고양이)이 메뉴바에 앉아서 Claude Code 작업 상태를 알려줍니다.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9+-orange) ![npm](https://img.shields.io/npm/v/nyanbar) ![License](https://img.shields.io/badge/license-MIT-green)

<!-- 스크린샷 추가 후 주석 해제
![Menu Bar Preview](assets/menubar-preview.png)
![Dashboard](assets/dashboard-preview.png)
![Animation](assets/menubar-animation.gif)
-->

## Features

- **메뉴바 고양이 아이콘** — 식빵고양이가 작업 상태를 표시
  - Idle: 꼬리 살랑살랑 + 랜덤 밈 문구 (30종, 이모지 포함)
  - Working: 꼬리 활발히 흔들림 + 프로젝트명 표시
  - Completed: 무지개 고양이 + 화면 상단 무지개 오버레이
- **세션 대시보드** — 클릭하면 모든 Claude Code 세션 목록 표시
- **세션으로 이동** — 세션 카드 클릭 시 해당 터미널로 포커스
- **무지개 알림** — 작업 완료 시 모든 모니터에 무지개 애니메이션 (확인할 때까지 지속)
- **헬스체크** — 세션이 살아있는지 주기적으로 확인 (5분/30분/1시간)
- **자동 시작** — 로그인 시 자동 실행
- **멀티 터미널** — cmux, iTerm2, Terminal.app, VS Code, Warp, Ghostty

## Requirements

- macOS 14.0 (Sonoma) 이상
- Node.js 18+ (npm 설치 시)
- [Claude Code CLI](https://claude.ai/code)

---

## Installation

### npm (권장) ⚡

```bash
npm install -g nyanbar
nyanbar install
```

이 한 줄이면 끝! 빌드, 앱 설치, Hook 등록, LaunchAgent 설정까지 자동으로 완료됩니다.

### npx (설치 없이 실행)

```bash
npx nyanbar install
```

### Git Clone

```bash
git clone https://github.com/UjiinEatingTangerines/nyanbar.git
cd nyanbar
npm install
nyanbar install
```

---

## Commands

```bash
nyanbar install     # 빌드 + 설치 + Hook 등록 + 자동시작 설정
nyanbar uninstall   # 완전 제거 (앱, Hook, LaunchAgent, 세션 데이터)
nyanbar start       # 앱 시작
nyanbar stop        # 앱 종료
nyanbar status      # 설치 상태 확인
nyanbar help        # 도움말
```

### `nyanbar install` 이 하는 것

1. ✅ Swift로 앱 빌드 (`swift build -c release`)
2. ✅ `~/Applications/ClaudeMenuBar.app` 번들 생성
3. ✅ Hook 스크립트를 `~/.claude/scripts/hooks/`에 복사
4. ✅ `~/.claude/settings.json`에 4개 Hook 자동 등록
5. ✅ LaunchAgent 설치 (로그인 시 자동 시작)
6. ✅ 앱 실행

### `nyanbar uninstall` 이 하는 것

1. 앱 종료
2. LaunchAgent 제거
3. 앱 번들 삭제
4. Hook 스크립트 삭제
5. `settings.json`에서 Hook 항목 제거
6. 세션 데이터 삭제

---

## Usage

1. 앱이 실행되면 메뉴바에 고양이빵 아이콘이 나타납니다
2. Claude Code 세션을 시작하면 자동으로 감지됩니다
3. 고양이 아이콘을 클릭하면 세션 대시보드가 열립니다
4. 세션 카드를 클릭하면 해당 터미널로 이동합니다
5. 작업이 완료되면 무지개 알림 → 아이콘 클릭하면 확인 처리

### Menu Bar States

| 상태 | 아이콘 | 텍스트 |
|------|--------|--------|
| Idle | 🐱 고양이빵 (꼬리 살랑) | 🍞 빵 굽는 중.. (밈 30종 랜덤) |
| Working | 🐱 고양이빵 (꼬리 활발) | 프로젝트명 |
| Completed | 🌈 무지개 고양이 | done! |

### Spinner Messages (30종)

> 🍞 빵 굽는 중.. · 🐾 꾹꾹이 하는 중.. · 😴 골골골.. · 💤 낮잠 모드.. · 👀 집사 감시 중.. · 😾 야옹 안 할거다냥 · 🏃 3초후 미친듯이 뜀 · 😸 집사 교육 95% · ...

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

## Project Structure

```
nyanbar/
├── package.json              # npm package
├── bin/nyanbar.js            # CLI (install/uninstall/start/stop/status)
├── Package.swift             # Swift Package Manager
├── Sources/ClaudeMenuBar/    # Swift app source
│   ├── AppDelegate.swift
│   ├── Core/                 # SessionState, Watcher, Formatter
│   ├── Services/             # IconManager, HealthCheck, Settings, Terminal
│   ├── Modules/              # SessionDashboard, RainbowAnimation
│   └── Views/                # PopoverContent, Settings
├── Hooks/                    # Claude Code hook script
│   └── menubar-session-update.js
└── scripts/                  # Shell scripts (build, install, uninstall)
```

## Supported Terminals

| Terminal | Detection | Focus (click) |
|----------|:-:|:-:|
| cmux | ✅ | ✅ panel-level |
| Ghostty | ✅ | ✅ |
| iTerm2 | ✅ | ✅ |
| Terminal.app | ✅ | ✅ |
| VS Code | ✅ | ✅ |
| Warp | ✅ | ✅ |

## License

MIT

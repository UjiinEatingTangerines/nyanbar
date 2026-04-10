# 🐱 NyanBar (Claude Code)

> macOS 메뉴바에서 Claude Code 세션을 모니터링하는 고양이빵 앱

[![npm](https://img.shields.io/npm/v/nyanbar)](https://www.npmjs.com/package/nyanbar) ![macOS](https://img.shields.io/badge/macOS-14.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9+-orange) [![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

```bash
npm install -g nyanbar && nyanbar install
```

<!-- 스크린샷은 assets/ 에 추가 후 아래 주석 해제
![Preview](assets/menubar-preview.png)
-->

---

## 왜 NyanBar?

Claude Code로 작업하다 보면 여러 세션을 동시에 돌릴 때가 많습니다.
작업이 끝났는지 확인하려고 터미널을 계속 왔다 갔다 하는 건 비효율적이죠.

NyanBar는 **메뉴바에 고양이빵이 앉아서** 모든 Claude Code 세션 상태를 실시간으로 알려줍니다.
작업이 끝나면 **무지개 알림**으로 바로 알 수 있고, 클릭 한 번으로 해당 터미널로 이동할 수 있습니다.

---

## Features

🍞 **메뉴바 고양이빵** — 식빵고양이가 꼬리를 흔들며 작업 상태를 알려줌

| 상태 | 고양이 | 메뉴바 텍스트 |
|------|--------|-------------|
| **Idle** | 꼬리 살랑살랑 + 가끔 하품 | `🍞 빵 굽는 중..` (밈 30종 랜덤) |
| **Working** | 꼬리 활발히 S자 흔들림 | 프로젝트명 |
| **Completed** | 🌈 무지개 고양이 | `done!` |

📋 **세션 대시보드** — 고양이 클릭하면 모든 세션을 한눈에

- Working / Completed / Crashed / Idle 그룹별 카드 UI
- 프로젝트명, 경로, 경과시간, 마지막 메시지, 사용 터미널 표시
- 세션 카드 클릭 → 해당 터미널로 바로 이동

🌈 **무지개 알림** — 작업 완료를 놓치지 않음

- 화면 상단에 무지개 그라디언트 바가 흐름
- 모든 연결된 모니터에 동시 표시
- 확인할 때까지 계속 표시 (아이콘 클릭으로 해제)

⚙️ **설정**

- 헬스체크 주기: 5분 / 30분 / 1시간
- 다음 헬스체크까지 남은 시간 실시간 카운트다운
- 로그인 시 자동 시작 (LaunchAgent)

---

## Installation

### npm (권장)

```bash
npm install -g nyanbar
nyanbar install
```

### npx (설치 없이)

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

### `nyanbar install` 이 하는 것

1. Swift로 앱 빌드 (`swift build -c release`)
2. `~/Applications/ClaudeMenuBar.app` 번들 생성
3. Hook 스크립트를 `~/.claude/scripts/hooks/`에 복사
4. `~/.claude/settings.json`에 4개 Hook 자동 등록
5. LaunchAgent 설치 (로그인 시 자동 시작)
6. 앱 실행

---

## Commands

```bash
nyanbar install     # 빌드 + 설치 + Hook 등록 + 자동시작
nyanbar uninstall   # 완전 제거
nyanbar start       # 앱 시작
nyanbar stop        # 앱 종료
nyanbar status      # 설치 상태 확인
```

---

## Usage

1. 메뉴바에 고양이빵 아이콘이 나타남
2. Claude Code 세션을 시작하면 자동 감지
3. 고양이 클릭 → 세션 대시보드
4. 세션 카드 클릭 → 해당 터미널로 이동
5. 작업 완료 → 무지개 알림 → 고양이 클릭으로 확인

### 스피너 문구 (30종)

> 🍞 빵 굽는 중.. · 🐾 꾹꾹이 하는 중.. · 😴 골골골.. · 💤 낮잠 모드.. · 👀 집사 감시 중.. · 😾 야옹 안 할거다냥 · 🏃 3초후 미친듯이 뜀 · 😸 집사 교육 95% · 💧 고양이는 액체.. · 🔴 레이저 추적 중! · ...

---

## Supported Terminals

| Terminal | 세션 감지 | 클릭 이동 |
|----------|:-:|:-:|
| cmux | ✅ | ✅ (패널 단위) |
| Ghostty | ✅ | ✅ |
| iTerm2 | ✅ | ✅ |
| Terminal.app | ✅ | ✅ |
| VS Code | ✅ | ✅ |
| Warp | ✅ | ✅ |

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
│   ├── AppDelegate.swift     # NSStatusItem + NSPopover
│   ├── Core/                 # SessionState, Watcher, Formatter
│   ├── Services/             # IconManager, HealthCheck, Settings, Terminal
│   ├── Modules/              # SessionDashboard, RainbowAnimation
│   └── Views/                # PopoverContent, Settings
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

앱, Hook, LaunchAgent, 세션 데이터까지 깨끗하게 제거됩니다.

## License

[MIT](LICENSE)

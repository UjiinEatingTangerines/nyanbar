# 🐱 NyanBar (Claude Code)

> macOS 메뉴바에서 Claude Code 세션을 모니터링하는 고양이빵 앱

[![npm](https://img.shields.io/npm/v/nyanbar)](https://www.npmjs.com/package/nyanbar) ![macOS](https://img.shields.io/badge/macOS-14.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9+-orange) [![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

```bash
npm install -g nyanbar && nyanbar install
```

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
| **Pending** | 아이콘 깜빡 | `🙋 입력 대기` |
| **Completed** | 🌈 무지개 고양이 + 사운드 | `done!` |
| **Sleep** | 💤 천천히 숨쉬는 고양이 | `💤 zzZ...` |

📋 **세션 대시보드** — 고양이 클릭하면 모든 세션을 한눈에

- Working / Waiting for Input / 그룹별 카드 UI
- 프로젝트명, 경로, 경과시간, 터미널 앱, 마지막 메시지 표시
- 세션 카드 클릭 → 해당 터미널로 바로 이동

🌈 **무지개 알림** — 작업 완료를 놓치지 않음

- 화면 상단에 무지개 그라디언트 바가 흐름
- 모든 연결된 모니터에 동시 표시
- 확인할 때까지 계속 표시 (아이콘 클릭으로 해제)
- 10초 이상 작업 후 완료만 트리거 (짧은 응답은 무시)

📜 **히스토리** — 완료/유휴/충돌 세션 이력

- History 탭에서 과거 세션 확인
- 24시간 후 자동 삭제 (파일 시스템 직접 스캔으로 확실한 정리)
- Clear All 버튼으로 수동 정리

⚙️ **설정**

- 🌐 **언어**: 한국어 / 日本語 / English (실시간 전환)
- 🌓 **화면 모드**: System / Light / Dark
- 🎨 **고양이 색상**: 12색 팔레트 + 초기화 (밝은 색은 검정 눈, 어두운 색은 흰 눈 자동 전환)
- 🔊 **완료 사운드**: on/off
- 🌙 **수면 모드**: 모든 알림 일시 중지
- 💬 **커스텀 스피너**: 나만의 문구 추가 (on/off 토글 + 삭제)
- ❤️ **헬스체크**: 10s / 20s / 30s / 5m / 30m / 1h
- 🔄 **업데이트 체크**: npm 최신 버전 확인 + 원클릭 업데이트

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
2. `~/Applications/ClaudeMenuBar.app` 번들 생성 + 코드 서명
3. Hook 스크립트를 `~/.claude/scripts/hooks/`에 복사
4. `~/.claude/settings.json`에 5개 Hook 자동 등록 (SessionStart, PreToolUse, Stop, Notification, SessionEnd)
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
3. 고양이 클릭 → 세션 대시보드 (Sessions / History / Settings 탭)
4. 세션 카드 클릭 → 해당 터미널로 이동
5. 작업 완료 → 무지개 + 사운드 → 고양이 클릭으로 확인

### 스피너 문구 (30종 × 3개 언어)

> 🍞 빵 굽는 중.. · 🐾 꾹꾹이 하는 중.. · 😴 골골골.. · 😾 야옹 안 할거다냥 · 🏃 3초후 미친듯이 뜀 · 😸 집사 교육 95% · ...

> 🍞 食パン焼き中.. · 🐾 ふみふみ中.. · 😴 ゴロゴロ.. · 😾 にゃーしないもん · 🏃 3秒後に全力疾走 · 😸 下僕の教育 95% · ...

> 🍞 Baking bread.. · 🐾 Making biscuits.. · 😴 Purring away.. · 😾 Not meowing today · 🏃 Zoomies in 3..2.. · 😸 Hooman training 95% · ...

---

## Smart Detection

| 상황 | 감지 방법 | 결과 |
|------|----------|------|
| 10초+ 작업 후 완료 | Stop hook + duration check + 10s 시간 기반 감지 | ✅ 무지개 + 사운드 |
| 짧은 응답/에러 | Stop hook + duration < 10s | idle (무지개 X) |
| AskUserQuestion | Stop hook + tool name check | pending (🙋 입력 대기) |
| 질문 패턴 | 메시지 패턴 매칭 | pending |
| 권한 프롬프트 | 30초 stale-working 감지 | pending |
| 프로세스 종료 | PID health check | dead |
| cmux 탭 닫힘 | Surface 유효성 체크 | dead |
| Hook 없는 세션 | 프로세스 스캔 (`ps`) | 자동 발견 + 추적 |
| 맥북 잠자기 후 | Sleep/Wake notification + 팬텀 팝오버 해제 + 전체 타이머 재시작 + 버튼 재검증 | 자동 복구 |
| UI 프리즈 방지 | 헬스체크 백그라운드 + 상태별 적응형 FPS (idle 3fps, working 5fps) | CPU ~4%, 메인 스레드 블로킹 없음 |

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

앱, Hook, LaunchAgent, 세션 데이터, settings.json의 Hook 항목까지 깨끗하게 제거됩니다.

## License

[MIT](LICENSE)

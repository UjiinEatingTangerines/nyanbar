import Foundation

/// Catalog verified against OpenUsage ProviderCatalog.swift at
/// 66aada23bfbac5c5988617fdd6a0f8edbe106764. See docs/provider-monitoring.md.
/// These identify local tools, NOT the model/API account used by those tools.
enum MonitoredProvider: String, Codable, CaseIterable, Identifiable {
    case claude, codex, cursor, antigravity, copilot, devin, grok, ollama, opencode, openrouter, zai

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .cursor: "Cursor"
        case .antigravity: "Antigravity"
        case .copilot: "Copilot"
        case .devin: "Devin"
        case .grok: "Grok"
        case .ollama: "Ollama"
        case .opencode: "OpenCode"
        case .openrouter: "OpenRouter"
        case .zai: "Z.ai"
        }
    }
    var canMonitor: Bool { self != .openrouter && self != .zai }
    func capability(in language: AppLanguage) -> String {
        switch language {
        case .korean:
            switch self {
            case .claude: return "Claude Code 훅: 작업 중, 입력 대기, 완료 감지. 프로세스로 감지할 때는 실행 여부만 확인합니다."
            case .codex: return "CLI / 앱 프로세스만 감지합니다. 여러 홈 폴더는 프로필로 표시되며, 확인된 계정이 아닙니다."
            case .cursor: return "Cursor 앱 / cursor-agent 프로세스만 감지합니다. 에이전트 작업 상태는 알 수 없습니다."
            case .copilot: return "Copilot CLI만 감지합니다. 편집기 확장과 사용량 한도는 모니터링하지 않습니다."
            case .ollama: return "로컬 앱 / CLI / 서버 프로세스만 감지합니다. 생성 상태와 Cloud 사용량 한도는 알 수 없습니다."
            case .openrouter, .zai: return "지원 안 됨: 로컬 프로세스로 식별할 수 없는 API 서비스입니다. 사용량 한도 연동은 구현되지 않았습니다."
            default: return "로컬 앱 / CLI 프로세스만 감지합니다. 작업 상태, 완료 여부, 사용량 한도는 알 수 없습니다."
            }
        case .japanese:
            switch self {
            case .claude: return "Claude Codeフック: 作業中、入力待ち、完了を検出。プロセスによる検出では実行の有無のみ確認します。"
            case .codex: return "CLI / アプリのプロセスのみ検出。複数のホームはプロファイルとして表示され、確認済みアカウントではありません。"
            case .cursor: return "Cursorアプリ / cursor-agentのプロセスのみ検出。エージェントのタスク状態は不明です。"
            case .copilot: return "Copilot CLIのみ検出。エディター拡張と使用量上限は監視しません。"
            case .ollama: return "ローカルアプリ / CLI / サーバーのプロセスのみ検出。生成状態やCloudの使用量上限は不明です。"
            case .openrouter, .zai: return "未対応: 特定できるローカルプロセスのないAPIサービスです。使用量上限の連携は未実装です。"
            default: return "ローカルアプリ / CLIのプロセスのみ検出。タスク状態、完了、使用量上限は不明です。"
            }
        case .english:
            return englishCapability
        }
    }

    private var englishCapability: String {
        switch self {
        case .claude: "Claude Code hooks: working, input, completion; process fallback: running only."
        case .codex: "CLI / app process only. Multiple homes shown as profiles, never verified accounts."
        case .cursor: "Cursor app / cursor-agent process only; no agent task state."
        case .copilot: "Copilot CLI only; editor extensions and quota are not monitored."
        case .ollama: "Local app / CLI / server process only; no generation state or Cloud quota."
        case .openrouter, .zai: "Unavailable: API service, no attributable local process. Quota integration is not implemented."
        default: "Local app / CLI process only; no task state, completion or quota."
        }
    }
}

struct ProviderPreferences {
    static let key = "enabledMonitoringProvidersV1"
    static func load(defaults: UserDefaults = .standard) -> Set<MonitoredProvider> {
        guard let values = defaults.stringArray(forKey: key) else { return [.claude] }
        return Set(values.compactMap(MonitoredProvider.init(rawValue:)).filter(\.canMonitor))
    }
    static func save(_ providers: Set<MonitoredProvider>, defaults: UserDefaults = .standard) {
        defaults.set(providers.filter(\.canMonitor).map(\.rawValue).sorted(), forKey: key)
    }
}

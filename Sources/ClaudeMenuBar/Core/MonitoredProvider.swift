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
    var capability: String {
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

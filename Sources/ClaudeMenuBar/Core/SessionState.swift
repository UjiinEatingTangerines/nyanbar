import Foundation

enum SessionStatus: String, Codable, CaseIterable {
    case working
    case pending   // waiting for user input (AskUserQuestion, etc.)
    case completed
    case idle
    case dead
}

struct SessionState: Codable, Identifiable, Equatable {
    let schemaVersion: Int
    let sessionId: String
    var status: SessionStatus
    let projectName: String
    let workingDirectory: String
    let startedAt: Date
    var lastUpdatedAt: Date
    var lastMessage: String?
    var lastToolName: String?
    var completedAt: Date?
    var diedAt: Date?
    var pid: Int?

    /// When the *currently running* tool started. Set by PreToolUse,
    /// cleared by PostToolUse / Stop / UserPromptSubmit. Lets the stale
    /// checker distinguish "long-running tool" (not stale) from "idle
    /// working session" (stale) — a Bash that streams for 5 minutes
    /// should stay "working", not flicker to "pending" at the 180s mark.
    var toolStartedAt: Date?

    // Terminal info
    var terminalApp: String?
    var cmuxPanelId: String?
    var cmuxTabId: String?
    var cmuxSurfaceId: String?

    var id: String { sessionId }

    var displayProjectName: String {
        projectName.isEmpty ? "unknown" : projectName
    }

    /// Whether this session can be focused in the terminal
    var canFocusTerminal: Bool {
        // cmux: direct panel focus
        if cmuxPanelId != nil || cmuxSurfaceId != nil { return true }
        // Other terminals: activate via AppleScript or bundle ID
        if terminalApp != nil { return true }
        return false
    }

    /// Human-readable terminal name
    var terminalDisplayName: String? {
        guard let app = terminalApp else { return nil }
        switch app {
        case "cmux", "com.cmuxterm.app": return "cmux"
        case "ghostty", "com.mitchellh.ghostty": return "Ghostty"
        case "iTerm.app", "iTerm2", "com.googlecode.iterm2": return "iTerm2"
        case "Apple_Terminal", "com.apple.Terminal": return "Terminal"
        case "vscode", "com.microsoft.VSCode": return "VS Code"
        case "WarpTerminal", "dev.warp.Warp-Stable": return "Warp"
        default:
            if app.contains(".") { return app.components(separatedBy: ".").last }
            return app
        }
    }
}

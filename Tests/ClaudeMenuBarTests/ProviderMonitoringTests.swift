import Testing
import Foundation
@testable import ClaudeMenuBar

struct ProviderMonitoringTests {
    @Test func liveProcessDiscoveryAndExit() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appendingPathComponent("opencode")
        try FileManager.default.createSymbolicLink(at: executable, withDestinationURL: URL(fileURLWithPath: "/bin/sleep"))
        let process = Process()
        process.executableURL = executable
        process.arguments = ["30"]
        try process.run()
        defer { if process.isRunning { process.terminate(); process.waitUntilExit() } }
        let pid = Int(process.processIdentifier)
        let found = ProcessScanner.findUntrackedSessions(existingPids: [], enabledProviders: [.opencode])
        #expect(found.contains { $0.pid == pid && $0.provider == .opencode && $0.state().status == .running })
        #expect(ProcessScanner.findUntrackedSessions(existingPids: [], enabledProviders: []).isEmpty)
        process.terminate()
        process.waitUntilExit()
        #expect(!ProcessScanner.findUntrackedSessions(existingPids: [], enabledProviders: [.opencode]).contains { $0.pid == pid })
    }

    @Test func catalogMatchesVerifiedUpstreamAndCapabilities() {
        #expect(MonitoredProvider.allCases.map(\.rawValue) == [
            "claude", "codex", "cursor", "antigravity", "copilot", "devin", "grok", "ollama", "opencode", "openrouter", "zai"
        ])
        #expect(Set(MonitoredProvider.allCases.filter { !$0.canMonitor }) == [.openrouter, .zai])
    }

    @Test func preferencesMigrationPersistenceAndServiceRejection() throws {
        let suite = "NyanBarTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(ProviderPreferences.load(defaults: defaults) == [.claude])
        ProviderPreferences.save([.codex, .cursor, .opencode, .zai], defaults: defaults)
        #expect(ProviderPreferences.load(defaults: defaults) == [.codex, .cursor, .opencode])
        ProviderPreferences.save([], defaults: defaults)
        #expect(ProviderPreferences.load(defaults: defaults) == [])
        defaults.set(["future-provider", "openrouter", "grok"], forKey: ProviderPreferences.key)
        #expect(ProviderPreferences.load(defaults: defaults) == [.grok])
    }

    @Test func executableRecognitionForEveryMonitorableProvider() {
        let cases: [(String, MonitoredProvider)] = [
            ("/opt/homebrew/bin/claude --resume", .claude),
            ("/usr/bin/node /opt/lib/node_modules/@anthropic-ai/claude-code/cli.js", .claude),
            ("/opt/bin/codex", .codex),
            ("node /opt/lib/node_modules/@openai/codex/bin/codex.js", .codex),
            ("/Applications/Cursor.app/Contents/MacOS/Cursor --reuse-window", .cursor),
            ("cursor-agent --resume", .cursor),
            ("/Users/test/.local/share/cursor-agent/versions/v1/agent", .cursor),
            ("/Applications/Antigravity.app/Contents/MacOS/Electron", .antigravity),
            ("agy", .antigravity), ("copilot", .copilot), ("devin", .devin),
            ("grok", .grok), ("ollama serve", .ollama), ("opencode", .opencode),
            ("node /opt/lib/node_modules/opencode-ai/bin/opencode", .opencode)
        ]
        for (command, provider) in cases {
            #expect(ProcessScanner.provider(for: command) == provider, "\(command)")
        }
    }

    @Test func noSubstringArgumentOrHelperFalsePositives() {
        for command in [
            "cat /tmp/claude", "echo codex", "sh -c claude", "agent", "claude-helper", "codex-notes",
            "node /tmp/claude.js", "python /tmp/codex", "vim /opt/bin/opencode", "openrouter", "zai",
            "/Applications/Cursor.app/Contents/Frameworks/Cursor Helper.app/Contents/MacOS/Cursor Helper",
            "/bin/echo /Applications/Cursor.app/Contents/MacOS/Cursor", "ps -eo command",
            "/bin/sh /tmp/menubar-session-update.js", "ClaudeMenuBar"
        ] {
            #expect(ProcessScanner.provider(for: command) == nil, "\(command)")
        }
    }

    @Test func optInAndProviderTreeDeduplication() {
        let table: [ProcessScanner.ProcessInfo] = [
            .init(pid: 10, ppid: 1, command: "codex"),
            .init(pid: 11, ppid: 10, command: "sh"),
            .init(pid: 12, ppid: 11, command: "codex"),
            .init(pid: 20, ppid: 1, command: "codex"),
            .init(pid: 30, ppid: 1, command: "cursor-agent"),
            .init(pid: 40, ppid: 1, command: "opencode")
        ]
        #expect(ProcessScanner.selectProcesses(table, existingPids: [], enabledProviders: []).isEmpty)
        #expect(ProcessScanner.selectProcesses(table, existingPids: [], enabledProviders: [.codex]).map { $0.0.pid } == [10, 20])
        #expect(ProcessScanner.selectProcesses(table, existingPids: [12], enabledProviders: [.codex, .cursor, .opencode]).map { $0.0.pid } == [20, 30, 40])
        #expect(ProcessScanner.selectProcesses(table, existingPids: [10], enabledProviders: [.codex]).map { $0.0.pid } == [20])
    }

    @Test func legacyHookDecodeAndProviderRoundTrip() throws {
        let json = """
        {"schemaVersion":1,"sessionId":"hook-id","status":"working","projectName":"demo","workingDirectory":"/tmp/demo","startedAt":"2026-01-01T00:00:00Z","lastUpdatedAt":"2026-01-01T00:00:00Z","pid":123,"toolStartedAt":"2026-01-01T00:00:00Z","cmuxPanelId":"panel"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let old = try decoder.decode(SessionState.self, from: Data(json.utf8))
        #expect(old.provider == .claude)
        #expect(old.status == .working)
        #expect(!old.isProcessObservation)
        #expect(old.cmuxPanelId == "panel")
        #expect(old.toolStartedAt != nil)
        let observed = ProcessScanner.DiscoveredSession(pid: 20, projectName: "demo", workingDirectory: "/tmp/demo", terminalApp: nil, provider: .codex, profilePath: "/tmp/.codex-work").state()
        #expect(observed.status == .running)
        #expect(observed.completedAt == nil)
        #expect(observed.lastToolName == nil)
        let encoder = JSONEncoder()
        #expect(try JSONDecoder().decode(SessionState.self, from: encoder.encode(observed)) == observed)
    }

    @Test func codexHomesMultipleDefaultsCustomSymlinksAndAssociation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in [".codex", ".config/codex", ".codex-work", ".config/codex-personal", "custom", "unrelated"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent(".codex-alias"), withDestinationURL: root.appendingPathComponent(".codex-work"))
        let homes = CodexHomeDiscovery.discover(home: root, environment: ["CODEX_HOME": root.appendingPathComponent("custom").path])
        #expect(Set(homes.map(\.label)) == [".codex", "codex", ".codex-work", "codex-personal", "custom"])
        let work = try #require(homes.first { $0.label == ".codex-work" })
        #expect(CodexHomeDiscovery.associatedHome(openPaths: [work.path + "/sessions/2026/test.jsonl"], homes: homes) == work)
        #expect(CodexHomeDiscovery.associatedHome(openPaths: [work.path + "/auth.json"], homes: homes) == nil)
        #expect(CodexHomeDiscovery.associatedHome(openPaths: [work.path + "-other/sessions/a.jsonl"], homes: homes) == nil)
        #expect(CodexHomeDiscovery.associatedHome(openPaths: homes.map { $0.path + "/sessions/a.jsonl" }, homes: homes) == nil)
        #expect(CodexHomeDiscovery.associatedHome(openPaths: [], homes: homes) == nil)
    }

    @Test func loaderPreservesHooksAndIgnoresLegacySyntheticWorking() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let now = Date()
        let hook = SessionState(schemaVersion: 1, sessionId: "pid-123", status: .completed, projectName: "demo", workingDirectory: "/tmp", startedAt: now, lastUpdatedAt: now)
        let legacy = SessionState(schemaVersion: 1, sessionId: "process-1", status: .running, projectName: "demo", workingDirectory: "/tmp", startedAt: now, lastUpdatedAt: now, observationSource: "process")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        for state in [hook, legacy] {
            try encoder.encode(state).write(to: root.appendingPathComponent(state.id + ".json"))
        }
        let loaded = SessionDirectoryWatcher.loadSessionsOffMain(directoryURL: root, staleThreshold: 3600)
        #expect(loaded.map(\.id) == ["pid-123"])
        #expect(loaded.first?.status == .completed)
        #expect(loaded.first?.provider == .claude)
    }
}

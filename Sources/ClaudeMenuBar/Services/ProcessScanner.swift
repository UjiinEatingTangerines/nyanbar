import Foundation
import Darwin

/// Local process presence only: never infers task activity or completion.
struct ProcessScanner {

    struct DiscoveredSession {
        let pid: Int
        let projectName: String
        let workingDirectory: String
        let terminalApp: String?
        let provider: MonitoredProvider
        let profilePath: String?

        func state(now: Date = Date()) -> SessionState {
            SessionState(schemaVersion: 1, sessionId: "process-\(provider.rawValue)-\(pid)",
                status: .running, projectName: projectName, workingDirectory: workingDirectory,
                startedAt: now, lastUpdatedAt: now, pid: pid, providerID: provider.rawValue,
                observationSource: "process", profilePath: profilePath, terminalApp: terminalApp)
        }
    }

    /// A single process table per poll; lsof reads paths, never file contents.
    static func findUntrackedSessions(existingPids: Set<Int>,
                                      enabledProviders: Set<MonitoredProvider>) -> [DiscoveredSession] {
        guard !enabledProviders.isEmpty else { return [] }
        let allProcs = getAllProcesses()
        let candidates = selectProcesses(allProcs, existingPids: existingPids, enabledProviders: enabledProviders)
        let homes = enabledProviders.contains(.codex) ? CodexHomeDiscovery.discover() : []

        var untracked: [DiscoveredSession] = []

        for (proc, provider) in candidates {

            // Revalidate metadata each poll; do not retain PID identity across exits.
            let cwd = getProcessCwd(pid: proc.pid) ?? "/"
            let projectName = cwd == "/" ? provider.displayName : URL(fileURLWithPath: cwd).lastPathComponent

            // Walk parent chain using cached process table (no extra ps calls)
            let terminal = identifyTerminal(pid: proc.pid, processTable: allProcs)

            untracked.append(DiscoveredSession(
                pid: proc.pid,
                projectName: projectName,
                workingDirectory: cwd,
                terminalApp: terminal,
                provider: provider,
                profilePath: provider == .codex
                    ? CodexHomeDiscovery.associatedHome(openPaths: openFilePaths(pid: proc.pid), homes: homes)?.path : nil
            ))
        }

        return untracked
    }

    // MARK: - Process Table (single ps call)

    struct ProcessInfo {
        let pid: Int
        let ppid: Int
        let command: String
    }

    /// Single `ps` call to build full process table
    private static func getAllProcesses() -> [ProcessInfo] {
        guard let output = runShell("/bin/ps -ww -U \(getuid()) -o pid,ppid,command") else { return [] }

        var results: [ProcessInfo] = []
        for line in output.split(separator: "\n").dropFirst() { // skip header
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.split(separator: " ", maxSplits: 2)
            guard parts.count >= 2,
                  let pid = Int(parts[0]),
                  let ppid = Int(parts[1]) else { continue }
            let command = parts.count > 2 ? String(parts[2]) : ""
            results.append(ProcessInfo(pid: pid, ppid: ppid, command: command))
        }
        return results
    }

    /// Recognize argv[0], or a known node package entry point; never search arguments.
    /// ps does not quote spaces reliably, so desktop entry points are anchored explicitly.
    static func provider(for command: String) -> MonitoredProvider? {
        let apps: [(String, String, MonitoredProvider)] = [
            ("Cursor", "Cursor", .cursor), ("Codex", "Codex", .codex),
            ("Antigravity", "Electron", .antigravity), ("Antigravity", "Antigravity", .antigravity),
            ("Devin", "Devin", .devin), ("Devin", "Electron", .devin),
            ("Ollama", "Ollama", .ollama), ("OpenCode", "OpenCode", .opencode),
            ("OpenCode", "opencode", .opencode)
        ]
        for (app, executable, provider) in apps {
            let pattern = "^\"?/[^\\s\"]*?/" + app + "\\.app/Contents/MacOS/" + executable + "(?:\"?(?:\\s|$))"
            if command.range(of: pattern, options: .regularExpression) != nil { return provider }
        }
        let tokens = command.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let first = tokens.first else { return nil }
        let executable = URL(fileURLWithPath: first.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))).lastPathComponent
        let names: [String: MonitoredProvider] = [
            "claude": .claude, "codex": .codex, "cursor-agent": .cursor,
            "agent": .cursor, "agy": .antigravity, "antigravity": .antigravity,
            "copilot": .copilot, "devin": .devin, "grok": .grok,
            "ollama": .ollama, "opencode": .opencode
        ]
        // 'agent' is generic: only Cursor's own install path is attributable.
        if executable == "agent" {
            return first.contains("/.local/share/cursor-agent/") ? .cursor : nil
        }
        if let provider = names[executable] { return provider }
        guard ["node", "nodejs", "bun"].contains(executable), tokens.count > 1 else { return nil }
        let script = tokens[1]
        let entries: [(String, MonitoredProvider)] = [
            ("/@anthropic-ai/claude-code/cli.js", .claude),
            ("/@openai/codex/bin/codex.js", .codex),
            ("/@github/copilot/index.js", .copilot),
            ("/opencode-ai/bin/opencode", .opencode)
        ]
        return entries.first { script.hasSuffix($0.0) }?.1
    }

    static func selectProcesses(_ processes: [ProcessInfo], existingPids: Set<Int>,
                                enabledProviders: Set<MonitoredProvider>) -> [(ProcessInfo, MonitoredProvider)] {
        let table = Dictionary(processes.map { ($0.pid, $0) }, uniquingKeysWith: { a, _ in a })
        func ancestors(_ pid: Int) -> Set<Int> {
            var seen = Set<Int>()
            var next = table[pid]?.ppid ?? 0
            while next > 1 && seen.insert(next).inserted { next = table[next]?.ppid ?? 0 }
            return seen
        }
        let recognized = processes.compactMap { proc -> (ProcessInfo, MonitoredProvider)? in
            guard let provider = provider(for: proc.command), enabledProviders.contains(provider), provider.canMonitor else { return nil }
            return (proc, provider)
        }
        let hookAncestors = existingPids.reduce(into: Set<Int>()) { $0.formUnion(ancestors($1)) }
        return recognized.filter { proc, provider in
            let parents = ancestors(proc.pid)
            guard !existingPids.contains(proc.pid), !hookAncestors.contains(proc.pid),
                  parents.isDisjoint(with: existingPids) else { return false }
            // One observation per provider process tree, even across shell intermediaries.
            return !recognized.contains { other, otherProvider in
                otherProvider == provider && parents.contains(other.pid)
            }
        }
    }

    private static func openFilePaths(pid: Int) -> [String] {
        guard let output = runShell("/usr/sbin/lsof -a -p \(pid) -Fn 2>/dev/null") else { return [] }
        return output.split(separator: "\n").filter { $0.hasPrefix("n/") }.map { String($0.dropFirst()) }
    }

    /// Get cwd via lsof (only for new PIDs)
    private static func getProcessCwd(pid: Int) -> String? {
        guard let output = runShell("/usr/sbin/lsof -a -p \(pid) -d cwd -Fn 2>/dev/null") else { return nil }
        for line in output.split(separator: "\n") {
            let s = String(line)
            if s.hasPrefix("n/") { return String(s.dropFirst()) }
        }
        return nil
    }

    /// Walk parent chain using cached process table (zero extra shell calls)
    static func identifyTerminal(pid: Int, processTable: [ProcessInfo]) -> String? {
        let pidMap = Dictionary(processTable.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        var currentPid = pid
        var depth = 0

        while currentPid > 1 && depth < 10 {
            guard let proc = pidMap[currentPid] else { break }
            let ppid = proc.ppid

            if let parent = pidMap[ppid] {
                let cmd = parent.command.lowercased()
                if cmd.hasPrefix("/") && cmd.contains("/orca.app/contents/") { return "com.stablyai.orca" }
                if cmd.contains("cmux") { return "cmux" }
                if cmd.contains("iterm") { return "iTerm2" }
                if cmd.contains("terminal") && cmd.contains("apple") { return "Apple_Terminal" }
                if cmd.contains("ghostty") { return "ghostty" }
                if cmd.contains("warp") { return "WarpTerminal" }
                if cmd.contains("code") && (cmd.contains("visual") || cmd.contains("electron")) { return "vscode" }
                if cmd.contains("intellij") || cmd.contains("jetbrains") { return "com.jetbrains.intellij" }
            }

            currentPid = ppid
            depth += 1
        }

        return nil
    }

    private static func runShell(_ command: String, timeout: TimeInterval = 10) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", command]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()

            // L3: Deadline — terminate child if it exceeds timeout (prevents
            // indefinite hangs from slow lsof, stuck NFS, etc.)
            let deadline = DispatchWorkItem {
                if task.isRunning { task.terminate() }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: deadline)

            // L1: Read FIRST, wait SECOND — prevents pipe buffer deadlock.
            // waitUntilExit before readDataToEndOfFile deadlocks when output
            // exceeds the 64 KB pipe buffer (ps output grows with process count).
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            deadline.cancel()

            guard task.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

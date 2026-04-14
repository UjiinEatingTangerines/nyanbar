import Foundation
import Darwin

/// Scans running processes to discover Claude Code sessions
/// that weren't tracked by hooks. Optimized for minimal shell spawning.
struct ProcessScanner {

    struct DiscoveredSession {
        let pid: Int
        let projectName: String
        let workingDirectory: String
        let terminalApp: String?
    }

    /// Find all running Claude Code processes and return untracked ones.
    /// Uses a single `ps` call + selective `lsof` only for new PIDs.
    static func findUntrackedSessions(existingPids: Set<Int>) -> [DiscoveredSession] {
        // Single ps call to get all processes with pid, ppid, command
        let allProcs = getAllProcesses()
        let claudeProcs = allProcs.filter { isClaudeProcess($0.command) }

        var untracked: [DiscoveredSession] = []

        for proc in claudeProcs {
            guard !existingPids.contains(proc.pid) else { continue }
            guard isMainClaudeProcess(command: proc.command) else { continue }

            // Only call lsof for truly new PIDs (expensive)
            let cwd = getProcessCwd(pid: proc.pid) ?? "/"
            let projectName = URL(fileURLWithPath: cwd).lastPathComponent

            // Walk parent chain using cached process table (no extra ps calls)
            let terminal = identifyTerminal(pid: proc.pid, processTable: allProcs)

            untracked.append(DiscoveredSession(
                pid: proc.pid,
                projectName: projectName,
                workingDirectory: cwd,
                terminalApp: terminal
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
        guard let output = runShell("ps -eo pid,ppid,command") else { return [] }

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

    private static func isClaudeProcess(_ command: String) -> Bool {
        command.contains("/claude") || command.hasPrefix("claude ") || command == "claude"
    }

    private static func isMainClaudeProcess(command: String) -> Bool {
        if command.contains("node ") { return false }
        if command.contains("menubar-session-update") { return false }
        if command.contains("run-with-flags") { return false }
        if command.contains("ClaudeMenuBar") { return false }
        return true
    }

    /// Get cwd via lsof (only for new PIDs)
    private static func getProcessCwd(pid: Int) -> String? {
        guard let output = runShell("lsof -p \(pid) -d cwd -Fn 2>/dev/null") else { return nil }
        for line in output.split(separator: "\n") {
            let s = String(line)
            if s.hasPrefix("n/") { return String(s.dropFirst()) }
        }
        return nil
    }

    /// Walk parent chain using cached process table (zero extra shell calls)
    private static func identifyTerminal(pid: Int, processTable: [ProcessInfo]) -> String? {
        let pidMap = Dictionary(processTable.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        var currentPid = pid
        var depth = 0

        while currentPid > 1 && depth < 10 {
            guard let proc = pidMap[currentPid] else { break }
            let ppid = proc.ppid

            if let parent = pidMap[ppid] {
                let cmd = parent.command.lowercased()
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

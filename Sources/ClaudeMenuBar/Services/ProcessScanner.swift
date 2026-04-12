import Foundation
import Darwin

/// Scans running processes to discover Claude Code sessions
/// that weren't tracked by hooks (e.g., cmux-spawned sessions).
struct ProcessScanner {

    struct DiscoveredSession {
        let pid: Int
        let projectName: String
        let workingDirectory: String
        let terminalApp: String?
    }

    /// Find all running Claude Code processes and return untracked ones
    static func findUntrackedSessions(existingPids: Set<Int>) -> [DiscoveredSession] {
        let claudeProcesses = findClaudeProcesses()
        var untracked: [DiscoveredSession] = []

        for (pid, command) in claudeProcesses {
            // Skip if already tracked
            guard !existingPids.contains(pid) else { continue }

            // Skip child/helper processes — only track main claude processes
            guard isMainClaudeProcess(command: command) else { continue }

            // Get working directory
            let cwd = getProcessCwd(pid: pid) ?? "/"
            let projectName = URL(fileURLWithPath: cwd).lastPathComponent

            // Identify terminal from parent process chain
            let terminal = identifyTerminal(pid: pid)

            untracked.append(DiscoveredSession(
                pid: pid,
                projectName: projectName,
                workingDirectory: cwd,
                terminalApp: terminal
            ))
        }

        return untracked
    }

    /// Check which tracked PIDs are still alive
    static func validatePids(_ pids: [Int]) -> [Int: Bool] {
        var results: [Int: Bool] = [:]
        for pid in pids {
            let result = kill(pid_t(pid), 0)
            results[pid] = (result == 0 || errno == EPERM)
        }
        return results
    }

    // MARK: - Private

    /// Run `ps` to find all claude processes
    private static func findClaudeProcesses() -> [(pid: Int, command: String)] {
        guard let output = runShell("ps -eo pid,command") else { return [] }

        var results: [(Int, String)] = []
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Parse: "12345 /path/to/claude ..."
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard parts.count == 2,
                  let pid = Int(parts[0]) else { continue }
            let command = String(parts[1])

            // Match claude binary
            if command.contains("/claude") || command.hasPrefix("claude ") || command == "claude" {
                results.append((pid, command))
            }
        }
        return results
    }

    /// Only track main claude processes, not helpers/workers
    private static func isMainClaudeProcess(command: String) -> Bool {
        // Main process patterns:
        // - "/path/to/claude" (bare)
        // - "/path/to/claude --session-id ..."
        // - "claude --dangerously-skip-permissions"
        // Skip node/hook child processes
        if command.contains("node ") { return false }
        if command.contains("menubar-session-update") { return false }
        if command.contains("run-with-flags") { return false }
        return true
    }

    /// Get process working directory via lsof
    private static func getProcessCwd(pid: Int) -> String? {
        guard let output = runShell("lsof -p \(pid) -Fn 2>/dev/null | grep '^n/' | head -1") else {
            return nil
        }
        // lsof output: "n/path/to/dir"
        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if path.hasPrefix("n") {
            return String(path.dropFirst())
        }
        return nil
    }

    /// Walk parent process chain to identify terminal app
    private static func identifyTerminal(pid: Int) -> String? {
        var currentPid = pid
        var depth = 0

        while currentPid > 1 && depth < 10 {
            // Get parent PID
            guard let ppidStr = runShell("ps -o ppid= -p \(currentPid)"),
                  let ppid = Int(ppidStr.trimmingCharacters(in: .whitespaces)) else {
                break
            }

            // Check parent's executable path
            if let path = getExecutablePath(pid: ppid) {
                let lower = path.lowercased()
                if lower.contains("cmux") { return "cmux" }
                if lower.contains("iterm") { return "iTerm2" }
                if lower.contains("terminal.app") { return "Apple_Terminal" }
                if lower.contains("ghostty") { return "ghostty" }
                if lower.contains("warp") { return "WarpTerminal" }
                if lower.contains("code") && lower.contains("visual") { return "vscode" }
                if lower.contains("intellij") || lower.contains("jetbrains") { return "com.jetbrains.intellij" }
            }

            currentPid = ppid
            depth += 1
        }

        return nil
    }

    /// Get executable path for a PID
    private static func getExecutablePath(pid: Int) -> String? {
        // PROC_PIDPATHINFO_MAXSIZE = 4 * MAXPATHLEN = 4 * 1024 = 4096
        let bufSize = 4096
        let pathBuffer = UnsafeMutablePointer<CChar>.allocate(capacity: bufSize)
        defer { pathBuffer.deallocate() }
        let result = proc_pidpath(pid_t(pid), pathBuffer, UInt32(bufSize))
        guard result > 0 else { return nil }
        return String(cString: pathBuffer)
    }

    private static func runShell(_ command: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", command]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

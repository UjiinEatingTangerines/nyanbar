import Foundation
import Darwin

@MainActor
final class HealthCheckService: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var nextCheckAt: Date?

    private var timer: Timer?
    private var countdownTimer: Timer?
    private let watcher: SessionDirectoryWatcher
    private let settings: SettingsStore
    var onHealthCheckDone: (() -> Void)?  // callback to trigger flash

    /// Seconds remaining until next health check (updated every second)
    var secondsRemaining: Int {
        guard let next = nextCheckAt else { return 0 }
        return max(0, Int(next.timeIntervalSinceNow))
    }

    /// Formatted countdown string: "4:32" or "0:05"
    var countdownString: String {
        let total = secondsRemaining
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private static let garbageCollectAge: TimeInterval = 24 * 60 * 60

    init(watcher: SessionDirectoryWatcher, settings: SettingsStore) {
        self.watcher = watcher
        self.settings = settings
    }

    func start() {
        isRunning = true
        scheduleTimer()
        startCountdown()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        isRunning = false
        nextCheckAt = nil
    }

    func reschedule() {
        guard isRunning else { return }
        scheduleTimer()
    }

    // MARK: - Private

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = settings.healthCheckSeconds
        nextCheckAt = Date().addingTimeInterval(interval)

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performHealthCheck()
                self?.nextCheckAt = Date().addingTimeInterval(self?.settings.healthCheckSeconds ?? 1800)
                // Trigger flash after reload is done
                self?.onHealthCheckDone?()
            }
        }
    }

    private func startCountdown() {
        countdownTimer?.invalidate()
        // Tick every second to update the published countdown
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.objectWillChange.send()
            }
        }
    }

    private func performHealthCheck() {
        // Check all non-dead sessions
        for session in watcher.sessions where session.status != .dead {
            // 1. PID check — if process died, mark as dead
            if let pid = session.pid {
                if !isProcessAlive(pid: pid) {
                    markAsDead(session)
                    continue
                }
            }

            // 2. For working/pending without PID, use staleness
            if session.pid == nil && (session.status == .working || session.status == .pending) {
                let stalenessThreshold = settings.healthCheckSeconds * 2
                let elapsed = Date().timeIntervalSince(session.lastUpdatedAt)
                if elapsed > stalenessThreshold {
                    markAsDead(session)
                    continue
                }
            }

            // 3. Validate cmux surface — if surface is gone, clear it
            if session.cmuxSurfaceId != nil {
                if !isCmuxSurfaceAlive(session.cmuxSurfaceId!) {
                    var updated = session
                    updated.cmuxSurfaceId = nil
                    updated.cmuxPanelId = nil
                    // If it was active and surface is gone, mark as dead
                    if session.status == .working || session.status == .pending {
                        updated.status = .dead
                        updated.diedAt = Date()
                    }
                    watcher.writeState(updated)
                }
            }
        }

        watcher.reload()
        garbageCollect()
    }

    private func markAsDead(_ session: SessionState) {
        var updated = session
        updated.status = .dead
        updated.diedAt = Date()
        watcher.writeState(updated)
    }

    /// Check if a cmux surface UUID is still valid
    private func isCmuxSurfaceAlive(_ surfaceId: String) -> Bool {
        guard TerminalController.isCmuxAvailable else { return true } // can't verify, assume alive

        let cmuxPath = "/Applications/cmux.app/Contents/Resources/bin/cmux"
        guard FileManager.default.isExecutableFile(atPath: cmuxPath) else { return true }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: cmuxPath)
        task.arguments = ["identify", "--surface", surfaceId]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else { return false }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let caller = json["caller"] as? [String: Any],
               let ref = caller["surface_ref"] as? String,
               !ref.isEmpty {
                return true
            }
            return false
        } catch {
            return true // can't verify, assume alive
        }
    }

    private func garbageCollect() {
        let now = Date()

        // Move stale pending/idle sessions to idle (10 min without update)
        for session in watcher.sessions where session.status == .pending {
            let elapsed = now.timeIntervalSince(session.lastUpdatedAt)
            if elapsed > 600 { // 10 minutes
                var updated = session
                updated.status = .idle
                watcher.writeState(updated)
            }
        }

        for session in watcher.sessions {
            guard session.status == .dead || session.status == .completed || session.status == .idle else { continue }
            let referenceDate = session.diedAt ?? session.completedAt ?? session.lastUpdatedAt
            if now.timeIntervalSince(referenceDate) > Self.garbageCollectAge {
                watcher.deleteSessionFile(sessionId: session.sessionId)
            }
        }
    }

    private func isProcessAlive(pid: Int) -> Bool {
        let result = kill(pid_t(pid), 0)
        if result == 0 { return true }
        return errno == EPERM
    }
}

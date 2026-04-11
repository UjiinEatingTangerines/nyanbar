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
                // Reset countdown for next cycle
                self?.nextCheckAt = Date().addingTimeInterval(self?.settings.healthCheckSeconds ?? 1800)
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
        let workingSessions = watcher.sessions.filter { $0.status == .working || $0.status == .pending }

        for session in workingSessions {
            if let pid = session.pid {
                if !isProcessAlive(pid: pid) {
                    markAsDead(session)
                }
            } else {
                let stalenessThreshold = settings.healthCheckSeconds * 2
                let elapsed = Date().timeIntervalSince(session.lastUpdatedAt)
                if elapsed > stalenessThreshold {
                    markAsDead(session)
                }
            }
        }

        garbageCollect()
    }

    private func markAsDead(_ session: SessionState) {
        var updated = session
        updated.status = .dead
        updated.diedAt = Date()
        watcher.writeState(updated)
        watcher.reload()
    }

    private func garbageCollect() {
        let now = Date()
        for session in watcher.sessions {
            guard session.status == .dead || session.status == .completed else { continue }
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

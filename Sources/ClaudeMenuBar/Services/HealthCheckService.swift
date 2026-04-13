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
    nonisolated(unsafe) private static var healthCheckCount = 0
    // Run process scan more often so untracked sessions (e.g., spawned in
    // a terminal whose hooks override the menubar hook) are picked up sooner.
    nonisolated private static let scanEveryNChecks = 2

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

    /// Restart all timers after wake from sleep
    func rescheduleAfterWake() {
        guard isRunning else { return }
        timer?.invalidate()
        timer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        scheduleTimer()
        startCountdown()
    }

    /// Pause the per-second countdown tick when the popover is hidden —
    /// nobody is watching the countdown, so publishing `objectWillChange`
    /// 86,400 times a day is pure waste.
    func pauseCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    /// Resume the countdown tick when the popover becomes visible again.
    func resumeCountdown() {
        guard isRunning, countdownTimer == nil else { return }
        startCountdown()
    }

    // MARK: - Private

    private func scheduleTimer() {
        timer?.invalidate()
        let interval = settings.healthCheckSeconds
        nextCheckAt = Date().addingTimeInterval(interval)

        let t = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            // Run health check on background thread to avoid blocking UI
            DispatchQueue.global(qos: .utility).async {
                self?.performHealthCheckBackground()
                DispatchQueue.main.async {
                    self?.watcher.reload()
                    self?.nextCheckAt = Date().addingTimeInterval(self?.settings.healthCheckSeconds ?? 1800)
                    self?.onHealthCheckDone?()
                }
            }
        }
        // Allow macOS to coalesce with other timers — health check is not time-critical.
        // 10% tolerance (up to 3 minutes on a 30-min interval) lets the scheduler wake
        // the CPU less often, saving battery.
        t.tolerance = max(1.0, interval * 0.1)
        timer = t
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

    /// Called from background thread — no UI access, file I/O only
    nonisolated private func performHealthCheckBackground() {
        // Read sessions from disk directly (avoid MainActor)
        let sessionsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/menubar-sessions")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: sessionsDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        ) else { return }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        var existingPids = Set<Int>()
        let gcAge: TimeInterval = 24 * 60 * 60
        let now = Date()

        // Single pass: health checks + GC (reads each file only once)
        for fileURL in files where fileURL.pathExtension == "json" {
            guard let data = try? Data(contentsOf: fileURL),
                  var session = try? decoder.decode(SessionState.self, from: data) else { continue }

            if let pid = session.pid { existingPids.insert(pid) }

            // GC: delete 24h+ old non-working sessions
            if session.status != .working {
                let ref = session.diedAt ?? session.completedAt ?? session.lastUpdatedAt
                if now.timeIntervalSince(ref) > gcAge {
                    try? FileManager.default.removeItem(at: fileURL)
                    continue
                }
            }

            guard session.status != .dead else { continue }

            // 1. PID check
            if let pid = session.pid {
                let alive = (kill(pid_t(pid), 0) == 0 || errno == EPERM)
                if !alive {
                    session.status = .dead
                    session.diedAt = now
                    if let encoded = try? encoder.encode(session) {
                        try? encoded.write(to: fileURL, options: .atomic)
                    }
                    continue
                }
            }

            // 2. Staleness for PID-less sessions
            if session.pid == nil && (session.status == .working || session.status == .pending) {
                let threshold: TimeInterval = 60  // 1 minute without PID
                if now.timeIntervalSince(session.lastUpdatedAt) > threshold {
                    session.status = .dead
                    session.diedAt = now
                    if let encoded = try? encoder.encode(session) {
                        try? encoded.write(to: fileURL, options: .atomic)
                    }
                    continue
                }
            }

            // 3. Stale pending → idle (10 min)
            if session.status == .pending {
                if now.timeIntervalSince(session.lastUpdatedAt) > 600 {
                    session.status = .idle
                    if let encoded = try? encoder.encode(session) {
                        try? encoded.write(to: fileURL, options: .atomic)
                    }
                }
            }
        }

        // 4. Process scan (every 5th check)
        Self.healthCheckCount += 1
        if Self.healthCheckCount % Self.scanEveryNChecks == 0 {
            let untracked = ProcessScanner.findUntrackedSessions(existingPids: existingPids)
            for discovered in untracked {
                let state = SessionState(
                    schemaVersion: 1,
                    sessionId: "pid-\(discovered.pid)",
                    status: .working,
                    projectName: discovered.projectName,
                    workingDirectory: discovered.workingDirectory,
                    startedAt: now,
                    lastUpdatedAt: now,
                    lastMessage: nil,
                    lastToolName: nil,
                    completedAt: nil,
                    diedAt: nil,
                    pid: discovered.pid,
                    terminalApp: discovered.terminalApp,
                    cmuxPanelId: nil,
                    cmuxTabId: nil,
                    cmuxSurfaceId: nil
                )
                if let encoded = try? encoder.encode(state) {
                    let safeId = state.sessionId.replacingOccurrences(
                        of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression
                    )
                    let url = sessionsDir.appendingPathComponent("\(safeId).json")
                    try? encoded.write(to: url, options: .atomic)
                }
            }
        }
    }

}

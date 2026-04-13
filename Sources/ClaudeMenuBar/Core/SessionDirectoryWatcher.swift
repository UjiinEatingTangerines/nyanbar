import Foundation
import Combine
import AppKit

@MainActor
final class SessionDirectoryWatcher: ObservableObject {
    @Published private(set) var sessions: [SessionState] = []

    let directoryURL: URL
    private let staleThreshold: TimeInterval
    private var directoryFD: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var pollTimer: Timer?
    private var reloadDebounceTimer: Timer?
    private let decoder: JSONDecoder
    private var wakeObserver: Any?

    init(
        directoryURL: URL? = nil,
        staleThreshold: TimeInterval = 6 * 60 * 60
    ) {
        self.directoryURL = directoryURL ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/menubar-sessions")
        self.staleThreshold = staleThreshold

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        self.decoder = dec
    }

    func startWatching() {
        ensureDirectory()
        setupDirectoryMonitor()
        startPollTimer()
        observeWakeSleep()
        reload()
    }

    func stopWatching() {
        dispatchSource?.cancel()
        dispatchSource = nil
        if directoryFD >= 0 {
            Darwin.close(directoryFD)
            directoryFD = -1
        }
        pollTimer?.invalidate()
        pollTimer = nil
        reloadDebounceTimer?.invalidate()
        reloadDebounceTimer = nil
        if let obs = wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(obs) }
    }

    /// Restart file monitoring (called after wake from sleep)
    func restartMonitoring() {
        // Tear down old dispatch source
        dispatchSource?.cancel()
        dispatchSource = nil
        if directoryFD >= 0 {
            Darwin.close(directoryFD)
            directoryFD = -1
        }
        // Restart poll timer (may have died during sleep)
        pollTimer?.invalidate()
        pollTimer = nil
        startPollTimer()
        // Recreate dispatch source
        setupDirectoryMonitor()
        reload()
    }

    /// Debounce rapid filesystem events into a single reload (0.1s window).
    /// The hook layer already debounces at 500ms, so filesystem-level events
    /// rarely burst tighter than that; a tight 100ms window here keeps
    /// first-event latency low while still collapsing simultaneous writes
    /// to multiple session files into one reload.
    private func scheduleReload() {
        reloadDebounceTimer?.invalidate()
        reloadDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.reload()
            }
        }
    }

    /// Reload sessions off the main thread. File I/O, JSON decode, and sort
    /// all happen on a background queue; only the final assignment to
    /// `@Published sessions` lands back on main. Callers are fire-and-forget.
    func reload() {
        let directoryURL = self.directoryURL
        let staleThreshold = self.staleThreshold
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let loaded = Self.loadSessionsOffMain(
                directoryURL: directoryURL,
                staleThreshold: staleThreshold
            )
            DispatchQueue.main.async {
                self?.sessions = loaded
            }
        }
    }

    /// Pure file I/O + decode + sort. Runs off the MainActor so the UI never
    /// blocks on disk — even with dozens of session files or a slow volume.
    nonisolated private static func loadSessionsOffMain(
        directoryURL: URL,
        staleThreshold: TimeInterval
    ) -> [SessionState] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let now = Date()
        var loaded: [SessionState] = []
        for fileURL in files where fileURL.pathExtension == "json" {
            guard let data = try? Data(contentsOf: fileURL),
                  let state = try? decoder.decode(SessionState.self, from: data),
                  state.schemaVersion == 1 else {
                continue
            }
            if now.timeIntervalSince(state.lastUpdatedAt) > staleThreshold {
                continue
            }
            loaded.append(state)
        }
        // Sort: working first (newest), then completed, then idle, then dead
        loaded.sort { a, b in
            let orderA = statusOrderValue(a.status)
            let orderB = statusOrderValue(b.status)
            if orderA != orderB { return orderA < orderB }
            return a.lastUpdatedAt > b.lastUpdatedAt
        }
        return loaded
    }

    nonisolated private static func statusOrderValue(_ status: SessionStatus) -> Int {
        switch status {
        case .working: return 0
        case .pending: return 1
        case .completed: return 2
        case .idle: return 3
        case .dead: return 4
        }
    }

    /// Write updated state back to disk (used by health check to mark dead)
    func writeState(_ state: SessionState) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let safeId = state.sessionId.replacingOccurrences(
            of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression
        )
        let fileURL = directoryURL.appendingPathComponent("\(safeId).json")

        guard let data = try? encoder.encode(state) else { return }
        // Use .atomic which handles replace correctly (unlike moveItem)
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Delete a session file
    func deleteSessionFile(sessionId: String) {
        let safeId = sessionId.replacingOccurrences(
            of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression
        )
        let fileURL = directoryURL.appendingPathComponent("\(safeId).json")
        try? FileManager.default.removeItem(at: fileURL)
        reload()
    }

    // MARK: - Computed

    /// Stale threshold: if a "working" session hasn't updated in this many seconds,
    /// it's likely waiting for user input (permission prompt, etc.).
    ///
    /// 180s balances two goals:
    ///   1. Long-running tools (Bash builds, test suites, slow fetches) can
    ///      legitimately run for minutes without emitting a PostToolUse —
    ///      PreToolUse fires at start, PostToolUse fires at end, nothing in
    ///      between. A 30s threshold would incorrectly flip them to "pending".
    ///   2. Truly stuck sessions (missed permission prompt, crashed API call)
    ///      eventually surface as pending so the user knows to check.
    ///
    /// Permission prompts are caught immediately by the Notification hook, so
    /// this threshold only matters when *all* signaling hooks miss.
    private static let pendingThreshold: TimeInterval = 180

    var workingSessions: [SessionState] {
        sessions.filter { $0.status == .working && !isStaleWorking($0) }
    }

    var pendingSessions: [SessionState] {
        let explicitPending = sessions.filter { $0.status == .pending }
        let stalePending = sessions.filter { $0.status == .working && isStaleWorking($0) }
        return explicitPending + stalePending
    }

    /// A "working" session that hasn't been updated recently is likely waiting for user input
    private func isStaleWorking(_ session: SessionState) -> Bool {
        guard session.status == .working else { return false }
        return Date().timeIntervalSince(session.lastUpdatedAt) > Self.pendingThreshold
    }

    var completedSessions: [SessionState] {
        sessions.filter { $0.status == .completed }
    }

    var idleSessions: [SessionState] {
        sessions.filter { $0.status == .idle }
    }

    var deadSessions: [SessionState] {
        sessions.filter { $0.status == .dead }
    }

    /// Active sessions (Sessions tab)
    var activeSessions: [SessionState] {
        workingSessions + pendingSessions
    }

    /// History sessions (History tab): completed, idle, dead
    var historySessions: [SessionState] {
        sessions.filter { [.completed, .idle, .dead].contains($0.status) }
    }

    var activeCount: Int { workingSessions.count + pendingSessions.count }
    var historyCount: Int { historySessions.count }
    var totalCount: Int { sessions.count }

    var latestWorkingSession: SessionState? {
        workingSessions.first
    }

    // MARK: - Private

    private func ensureDirectory() {
        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    private func setupDirectoryMonitor() {
        let fd = Darwin.open(directoryURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        directoryFD = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            self?.scheduleReload()
        }

        // No cancel handler — fd is closed explicitly in restartMonitoring/stopWatching.
        // A cancel handler here would race: it runs asynchronously after cancel(),
        // so if restartMonitoring() closes the fd and opens a new one before the
        // handler fires, the OS may reuse the same fd number, and the handler would
        // close the NEW fd — silently killing the file monitor.

        source.resume()
        dispatchSource = source
    }

    private func startPollTimer() {
        // Poll every 10s — DispatchSource handles most changes instantly
        let t = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.reload()
            }
        }
        // DispatchSource is the fast path; this poll is a safety net, so let
        // macOS coalesce it with other system timers (up to 2s off).
        t.tolerance = 2.0
        pollTimer = t
    }

    private func observeWakeSleep() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.restartMonitoring()
            }
        }
    }

    /// Trigger a lightweight republish to refresh time labels in UI
    func refreshTimestamps() {
        objectWillChange.send()
    }
}

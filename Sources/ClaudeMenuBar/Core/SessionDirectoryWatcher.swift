import Foundation
import Combine

@MainActor
final class SessionDirectoryWatcher: ObservableObject {
    @Published private(set) var sessions: [SessionState] = []

    private let directoryURL: URL
    private let staleThreshold: TimeInterval
    private var directoryFD: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var pollTimer: Timer?
    private let decoder: JSONDecoder

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
        reload()
    }

    func stopWatching() {
        dispatchSource?.cancel()
        dispatchSource = nil
        if directoryFD >= 0 {
            close(directoryFD)
            directoryFD = -1
        }
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func reload() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            sessions = []
            return
        }

        let now = Date()
        var loaded: [SessionState] = []

        for fileURL in files where fileURL.pathExtension == "json" {
            guard let data = try? Data(contentsOf: fileURL),
                  let state = try? decoder.decode(SessionState.self, from: data),
                  state.schemaVersion == 1 else {
                continue
            }

            // Skip stale sessions
            if now.timeIntervalSince(state.lastUpdatedAt) > staleThreshold {
                continue
            }

            loaded.append(state)
        }

        // Sort: working first (newest), then completed, then idle, then dead
        loaded.sort { a, b in
            let orderA = statusOrder(a.status)
            let orderB = statusOrder(b.status)
            if orderA != orderB { return orderA < orderB }
            return a.lastUpdatedAt > b.lastUpdatedAt
        }

        sessions = loaded
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

    var workingSessions: [SessionState] {
        sessions.filter { $0.status == .working }
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

    var activeCount: Int { workingSessions.count }
    var totalCount: Int { sessions.count }

    var latestWorkingSession: SessionState? {
        workingSessions.first
    }

    // MARK: - Private

    private func statusOrder(_ status: SessionStatus) -> Int {
        switch status {
        case .working: return 0
        case .completed: return 1
        case .idle: return 2
        case .dead: return 3
        }
    }

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
            self?.reload()
        }

        source.setCancelHandler { [fd] in
            Darwin.close(fd)
        }

        source.resume()
        dispatchSource = source
    }

    private func startPollTimer() {
        // Safety-net poll every 30s (DispatchSource handles normal case)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.reload()
            }
        }
    }

    /// Trigger a lightweight republish to refresh time labels in UI
    func refreshTimestamps() {
        objectWillChange.send()
    }
}

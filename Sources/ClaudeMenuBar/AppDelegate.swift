import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var iconManager: MenuBarIconManager!

    private var watcher: SessionDirectoryWatcher!
    private let settings = SettingsStore()
    private var healthCheck: HealthCheckService!

    private var cancellables = Set<AnyCancellable>()
    private var previousCompletedIds = Set<String>()
    private var acknowledgedPendingIds = Set<String>()
    private var timestampRefreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let myBundleId = Bundle.main.bundleIdentifier ?? "com.claudecode.menubar"
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: myBundleId)
        if running.count > 1 {
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)

        watcher = SessionDirectoryWatcher()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        iconManager = MenuBarIconManager(statusItem: statusItem)

        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
            button.setAccessibilityLabel("Claude Code Sessions")
        }

        // Popover anchored to status item button
        popover = NSPopover()
        popover.contentSize = NSSize(width: 370, height: 500)
        popover.behavior = .transient
        popover.animates = true

        healthCheck = HealthCheckService(watcher: watcher, settings: settings)

        let contentView = PopoverContentView(
            watcher: watcher,
            settings: settings,
            healthCheck: healthCheck,
            onReschedule: { [weak self] in
                self?.healthCheck.reschedule()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            },
            onFocusSession: { [weak self] session in
                self?.focusTerminalSession(session)
            }
        )
        popover.contentViewController = NSHostingController(rootView: contentView)

        watcher.startWatching()
        healthCheck.start()

        timestampRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.watcher.refreshTimestamps()
            }
        }

        // Snapshot current completed sessions to avoid false triggers on startup
        previousCompletedIds = Set(
            watcher.sessions.filter { $0.status == .completed }.map(\.sessionId)
        )

        watcher.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.updateIcon(sessions: sessions)
            }
            .store(in: &cancellables)
    }

    func applicationWillTerminate(_ notification: Notification) {
        watcher.stopWatching()
        healthCheck.stop()
        timestampRefreshTimer?.invalidate()
    }

    // MARK: - Popover (anchored to icon)

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            // One click = acknowledge ALL pending events
            acknowledgeAllEvents()
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Terminal Focus

    private func focusTerminalSession(_ session: SessionState) {
        popover.performClose(nil)
        let sessionCopy = session
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
            TerminalController.focusSession(sessionCopy)
        }
    }

    // MARK: - Event Acknowledgment

    /// One click = acknowledge everything: dismiss rainbow + mark all pending/completed as seen
    private func acknowledgeAllEvents() {
        // Dismiss rainbow if active
        if iconManager.isShowingRainbow {
            iconManager.dismissRainbow()
            RainbowOverlayManager.shared.hideRainbow()
        }

        // Mark all completed as acknowledged
        let allCompleted = watcher.sessions.filter { $0.status == .completed }
        previousCompletedIds = Set(allCompleted.map(\.sessionId))

        // Mark all pending as acknowledged (won't show pending icon until new pending arrives)
        let allPending = watcher.pendingSessions
        acknowledgedPendingIds = Set(allPending.map(\.sessionId))

        // Revert icon to idle
        iconManager.update(state: .idle)
    }

    // MARK: - Icon Updates

    private func updateIcon(sessions: [SessionState]) {
        let completed = sessions.filter { $0.status == .completed }
        let completedIds = Set(completed.map(\.sessionId))
        let newlyCompleted = completedIds.subtracting(previousCompletedIds)

        // Always keep tracking set in sync
        previousCompletedIds = completedIds
        let allCurrentIds = Set(sessions.map(\.sessionId))
        previousCompletedIds = previousCompletedIds.intersection(allCurrentIds)

        // Clear acknowledged pending for sessions that returned to working
        let workingIds = Set(sessions.filter { $0.status == .working }.map(\.sessionId))
        acknowledgedPendingIds.subtract(workingIds)
        acknowledgedPendingIds = acknowledgedPendingIds.intersection(allCurrentIds)

        // Don't interrupt an active rainbow
        if iconManager.isShowingRainbow { return }

        if !newlyCompleted.isEmpty {
            iconManager.update(state: .completed)
            RainbowOverlayManager.shared.showRainbow()
            return
        }

        updateIconWithoutRainbow()
    }

    private func updateIconWithoutRainbow() {
        // Priority: working > unacknowledged pending > idle
        if let latest = watcher.workingSessions.first {
            // New working session clears acknowledged state
            acknowledgedPendingIds.remove(latest.sessionId)
            iconManager.update(state: .working(projectName: latest.displayProjectName))
        } else if let pending = watcher.pendingSessions.first(where: { !acknowledgedPendingIds.contains($0.sessionId) }) {
            iconManager.update(state: .pending(projectName: pending.displayProjectName))
        } else {
            iconManager.update(state: .idle)
        }
    }
}

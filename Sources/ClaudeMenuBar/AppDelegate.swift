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
    private var sleepObserver: Any?
    private var wakeObserver: Any?

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
        iconManager = MenuBarIconManager(statusItem: statusItem, settings: settings)

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
        healthCheck.onHealthCheckDone = { [weak self] in
            guard let self, !self.iconManager.isShowingRainbow else { return }
            self.iconManager.update(state: .healthCheckDone)
        }
        healthCheck.start()
        observeWakeSleep()

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
        let center = NSWorkspace.shared.notificationCenter
        if let obs = sleepObserver { center.removeObserver(obs) }
        if let obs = wakeObserver { center.removeObserver(obs) }
    }

    // MARK: - Sleep / Wake Recovery

    /// Delay before restarting timers after wake.
    /// WindowServer and NSStatusItem may not be fully ready immediately after wake.
    nonisolated private static let wakeStabilizationDelay: TimeInterval = 1.5

    private func observeWakeSleep() {
        let center = NSWorkspace.shared.notificationCenter

        sleepObserver = center.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSleep()
            }
        }

        wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Immediately fix phantom popover and button (no delay)
            Task { @MainActor in
                self?.handleWakeImmediate()
            }
            // Delayed: restart timers and refresh state after system stabilizes
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.wakeStabilizationDelay) {
                Task { @MainActor in
                    self?.handleWakeDeferred()
                }
            }
        }
    }

    private func handleSleep() {
        // Close popover to prevent phantom isShown state on wake
        if popover.isShown {
            popover.performClose(nil)
        }
        // Dismiss rainbow overlay
        if iconManager.isShowingRainbow {
            iconManager.dismissRainbow()
            RainbowOverlayManager.shared.hideRainbow()
        }
        // Acknowledge completed sessions to prevent false rainbow trigger on wake
        let allCompleted = watcher.sessions.filter { $0.status == .completed }
        previousCompletedIds = Set(allCompleted.map(\.sessionId))
        // Stop timers (restarted on wake)
        timestampRefreshTimer?.invalidate()
        timestampRefreshTimer = nil
    }

    /// Called immediately on wake — fixes button responsiveness without delay.
    private func handleWakeImmediate() {
        // Force-close phantom popover (in case willSleep didn't fire or was too late)
        if popover.isShown {
            popover.performClose(nil)
        }
        // Re-validate status item button action/target
        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    /// Called after stabilization delay — restarts timers and refreshes state.
    private func handleWakeDeferred() {
        // Restart timestamp refresh timer
        timestampRefreshTimer?.invalidate()
        timestampRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.watcher.refreshTimestamps()
            }
        }
        // Restart health check timers
        healthCheck.rescheduleAfterWake()
        // Refresh icon state based on current sessions
        updateIconWithoutRainbow()
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
        settings.applyAppearance() // Ensure popover uses correct appearance
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Terminal Focus

    private func focusTerminalSession(_ session: SessionState) {
        // Focus terminal first, then close popover
        let sessionCopy = session
        DispatchQueue.global(qos: .userInitiated).async {
            TerminalController.focusSession(sessionCopy)
        }
        // Close popover after a short delay so focus command gets dispatched
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.popover.performClose(nil)
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
        // Don't interrupt health check flash or rainbow
        if iconManager.currentState == .healthCheckDone { return }

        let completed = sessions.filter { $0.status == .completed }
        let completedIds = Set(completed.map(\.sessionId))

        // Detect newly completed: either new ID or recently completed (within 10s)
        let recentlyCompleted = completed.filter {
            guard let completedAt = $0.completedAt else { return false }
            return Date().timeIntervalSince(completedAt) < 10
        }
        let newById = completedIds.subtracting(previousCompletedIds)
        let newByTime = Set(recentlyCompleted.map(\.sessionId)).subtracting(previousCompletedIds)
        let newlyCompleted = newById.union(newByTime)

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

        if !newlyCompleted.isEmpty && !settings.sleepMode {
            iconManager.update(state: .completed)
            RainbowOverlayManager.shared.showRainbow()
            if settings.soundEnabled {
                SoundPlayer.playMeow()
            }
            return
        }

        updateIconWithoutRainbow()
    }

    private func updateIconWithoutRainbow() {
        // Priority: working > unacknowledged pending > idle
        if settings.sleepMode {
            iconManager.update(state: .idle)
            return
        }

        if let latest = watcher.workingSessions.first {
            acknowledgedPendingIds.remove(latest.sessionId)
            iconManager.update(state: .working(projectName: latest.displayProjectName))
        } else if let pending = watcher.pendingSessions.first(where: { !acknowledgedPendingIds.contains($0.sessionId) }) {
            iconManager.update(state: .pending(projectName: pending.displayProjectName))
        } else {
            iconManager.update(state: .idle)
        }
    }
}

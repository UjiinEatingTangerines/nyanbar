import SwiftUI

enum PopoverTab: CaseIterable {
    case sessions
    case history
    case settings

    var icon: String {
        switch self {
        case .sessions: "tray.2"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }

    func title(_ lang: AppLanguage) -> String {
        switch self {
        case .sessions: lang.sessionsTab
        case .history: lang.historyTab
        case .settings: lang.settingsTab
        }
    }
}

struct PopoverContentView: View {
    @ObservedObject var watcher: SessionDirectoryWatcher
    @ObservedObject var settings: SettingsStore
    @ObservedObject var healthCheck: HealthCheckService
    var onReschedule: () -> Void
    var onQuit: () -> Void
    var onFocusSession: ((SessionState) -> Void)?

    @State private var selectedTab: PopoverTab = .sessions

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()

            Group {
                switch selectedTab {
                case .sessions:
                    SessionDashboardView(watcher: watcher, settings: settings, onFocusSession: onFocusSession)
                case .history:
                    HistoryView(watcher: watcher, settings: settings, onFocusSession: onFocusSession)
                case .settings:
                    SettingsView(settings: settings, onReschedule: onReschedule)
                }
            }
            .frame(maxHeight: .infinity)

            Divider()
            footerBar
        }
        .frame(width: 380, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                ForEach(PopoverTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 9, weight: .medium))
                            Text(tab.title(settings.selectedLanguage))
                                .font(.system(size: 11, weight: .medium))
                            // Badge for counts
                            if tab == .sessions && watcher.activeCount > 0 {
                                Text("\(watcher.activeCount)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Color.green))
                            }
                            if tab == .history && watcher.historyCount > 0 {
                                Text("\(watcher.historyCount)")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Color.secondary))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedTab == tab
                                      ? Color.accentColor.opacity(0.15)
                                      : Color.clear)
                        )
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack(spacing: 0) {
            Button(action: onQuit) {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 10))
                    Text("Quit")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            // Health check countdown
            if healthCheck.isRunning {
                HStack(spacing: 4) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 9))
                        .foregroundStyle(.pink.opacity(0.5))
                    Text(healthCheck.countdownString)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.quaternary)
                        .monospacedDigit()
                }
                .help("Next health check in \(healthCheck.countdownString)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

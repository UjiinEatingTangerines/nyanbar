import SwiftUI

enum PopoverTab: String, CaseIterable {
    case sessions = "Sessions"
    case settings = "Settings"

    var icon: String {
        switch self {
        case .sessions: "tray.2"
        case .settings: "gearshape"
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
                    SessionDashboardView(watcher: watcher, onFocusSession: onFocusSession)
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
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(PopoverTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 10, weight: .medium))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
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

            if watcher.totalCount > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(watcher.activeCount > 0 ? Color.green : Color.secondary)
                        .frame(width: 6, height: 6)
                    Text("\(watcher.activeCount)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                    Text("/ \(watcher.totalCount)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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

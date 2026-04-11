import SwiftUI

struct SessionDashboardView: View {
    @ObservedObject var watcher: SessionDirectoryWatcher
    @ObservedObject var settings: SettingsStore
    var onFocusSession: ((SessionState) -> Void)?

    private var lang: AppLanguage { settings.selectedLanguage }

    var body: some View {
        if watcher.activeSessions.isEmpty {
            emptyState
        } else {
            sessionList
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.06))
                    .frame(width: 72, height: 72)
                Image(systemName: "cat.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.quaternary)
            }
            VStack(spacing: 4) {
                Text(lang.noActiveSessions)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(lang.startSessionHint)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    @ViewBuilder
    private var sessionList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SessionGroupView(
                    title: lang.workingGroup,
                    icon: "circle.fill",
                    color: .green,
                    sessions: watcher.workingSessions,
                    onFocus: { onFocusSession?($0) }
                )
                SessionGroupView(
                    title: lang.waitingGroup,
                    icon: "hand.raised.fill",
                    color: .orange,
                    sessions: watcher.pendingSessions,
                    onFocus: { onFocusSession?($0) }
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

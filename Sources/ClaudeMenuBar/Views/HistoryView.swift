import SwiftUI

struct HistoryView: View {
    @ObservedObject var watcher: SessionDirectoryWatcher
    @ObservedObject var settings: SettingsStore
    var onFocusSession: ((SessionState) -> Void)?

    private var lang: AppLanguage { settings.selectedLanguage }

    var body: some View {
        if watcher.historySessions.isEmpty {
            emptyState
        } else {
            historyList
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
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 28))
                    .foregroundStyle(.quaternary)
            }
            VStack(spacing: 4) {
                Text(lang.noHistory)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(lang.historyHint)
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
    private var historyList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SessionGroupView(
                    title: lang.completedGroup,
                    icon: "checkmark.circle.fill",
                    color: .blue,
                    sessions: watcher.completedSessions,
                    onFocus: { onFocusSession?($0) }
                )
                SessionGroupView(
                    title: lang.idleGroup,
                    icon: "circle",
                    color: .secondary,
                    sessions: watcher.idleSessions,
                    onFocus: { onFocusSession?($0) }
                )
                SessionGroupView(
                    title: lang.crashedGroup,
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    sessions: watcher.deadSessions,
                    onDismiss: { watcher.deleteSessionFile(sessionId: $0.sessionId) },
                    onFocus: { onFocusSession?($0) }
                )

                HStack {
                    Image(systemName: "trash.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                    Text(lang.autoDeleteNote)
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                    Spacer()
                    Button(lang.clearAll) { clearHistory() }
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    private func clearHistory() {
        for session in watcher.historySessions {
            watcher.deleteSessionFile(sessionId: session.sessionId)
        }
    }
}

import SwiftUI

struct SessionDashboardView: View {
    @ObservedObject var watcher: SessionDirectoryWatcher
    var onFocusSession: ((SessionState) -> Void)?

    var body: some View {
        if watcher.sessions.isEmpty {
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
                Text("No active sessions")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Start a Claude Code session\nto see it here")
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
                    title: "Working",
                    icon: "circle.fill",
                    color: .green,
                    sessions: watcher.workingSessions,
                    onFocus: { onFocusSession?($0) }
                )

                SessionGroupView(
                    title: "Completed",
                    icon: "checkmark.circle.fill",
                    color: .blue,
                    sessions: watcher.completedSessions,
                    onFocus: { onFocusSession?($0) }
                )

                SessionGroupView(
                    title: "Crashed",
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    sessions: watcher.deadSessions,
                    onDismiss: { session in
                        watcher.deleteSessionFile(sessionId: session.sessionId)
                    },
                    onFocus: { onFocusSession?($0) }
                )

                SessionGroupView(
                    title: "Idle",
                    icon: "circle",
                    color: .secondary,
                    sessions: watcher.idleSessions,
                    onFocus: { onFocusSession?($0) }
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

import SwiftUI

struct SessionCardView: View {
    let session: SessionState
    var onDismiss: (() -> Void)?
    var onFocus: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        Button {
            onFocus?()
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var cardContent: some View {
        HStack(alignment: .center, spacing: 10) {
            // Status indicator
            statusIndicator

            // Content
            VStack(alignment: .leading, spacing: 3) {
                // Project name + terminal app badge
                HStack(spacing: 6) {
                    Text(session.displayProjectName)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let terminal = session.terminalDisplayName {
                        Text(terminal)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.secondary.opacity(0.1))
                            )
                    }
                }

                // Path
                Text(shortenedPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                // Time + last tool
                HStack(spacing: 5) {
                    timeLabel
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)

                    if let tool = session.lastToolName {
                        Text("·")
                            .foregroundStyle(.quaternary)
                        Text(tool)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.quaternary)
                    }
                }

                // Last message
                if let message = session.lastMessage {
                    Text(message)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 4)

            // Right side
            if session.status == .dead, let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Dismiss")
            } else if session.canFocusTerminal {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 11))
                    .foregroundStyle(isHovering ? .primary : .quaternary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovering ? hoverBackground : cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(borderColor, lineWidth: session.status == .dead ? 1 : 0)
        )
    }

    // MARK: - Computed

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "ko") ?? .korean
    }

    private var shortenedPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let dir = session.workingDirectory
        if dir.hasPrefix(home) {
            return "~" + dir.dropFirst(home.count)
        }
        return dir
    }

    // MARK: - Subviews

    @ViewBuilder
    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(dotColor.opacity(0.15))
                .frame(width: 20, height: 20)
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
        }
    }

    @ViewBuilder
    private var timeLabel: some View {
        switch session.status {
        case .working:
            Text(RelativeTimeFormatter.durationString(from: session.startedAt))
        case .pending:
            Text(currentLanguage.waitingForInput)
        case .completed:
            if let completedAt = session.completedAt {
                Text("done \(RelativeTimeFormatter.string(from: completedAt))")
            } else {
                Text("completed")
            }
        case .idle:
            Text("idle \(RelativeTimeFormatter.string(from: session.lastUpdatedAt))")
        case .dead:
            if let diedAt = session.diedAt {
                Text("crashed \(RelativeTimeFormatter.string(from: diedAt))")
            } else {
                Text("crashed")
            }
        }
    }

    // MARK: - Styling

    private var dotColor: Color {
        switch session.status {
        case .working: .green
        case .pending: .orange
        case .completed: .blue
        case .idle: .gray
        case .dead: .red
        }
    }

    private var cardBackground: Color {
        switch session.status {
        case .pending: Color.orange.opacity(0.05)
        case .dead: Color.red.opacity(0.04)
        default: Color(nsColor: .controlBackgroundColor).opacity(0.4)
        }
    }

    private var hoverBackground: Color {
        switch session.status {
        case .pending: Color.orange.opacity(0.1)
        case .dead: Color.red.opacity(0.08)
        default: Color.accentColor.opacity(0.08)
        }
    }

    private var borderColor: Color {
        session.status == .dead ? .red.opacity(0.2) : .clear
    }
}

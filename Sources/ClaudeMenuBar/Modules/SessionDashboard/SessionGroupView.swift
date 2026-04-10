import SwiftUI

struct SessionGroupView: View {
    let title: String
    let icon: String
    let color: Color
    let sessions: [SessionState]
    var onDismiss: ((SessionState) -> Void)?
    var onFocus: ((SessionState) -> Void)?

    var body: some View {
        if !sessions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // Section header
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 8))
                        .foregroundStyle(color)
                    Text(title.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(color.opacity(0.8))
                        .tracking(0.5)
                    Text("\(sessions.count)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(color.opacity(0.5))
                }
                .padding(.leading, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(title) \(sessions.count) sessions")

                ForEach(sessions) { session in
                    SessionCardView(
                        session: session,
                        onDismiss: { onDismiss?(session) },
                        onFocus: { onFocus?(session) }
                    )
                    .accessibilityLabel("\(session.displayProjectName), \(session.status.rawValue)")
                    .accessibilityHint(session.canFocusTerminal ? "Double tap to focus terminal" : "")
                }
            }
        }
    }
}

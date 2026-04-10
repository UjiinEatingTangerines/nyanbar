import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    var onReschedule: () -> Void

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Health Check
                settingsCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.text.square")
                                .font(.system(size: 14))
                                .foregroundStyle(.pink)
                            Text("Health Check")
                                .font(.system(size: 13, weight: .semibold))
                        }

                        Text("How often to check if sessions are still alive")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 6) {
                            // Row 1: seconds
                            HStack(spacing: 4) {
                                ForEach([HealthCheckInterval.tenSeconds, .twentySeconds, .thirtySeconds], id: \.id) { interval in
                                    intervalButton(interval)
                                }
                            }
                            // Row 2: minutes/hours
                            HStack(spacing: 4) {
                                ForEach([HealthCheckInterval.fiveMinutes, .thirtyMinutes, .oneHour], id: \.id) { interval in
                                    intervalButton(interval)
                                }
                            }
                        }
                        .onChange(of: settings.selectedInterval) { _, _ in
                            onReschedule()
                        }
                    }
                }

                // About
                settingsCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(.blue)
                            Text("About")
                                .font(.system(size: 13, weight: .semibold))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Text("Claude Code Menu Bar")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Text("v\(appVersion)")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.quaternary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.secondary.opacity(0.1))
                                    )
                            }

                            Label {
                                Text("~/.claude/menubar-sessions/")
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .textSelection(.enabled)
                            } icon: {
                                Image(systemName: "folder")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private func intervalButton(_ interval: HealthCheckInterval) -> some View {
        let isSelected = settings.selectedInterval == interval
        Button {
            settings.selectedInterval = interval
        } label: {
            Text(interval.displayName)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular, design: .monospaced))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
            )
    }
}

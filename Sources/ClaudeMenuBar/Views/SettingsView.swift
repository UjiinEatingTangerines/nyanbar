import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @StateObject private var updateChecker = UpdateChecker()
    var onReschedule: () -> Void

    private var appVersion: String { UpdateChecker.currentVersion }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // About + Update (맨 위 — 바로 보이게)
                settingsCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundStyle(.blue)
                            Text(settings.selectedLanguage.aboutTitle)
                                .font(.system(size: 13, weight: .semibold))
                        }

                        // Version + check button
                        HStack(spacing: 8) {
                            Text("NyanBar")
                                .font(.system(size: 12, weight: .medium))
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

                            Spacer()

                            updateButton
                        }

                        updateStatusView
                    }
                }

                // Language
                settingsCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .font(.system(size: 14))
                                .foregroundStyle(.cyan)
                            Text("Language")
                                .font(.system(size: 13, weight: .semibold))
                        }

                        HStack(spacing: 4) {
                            ForEach(AppLanguage.allCases) { lang in
                                languageButton(lang)
                            }
                        }
                    }
                }

                // Health Check
                settingsCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.text.square")
                                .font(.system(size: 14))
                                .foregroundStyle(.pink)
                            Text("Health Check")
                                .font(.system(size: 13, weight: .semibold))
                        }

                        Text(settings.selectedLanguage.healthCheckDesc)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 5) {
                            Text("Seconds")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 4) {
                                intervalButton(.tenSeconds)
                                intervalButton(.twentySeconds)
                                intervalButton(.thirtySeconds)
                            }
                        }
                        VStack(spacing: 5) {
                            Text("Minutes / Hours")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            HStack(spacing: 4) {
                                intervalButton(.fiveMinutes)
                                intervalButton(.thirtyMinutes)
                                intervalButton(.oneHour)
                            }
                        }
                    }
                    .onChange(of: settings.selectedInterval) { _, _ in
                        onReschedule()
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Update UI

    @ViewBuilder
    private var updateButton: some View {
        switch updateChecker.state {
        case .idle, .error:
            Button { updateChecker.checkForUpdate() } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 9))
                    Text("Check")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.1)))
            }
            .buttonStyle(.plain)

        case .checking:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("Checking...")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

        case .upToDate:
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
                Text("Latest")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
            }

        case .updateAvailable(let version):
            Button { updateChecker.performUpdate() } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 10))
                    Text("v\(version)")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.orange))
            }
            .buttonStyle(.plain)

        case .updating:
            HStack(spacing: 4) {
                ProgressView().controlSize(.mini)
                Text("Updating...")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }

        case .updateDone:
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
                Text("Restart app")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.green)
            }
        }
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch updateChecker.state {
        case .updateAvailable(let version):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle").font(.system(size: 9)).foregroundStyle(.orange)
                Text("v\(version) available").font(.system(size: 10)).foregroundStyle(.orange)
            }
        case .error(let msg):
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle").font(.system(size: 9)).foregroundStyle(.red)
                Text(msg).font(.system(size: 10)).foregroundStyle(.red).lineLimit(1)
            }
        case .updateDone:
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise").font(.system(size: 9)).foregroundStyle(.green)
                Text("Update installed — restart to apply").font(.system(size: 10)).foregroundStyle(.green)
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Buttons

    @ViewBuilder
    private func languageButton(_ lang: AppLanguage) -> some View {
        let isSelected = settings.selectedLanguage == lang
        Button { settings.selectedLanguage = lang } label: {
            HStack(spacing: 4) {
                Text(lang.flag).font(.system(size: 13))
                Text(lang.displayName).font(.system(size: 11, weight: isSelected ? .bold : .medium))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSelected ? Color.clear : Color.secondary.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func intervalButton(_ interval: HealthCheckInterval) -> some View {
        let isSelected = settings.selectedInterval == interval
        Button { settings.selectedInterval = interval } label: {
            Text(interval.displayName)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .monospaced))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSelected ? Color.clear : Color.secondary.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor).opacity(0.4)))
    }
}

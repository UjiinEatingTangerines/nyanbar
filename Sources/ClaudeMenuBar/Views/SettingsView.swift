import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @StateObject private var updateChecker = UpdateChecker()
    var onReschedule: () -> Void

    @State private var newSpinnerText = ""

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

                // Appearance
                settingsCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: settings.appearance == "dark" ? "moon.stars.fill" : settings.appearance == "light" ? "sun.max.fill" : "circle.lefthalf.filled")
                                .font(.system(size: 14))
                                .foregroundStyle(.purple)
                            Text(settings.selectedLanguage.appearanceTitle)
                                .font(.system(size: 13, weight: .semibold))
                        }

                        HStack(spacing: 4) {
                            appearanceButton("system", icon: "circle.lefthalf.filled", label: "System")
                            appearanceButton("light", icon: "sun.max.fill", label: "Light")
                            appearanceButton("dark", icon: "moon.fill", label: "Dark")
                        }
                    }
                }

                // Cat Color
                settingsCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "paintpalette.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.pink)
                            Text(settings.selectedLanguage.catColorTitle)
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            if settings.catColorHex != nil {
                                Button(settings.selectedLanguage.catColorReset) {
                                    settings.catColorHex = nil
                                }
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                                .buttonStyle(.plain)
                            } else {
                                Text(settings.selectedLanguage.catColorSystemDesc)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        // Color palette grid
                        let palette: [(String, String)] = [
                            ("#000000", "⬛"), ("#FFFFFF", "⬜"), ("#FF6B6B", "🔴"), ("#FF922B", "🟠"),
                            ("#FFD43B", "🟡"), ("#51CF66", "🟢"), ("#339AF0", "🔵"), ("#845EF7", "🟣"),
                            ("#F06595", "💗"), ("#20C997", "🩵"), ("#868E96", "🩶"), ("#C2255C", "🌹"),
                        ]
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 4) {
                            ForEach(palette, id: \.0) { hex, _ in
                                let isSelected = settings.catColorHex == hex
                                Button {
                                    settings.catColorHex = hex
                                } label: {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(nsColor: NSColor(hex: hex) ?? .black))
                                        .frame(height: 24)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                                        )
                                        .overlay(
                                            isSelected ? Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(.white.opacity(0.9)) : nil
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Sleep Mode + Sound
                settingsCard {
                    VStack(alignment: .leading, spacing: 10) {
                        // Sleep mode toggle
                        Toggle(isOn: $settings.sleepMode) {
                            HStack(spacing: 6) {
                                Image(systemName: settings.sleepMode ? "moon.fill" : "moon")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.indigo)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(settings.selectedLanguage.sleepModeTitle)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(settings.selectedLanguage.sleepModeDesc)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)

                        Divider()

                        // Sound toggle
                        Toggle(isOn: $settings.soundEnabled) {
                            HStack(spacing: 6) {
                                Image(systemName: settings.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(settings.selectedLanguage.soundTitle)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(settings.selectedLanguage.soundDesc)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                }

                // Custom Spinner Messages
                settingsCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 14))
                                .foregroundStyle(.green)
                            Text(settings.selectedLanguage.customSpinnerTitle)
                                .font(.system(size: 13, weight: .semibold))
                        }

                        Text(settings.selectedLanguage.customSpinnerDesc)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)

                        // Input field
                        HStack(spacing: 6) {
                            TextField("🐱 새 문구...", text: $newSpinnerText)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11))

                            Button(settings.selectedLanguage.addMessage) {
                                addCustomMessage()
                            }
                            .font(.system(size: 11, weight: .medium))
                            .disabled(newSpinnerText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }

                        // List of custom messages
                        if !settings.customSpinnerMessages.isEmpty {
                            VStack(spacing: 4) {
                                ForEach(settings.customSpinnerMessages, id: \.self) { msg in
                                    HStack {
                                        Text(msg)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                        Spacer()
                                        Button {
                                            removeCustomMessage(msg)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 10))
                                                .foregroundStyle(.tertiary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.06)))
                                }
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
    private func appearanceButton(_ value: String, icon: String, label: String) -> some View {
        let isSelected = settings.appearance == value
        Button { settings.appearance = value } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSelected ? Color.clear : Color.secondary.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func addCustomMessage() {
        let msg = newSpinnerText.trimmingCharacters(in: .whitespaces)
        guard !msg.isEmpty else { return }
        settings.customSpinnerMessages.append(msg)
        newSpinnerText = ""
    }

    private func removeCustomMessage(_ msg: String) {
        settings.customSpinnerMessages.removeAll { $0 == msg }
    }

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor).opacity(0.4)))
    }
}

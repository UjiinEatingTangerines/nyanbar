import SwiftUI

enum HealthCheckInterval: Int, CaseIterable, Identifiable {
    case tenSeconds = 10
    case twentySeconds = 20
    case thirtySeconds = 30
    case fiveMinutes = 300
    case thirtyMinutes = 1800
    case oneHour = 3600

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .tenSeconds: "10s"
        case .twentySeconds: "20s"
        case .thirtySeconds: "30s"
        case .fiveMinutes: "5m"
        case .thirtyMinutes: "30m"
        case .oneHour: "1h"
        }
    }

    var seconds: TimeInterval {
        TimeInterval(rawValue)
    }
}

struct SpinnerMessage: Codable, Identifiable, Equatable {
    var id: String { text }
    let text: String
    var enabled: Bool
}

final class SettingsStore: ObservableObject {
    @Published var selectedInterval: HealthCheckInterval {
        didSet { UserDefaults.standard.set(selectedInterval.rawValue, forKey: "healthCheckIntervalRawValue") }
    }

    @Published var selectedLanguage: AppLanguage {
        didSet { UserDefaults.standard.set(selectedLanguage.rawValue, forKey: "appLanguage") }
    }

    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }

    @Published var sleepMode: Bool {
        didSet { UserDefaults.standard.set(sleepMode, forKey: "sleepMode") }
    }

    @Published var appearance: String {
        didSet {
            UserDefaults.standard.set(appearance, forKey: "appearance")
            applyAppearance()
        }
    }

    @Published var catColorHex: String? {
        didSet { UserDefaults.standard.set(catColorHex, forKey: "catColorHex") }
    }

    @Published var customMessages: [SpinnerMessage] {
        didSet { saveCustomMessages() }
    }

    var healthCheckSeconds: TimeInterval {
        selectedInterval.seconds
    }

    /// Only enabled custom messages for spinner
    var enabledCustomMessages: [String] {
        customMessages.filter(\.enabled).map(\.text)
    }

    init() {
        let intervalRaw = UserDefaults.standard.integer(forKey: "healthCheckIntervalRawValue")
        self.selectedInterval = HealthCheckInterval(rawValue: intervalRaw) ?? .thirtySeconds

        let langRaw = UserDefaults.standard.string(forKey: "appLanguage") ?? "ko"
        self.selectedLanguage = AppLanguage(rawValue: langRaw) ?? .korean

        self.soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        self.sleepMode = UserDefaults.standard.bool(forKey: "sleepMode")
        self.appearance = UserDefaults.standard.string(forKey: "appearance") ?? "system"
        self.catColorHex = UserDefaults.standard.string(forKey: "catColorHex")

        // Load custom messages
        if let data = UserDefaults.standard.data(forKey: "customMessagesV2"),
           let decoded = try? JSONDecoder().decode([SpinnerMessage].self, from: data) {
            self.customMessages = decoded
        } else if let old = UserDefaults.standard.stringArray(forKey: "customSpinnerMessages"), !old.isEmpty {
            // Migrate old format
            self.customMessages = old.map { SpinnerMessage(text: $0, enabled: true) }
            UserDefaults.standard.removeObject(forKey: "customSpinnerMessages")
        } else {
            self.customMessages = []
        }

        applyAppearance()
    }

    func addCustomMessage(_ text: String) {
        customMessages.append(SpinnerMessage(text: text, enabled: true))
    }

    func removeCustomMessage(at index: Int) {
        guard index < customMessages.count else { return }
        customMessages.remove(at: index)
    }

    func toggleCustomMessage(at index: Int) {
        guard index < customMessages.count else { return }
        customMessages[index].enabled.toggle()
    }

    func applyAppearance() {
        let newAppearance: NSAppearance? = switch appearance {
        case "light": NSAppearance(named: .aqua)
        case "dark": NSAppearance(named: .darkAqua)
        default: nil
        }
        NSApp.appearance = newAppearance
        for window in NSApp.windows {
            window.appearance = newAppearance
        }
    }

    private func saveCustomMessages() {
        if let data = try? JSONEncoder().encode(customMessages) {
            UserDefaults.standard.set(data, forKey: "customMessagesV2")
        }
    }
}

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

    @Published var customSpinnerMessages: [String] {
        didSet { UserDefaults.standard.set(customSpinnerMessages, forKey: "customSpinnerMessages") }
    }

    /// Appearance: "system", "light", "dark"
    @Published var appearance: String {
        didSet {
            UserDefaults.standard.set(appearance, forKey: "appearance")
            applyAppearance()
        }
    }

    /// Cat icon color: nil = system template (auto), otherwise fixed hex color
    @Published var catColorHex: String? {
        didSet { UserDefaults.standard.set(catColorHex, forKey: "catColorHex") }
    }

    var healthCheckSeconds: TimeInterval {
        selectedInterval.seconds
    }

    init() {
        let intervalRaw = UserDefaults.standard.integer(forKey: "healthCheckIntervalRawValue")
        self.selectedInterval = HealthCheckInterval(rawValue: intervalRaw) ?? .thirtySeconds

        let langRaw = UserDefaults.standard.string(forKey: "appLanguage") ?? "ko"
        self.selectedLanguage = AppLanguage(rawValue: langRaw) ?? .korean

        self.soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        self.sleepMode = UserDefaults.standard.bool(forKey: "sleepMode")
        self.customSpinnerMessages = UserDefaults.standard.stringArray(forKey: "customSpinnerMessages") ?? []
        self.appearance = UserDefaults.standard.string(forKey: "appearance") ?? "system"
        self.catColorHex = UserDefaults.standard.string(forKey: "catColorHex")

        applyAppearance()
    }

    func applyAppearance() {
        let newAppearance: NSAppearance? = switch appearance {
        case "light": NSAppearance(named: .aqua)
        case "dark": NSAppearance(named: .darkAqua)
        default: nil
        }

        // Apply to app and all windows (including popover)
        NSApp.appearance = newAppearance
        for window in NSApp.windows {
            window.appearance = newAppearance
        }
    }
}

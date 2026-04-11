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

    var healthCheckSeconds: TimeInterval {
        selectedInterval.seconds
    }

    init() {
        let intervalRaw = UserDefaults.standard.integer(forKey: "healthCheckIntervalRawValue")
        self.selectedInterval = HealthCheckInterval(rawValue: intervalRaw) ?? .thirtySeconds

        let langRaw = UserDefaults.standard.string(forKey: "appLanguage") ?? "ko"
        self.selectedLanguage = AppLanguage(rawValue: langRaw) ?? .korean
    }
}

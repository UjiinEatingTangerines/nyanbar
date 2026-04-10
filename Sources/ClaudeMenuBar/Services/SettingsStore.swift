import SwiftUI

enum HealthCheckInterval: Int, CaseIterable, Identifiable {
    case fiveMinutes = 300
    case thirtyMinutes = 1800
    case oneHour = 3600

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .fiveMinutes: "5 min"
        case .thirtyMinutes: "30 min"
        case .oneHour: "1 hour"
        }
    }

    var seconds: TimeInterval {
        TimeInterval(rawValue)
    }
}

final class SettingsStore: ObservableObject {
    @AppStorage("healthCheckIntervalRawValue")
    var healthCheckIntervalRawValue: Int = HealthCheckInterval.thirtyMinutes.rawValue

    var selectedInterval: HealthCheckInterval {
        get {
            HealthCheckInterval(rawValue: healthCheckIntervalRawValue) ?? .thirtyMinutes
        }
        set {
            healthCheckIntervalRawValue = newValue.rawValue
            objectWillChange.send()
        }
    }

    var healthCheckSeconds: TimeInterval {
        selectedInterval.seconds
    }
}

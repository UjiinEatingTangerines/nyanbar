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
    @AppStorage("healthCheckIntervalRawValue")
    var healthCheckIntervalRawValue: Int = HealthCheckInterval.thirtySeconds.rawValue

    var selectedInterval: HealthCheckInterval {
        get {
            HealthCheckInterval(rawValue: healthCheckIntervalRawValue) ?? .thirtySeconds
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

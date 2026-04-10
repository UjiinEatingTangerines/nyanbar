import Foundation

struct RelativeTimeFormatter {
    static func string(from date: Date, relativeTo now: Date = Date()) -> String {
        let elapsed = now.timeIntervalSince(date)

        if elapsed < 0 { return "just now" }
        if elapsed < 60 { return "just now" }

        let minutes = Int(elapsed / 60)
        if minutes < 60 { return "\(minutes)m ago" }

        let hours = Int(elapsed / 3600)
        if hours < 24 { return "\(hours)h ago" }

        let days = Int(elapsed / 86400)
        return "\(days)d ago"
    }

    static func durationString(from start: Date, to end: Date = Date()) -> String {
        let elapsed = end.timeIntervalSince(start)
        if elapsed < 60 { return "< 1m" }

        let minutes = Int(elapsed / 60)
        if minutes < 60 { return "\(minutes)m" }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 { return "\(hours)h" }
        return "\(hours)h \(remainingMinutes)m"
    }
}

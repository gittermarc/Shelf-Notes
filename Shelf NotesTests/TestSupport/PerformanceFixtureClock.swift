import Foundation

enum PerformanceFixtureClock {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()

    static let now = date(2026, 6, 18, hour: 12)

    static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 12,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute,
                second: second
            )
        ) ?? Date(timeIntervalSince1970: 0)
    }

    static func adding(
        _ component: Calendar.Component,
        value: Int,
        to date: Date
    ) -> Date {
        calendar.date(byAdding: component, value: value, to: date) ?? date
    }

    static func stableUUID(category: Int, index: Int) -> UUID {
        let value = max(0, category) * 100_000_000 + max(0, index)
        let suffix = String(format: "%012d", value)
        return UUID(uuidString: "00000000-0000-0000-0000-\(suffix)") ?? UUID()
    }
}
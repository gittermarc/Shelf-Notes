import Foundation

nonisolated struct StatisticsMonthKey: Hashable, Identifiable, Sendable {
    let year: Int
    let month: Int

    var id: String { "\(year)-\(month)" }
}

nonisolated enum StatisticsMonthAxisBuilder {
    static func months(
        for year: Int,
        now: Date,
        calendar: Calendar
    ) -> [StatisticsMonthKey] {
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        let maxMonth: Int
        if year == currentYear {
            maxMonth = max(1, currentMonth)
        } else {
            maxMonth = 12
        }

        return (1...maxMonth).map { StatisticsMonthKey(year: year, month: $0) }
    }

    static func monthLabel(
        for month: StatisticsMonthKey,
        calendar: Calendar,
        fallbackDate: Date
    ) -> String {
        let date = calendar.date(from: DateComponents(year: month.year, month: month.month, day: 1)) ?? fallbackDate
        return date.formatted(.dateTime.month(.abbreviated))
    }
}

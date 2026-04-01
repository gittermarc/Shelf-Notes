import Foundation
import Testing
@testable import Shelf_Notes

struct StatisticsMonthAxisBuilderTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    @Test func usesElapsedMonthsForCurrentYear() {
        let months = StatisticsMonthAxisBuilder.months(
            for: 2026,
            now: date(2026, 4, 15),
            calendar: calendar
        )

        #expect(months.count == 4)
        #expect(months.map(\.month) == [1, 2, 3, 4])
    }

    @Test func usesFullYearForPastAndFutureYears() {
        let now = date(2026, 4, 15)

        let pastMonths = StatisticsMonthAxisBuilder.months(for: 2025, now: now, calendar: calendar)
        let futureMonths = StatisticsMonthAxisBuilder.months(for: 2027, now: now, calendar: calendar)

        #expect(pastMonths.count == 12)
        #expect(futureMonths.count == 12)
        #expect(pastMonths.first?.month == 1)
        #expect(futureMonths.last?.month == 12)
    }
}

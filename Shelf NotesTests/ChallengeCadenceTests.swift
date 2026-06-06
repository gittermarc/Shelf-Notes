import Foundation
import Testing
@testable import Shelf_Notes

struct ChallengeCadenceTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    @Test func dailyBoundsUseStartAndEndOfDay() {
        let bounds = ChallengeCadence.periodBounds(
            for: .daily,
            now: date(2026, 6, 3, 15),
            calendar: calendar
        )

        #expect(bounds.start == date(2026, 6, 3, 0))
        #expect(bounds.end == date(2026, 6, 4, 0))
    }

    @Test func weeklyBoundsKeepIsoWeekBehavior() {
        let bounds = ChallengeCadence.periodBounds(
            for: .weekly,
            now: date(2026, 6, 3, 15),
            calendar: calendar
        )

        #expect(bounds.start == date(2026, 6, 1, 0))
        #expect(bounds.end == date(2026, 6, 8, 0))
    }

    @Test func monthlyBoundsUseCalendarMonth() {
        let bounds = ChallengeCadence.periodBounds(
            for: .monthly,
            now: date(2026, 6, 3, 15),
            calendar: calendar
        )

        #expect(bounds.start == date(2026, 6, 1, 0))
        #expect(bounds.end == date(2026, 7, 1, 0))
    }

    @Test func yearlyBoundsUseCalendarYear() {
        let bounds = ChallengeCadence.periodBounds(
            for: .yearly,
            now: date(2026, 6, 3, 15),
            calendar: calendar
        )

        #expect(bounds.start == date(2026, 1, 1, 0))
        #expect(bounds.end == date(2027, 1, 1, 0))
    }

    @Test func cadenceSortOrderIsStable() {
        let sorted = ChallengeKind.allCases.sorted { lhs, rhs in
            lhs.sortOrder < rhs.sortOrder
        }

        #expect(sorted == [.daily, .weekly, .monthly, .yearly])
        #expect(ChallengeKind.unknown.sortOrder > ChallengeKind.yearly.sortOrder)
    }

    @Test func defaultGenerationKeepsExistingWeeklyMonthlyBehavior() {
        #expect(ChallengeCadence.defaultGenerationKinds == [.weekly, .monthly])
        #expect(ChallengeCadence.definition(for: .weekly).generatesByDefault)
        #expect(ChallengeCadence.definition(for: .monthly).generatesByDefault)
        #expect(!ChallengeCadence.definition(for: .daily).generatesByDefault)
        #expect(!ChallengeCadence.definition(for: .yearly).generatesByDefault)
    }

    @Test func baselineConfigurationMatchesCurrentBehavior() {
        #expect(ChallengeCadence.definition(for: .weekly).baselineLookbackDays == 28)
        #expect(ChallengeCadence.baselineDivisor(for: .weekly) == 4)
        #expect(ChallengeCadence.definition(for: .monthly).baselineLookbackDays == 90)
        #expect(ChallengeCadence.baselineDivisor(for: .monthly) == 3)
    }
}

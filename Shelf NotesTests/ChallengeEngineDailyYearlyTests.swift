import Foundation
import Testing
@testable import Shelf_Notes

struct ChallengeEngineDailyYearlyTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private func period(_ start: Date, _ end: Date) -> ChallengeEngine.PeriodBounds {
        ChallengeEngine.PeriodBounds(start: start, end: end)
    }

    private var emptySnapshot: ChallengeEngine.Snapshot {
        ChallengeEngine.Snapshot(sessions: [], finishedBookReadTo: [])
    }

    @Test func dailyPlanUsesDailyTemplateForRequestedDay() {
        let day = period(date(2026, 6, 3, 0), date(2026, 6, 4, 0))
        let plans = ChallengeEngine.planEnsures(
            cadences: [ChallengeEngine.EnsureCadenceInput(kind: .daily, period: day, existing: nil)],
            snapshot: emptySnapshot
        )

        let dailyMetrics = Set(ChallengeTemplateRegistry.templates(for: .daily).map(\.metric))

        #expect(plans.count == 1)
        #expect(plans.first?.kind == .daily)
        #expect(plans.first?.periodStart == day.start)
        #expect(plans.first?.periodEnd == day.end)
        #expect((plans.first?.targetValue ?? 0) > 0)
        #expect(plans.first.map { dailyMetrics.contains($0.metric) } ?? false)
    }

    @Test func yearlyPlanUsesYearlyTemplateForRequestedYear() {
        let year = period(date(2026, 1, 1, 0), date(2027, 1, 1, 0))
        let plans = ChallengeEngine.planEnsures(
            cadences: [ChallengeEngine.EnsureCadenceInput(kind: .yearly, period: year, existing: nil)],
            snapshot: emptySnapshot
        )

        let yearlyMetrics = Set(ChallengeTemplateRegistry.templates(for: .yearly).map(\.metric))

        #expect(plans.count == 1)
        #expect(plans.first?.kind == .yearly)
        #expect(plans.first?.periodStart == year.start)
        #expect(plans.first?.periodEnd == year.end)
        #expect((plans.first?.targetValue ?? 0) > 0)
        #expect(plans.first.map { yearlyMetrics.contains($0.metric) } ?? false)
    }

    @Test func existingDailyAndYearlyRecordsAreNotDuplicated() {
        let day = period(date(2026, 6, 3, 0), date(2026, 6, 4, 0))
        let year = period(date(2026, 1, 1, 0), date(2027, 1, 1, 0))
        let existingDaily = ChallengeEngine.ChallengeRecordSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000005001") ?? UUID(),
            kind: .daily,
            metric: .readingMinutes,
            periodStart: day.start,
            periodEnd: day.end,
            targetValue: 15,
            completedAt: nil
        )
        let existingYearly = ChallengeEngine.ChallengeRecordSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000005002") ?? UUID(),
            kind: .yearly,
            metric: .booksFinished,
            periodStart: year.start,
            periodEnd: year.end,
            targetValue: 12,
            completedAt: nil
        )

        let plans = ChallengeEngine.planEnsures(
            cadences: [
                ChallengeEngine.EnsureCadenceInput(kind: .daily, period: day, existing: existingDaily),
                ChallengeEngine.EnsureCadenceInput(kind: .yearly, period: year, existing: existingYearly)
            ],
            snapshot: emptySnapshot
        )

        #expect(plans.isEmpty)
    }

    @Test func weeklyAndMonthlyPlansRemainStableBesideNewCadences() {
        let day = period(date(2026, 6, 3, 0), date(2026, 6, 4, 0))
        let week = period(date(2026, 6, 1, 0), date(2026, 6, 8, 0))
        let month = period(date(2026, 6, 1, 0), date(2026, 7, 1, 0))
        let year = period(date(2026, 1, 1, 0), date(2027, 1, 1, 0))

        let plans = ChallengeEngine.planEnsures(
            cadences: [
                ChallengeEngine.EnsureCadenceInput(kind: .daily, period: day, existing: nil),
                ChallengeEngine.EnsureCadenceInput(kind: .weekly, period: week, existing: nil),
                ChallengeEngine.EnsureCadenceInput(kind: .monthly, period: month, existing: nil),
                ChallengeEngine.EnsureCadenceInput(kind: .yearly, period: year, existing: nil)
            ],
            snapshot: emptySnapshot
        )

        #expect(plans.map(\.kind) == [.daily, .weekly, .monthly, .yearly])
        #expect(plans.allSatisfy { $0.targetValue > 0 })
    }
}

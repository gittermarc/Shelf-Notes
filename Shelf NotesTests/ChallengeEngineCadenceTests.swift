import Foundation
import Testing
@testable import Shelf_Notes

struct ChallengeEngineCadenceTests {
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

    @Test func planEnsuresCreatesWeeklyAndMonthlyPlans() {
        let weekly = period(date(2026, 6, 1, 0), date(2026, 6, 8, 0))
        let monthly = period(date(2026, 6, 1, 0), date(2026, 7, 1, 0))

        let plans = ChallengeEngine.planEnsures(
            cadences: [
                ChallengeEngine.EnsureCadenceInput(kind: .weekly, period: weekly, existing: nil),
                ChallengeEngine.EnsureCadenceInput(kind: .monthly, period: monthly, existing: nil)
            ],
            snapshot: emptySnapshot
        )

        #expect(plans.map(\.kind) == [.weekly, .monthly])
        #expect(plans.allSatisfy { $0.targetValue > 0 })
    }

    @Test func planEnsuresSkipsExistingCadence() {
        let weekly = period(date(2026, 6, 1, 0), date(2026, 6, 8, 0))
        let monthly = period(date(2026, 6, 1, 0), date(2026, 7, 1, 0))
        let existingWeekly = ChallengeEngine.ChallengeRecordSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000001001") ?? UUID(),
            kind: .weekly,
            metric: .readingMinutes,
            periodStart: weekly.start,
            periodEnd: weekly.end,
            targetValue: 60,
            completedAt: nil
        )

        let plans = ChallengeEngine.planEnsures(
            cadences: [
                ChallengeEngine.EnsureCadenceInput(kind: .weekly, period: weekly, existing: existingWeekly),
                ChallengeEngine.EnsureCadenceInput(kind: .monthly, period: monthly, existing: nil)
            ],
            snapshot: emptySnapshot
        )

        #expect(plans.map(\.kind) == [.monthly])
    }

    @Test func planEnsuresDoesNotActivatePreparedCadencesWithoutTemplates() {
        let daily = period(date(2026, 6, 3, 0), date(2026, 6, 4, 0))
        let yearly = period(date(2026, 1, 1, 0), date(2027, 1, 1, 0))

        let plans = ChallengeEngine.planEnsures(
            cadences: [
                ChallengeEngine.EnsureCadenceInput(kind: .daily, period: daily, existing: nil),
                ChallengeEngine.EnsureCadenceInput(kind: .yearly, period: yearly, existing: nil)
            ],
            snapshot: emptySnapshot
        )

        #expect(plans.isEmpty)
    }

    @Test @MainActor func unknownStoredKindDoesNotFallbackToWeekly() {
        let record = ChallengeRecord(
            kind: .weekly,
            metric: .readingMinutes,
            periodStart: date(2026, 6, 1, 0),
            periodEnd: date(2026, 6, 8, 0),
            title: "Legacy",
            detail: "Legacy kind",
            targetValue: 60
        )
        record.kindRawValue = "futureCadence"

        #expect(record.kind == .unknown)
        #expect(record.kind.displayName == "Unbekannt")
        #expect(record.canReroll == false)
    }
}

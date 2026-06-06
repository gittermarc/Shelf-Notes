import Foundation
import Testing
@testable import Shelf_Notes

struct ChallengeEnginePreferencesTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private var emptySnapshot: ChallengeEngine.Snapshot {
        ChallengeEngine.Snapshot(sessions: [], finishedBookReadTo: [])
    }

    private func input(kind: ChallengeKind) -> ChallengeEngine.EnsureCadenceInput {
        let period = ChallengeCadence.periodBounds(for: kind, now: date(2026, 6, 3), calendar: calendar)
        return ChallengeEngine.EnsureCadenceInput(kind: kind, period: period, existing: nil)
    }

    @Test func pausedPreferencesCreateNoEnsurePlans() {
        let preferences = ChallengePreferences(enabledKinds: [], preset: .paused)
        let plans = ChallengeEngine.planEnsures(
            cadences: preferences.enabledKinds.map { input(kind: $0) },
            snapshot: emptySnapshot
        )

        #expect(plans.isEmpty)
    }

    @Test func activatedKindsCreatePlans() {
        let preferences = ChallengePreferences(enabledKinds: [.daily, .yearly], preset: .custom)
        let plans = ChallengeEngine.planEnsures(
            cadences: preferences.enabledKinds.map { input(kind: $0) },
            snapshot: emptySnapshot
        )

        #expect(plans.map(\.kind) == [.daily, .yearly])
        #expect(plans.allSatisfy { $0.targetValue > 0 })
    }

    @Test func disabledExistingKindDoesNotCreateReplacementPlan() {
        let preferences = ChallengePreferences(enabledKinds: [.weekly], preset: .custom)
        let disabledDaily = ChallengeEngine.ChallengeRecordSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000006001") ?? UUID(),
            kind: .daily,
            metric: .readingMinutes,
            periodStart: date(2026, 6, 3, 0),
            periodEnd: date(2026, 6, 4, 0),
            targetValue: 15,
            completedAt: nil
        )
        let enabledInputs = preferences.enabledKinds.map { input(kind: $0) }
        let plans = ChallengeEngine.planEnsures(cadences: enabledInputs, snapshot: emptySnapshot)

        #expect(disabledDaily.kind == .daily)
        #expect(plans.map(\.kind) == [.weekly])
        #expect(!plans.contains { $0.kind == .daily })
    }
}

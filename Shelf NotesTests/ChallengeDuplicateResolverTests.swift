import Foundation
import Testing
@testable import Shelf_Notes

struct ChallengeDuplicateResolverTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private func id(_ suffix: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-000000009%03d", suffix)) ?? UUID()
    }

    private func snapshot(
        id: UUID,
        kind: ChallengeKind = .weekly,
        periodStart: Date? = nil,
        periodEnd: Date? = nil,
        createdAt: Date? = nil,
        completedAt: Date? = nil,
        acknowledgedAt: Date? = nil,
        rerollsUsed: Int = 0,
        rerolledAt: Date? = nil
    ) -> ChallengeDuplicateResolver.RecordSnapshot {
        ChallengeDuplicateResolver.RecordSnapshot(
            id: id,
            kindRawValue: kind.rawValue,
            periodStart: periodStart ?? date(2026, 6, 1),
            periodEnd: periodEnd ?? date(2026, 6, 8),
            createdAt: createdAt ?? date(2026, 5, 20),
            completedAt: completedAt,
            acknowledgedAt: acknowledgedAt,
            rerollsUsed: rerollsUsed,
            rerolledAt: rerolledAt
        )
    }

    @Test func removesDuplicateWeeklyChallengesForSamePeriod() {
        let retainedID = id(1)
        let duplicateID = id(2)
        let retained = snapshot(id: retainedID, createdAt: date(2026, 5, 20))
        let duplicate = snapshot(id: duplicateID, createdAt: date(2026, 5, 21))

        let resolutions = ChallengeDuplicateResolver.resolutions(for: [duplicate, retained])

        #expect(resolutions.count == 1)
        #expect(resolutions.first?.retainedID == retainedID)
        #expect(Set(resolutions.first?.removedIDs ?? []) == Set([duplicateID]))
    }

    @Test func keepsWeeklyAndMonthlyChallengesSeparateForSameStartDate() {
        let weekly = snapshot(id: id(3), kind: .weekly, periodStart: date(2026, 6, 1), periodEnd: date(2026, 6, 8))
        let monthly = snapshot(id: id(4), kind: .monthly, periodStart: date(2026, 6, 1), periodEnd: date(2026, 7, 1))

        let resolutions = ChallengeDuplicateResolver.resolutions(for: [weekly, monthly])

        #expect(resolutions.isEmpty)
        #expect(ChallengeDuplicateResolver.idsToDelete(from: [weekly, monthly]).isEmpty)
    }

    @Test func prefersClaimedOrCompletedDuplicateOverFreshRecord() {
        let freshID = id(5)
        let claimedID = id(6)
        let fresh = snapshot(id: freshID, createdAt: date(2026, 5, 20))
        let claimed = snapshot(
            id: claimedID,
            createdAt: date(2026, 5, 22),
            completedAt: date(2026, 6, 3),
            acknowledgedAt: date(2026, 6, 4)
        )

        let resolutions = ChallengeDuplicateResolver.resolutions(for: [fresh, claimed])

        #expect(resolutions.first?.retainedID == claimedID)
        #expect(Set(resolutions.first?.removedIDs ?? []) == Set([freshID]))
    }

    @Test func prefersRerolledDuplicateOverFreshRecord() {
        let freshID = id(7)
        let rerolledID = id(8)
        let fresh = snapshot(id: freshID, createdAt: date(2026, 5, 20))
        let rerolled = snapshot(
            id: rerolledID,
            createdAt: date(2026, 5, 22),
            rerollsUsed: 1,
            rerolledAt: date(2026, 6, 2)
        )

        let resolutions = ChallengeDuplicateResolver.resolutions(for: [fresh, rerolled])

        #expect(resolutions.first?.retainedID == rerolledID)
        #expect(Set(resolutions.first?.removedIDs ?? []) == Set([freshID]))
    }

    @Test func keepsOldestRecordWhenNoStatusSignalExists() {
        let olderID = id(9)
        let newerID = id(10)
        let older = snapshot(id: olderID, createdAt: date(2026, 5, 20))
        let newer = snapshot(id: newerID, createdAt: date(2026, 5, 22))

        let idsToDelete = ChallengeDuplicateResolver.idsToDelete(from: [newer, older])

        #expect(idsToDelete == Set([newerID]))
    }
}

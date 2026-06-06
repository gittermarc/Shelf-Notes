import Foundation
import Testing
@testable import Shelf_Notes

struct ChallengeDashboardBuilderTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    @MainActor
    private func makeChallenge(
        id: UUID,
        kind: ChallengeKind,
        metric: ChallengeMetric = .readingMinutes,
        periodStart: Date,
        periodEnd: Date,
        targetValue: Int = 100,
        createdAt: Date? = nil,
        completed: Bool = false,
        claimed: Bool = false
    ) -> ChallengeRecord {
        let record = ChallengeRecord(
            kind: kind,
            metric: metric,
            periodStart: periodStart,
            periodEnd: periodEnd,
            title: "Read more",
            detail: "Read for a focused amount of time.",
            targetValue: targetValue
        )
        record.id = id
        if let createdAt {
            record.createdAt = createdAt
        }
        if completed {
            record.completedAt = periodStart.addingTimeInterval(60 * 60)
        }
        if claimed {
            record.acknowledgedAt = periodStart.addingTimeInterval(2 * 60 * 60)
        }
        return record
    }

    @Test @MainActor func heroPrefersUnclaimedReward() {
        let now = date(2026, 6, 3)
        let weeklyID = UUID(uuidString: "00000000-0000-0000-0000-000000000101") ?? UUID()
        let monthlyID = UUID(uuidString: "00000000-0000-0000-0000-000000000102") ?? UUID()
        let weekly = makeChallenge(
            id: weeklyID,
            kind: .weekly,
            periodStart: date(2026, 6, 1),
            periodEnd: date(2026, 6, 8),
            completed: true
        )
        let monthly = makeChallenge(
            id: monthlyID,
            kind: .monthly,
            periodStart: date(2026, 6, 1),
            periodEnd: date(2026, 7, 1)
        )

        let state = ChallengeDashboardBuilder.make(
            challenges: [monthly, weekly],
            progressByID: [
                weeklyID: ChallengeEngine.ChallengeProgress(value: 100, unitSuffix: "min"),
                monthlyID: ChallengeEngine.ChallengeProgress(value: 95, unitSuffix: "min")
            ],
            now: now,
            calendar: calendar
        )

        #expect(state.hero?.itemID == weeklyID)
        #expect(state.hero?.isRewardReady == true)
        #expect(state.unclaimedCount == 1)
    }

    @Test @MainActor func heroUsesClosestActiveChallengeWhenNoRewardIsReady() {
        let now = date(2026, 6, 3)
        let weeklyID = UUID(uuidString: "00000000-0000-0000-0000-000000000201") ?? UUID()
        let monthlyID = UUID(uuidString: "00000000-0000-0000-0000-000000000202") ?? UUID()
        let weekly = makeChallenge(
            id: weeklyID,
            kind: .weekly,
            periodStart: date(2026, 6, 1),
            periodEnd: date(2026, 6, 8)
        )
        let monthly = makeChallenge(
            id: monthlyID,
            kind: .monthly,
            periodStart: date(2026, 6, 1),
            periodEnd: date(2026, 7, 1)
        )

        let state = ChallengeDashboardBuilder.make(
            challenges: [weekly, monthly],
            progressByID: [
                weeklyID: ChallengeEngine.ChallengeProgress(value: 20, unitSuffix: "min"),
                monthlyID: ChallengeEngine.ChallengeProgress(value: 80, unitSuffix: "min")
            ],
            now: now,
            calendar: calendar
        )

        #expect(state.hero?.itemID == monthlyID)
        #expect(state.hero?.isRewardReady == false)
    }

    @Test @MainActor func historyExcludesActiveChallengesAndRespectsLimit() {
        let now = date(2026, 6, 20)
        let activeID = UUID(uuidString: "00000000-0000-0000-0000-000000000301") ?? UUID()
        let active = makeChallenge(
            id: activeID,
            kind: .weekly,
            periodStart: date(2026, 6, 15),
            periodEnd: date(2026, 6, 22)
        )
        let past = (0..<14).map { index in
            makeChallenge(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-0000000004%02d", index)) ?? UUID(),
                kind: index.isMultiple(of: 2) ? .weekly : .monthly,
                periodStart: date(2026, 1, 1 + index),
                periodEnd: date(2026, 1, 2 + index),
                completed: index.isMultiple(of: 3),
                claimed: index.isMultiple(of: 3)
            )
        }

        let state = ChallengeDashboardBuilder.make(
            challenges: [active] + past,
            progressByID: [:],
            now: now,
            calendar: calendar,
            historyLimit: 12
        )

        #expect(state.activeItems.map(\.id) == [activeID])
        #expect(state.historyItems.count == 12)
        #expect(!state.historyItems.contains { $0.id == activeID })
    }

    @Test @MainActor func duplicateActiveWeeklyChallengesProduceOneVisibleItem() {
        let now = date(2026, 6, 3)
        let retainedID = UUID(uuidString: "00000000-0000-0000-0000-000000000501") ?? UUID()
        let duplicateID = UUID(uuidString: "00000000-0000-0000-0000-000000000502") ?? UUID()
        let retained = makeChallenge(
            id: retainedID,
            kind: .weekly,
            periodStart: date(2026, 6, 1),
            periodEnd: date(2026, 6, 8),
            createdAt: date(2026, 5, 20)
        )
        let duplicate = makeChallenge(
            id: duplicateID,
            kind: .weekly,
            periodStart: date(2026, 6, 1),
            periodEnd: date(2026, 6, 8),
            createdAt: date(2026, 5, 21)
        )

        let state = ChallengeDashboardBuilder.make(
            challenges: [duplicate, retained],
            progressByID: [
                retainedID: ChallengeEngine.ChallengeProgress(value: 20, unitSuffix: "min"),
                duplicateID: ChallengeEngine.ChallengeProgress(value: 80, unitSuffix: "min")
            ],
            now: now,
            calendar: calendar
        )

        #expect(state.activeItems.map(\.id) == [retainedID])
        #expect(state.activeItems.first?.progress?.value == 20)
    }

    @Test @MainActor func weeklyAndMonthlyChallengesForSameCalendarStartStayVisibleSeparately() {
        let now = date(2026, 6, 3)
        let weeklyID = UUID(uuidString: "00000000-0000-0000-0000-000000000601") ?? UUID()
        let monthlyID = UUID(uuidString: "00000000-0000-0000-0000-000000000602") ?? UUID()
        let weekly = makeChallenge(
            id: weeklyID,
            kind: .weekly,
            periodStart: date(2026, 6, 1),
            periodEnd: date(2026, 6, 8),
            createdAt: date(2026, 5, 20)
        )
        let monthly = makeChallenge(
            id: monthlyID,
            kind: .monthly,
            periodStart: date(2026, 6, 1),
            periodEnd: date(2026, 7, 1),
            createdAt: date(2026, 5, 20)
        )

        let state = ChallengeDashboardBuilder.make(
            challenges: [monthly, weekly],
            progressByID: [:],
            now: now,
            calendar: calendar
        )

        #expect(state.activeItems.map(\.id) == [weeklyID, monthlyID])
    }

    @Test @MainActor func claimedDuplicateIsPreferredOverFreshDuplicate() {
        let now = date(2026, 6, 3)
        let freshID = UUID(uuidString: "00000000-0000-0000-0000-000000000701") ?? UUID()
        let claimedID = UUID(uuidString: "00000000-0000-0000-0000-000000000702") ?? UUID()
        let fresh = makeChallenge(
            id: freshID,
            kind: .weekly,
            periodStart: date(2026, 6, 1),
            periodEnd: date(2026, 6, 8),
            createdAt: date(2026, 5, 20)
        )
        let claimed = makeChallenge(
            id: claimedID,
            kind: .weekly,
            periodStart: date(2026, 6, 1),
            periodEnd: date(2026, 6, 8),
            createdAt: date(2026, 5, 22),
            completed: true,
            claimed: true
        )

        let state = ChallengeDashboardBuilder.make(
            challenges: [fresh, claimed],
            progressByID: [claimedID: ChallengeEngine.ChallengeProgress(value: 100, unitSuffix: "min")],
            now: now,
            calendar: calendar
        )

        #expect(state.activeItems.map(\.id) == [claimedID])
        #expect(state.activeItems.first?.status == .claimed)
        #expect(state.completedCount == 1)
        #expect(state.unclaimedCount == 0)
    }
}

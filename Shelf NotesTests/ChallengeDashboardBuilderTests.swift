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

    @Test @MainActor func disabledActiveKindsAreNotShownAsActiveMissions() {
        let now = date(2026, 6, 3)
        let dailyID = UUID(uuidString: "00000000-0000-0000-0000-000000000801") ?? UUID()
        let weeklyID = UUID(uuidString: "00000000-0000-0000-0000-000000000802") ?? UUID()
        let daily = makeChallenge(
            id: dailyID,
            kind: .daily,
            periodStart: date(2026, 6, 3, 0),
            periodEnd: date(2026, 6, 4, 0)
        )
        let weekly = makeChallenge(
            id: weeklyID,
            kind: .weekly,
            periodStart: date(2026, 6, 1, 0),
            periodEnd: date(2026, 6, 8, 0)
        )

        let state = ChallengeDashboardBuilder.make(
            challenges: [daily, weekly],
            progressByID: [:],
            now: now,
            calendar: calendar,
            enabledKinds: [.weekly]
        )

        #expect(state.activeItems.map(\.id) == [weeklyID])
        #expect(!state.activeItems.contains { $0.id == dailyID })
        #expect(state.todayFocus == nil)
    }

    @Test @MainActor func dailyChallengeBecomesTodayFocusAndIsNotDuplicatedInActiveItems() {
        let now = date(2026, 6, 3, 12)
        let dailyID = UUID(uuidString: "00000000-0000-0000-0000-000000001001") ?? UUID()
        let weeklyID = UUID(uuidString: "00000000-0000-0000-0000-000000001002") ?? UUID()
        let monthlyID = UUID(uuidString: "00000000-0000-0000-0000-000000001003") ?? UUID()
        let yearlyID = UUID(uuidString: "00000000-0000-0000-0000-000000001004") ?? UUID()
        let daily = makeChallenge(
            id: dailyID,
            kind: .daily,
            periodStart: date(2026, 6, 3, 0),
            periodEnd: date(2026, 6, 4, 0),
            targetValue: 30
        )
        let weekly = makeChallenge(
            id: weeklyID,
            kind: .weekly,
            periodStart: date(2026, 6, 1, 0),
            periodEnd: date(2026, 6, 8, 0)
        )
        let monthly = makeChallenge(
            id: monthlyID,
            kind: .monthly,
            periodStart: date(2026, 6, 1, 0),
            periodEnd: date(2026, 7, 1, 0)
        )
        let yearly = makeChallenge(
            id: yearlyID,
            kind: .yearly,
            periodStart: date(2026, 1, 1, 0),
            periodEnd: date(2027, 1, 1, 0)
        )

        let state = ChallengeDashboardBuilder.make(
            challenges: [yearly, monthly, weekly, daily],
            progressByID: [
                dailyID: ChallengeEngine.ChallengeProgress(value: 18, unitSuffix: "min"),
                weeklyID: ChallengeEngine.ChallengeProgress(value: 70, unitSuffix: "min"),
                monthlyID: ChallengeEngine.ChallengeProgress(value: 50, unitSuffix: "min"),
                yearlyID: ChallengeEngine.ChallengeProgress(value: 20, unitSuffix: "min")
            ],
            now: now,
            calendar: calendar,
            enabledKinds: [.daily, .weekly, .monthly, .yearly]
        )

        #expect(state.todayFocus?.item.id == dailyID)
        #expect(state.todayFocus?.headline == "Heute im Fokus")
        #expect(state.todayFocus?.message.contains("Tagesmission") == true)
        #expect(state.activeItems.map(\.id) == [weeklyID, monthlyID, yearlyID])
        #expect(Array(state.sessionHintItems.map(\.id).prefix(2)) == [dailyID, weeklyID])
    }

    @Test @MainActor func dailyFocusIsHiddenWhenDailyKindIsDisabled() {
        let now = date(2026, 6, 3, 12)
        let dailyID = UUID(uuidString: "00000000-0000-0000-0000-000000001101") ?? UUID()
        let daily = makeChallenge(
            id: dailyID,
            kind: .daily,
            periodStart: date(2026, 6, 3, 0),
            periodEnd: date(2026, 6, 4, 0)
        )

        let state = ChallengeDashboardBuilder.make(
            challenges: [daily],
            progressByID: [dailyID: ChallengeEngine.ChallengeProgress(value: 10, unitSuffix: "min")],
            now: now,
            calendar: calendar,
            enabledKinds: [.weekly, .monthly]
        )

        #expect(state.todayFocus == nil)
        #expect(state.activeItems.isEmpty)
        #expect(state.hero == nil)
    }

    @Test @MainActor func disabledUnclaimedRewardsRemainVisible() {
        let now = date(2026, 6, 3)
        let dailyID = UUID(uuidString: "00000000-0000-0000-0000-000000000901") ?? UUID()
        let daily = makeChallenge(
            id: dailyID,
            kind: .daily,
            periodStart: date(2026, 6, 3, 0),
            periodEnd: date(2026, 6, 4, 0),
            completed: true,
            claimed: false
        )

        let state = ChallengeDashboardBuilder.make(
            challenges: [daily],
            progressByID: [dailyID: ChallengeEngine.ChallengeProgress(value: 100, unitSuffix: "min")],
            now: now,
            calendar: calendar,
            enabledKinds: [.weekly, .monthly]
        )

        #expect(state.activeItems.map(\.id) == [dailyID])
        #expect(state.activeItems.first?.status == .readyToClaim)
        #expect(state.unclaimedCount == 1)
    }

    @Test @MainActor func readyToClaimItemExposesCelebrationState() {
        let now = date(2026, 6, 3)
        let weeklyID = UUID(uuidString: "00000000-0000-0000-0000-000000001201") ?? UUID()
        let weekly = makeChallenge(
            id: weeklyID,
            kind: .weekly,
            periodStart: date(2026, 6, 1, 0),
            periodEnd: date(2026, 6, 8, 0),
            completed: true,
            claimed: false
        )

        let state = ChallengeDashboardBuilder.make(
            challenges: [weekly],
            progressByID: [weeklyID: ChallengeEngine.ChallengeProgress(value: 100, unitSuffix: "min")],
            now: now,
            calendar: calendar,
            enabledKinds: [.weekly]
        )

        #expect(state.activeItems.first?.id == weeklyID)
        #expect(state.activeItems.first?.celebrationState == .readyToClaim)
        #expect(state.activeItems.first?.shouldHighlightCompletion == true)
        #expect(state.activeItems.first?.statusSystemImage == "sparkles")
    }

}

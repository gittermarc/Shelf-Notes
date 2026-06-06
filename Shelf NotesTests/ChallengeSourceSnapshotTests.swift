import Foundation
import Testing
@testable import Shelf_Notes

struct ChallengeSourceSnapshotTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    private func addingDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date.addingTimeInterval(TimeInterval(days * 24 * 60 * 60))
    }

    @MainActor
    private func makeChallenge(
        id: UUID,
        kind: ChallengeKind,
        periodStart: Date,
        periodEnd: Date,
        metric: ChallengeMetric = .readingMinutes,
        targetValue: Int = 30,
        createdAt: Date? = nil,
        completed: Bool = false,
        claimed: Bool = false
    ) -> ChallengeRecord {
        let record = ChallengeRecord(
            kind: kind,
            metric: metric,
            periodStart: periodStart,
            periodEnd: periodEnd,
            title: "Test Mission",
            detail: "Test detail",
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

    @Test @MainActor func activeSnapshotRespectsEnabledKindsButKeepsUnclaimedRewards() {
        let now = date(2026, 6, 20, 12)
        let dailyID = UUID(uuidString: "00000000-0000-0000-0000-000000010001") ?? UUID()
        let weeklyID = UUID(uuidString: "00000000-0000-0000-0000-000000010002") ?? UUID()
        let unclaimedDailyID = UUID(uuidString: "00000000-0000-0000-0000-000000010003") ?? UUID()
        let daily = makeChallenge(
            id: dailyID,
            kind: .daily,
            periodStart: date(2026, 6, 20, 0),
            periodEnd: date(2026, 6, 21, 0)
        )
        let weekly = makeChallenge(
            id: weeklyID,
            kind: .weekly,
            periodStart: date(2026, 6, 15, 0),
            periodEnd: date(2026, 6, 22, 0)
        )
        let unclaimedDaily = makeChallenge(
            id: unclaimedDailyID,
            kind: .daily,
            periodStart: date(2026, 6, 20, 0),
            periodEnd: date(2026, 6, 21, 0),
            completed: true,
            claimed: false
        )

        let snapshot = ChallengeSourceSnapshot.make(
            records: [daily, weekly, unclaimedDaily],
            enabledKinds: [.weekly],
            now: now
        )

        #expect(snapshot.activeRecords.map(\.id) == [unclaimedDailyID, weeklyID])
        #expect(!snapshot.activeRecords.contains { $0.id == dailyID })
        #expect(snapshot.unclaimedRecords.map(\.id) == [unclaimedDailyID])
        #expect(snapshot.dashboardRecords.contains { $0.id == weeklyID })
        #expect(snapshot.dashboardRecords.contains { $0.id == unclaimedDailyID })
    }

    @Test @MainActor func dailyHistoryIsBoundedBeforeDashboardBuilds() {
        let now = date(2026, 6, 20, 12)
        let records = (1..<61).map { index in
            let start = addingDays(-index, to: date(2026, 6, 20, 0))
            return makeChallenge(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-00000002%04d", index)) ?? UUID(),
                kind: .daily,
                periodStart: start,
                periodEnd: addingDays(1, to: start),
                completed: index.isMultiple(of: 2),
                claimed: index.isMultiple(of: 2)
            )
        }

        let snapshot = ChallengeSourceSnapshot.make(
            records: records,
            enabledKinds: [.daily, .weekly, .monthly, .yearly],
            now: now
        )

        #expect(snapshot.historyRecords.filter { $0.kind == .daily }.count == 14)
        #expect(snapshot.dashboardRecords.count == 14)
        #expect(snapshot.progressRecords.count == 12)
    }

    @Test @MainActor func longerCadenceHistoryRemainsAvailableBesideDailyRecords() {
        let now = date(2026, 6, 20, 12)
        let dailyRecords = (1..<31).map { index in
            let start = addingDays(-index, to: date(2026, 6, 20, 0))
            return makeChallenge(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-00000003%04d", index)) ?? UUID(),
                kind: .daily,
                periodStart: start,
                periodEnd: addingDays(1, to: start)
            )
        }
        let weekly = makeChallenge(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000030101") ?? UUID(),
            kind: .weekly,
            periodStart: date(2026, 6, 8, 0),
            periodEnd: date(2026, 6, 15, 0)
        )
        let monthly = makeChallenge(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000030102") ?? UUID(),
            kind: .monthly,
            periodStart: date(2026, 5, 1, 0),
            periodEnd: date(2026, 6, 1, 0)
        )
        let yearly = makeChallenge(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000030103") ?? UUID(),
            kind: .yearly,
            periodStart: date(2025, 1, 1, 0),
            periodEnd: date(2026, 1, 1, 0)
        )

        let snapshot = ChallengeSourceSnapshot.make(
            records: dailyRecords + [weekly, monthly, yearly],
            enabledKinds: [.daily, .weekly, .monthly, .yearly],
            now: now
        )

        #expect(snapshot.historyRecords.contains { $0.kind == .weekly })
        #expect(snapshot.historyRecords.contains { $0.kind == .monthly })
        #expect(snapshot.historyRecords.contains { $0.kind == .yearly })
        #expect(snapshot.historyRecords.filter { $0.kind == .daily }.count == 14)
    }

    @Test @MainActor func duplicateRecordsAreResolvedInsideSourceSnapshot() {
        let now = date(2026, 6, 20, 12)
        let retainedID = UUID(uuidString: "00000000-0000-0000-0000-000000040001") ?? UUID()
        let duplicateID = UUID(uuidString: "00000000-0000-0000-0000-000000040002") ?? UUID()
        let retained = makeChallenge(
            id: retainedID,
            kind: .weekly,
            periodStart: date(2026, 6, 15, 0),
            periodEnd: date(2026, 6, 22, 0),
            createdAt: date(2026, 6, 1)
        )
        let duplicate = makeChallenge(
            id: duplicateID,
            kind: .weekly,
            periodStart: date(2026, 6, 15, 0),
            periodEnd: date(2026, 6, 22, 0),
            createdAt: date(2026, 6, 2)
        )

        let snapshot = ChallengeSourceSnapshot.make(
            records: [duplicate, retained],
            enabledKinds: [.weekly],
            now: now
        )

        #expect(snapshot.activeRecords.map(\.id) == [retainedID])
        #expect(snapshot.dashboardRecords.map(\.id) == [retainedID])
    }

    @Test @MainActor func oldUnclaimedRewardsRemainProminentInDashboardState() {
        let now = date(2026, 6, 20, 12)
        let rewardID = UUID(uuidString: "00000000-0000-0000-0000-000000045001") ?? UUID()
        let reward = makeChallenge(
            id: rewardID,
            kind: .daily,
            periodStart: date(2026, 5, 1, 0),
            periodEnd: date(2026, 5, 2, 0),
            completed: true,
            claimed: false
        )
        let recentHistory = (1..<21).map { index in
            let start = addingDays(-index, to: date(2026, 6, 20, 0))
            return makeChallenge(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-00000004%04d", index + 600)) ?? UUID(),
                kind: .daily,
                periodStart: start,
                periodEnd: addingDays(1, to: start),
                completed: true,
                claimed: true
            )
        }
        let snapshot = ChallengeSourceSnapshot.make(
            records: [reward] + recentHistory,
            enabledKinds: [.weekly],
            now: now
        )

        let state = ChallengeDashboardBuilder.make(
            sourceSnapshot: snapshot,
            progressByID: [rewardID: ChallengeEngine.ChallengeProgress(value: 30, unitSuffix: "min")],
            now: now,
            calendar: calendar,
            enabledKinds: [.weekly]
        )

        #expect(state.activeItems.map(\.id).contains(rewardID))
        #expect(state.hero?.itemID == rewardID)
        #expect(!state.historyItems.contains { $0.id == rewardID })
    }

    @Test @MainActor func dashboardBuilderCanUseBoundedSourceSnapshot() {
        let now = date(2026, 6, 20, 12)
        let weeklyID = UUID(uuidString: "00000000-0000-0000-0000-000000050001") ?? UUID()
        let disabledDailyID = UUID(uuidString: "00000000-0000-0000-0000-000000050002") ?? UUID()
        let weekly = makeChallenge(
            id: weeklyID,
            kind: .weekly,
            periodStart: date(2026, 6, 15, 0),
            periodEnd: date(2026, 6, 22, 0)
        )
        let disabledDaily = makeChallenge(
            id: disabledDailyID,
            kind: .daily,
            periodStart: date(2026, 6, 20, 0),
            periodEnd: date(2026, 6, 21, 0)
        )
        let oldDailyRecords = (1..<41).map { index in
            let start = addingDays(-index, to: date(2026, 6, 20, 0))
            return makeChallenge(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-00000005%04d", index + 100)) ?? UUID(),
                kind: .daily,
                periodStart: start,
                periodEnd: addingDays(1, to: start)
            )
        }
        let snapshot = ChallengeSourceSnapshot.make(
            records: [weekly, disabledDaily] + oldDailyRecords,
            enabledKinds: [.weekly],
            now: now
        )

        let state = ChallengeDashboardBuilder.make(
            sourceSnapshot: snapshot,
            progressByID: [weeklyID: ChallengeEngine.ChallengeProgress(value: 5, unitSuffix: "min")],
            now: now,
            calendar: calendar,
            enabledKinds: [.weekly]
        )

        #expect(state.activeItems.map(\.id) == [weeklyID])
        #expect(!state.activeItems.contains { $0.id == disabledDailyID })
        #expect(state.historyItems.count == 12)
    }
}

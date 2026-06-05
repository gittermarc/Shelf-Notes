import Foundation
import Testing
@testable import Shelf_Notes

struct ChallengeRewardSummaryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? .distantPast
    }

    private func item(
        id: UUID = UUID(),
        kind: ChallengeKind,
        start: Date,
        end: Date,
        status: ChallengeDashboardItem.Status
    ) -> ChallengeDashboardItem {
        ChallengeDashboardItem(
            id: id,
            kind: kind,
            metric: .readingMinutes,
            title: "Test",
            detail: "Test detail",
            targetValue: 100,
            periodLabel: "Test period",
            periodStart: start,
            periodEnd: end,
            progress: ChallengeEngine.ChallengeProgress(value: status == .expired ? 20 : 100, unitSuffix: "min"),
            status: status,
            canReroll: false,
            timeRemainingText: "beendet",
            deadlineText: "bis Test",
            progressText: "100/100 min",
            remainingText: "Ziel erreicht",
            motivationText: "Stark.",
            difficultyText: "Dranbleiben",
            rewardText: "Belohnung."
        )
    }

    @Test func rewardSummaryDerivesWeeklyStreakAndReadyCount() {
        let now = date(2026, 6, 20)
        let items = [
            item(kind: .weekly, start: date(2026, 6, 15), end: date(2026, 6, 22), status: .readyToClaim),
            item(kind: .weekly, start: date(2026, 6, 8), end: date(2026, 6, 15), status: .claimed),
            item(kind: .weekly, start: date(2026, 6, 1), end: date(2026, 6, 8), status: .claimed),
            item(kind: .monthly, start: date(2026, 6, 1), end: date(2026, 7, 1), status: .active)
        ]

        let summary = ChallengeRewardSummaryBuilder.make(items: items, now: now)

        #expect(summary.completedCount == 3)
        #expect(summary.readyToClaimCount == 1)
        #expect(summary.weeklyStreak == 3)
        #expect(summary.highlightTitle == "Belohnung wartet")
    }
}

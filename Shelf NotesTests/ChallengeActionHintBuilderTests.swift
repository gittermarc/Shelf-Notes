import Foundation
import Testing
@testable import Shelf_Notes

struct ChallengeActionHintBuilderTests {
    private func item(
        id: UUID = UUID(),
        kind: ChallengeKind = .weekly,
        metric: ChallengeMetric,
        progressValue: Int,
        targetValue: Int = 100,
        status: ChallengeDashboardItem.Status = .active
    ) -> ChallengeDashboardItem {
        ChallengeDashboardItem(
            id: id,
            kind: kind,
            metric: metric,
            title: "Test Challenge",
            detail: "Test detail",
            targetValue: targetValue,
            periodLabel: "01.06.–07.06.",
            periodStart: Date(timeIntervalSince1970: 0),
            periodEnd: Date(timeIntervalSince1970: 10_000),
            progress: ChallengeEngine.ChallengeProgress(value: progressValue, unitSuffix: metric.unitSuffix),
            status: status,
            canReroll: true,
            timeRemainingText: "noch 2 Tage",
            deadlineText: "bis 07.06.",
            progressText: "\(progressValue)/\(targetValue) \(metric.unitSuffix)",
            remainingText: "Noch \(max(0, targetValue - progressValue)) \(metric.unitSuffix)",
            motivationText: "Dranbleiben.",
            difficultyText: "Dranbleiben",
            rewardText: "Belohnungstext."
        )
    }

    @Test func sessionHintsPreferNearlyCompletedChallenges() {
        let minutes = item(metric: .readingMinutes, progressValue: 40)
        let sessions = item(metric: .sessions, progressValue: 90)

        let hints = ChallengeActionHintBuilder.makeSessionHints(
            from: [minutes, sessions],
            bookTitle: "Dune",
            remainingPages: 120
        )

        #expect(hints.first?.metric == .sessions)
        #expect(hints.first?.priority == 0)
    }

    @Test func sessionHintsPrioritizeFastDailyMissionOverWeeklyProgress() {
        let daily = item(kind: .daily, metric: .readingMinutes, progressValue: 18, targetValue: 30)
        let weekly = item(kind: .weekly, metric: .readingMinutes, progressValue: 95, targetValue: 100)

        let hints = ChallengeActionHintBuilder.makeSessionHints(
            from: [weekly, daily],
            bookTitle: "Dune",
            remainingPages: 120
        )

        #expect(hints.first?.kind == .daily)
        #expect(hints.first?.message.contains("Tagesmission") == true)
    }

    @Test func sessionHintsHidePageChallengeWhenBookHasNoRemainingPages() {
        let pages = item(metric: .pagesRead, progressValue: 40)

        let hints = ChallengeActionHintBuilder.makeSessionHints(
            from: [pages],
            bookTitle: "Dune",
            remainingPages: 0
        )

        #expect(hints.isEmpty)
    }

    @Test func sessionHintsExcludeRewardReadyItems() {
        let rewardReady = item(metric: .readingMinutes, progressValue: 100, status: .readyToClaim)

        let hints = ChallengeActionHintBuilder.makeSessionHints(
            from: [rewardReady],
            bookTitle: "Dune",
            remainingPages: nil
        )

        #expect(hints.isEmpty)
    }
}

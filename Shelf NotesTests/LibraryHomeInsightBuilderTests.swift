import Foundation
import Testing
@testable import Shelf_Notes

struct LibraryHomeInsightBuilderTests {
    @Test func insightsStayEmptyWithoutInputs() {
        let snapshot = LibraryView.LibraryHomeInsightBuilder.makeSnapshot()

        #expect(snapshot.isEmpty)
        #expect(snapshot.items.isEmpty)
    }

    @Test func weeklyMinutesGoalAndStreakArePrepared() {
        let progress = LibraryView.LibraryHomeInsightProgressInput(
            year: 2026,
            finishedThisYear: 18,
            goalTarget: 30,
            minutesLast7: 145,
            activeDaysLast7: 4,
            currentStreak: 3
        )

        let snapshot = LibraryView.LibraryHomeInsightBuilder.makeSnapshot(progress: progress)
        let itemsByKind = Dictionary(uniqueKeysWithValues: snapshot.items.map { ($0.kind, $0) })

        #expect(itemsByKind[.yearGoal]?.value == "18 / 30")
        #expect(itemsByKind[.yearGoal]?.progressFraction == 0.6)
        #expect(itemsByKind[.weeklyMinutes]?.value == "145")
        #expect(itemsByKind[.readingStreak]?.value == "3")
        #expect(itemsByKind[.activeDays] == nil)
    }

    @Test func activeDaysAreUsedWhenNoStreakIsPresent() {
        let progress = LibraryView.LibraryHomeInsightProgressInput(
            year: 2026,
            finishedThisYear: 0,
            goalTarget: nil,
            minutesLast7: 0,
            activeDaysLast7: 2,
            currentStreak: 0
        )

        let snapshot = LibraryView.LibraryHomeInsightBuilder.makeSnapshot(progress: progress)

        #expect(snapshot.items.map(\.kind) == [.activeDays])
        #expect(snapshot.items.first?.value == "2")
        #expect(snapshot.items.first?.caption == "letzte 7 Tage")
    }

    @Test func goalProgressIsClampedAtOne() {
        let progress = LibraryView.LibraryHomeInsightProgressInput(
            year: 2026,
            finishedThisYear: 34,
            goalTarget: 30,
            minutesLast7: 0,
            activeDaysLast7: 0,
            currentStreak: 0
        )

        let snapshot = LibraryView.LibraryHomeInsightBuilder.makeSnapshot(progress: progress)

        #expect(snapshot.items.first?.kind == .yearGoal)
        #expect(snapshot.items.first?.progressFraction == 1)
        #expect(snapshot.items.first?.isProminent == true)
    }

    @Test func challengeRewardIsPrioritized() {
        let dashboard = ChallengeDashboardState(
            todayFocus: nil,
            hero: ChallengeDashboardHero(
                itemID: fixedID(1),
                title: "Nächster Sieg",
                subtitle: "Noch 20 Minuten",
                systemImage: "clock",
                progressFraction: 0.8,
                progressText: "80 %",
                actionText: "noch heute",
                isRewardReady: false
            ),
            activeItems: [],
            historyItems: [],
            completedCount: 4,
            unclaimedCount: 2,
            rewardSummary: .empty
        )

        let challengeInput = LibraryView.LibraryHomeInsightBuilder.makeChallengeInput(from: dashboard)
        let snapshot = LibraryView.LibraryHomeInsightBuilder.makeSnapshot(challenge: challengeInput)

        #expect(snapshot.items.first?.kind == .challenge)
        #expect(snapshot.items.first?.title == "Belohnung wartet")
        #expect(snapshot.items.first?.value == "2")
        #expect(snapshot.items.first?.isProminent == true)
        #expect(snapshot.items.first?.progressFraction == 1)
    }

    @Test func challengeHeroIsUsedWhenNoRewardIsReady() {
        let dashboard = ChallengeDashboardState(
            todayFocus: nil,
            hero: ChallengeDashboardHero(
                itemID: fixedID(2),
                title: "Nächster Sieg",
                subtitle: "Noch 20 Minuten",
                systemImage: "clock",
                progressFraction: 0.5,
                progressText: "20 / 40 min",
                actionText: "noch heute",
                isRewardReady: false
            ),
            activeItems: [],
            historyItems: [],
            completedCount: 0,
            unclaimedCount: 0,
            rewardSummary: .empty
        )

        let challengeInput = LibraryView.LibraryHomeInsightBuilder.makeChallengeInput(from: dashboard)
        let snapshot = LibraryView.LibraryHomeInsightBuilder.makeSnapshot(challenge: challengeInput)

        #expect(snapshot.items.first?.kind == .challenge)
        #expect(snapshot.items.first?.title == "Nächster Sieg")
        #expect(snapshot.items.first?.value == "20 / 40 min")
        #expect(snapshot.items.first?.caption == "noch heute")
        #expect(snapshot.items.first?.progressFraction == 0.5)
    }

    @Test func maxItemsLimitsInsightOutput() {
        let progress = LibraryView.LibraryHomeInsightProgressInput(
            year: 2026,
            finishedThisYear: 18,
            goalTarget: 30,
            minutesLast7: 145,
            activeDaysLast7: 4,
            currentStreak: 3
        )
        let challenge = LibraryView.LibraryHomeInsightChallengeInput(
            readyToClaimCount: 1,
            title: "Belohnung wartet",
            value: "1",
            caption: "Challenge bereit",
            systemImage: "sparkles",
            progressFraction: 1,
            isRewardReady: true
        )

        let snapshot = LibraryView.LibraryHomeInsightBuilder.makeSnapshot(
            progress: progress,
            challenge: challenge,
            maxItems: 2
        )

        #expect(snapshot.items.map(\.kind) == [.challenge, .yearGoal])
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
    }
}

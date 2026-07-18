import Foundation
import Testing
@testable import Shelf_Notes

struct ChallengeSessionImpactBuilderTests {
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
        kind: ChallengeKind = .weekly,
        metric: ChallengeMetric,
        targetValue: Int,
        start: Date,
        end: Date
    ) -> ChallengeRecord {
        let record = ChallengeRecord(
            kind: kind,
            metric: metric,
            periodStart: start,
            periodEnd: end,
            title: "Test Challenge",
            detail: "Test detail",
            targetValue: targetValue
        )
        record.id = id
        return record
    }

    @Test @MainActor func savedSessionImpactMarksChallengeCompletion() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000701") ?? UUID()
        let start = date(2026, 6, 1)
        let end = date(2026, 6, 8)
        let challenge = makeChallenge(id: id, metric: .readingMinutes, targetValue: 60, start: start, end: end)
        let contribution = ChallengeSessionContribution(
            bookID: UUID(),
            startedAt: date(2026, 6, 3, 10),
            endedAt: date(2026, 6, 3, 10).addingTimeInterval(20 * 60),
            durationSeconds: 20 * 60,
            pagesRead: nil,
            didMarkBookFinished: false
        )

        let impact = ChallengeSessionImpactBuilder.makeSavedSessionImpact(
            challenges: [challenge],
            progressAfterByID: [id: ChallengeEngine.ChallengeProgress(value: 65, unitSuffix: "min")],
            contribution: contribution,
            now: date(2026, 6, 3)
        )

        #expect(impact?.title == "Challenge geknackt")
        #expect(impact?.entries.first?.didComplete == true)
        #expect(impact?.entries.first?.contributionText == "+20 min")
        #expect(impact?.entries.first?.progressText == "65/60 min")
    }

    @Test @MainActor func pendingSessionImpactProjectsPagesForward() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000702") ?? UUID()
        let start = date(2026, 6, 1)
        let end = date(2026, 6, 8)
        let challenge = makeChallenge(id: id, metric: .pagesRead, targetValue: 100, start: start, end: end)
        let contribution = ChallengeSessionContribution(
            bookID: UUID(),
            startedAt: date(2026, 6, 3, 10),
            endedAt: date(2026, 6, 3, 10).addingTimeInterval(25 * 60),
            durationSeconds: 25 * 60,
            pagesRead: 30,
            didMarkBookFinished: false
        )

        let impact = ChallengeSessionImpactBuilder.makePendingSessionImpact(
            challenges: [challenge],
            progressBeforeByID: [id: ChallengeEngine.ChallengeProgress(value: 40, unitSuffix: "Seiten")],
            contribution: contribution,
            now: date(2026, 6, 3)
        )

        #expect(impact?.title == "Session zählt für Challenges")
        #expect(impact?.entries.first?.contributionText == "+30 Seiten")
        #expect(impact?.entries.first?.progressText == "70/100 Seiten")
        #expect(impact?.entries.first?.didComplete == false)
    }

    @Test @MainActor func finishedBookContributionCanCompleteBookChallenge() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000703") ?? UUID()
        let start = date(2026, 6, 1)
        let end = date(2026, 7, 1)
        let challenge = makeChallenge(id: id, kind: .monthly, metric: .booksFinished, targetValue: 1, start: start, end: end)
        let contribution = ChallengeSessionContribution(
            bookID: UUID(),
            startedAt: date(2026, 6, 10, 9),
            endedAt: date(2026, 6, 10, 9).addingTimeInterval(15 * 60),
            durationSeconds: 15 * 60,
            pagesRead: 12,
            didMarkBookFinished: true
        )

        let impact = ChallengeSessionImpactBuilder.makePendingSessionImpact(
            challenges: [challenge],
            progressBeforeByID: [id: ChallengeEngine.ChallengeProgress(value: 0, unitSuffix: "Abschlüsse")],
            contribution: contribution,
            now: date(2026, 6, 10)
        )

        #expect(impact?.entries.first?.contributionText == "+1 Abschlüsse")
        #expect(impact?.entries.first?.didComplete == true)
    }

    @Test @MainActor func dailyImpactIsPrioritizedWhenFastToFinish() {
        let dailyID = UUID(uuidString: "00000000-0000-0000-0000-000000000704") ?? UUID()
        let weeklyID = UUID(uuidString: "00000000-0000-0000-0000-000000000705") ?? UUID()
        let daily = makeChallenge(
            id: dailyID,
            kind: .daily,
            metric: .readingMinutes,
            targetValue: 50,
            start: date(2026, 6, 3, 0),
            end: date(2026, 6, 4, 0)
        )
        let weekly = makeChallenge(
            id: weeklyID,
            kind: .weekly,
            metric: .readingMinutes,
            targetValue: 100,
            start: date(2026, 6, 1, 0),
            end: date(2026, 6, 8, 0)
        )
        let contribution = ChallengeSessionContribution(
            bookID: UUID(),
            startedAt: date(2026, 6, 3, 10),
            endedAt: date(2026, 6, 3, 10).addingTimeInterval(10 * 60),
            durationSeconds: 10 * 60,
            pagesRead: nil,
            didMarkBookFinished: false
        )

        let impact = ChallengeSessionImpactBuilder.makeSavedSessionImpact(
            challenges: [weekly, daily],
            progressAfterByID: [
                dailyID: ChallengeEngine.ChallengeProgress(value: 45, unitSuffix: "min"),
                weeklyID: ChallengeEngine.ChallengeProgress(value: 95, unitSuffix: "min")
            ],
            contribution: contribution,
            now: date(2026, 6, 3)
        )

        #expect(impact?.title == "Zählt auf deine Tagesmission")
        #expect(impact?.entries.first?.kind == .daily)
    }

    @Test @MainActor func completedDailyImpactGetsDailyTitle() {
        let dailyID = UUID(uuidString: "00000000-0000-0000-0000-000000000706") ?? UUID()
        let daily = makeChallenge(
            id: dailyID,
            kind: .daily,
            metric: .readingMinutes,
            targetValue: 30,
            start: date(2026, 6, 3, 0),
            end: date(2026, 6, 4, 0)
        )
        let contribution = ChallengeSessionContribution(
            bookID: UUID(),
            startedAt: date(2026, 6, 3, 10),
            endedAt: date(2026, 6, 3, 10).addingTimeInterval(10 * 60),
            durationSeconds: 10 * 60,
            pagesRead: nil,
            didMarkBookFinished: false
        )

        let impact = ChallengeSessionImpactBuilder.makeSavedSessionImpact(
            challenges: [daily],
            progressAfterByID: [dailyID: ChallengeEngine.ChallengeProgress(value: 35, unitSuffix: "min")],
            contribution: contribution,
            now: date(2026, 6, 3)
        )

        #expect(impact?.title == "Tagesmission geknackt")
        #expect(impact?.entries.first?.didComplete == true)
    }

    @Test func percentageContributionCountsBookProgressButNotPages() {
        let now = date(2026, 6, 3, 10)
        let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000707") ?? UUID()
        let progressID = UUID(uuidString: "00000000-0000-0000-0000-000000000708") ?? UUID()
        let snapshots = [
            ChallengeEngine.ChallengeRecordSnapshot(
                id: pageID,
                kind: .weekly,
                metric: .pagesRead,
                periodStart: date(2026, 6, 1, 0),
                periodEnd: date(2026, 6, 8, 0),
                targetValue: 100,
                completedAt: nil,
                title: "Seiten"
            ),
            ChallengeEngine.ChallengeRecordSnapshot(
                id: progressID,
                kind: .weekly,
                metric: .booksProgressed,
                periodStart: date(2026, 6, 1, 0),
                periodEnd: date(2026, 6, 8, 0),
                targetValue: 3,
                completedAt: nil,
                title: "Bücher bewegt"
            )
        ]
        let contribution = ChallengeSessionContribution(
            bookID: UUID(),
            startedAt: now,
            endedAt: now.addingTimeInterval(15 * 60),
            durationSeconds: 15 * 60,
            pagesRead: nil,
            didMarkBookFinished: false,
            progressUnit: .percentage,
            origin: .quickLog,
            startValue: 20,
            endValue: 40,
            startNormalizedProgress: 0.2,
            endNormalizedProgress: 0.4
        )

        let impact = ChallengeSessionImpactBuilder.makePendingSessionImpact(
            challengeSnapshots: snapshots,
            progressBeforeByID: [
                pageID: ChallengeEngine.ChallengeProgress(value: 20, unitSuffix: "Seiten"),
                progressID: ChallengeEngine.ChallengeProgress(value: 1, unitSuffix: "Bücher")
            ],
            contribution: contribution,
            now: now
        )

        #expect(impact?.entries.map(\.metric) == [.booksProgressed])
        #expect(impact?.entries.first?.contributionText == "+1 Bücher")
    }

    @Test func providerImportContributionHasNoSessionMetricImpact() {
        let now = date(2026, 6, 3, 10)
        let snapshots = [
            ChallengeMetric.readingMinutes,
            .sessions,
            .readingDays,
            .booksProgressed
        ].enumerated().map { index, metric in
            ChallengeEngine.ChallengeRecordSnapshot(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 800 + index)) ?? UUID(),
                kind: .weekly,
                metric: metric,
                periodStart: date(2026, 6, 1, 0),
                periodEnd: date(2026, 6, 8, 0),
                targetValue: 10,
                completedAt: nil,
                title: metric.rawValue
            )
        }
        let progressBefore = Dictionary(uniqueKeysWithValues: snapshots.map { snapshot in
            (snapshot.id, ChallengeEngine.ChallengeProgress(value: 0, unitSuffix: snapshot.metric.unitSuffix))
        })
        let contribution = ChallengeSessionContribution(
            bookID: UUID(),
            startedAt: now,
            endedAt: now.addingTimeInterval(30 * 60),
            durationSeconds: 30 * 60,
            pagesRead: nil,
            didMarkBookFinished: false,
            progressUnit: .percentage,
            origin: .providerImport,
            startNormalizedProgress: 0.2,
            endNormalizedProgress: 0.4
        )

        let impact = ChallengeSessionImpactBuilder.makePendingSessionImpact(
            challengeSnapshots: snapshots,
            progressBeforeByID: progressBefore,
            contribution: contribution,
            now: now
        )

        #expect(impact?.entries.map(\.metric) == [.booksProgressed])
    }
}

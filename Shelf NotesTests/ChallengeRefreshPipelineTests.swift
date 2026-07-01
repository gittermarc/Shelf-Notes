import Foundation
import Testing
@testable import Shelf_Notes

struct ChallengeRefreshPipelineTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    private func period(_ start: Date, _ end: Date) -> ChallengeEngine.PeriodBounds {
        ChallengeEngine.PeriodBounds(start: start, end: end)
    }

    private func challenge(
        id: String,
        kind: ChallengeKind,
        metric: ChallengeMetric,
        start: Date,
        end: Date,
        target: Int,
        completedAt: Date? = nil,
        title: String? = nil
    ) -> ChallengeEngine.ChallengeRecordSnapshot {
        ChallengeEngine.ChallengeRecordSnapshot(
            id: UUID(uuidString: id) ?? UUID(),
            kind: kind,
            metric: metric,
            periodStart: start,
            periodEnd: end,
            targetValue: target,
            completedAt: completedAt,
            title: title ?? kind.displayName,
            detail: "Test"
        )
    }

    @Test func snapshotRangeCoversDailyWeeklyMonthlyAndYearlyWindows() {
        let now = date(2026, 6, 3)
        let daily = period(date(2026, 6, 3, 0), date(2026, 6, 4, 0))
        let weekly = period(date(2026, 6, 1, 0), date(2026, 6, 8, 0))
        let monthly = period(date(2026, 6, 1, 0), date(2026, 7, 1, 0))
        let yearly = period(date(2026, 1, 1, 0), date(2027, 1, 1, 0))
        let inputs = [
            ChallengeEngine.EnsureCadenceInput(kind: .daily, period: daily, existing: nil),
            ChallengeEngine.EnsureCadenceInput(kind: .weekly, period: weekly, existing: nil),
            ChallengeEngine.EnsureCadenceInput(kind: .monthly, period: monthly, existing: nil),
            ChallengeEngine.EnsureCadenceInput(kind: .yearly, period: yearly, existing: nil)
        ]

        let range = ChallengeRefreshPipeline.snapshotRange(
            cadenceInputs: inputs,
            activeSnapshots: [],
            now: now,
            calendar: calendar
        )

        #expect(range?.lowerBound == date(2025, 1, 1, 0))
        #expect(range?.upperBound == date(2027, 1, 1, 0))
    }

    @Test func progressMapMatchesDirectComputationForMultipleKinds() async {
        let fixture = makeInputFixture()

        let output = await Task.detached(priority: .utility) {
            ChallengeRefreshPipeline.makeOutput(input: fixture.input)
        }.value
        let expected = Dictionary(uniqueKeysWithValues: fixture.input.visibleProgressSnapshots.map { challenge in
            let progress = ChallengeEngine.computeProgress(
                metric: challenge.metric,
                window: challenge.periodStart..<challenge.periodEnd,
                snapshot: fixture.input.snapshot
            )
            return (challenge.id, progress)
        })

        #expect(output.progressByID == expected)
        #expect(output.progressByID[fixture.dailyID]?.value == 30)
        #expect(output.progressByID[fixture.weeklyID]?.value == 1)
        #expect(output.progressByID[fixture.monthlyID]?.value == 20)
        #expect(output.progressByID[fixture.yearlyID]?.value == 1)
    }

    @Test func completionPlansAreCreatedWhenTargetsAreReached() {
        let fixture = makeInputFixture()
        let output = ChallengeRefreshPipeline.makeOutput(input: fixture.input)

        let completedIDs = Set(output.completionPlans.map(\.challengeID))

        #expect(completedIDs == Set([fixture.dailyID, fixture.weeklyID, fixture.monthlyID, fixture.yearlyID]))
        #expect(output.completionPlans.allSatisfy { $0.completedAt == fixture.now })
    }

    @Test func savedSessionImpactMatchesValueSnapshotBuilder() {
        let fixture = makeInputFixture()
        let output = ChallengeRefreshPipeline.makeOutput(input: fixture.input)
        let contribution = ChallengeSessionContribution(
            bookID: fixture.bookID,
            startedAt: date(2026, 6, 3, 10, 0),
            endedAt: date(2026, 6, 3, 10, 30),
            durationSeconds: 30 * 60,
            pagesRead: 20,
            didMarkBookFinished: true,
            hasNote: true
        )
        let expected = ChallengeSessionImpactBuilder.makeSavedSessionImpact(
            challengeSnapshots: fixture.input.visibleProgressSnapshots,
            progressAfterByID: output.progressByID,
            contribution: contribution,
            now: fixture.now
        )

        #expect(output.savedSessionImpacts.count == 1)
        #expect(output.savedSessionImpacts.first?.title == expected?.title)
        #expect(output.savedSessionImpacts.first?.subtitle == expected?.subtitle)
        #expect(output.savedSessionImpacts.first?.entries.map(\.id) == expected?.entries.map(\.id))
    }

    @Test func ensuredChallengesAreIncludedInProgressSnapshots() {
        let now = date(2026, 6, 3)
        let daily = period(date(2026, 6, 3, 0), date(2026, 6, 4, 0))
        let snapshot = ChallengeEngine.Snapshot(
            sessions: [
                ChallengeEngine.SessionSnapshot(
                    bookID: UUID(uuidString: "00000000-0000-0000-0000-000000006001") ?? UUID(),
                    startedAt: date(2026, 6, 3, 9, 0),
                    endedAt: date(2026, 6, 3, 9, 20),
                    durationSeconds: 20 * 60,
                    pagesRead: 8,
                    hasNote: false
                )
            ],
            finishedBooks: []
        )
        let input = ChallengeRefreshPipeline.Input(
            now: now,
            cadenceInputs: [ChallengeEngine.EnsureCadenceInput(kind: .daily, period: daily, existing: nil)],
            completionSnapshots: [],
            visibleProgressSnapshots: [],
            snapshot: snapshot,
            savedSessionPayloads: []
        )

        let output = ChallengeRefreshPipeline.makeOutput(input: input)
        let firstPlanID = output.ensurePlans.first?.id

        #expect(output.ensurePlans.count == 1)
        #expect(output.progressSnapshots.map(\.id) == output.ensurePlans.map(\.id))
        #expect(firstPlanID != nil)
        if let firstPlanID {
            #expect(output.progressByID[firstPlanID] != nil)
        }
    }

    @Test func emptyInputProducesEmptyOutput() {
        let now = date(2026, 6, 3)
        let input = ChallengeRefreshPipeline.Input(
            now: now,
            cadenceInputs: [],
            completionSnapshots: [],
            visibleProgressSnapshots: [],
            snapshot: ChallengeEngine.Snapshot(sessions: [], finishedBookReadTo: []),
            savedSessionPayloads: []
        )

        let output = ChallengeRefreshPipeline.makeOutput(input: input)

        #expect(output.ensurePlans.isEmpty)
        #expect(output.completionPlans.isEmpty)
        #expect(output.progressByID.isEmpty)
        #expect(output.savedSessionImpacts.isEmpty)
    }

    private struct InputFixture {
        let now: Date
        let bookID: UUID
        let dailyID: UUID
        let weeklyID: UUID
        let monthlyID: UUID
        let yearlyID: UUID
        let input: ChallengeRefreshPipeline.Input
    }

    private func makeInputFixture() -> InputFixture {
        let now = date(2026, 6, 3)
        let bookID = UUID(uuidString: "00000000-0000-0000-0000-000000006001") ?? UUID()
        let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000006002") ?? UUID()
        let dailyID = UUID(uuidString: "00000000-0000-0000-0000-000000006101") ?? UUID()
        let weeklyID = UUID(uuidString: "00000000-0000-0000-0000-000000006102") ?? UUID()
        let monthlyID = UUID(uuidString: "00000000-0000-0000-0000-000000006103") ?? UUID()
        let yearlyID = UUID(uuidString: "00000000-0000-0000-0000-000000006104") ?? UUID()

        let daily = date(2026, 6, 3, 0)..<date(2026, 6, 4, 0)
        let weekly = date(2026, 6, 1, 0)..<date(2026, 6, 8, 0)
        let monthly = date(2026, 6, 1, 0)..<date(2026, 7, 1, 0)
        let yearly = date(2026, 1, 1, 0)..<date(2027, 1, 1, 0)
        let challengeSnapshots = [
            challenge(
                id: dailyID.uuidString,
                kind: .daily,
                metric: .readingMinutes,
                start: daily.lowerBound,
                end: daily.upperBound,
                target: 30,
                title: "Daily Test"
            ),
            challenge(
                id: weeklyID.uuidString,
                kind: .weekly,
                metric: .sessions,
                start: weekly.lowerBound,
                end: weekly.upperBound,
                target: 1,
                title: "Weekly Test"
            ),
            challenge(
                id: monthlyID.uuidString,
                kind: .monthly,
                metric: .pagesRead,
                start: monthly.lowerBound,
                end: monthly.upperBound,
                target: 20,
                title: "Monthly Test"
            ),
            challenge(
                id: yearlyID.uuidString,
                kind: .yearly,
                metric: .booksFinished,
                start: yearly.lowerBound,
                end: yearly.upperBound,
                target: 1,
                title: "Yearly Test"
            )
        ]
        let snapshot = ChallengeEngine.Snapshot(
            sessions: [
                ChallengeEngine.SessionSnapshot(
                    bookID: bookID,
                    startedAt: date(2026, 6, 3, 10, 0),
                    endedAt: date(2026, 6, 3, 10, 30),
                    durationSeconds: 30 * 60,
                    pagesRead: 20,
                    hasNote: true
                )
            ],
            finishedBooks: [
                ChallengeEngine.FinishedBookSnapshot(bookID: bookID, readTo: date(2026, 6, 3, 10, 30))
            ]
        )
        let sessionSnapshot = SavedReadingSessionSnapshot(
            id: sessionID,
            bookID: bookID,
            startedAt: date(2026, 6, 3, 10, 0),
            endedAt: date(2026, 6, 3, 10, 30),
            durationSeconds: 30 * 60,
            pagesRead: 20,
            note: "  Starkes Kapitel  "
        )
        let payload = ChallengeSessionMutationPayload.saved(
            sessionSnapshot: sessionSnapshot,
            didMarkBookFinished: true
        )
        let input = ChallengeRefreshPipeline.Input(
            now: now,
            cadenceInputs: [],
            completionSnapshots: challengeSnapshots,
            visibleProgressSnapshots: challengeSnapshots,
            snapshot: snapshot,
            savedSessionPayloads: [payload]
        )

        return InputFixture(
            now: now,
            bookID: bookID,
            dailyID: dailyID,
            weeklyID: weeklyID,
            monthlyID: monthlyID,
            yearlyID: yearlyID,
            input: input
        )
    }
}

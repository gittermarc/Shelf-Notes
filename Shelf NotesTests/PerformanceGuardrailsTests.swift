import Foundation
import Testing
@testable import Shelf_Notes

struct PerformanceGuardrailsTests {
    @Test @MainActor func largeTimelineFixtureKeepsRereadsAndYearsDeterministic() async {
        let fixture = LargeReadingDatasetBuilder.make300BookTimelineDataset()

        #expect(fixture.books.count == 300)
        #expect(fixture.sessions.count == 500)
        #expect(fixture.expectedCompletionCount == 280)
        #expect(fixture.expectedRereadCompletionCount == 60)
        #expect(fixture.expectedTimelineYears == [2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026])

        let displayStore = ReadingTimelineDisplayStore()
        await displayStore.refreshSnapshots(ReadingTimelineBookSnapshot.snapshots(from: fixture.books))

        let completionEntries = displayStore.displayState.items.compactMap { item -> ReadingTimelineEntryDisplayItem? in
            if case .completion(let entry) = item.kind {
                return entry
            }
            return nil
        }
        let statsByYear = Dictionary(uniqueKeysWithValues: displayStore.displayState.items.compactMap { item -> (Int, ReadingTimelineYearDisplayStats)? in
            if case .year(let year, let stats) = item.kind {
                return (year, stats)
            }
            return nil
        })

        #expect(displayStore.years == [2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026])
        #expect(completionEntries.count == 280)
        #expect(completionEntries.filter { $0.completion.isReread }.count == 60)
        #expect(displayStore.displayState.completionCount == 280)
        #expect(displayStore.displayState.rereadCompletionCount == 60)
        #expect(statsByYear[2017]?.count == 60)
        #expect(statsByYear[2017]?.uniqueBookCount == 30)
        #expect(statsByYear[2017]?.rereadCount == 30)
        #expect(statsByYear[2026]?.count == 20)
        #expect(statsByYear[2026]?.uniqueBookCount == 20)
        #expect(statsByYear[2026]?.rereadCount == 0)
    }

    @Test @MainActor func largeChallengeFixtureComputesDeterministicProgress() {
        let fixture = LargeReadingDatasetBuilder.make1000BookMixedDataset()
        let snapshot = fixture.challengeSnapshot
        let progressByMetric = Dictionary(uniqueKeysWithValues: fixture.activeChallengeSnapshots.map { challenge in
            let progress = ChallengeEngine.computeProgress(
                metric: challenge.metric,
                window: challenge.periodStart..<challenge.periodEnd,
                snapshot: snapshot
            )
            return (challenge.metric, progress)
        })

        #expect(fixture.books.count == 1000)
        #expect(fixture.sessions.count == 500)
        #expect(fixture.challenges.count == 8)
        #expect(fixture.activeChallengeSnapshots.count == 4)
        #expect(fixture.expectedCompletionCount == 934)
        #expect(fixture.expectedRereadCompletionCount == 200)
        #expect(progressByMetric[.readingMinutes]?.value == 300)
        #expect(progressByMetric[.readingMinutes]?.unitSuffix == "min")
        #expect(progressByMetric[.sessions]?.value == 48)
        #expect(progressByMetric[.sessions]?.unitSuffix == "Sessions")
        #expect(progressByMetric[.pagesRead]?.value == 3683)
        #expect(progressByMetric[.pagesRead]?.unitSuffix == "Seiten")
        #expect(progressByMetric[.booksFinished]?.value == 67)
        #expect(progressByMetric[.booksFinished]?.unitSuffix == "Abschlüsse")
    }
}
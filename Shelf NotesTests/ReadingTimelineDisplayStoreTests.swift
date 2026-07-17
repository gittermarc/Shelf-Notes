import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingTimelineDisplayStoreTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    @Test @MainActor func sameSourceSignatureDoesNotRebuild() async {
        let store = ReadingTimelineDisplayStore()
        let snapshots = [bookSnapshot(
            id: fixedUUID(1),
            title: "Stable",
            userRatingAverage: 4.0,
            completions: [completion(bookID: fixedUUID(1), sequenceNumber: 1, finishedAt: date(2024, 1, 3))]
        )]

        await store.refreshSnapshots(snapshots)
        let firstBuildCount = store.completedBuildCount
        await store.refreshSnapshots(snapshots)

        #expect(firstBuildCount == 1)
        #expect(store.completedBuildCount == 1)
        #expect(store.displayState.completionCount == 1)
    }

    @Test @MainActor func changedFinishedAtRebuildsTimeline() async {
        let store = ReadingTimelineDisplayStore()
        let bookID = fixedUUID(2)
        let firstSnapshots = [bookSnapshot(
            id: bookID,
            title: "Moved Finish",
            completions: [completion(bookID: bookID, sequenceNumber: 1, finishedAt: date(2024, 12, 30))]
        )]
        let changedSnapshots = [bookSnapshot(
            id: bookID,
            title: "Moved Finish",
            completions: [completion(bookID: bookID, sequenceNumber: 1, finishedAt: date(2025, 1, 2))]
        )]

        await store.refreshSnapshots(firstSnapshots)
        await store.refreshSnapshots(changedSnapshots)

        #expect(store.completedBuildCount == 2)
        #expect(store.years == [2025])
        #expect(completionItems(from: store.displayState).map(\.date) == [date(2025, 1, 2)])
    }

    @Test @MainActor func changedRatingUpdatesYearStats() async {
        let store = ReadingTimelineDisplayStore()
        let bookID = fixedUUID(3)
        let firstSnapshots = [bookSnapshot(
            id: bookID,
            title: "Rated",
            userRatingAverage: 3.0,
            completions: [completion(bookID: bookID, sequenceNumber: 1, finishedAt: date(2024, 4, 8))]
        )]
        let changedSnapshots = [bookSnapshot(
            id: bookID,
            title: "Rated",
            userRatingAverage: 4.5,
            completions: [completion(bookID: bookID, sequenceNumber: 1, finishedAt: date(2024, 4, 8))]
        )]

        await store.refreshSnapshots(firstSnapshots)
        #expect(yearStats(from: store.displayState)[2024]?.averageRatingText == "3.0")

        await store.refreshSnapshots(changedSnapshots)

        #expect(store.completedBuildCount == 2)
        #expect(yearStats(from: store.displayState)[2024]?.averageRatingText == "4.5")
    }

    @Test @MainActor func changedCompletionSourceRebuildsVisibleTimelinePresentation() async {
        let store = ReadingTimelineDisplayStore()
        let bookID = fixedUUID(35)
        let physical = [bookSnapshot(
            id: bookID,
            title: "Source",
            completions: [completion(
                bookID: bookID,
                sequenceNumber: 1,
                finishedAt: date(2024, 4, 8),
                medium: .physical,
                provider: .none,
                progressUnit: .pages
            )]
        )]
        let kindle = [bookSnapshot(
            id: bookID,
            title: "Source",
            completions: [completion(
                bookID: bookID,
                sequenceNumber: 1,
                finishedAt: date(2024, 4, 8),
                medium: .ebook,
                provider: .kindle,
                progressUnit: .percentage
            )]
        )]

        await store.refreshSnapshots(physical)
        #expect(completionItems(from: store.displayState).first?.sourceLabel == "Physisches Buch")
        await store.refreshSnapshots(kindle)

        #expect(store.completedBuildCount == 2)
        #expect(completionItems(from: store.displayState).first?.sourceLabel == "Kindle")
    }

    @Test @MainActor func markerPositionChangesDoNotRebuildDisplayStore() async {
        let store = ReadingTimelineDisplayStore()
        let bookID = fixedUUID(4)
        await store.refreshSnapshots([bookSnapshot(
            id: bookID,
            title: "Marker",
            completions: [completion(bookID: bookID, sequenceNumber: 1, finishedAt: date(2024, 7, 1))]
        )])
        let buildCount = store.completedBuildCount
        let viewModel = ReadingTimelineViewModel()

        viewModel.updateViewportWidth(320)
        viewModel.updateYearMarkerPositions([2024: 160])
        viewModel.updateYearMarkerPositions([2024: 160.25])
        viewModel.updateYearMarkerPositions([2024: 180])

        #expect(viewModel.selectedYear == 2024)
        #expect(store.completedBuildCount == buildCount)
    }
}

private extension ReadingTimelineDisplayStoreTests {
    func bookSnapshot(
        id: UUID,
        title: String,
        author: String = "Fixture Author",
        createdAt: Date? = nil,
        statusRawValue: String = ReadingStatus.finished.rawValue,
        readFrom: Date? = nil,
        readTo: Date? = nil,
        pageCount: Int? = 320,
        userRatingAverage: Double? = nil,
        completions: [ReadingTimelineCompletionSnapshot]
    ) -> ReadingTimelineBookSnapshot {
        ReadingTimelineBookSnapshot(
            id: id,
            title: title,
            author: author,
            createdAt: createdAt ?? date(2021, 1, 1),
            statusRawValue: statusRawValue,
            readFrom: readFrom,
            readTo: readTo,
            pageCount: pageCount,
            userRatingAverage: userRatingAverage,
            completions: completions
        )
    }

    func completion(
        bookID: UUID,
        sequenceNumber: Int,
        finishedAt: Date,
        isReread: Bool = false,
        medium: ReadingMedium = .physical,
        provider: ReadingProvider = .none,
        progressUnit: ReadingProgressUnit = .pages,
        title: String = "Fixture Completion",
        author: String = "Fixture Author"
    ) -> ReadingTimelineCompletionSnapshot {
        ReadingTimelineCompletionSnapshot(
            id: "attempt-\(bookID.uuidString)-\(sequenceNumber)",
            bookID: bookID,
            attemptID: fixedUUID(100 + sequenceNumber),
            sequenceNumber: sequenceNumber,
            title: title,
            author: author,
            startedAt: calendar.date(byAdding: .day, value: -7, to: finishedAt),
            finishedAt: finishedAt,
            pageCount: 320,
            mediumRawValue: medium.rawValue,
            providerRawValue: provider.rawValue,
            progressUnitRawValue: progressUnit.rawValue,
            isReread: isReread,
            isLegacyFallback: false
        )
    }

    func completionItems(from state: ReadingTimelineDisplayState) -> [ReadingTimelineEntryDisplayItem] {
        state.items.compactMap { item in
            if case .completion(let completion) = item.kind {
                return completion
            }
            return nil
        }
    }

    func yearStats(from state: ReadingTimelineDisplayState) -> [Int: ReadingTimelineYearDisplayStats] {
        Dictionary(uniqueKeysWithValues: state.items.compactMap { item -> (Int, ReadingTimelineYearDisplayStats)? in
            if case .year(let year, let stats) = item.kind {
                return (year, stats)
            }
            return nil
        })
    }

    func fixedUUID(_ value: Int) -> UUID {
        let suffix = String(format: "%012d", value)
        return UUID(uuidString: "00000000-0000-0000-0000-\(suffix)") ?? UUID()
    }
}

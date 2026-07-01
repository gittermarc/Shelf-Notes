import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingTimelineBuilderTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    @Test func emptySourceBuildsEmptyState() {
        let state = ReadingTimelineBuilder.build(bookSnapshots: [], calendar: calendar)

        #expect(state.years.isEmpty)
        #expect(state.items.isEmpty)
        #expect(state.completionCount == 0)
        #expect(state.rereadCompletionCount == 0)
    }

    @Test func legacyFinishedBookAppearsAsCompletion() throws {
        let bookID = fixedUUID(1)
        let legacy = try #require(ReadingCompletionRecord.legacyRecord(
            bookID: bookID,
            title: "Legacy Book",
            author: "Legacy Author",
            createdAt: date(2022, 1, 1),
            statusRawValue: ReadingStatus.finished.rawValue,
            readFrom: date(2022, 1, 3),
            readTo: date(2022, 1, 12),
            pageCount: 320
        ))
        let snapshot = bookSnapshot(
            id: bookID,
            title: "Legacy Book",
            author: "Legacy Author",
            completions: [ReadingTimelineCompletionSnapshot(record: legacy)]
        )

        let state = ReadingTimelineBuilder.build(bookSnapshots: [snapshot], calendar: calendar)
        let completions = completionItems(from: state)

        #expect(state.years == [2022])
        #expect(state.completionCount == 1)
        #expect(completions.first?.title == "Legacy Book")
        #expect(completions.first?.completion.isLegacyFallback == true)
    }

    @Test func multipleCompletedAttemptsForOneBookKeepRereadStats() {
        let bookID = fixedUUID(2)
        let snapshot = bookSnapshot(
            id: bookID,
            title: "Repeat Book",
            author: "Ada",
            userRatingAverage: 4.0,
            completions: [
                completion(bookID: bookID, sequenceNumber: 1, finishedAt: date(2024, 1, 8), isReread: false),
                completion(bookID: bookID, sequenceNumber: 2, finishedAt: date(2024, 3, 7), isReread: true)
            ]
        )

        let state = ReadingTimelineBuilder.build(bookSnapshots: [snapshot], calendar: calendar)
        let stats = yearStats(from: state)[2024]
        let completions = completionItems(from: state)

        #expect(completions.map(\.attemptLabel) == [nil, "2. Durchgang"])
        #expect(state.completionCount == 2)
        #expect(state.rereadCompletionCount == 1)
        #expect(stats?.count == 2)
        #expect(stats?.uniqueBookCount == 1)
        #expect(stats?.rereadCount == 1)
        #expect(stats?.ratedCount == 2)
        #expect(stats?.averageRatingText == "4.0")
        #expect(stats?.previewBookIDs == [bookID, bookID])
    }

    @Test @MainActor func activeRereadWithoutFinishedDateDoesNotAppear() {
        let book = Book(title: "Active Reread", author: "Ada", status: .reading)
        book.id = fixedUUID(3)
        book.createdAt = date(2023, 1, 1)
        book.pageCount = 280
        book.readFrom = date(2024, 2, 1)

        let first = ReadingAttempt(
            book: book,
            sequenceNumber: 1,
            status: .finished,
            startedAt: date(2023, 5, 1),
            finishedAt: date(2023, 5, 9),
            pageCountSnapshot: 280
        )
        first.id = fixedUUID(31)

        let active = ReadingAttempt(
            book: book,
            sequenceNumber: 2,
            status: .active,
            startedAt: date(2024, 2, 1),
            finishedAt: nil,
            pageCountSnapshot: 280
        )
        active.id = fixedUUID(32)
        book.readingAttempts = [first, active]

        let snapshot = ReadingTimelineBookSnapshot(book: book)
        let state = ReadingTimelineBuilder.build(bookSnapshots: [snapshot], calendar: calendar)
        let completions = completionItems(from: state)

        #expect(state.years == [2023])
        #expect(state.completionCount == 1)
        #expect(completions.map(\.completion.sequenceNumber) == [1])
        #expect(completions.first?.attemptLabel == nil)
    }

    @Test func yearGroupsAreDeterministicallySorted() {
        let book2025 = fixedUUID(41)
        let book2023 = fixedUUID(42)
        let book2024 = fixedUUID(43)
        let snapshots = [
            bookSnapshot(id: book2025, title: "Later", completions: [completion(bookID: book2025, sequenceNumber: 1, finishedAt: date(2025, 1, 1))]),
            bookSnapshot(id: book2023, title: "Earlier", completions: [completion(bookID: book2023, sequenceNumber: 1, finishedAt: date(2023, 1, 1))]),
            bookSnapshot(id: book2024, title: "Middle", completions: [completion(bookID: book2024, sequenceNumber: 1, finishedAt: date(2024, 1, 1))])
        ]

        let state = ReadingTimelineBuilder.build(bookSnapshots: snapshots, calendar: calendar)
        let yearOrder = state.items.compactMap { item -> Int? in
            if case .year(let year, _) = item.kind {
                return year
            }
            return nil
        }
        let completionOrder = completionItems(from: state).map(\.bookID)

        #expect(state.years == [2023, 2024, 2025])
        #expect(yearOrder == [2023, 2024, 2025])
        #expect(completionOrder == [book2023, book2024, book2025])
    }

    @Test @MainActor func largeFixtureWithOneThousandBooksBuildsDeterministicState() {
        let fixture = LargeReadingDatasetBuilder.make1000BookMixedDataset()
        let snapshots = ReadingTimelineBookSnapshot.snapshots(from: fixture.books)
        let state = ReadingTimelineBuilder.build(bookSnapshots: snapshots, calendar: fixture.calendar)
        let statsByYear = yearStats(from: state)

        #expect(snapshots.count == 1000)
        #expect(state.completionCount == fixture.expectedCompletionCount)
        #expect(state.rereadCompletionCount == fixture.expectedRereadCompletionCount)
        #expect(state.years == fixture.expectedTimelineYears)
        #expect(statsByYear[2017]?.count == 200)
        #expect(statsByYear[2017]?.uniqueBookCount == 100)
        #expect(statsByYear[2017]?.rereadCount == 100)
        #expect(statsByYear[2026]?.count == 67)
        #expect(statsByYear[2026]?.uniqueBookCount == 67)
        #expect(statsByYear[2026]?.rereadCount == 0)
    }
}

private extension ReadingTimelineBuilderTests {
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

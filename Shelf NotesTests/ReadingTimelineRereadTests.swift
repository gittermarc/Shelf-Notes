import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingTimelineRereadTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    @Test @MainActor func timelineShowsMultipleCompletedAttemptsForTheSameBook() async {
        let book = Book(title: "Repeat", author: "Ada", status: .reading)
        book.createdAt = date(2025, 1, 1)
        book.pageCount = 300
        book.readFrom = date(2026, 6, 1)

        let first = ReadingAttempt(
            book: book,
            sequenceNumber: 1,
            status: .finished,
            startedAt: date(2026, 1, 1),
            finishedAt: date(2026, 1, 8),
            pageCountSnapshot: 300
        )
        let second = ReadingAttempt(
            book: book,
            sequenceNumber: 2,
            status: .finished,
            startedAt: date(2026, 3, 1),
            finishedAt: date(2026, 3, 7),
            pageCountSnapshot: 300
        )
        let active = ReadingAttempt(
            book: book,
            sequenceNumber: 3,
            status: .active,
            startedAt: date(2026, 6, 1),
            finishedAt: nil,
            pageCountSnapshot: 300
        )
        book.readingAttempts = [first, second, active]

        let displayStore = ReadingTimelineDisplayStore()
        await displayStore.refreshSnapshots(ReadingTimelineBookSnapshot.snapshots(from: [book]))

        let completionEntries = displayStore.displayState.items.compactMap { item -> ReadingTimelineEntryDisplayItem? in
            if case .completion(let entry) = item.kind {
                return entry
            }
            return nil
        }
        let yearStats = displayStore.displayState.items.compactMap { item -> ReadingTimelineYearDisplayStats? in
            if case .year(_, let stats) = item.kind {
                return stats
            }
            return nil
        }.first

        #expect(displayStore.years == [2026])
        #expect(completionEntries.count == 2)
        #expect(completionEntries.map(\.date) == [date(2026, 1, 8), date(2026, 3, 7)])
        #expect(completionEntries.map { $0.attemptLabel } == [nil, "2. Durchgang"])
        #expect(yearStats?.count == 2)
        #expect(yearStats?.uniqueBookCount == 1)
        #expect(yearStats?.rereadCount == 1)
        #expect(displayStore.displayState.completionCount == 2)
        #expect(displayStore.displayState.rereadCompletionCount == 1)
    }
}

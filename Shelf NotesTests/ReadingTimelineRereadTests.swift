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

    @Test @MainActor func timelineShowsMultipleCompletedAttemptsForTheSameBook() {
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

        let viewModel = ReadingTimelineViewModel()
        viewModel.setBooks([book])

        let completionEntries = viewModel.items.compactMap { item -> ReadingTimelineEntry? in
            if case .completion(let entry) = item.kind {
                return entry
            }
            return nil
        }
        let yearStats = viewModel.items.compactMap { item -> ReadingTimelineYearStats? in
            if case .year(_, let stats) = item.kind {
                return stats
            }
            return nil
        }.first

        #expect(viewModel.years == [2026])
        #expect(completionEntries.count == 2)
        #expect(completionEntries.map(\.date) == [date(2026, 1, 8), date(2026, 3, 7)])
        #expect(completionEntries.map { $0.attemptLabel } == [nil, "2. Durchgang"])
        #expect(yearStats?.count == 2)
        #expect(yearStats?.uniqueBookCount == 1)
        #expect(yearStats?.rereadCount == 1)
    }
}

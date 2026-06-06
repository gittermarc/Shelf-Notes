import Foundation
import Testing
@testable import Shelf_Notes

struct GoalsYearMetricsBuilderTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private func makeBook(
        title: String,
        status: ReadingStatus,
        createdAt: Date,
        readFrom: Date? = nil,
        readTo: Date? = nil,
        pageCount: Int? = nil,
        author: String = ""
    ) -> Book {
        let book = Book(title: title, author: author, status: status)
        book.createdAt = createdAt
        book.readFrom = readFrom
        book.readTo = readTo
        book.pageCount = pageCount
        return book
    }

    @Test func yearOptionsIncludeCurrentNextBooksAndGoals() {
        let now = date(2026, 4, 15)
        let books = [
            makeBook(
                title: "Old Finished",
                status: .finished,
                createdAt: date(2024, 1, 1),
                readTo: date(2024, 6, 10)
            )
        ]
        let goals = [ReadingGoal(year: 2028, targetCount: 12)]

        let metrics = GoalsYearMetricsBuilder.make(
            selectedYear: 2026,
            books: books,
            goals: goals,
            now: now,
            calendar: calendar
        )

        #expect(metrics.availableYears == [2028, 2027, 2026, 2024])
    }

    @Test func yearOptionsKeepSelectedYearAvailable() {
        let now = date(2026, 4, 15)

        let metrics = GoalsYearMetricsBuilder.make(
            selectedYear: 2030,
            books: [],
            goals: [],
            now: now,
            calendar: calendar
        )

        #expect(metrics.availableYears == [2030, 2027, 2026])
    }

    @Test func filtersFinishedBooksBySelectedYearUsingReadToOrReadFrom() {
        let now = date(2026, 4, 15)
        let finishedInYear = makeBook(
            title: "In Year",
            status: .finished,
            createdAt: date(2026, 1, 1),
            readFrom: date(2026, 2, 1),
            readTo: nil,
            pageCount: 320
        )
        let finishedOtherYear = makeBook(
            title: "Other Year",
            status: .finished,
            createdAt: date(2025, 1, 1),
            readTo: date(2025, 12, 31),
            pageCount: 280
        )
        let reading = makeBook(
            title: "Reading",
            status: .reading,
            createdAt: date(2026, 3, 1),
            readTo: date(2026, 3, 10),
            pageCount: 200
        )

        let metrics = GoalsYearMetricsBuilder.make(
            selectedYear: 2026,
            books: [finishedOtherYear, reading, finishedInYear],
            goals: [],
            now: now,
            calendar: calendar
        )

        #expect(metrics.finishedBooks.map(\.title) == ["In Year"])
        #expect(metrics.pagesReadInSelectedYear == 320)
    }

    @Test func includesLegacyFinishedStatus() {
        let now = date(2026, 4, 15)
        let legacyFinished = makeBook(
            title: "Legacy",
            status: .toRead,
            createdAt: date(2026, 1, 1),
            readTo: date(2026, 2, 10),
            pageCount: 220
        )
        legacyFinished.statusRawValue = "Gelesen"

        let metrics = GoalsYearMetricsBuilder.make(
            selectedYear: 2026,
            books: [legacyFinished],
            goals: [],
            now: now,
            calendar: calendar
        )

        #expect(metrics.finishedBooks.map(\.title) == ["Legacy"])
        #expect(metrics.pagesReadInSelectedYear == 220)
    }

    @Test @MainActor func metricsInputTokenUsesOnlyGoalRelevantBookFields() {
        let book = makeBook(
            title: "Relevant",
            status: .finished,
            createdAt: date(2026, 1, 1),
            readTo: date(2026, 2, 10),
            pageCount: 220
        )
        let original = GoalsYearMetricsModel.makeInputToken(
            selectedYear: 2026,
            books: [book],
            goals: []
        )

        book.notes = "Ändert für Ziele nichts."
        let notesChanged = GoalsYearMetricsModel.makeInputToken(
            selectedYear: 2026,
            books: [book],
            goals: []
        )

        book.pageCount = 221
        let pageCountChanged = GoalsYearMetricsModel.makeInputToken(
            selectedYear: 2026,
            books: [book],
            goals: []
        )

        #expect(original == notesChanged)
        #expect(original != pageCountChanged)
    }

    @Test func sortsFinishedBooksDeterministicallyByReadDate() {
        let now = date(2026, 4, 15)
        let alpha = makeBook(
            title: "Alpha",
            status: .finished,
            createdAt: date(2026, 1, 2),
            readTo: date(2026, 1, 20),
            pageCount: 100
        )
        let beta = makeBook(
            title: "Beta",
            status: .finished,
            createdAt: date(2026, 1, 1),
            readTo: date(2026, 1, 20),
            pageCount: 120
        )
        let gamma = makeBook(
            title: "Gamma",
            status: .finished,
            createdAt: date(2026, 1, 3),
            readTo: date(2026, 2, 5),
            pageCount: 140
        )

        let metrics = GoalsYearMetricsBuilder.make(
            selectedYear: 2026,
            books: [gamma, alpha, beta],
            goals: [],
            now: now,
            calendar: calendar
        )

        #expect(metrics.finishedBooks.map(\.title) == ["Beta", "Alpha", "Gamma"])
    }

    @Test func computesAveragePagesIgnoringBooksWithoutPageCount() {
        let now = date(2026, 4, 15)
        let books = [
            makeBook(
                title: "Has Pages",
                status: .finished,
                createdAt: date(2026, 1, 1),
                readTo: date(2026, 1, 10),
                pageCount: 300
            ),
            makeBook(
                title: "No Pages",
                status: .finished,
                createdAt: date(2026, 1, 2),
                readTo: date(2026, 2, 10),
                pageCount: nil
            ),
            makeBook(
                title: "Zero Pages",
                status: .finished,
                createdAt: date(2026, 1, 3),
                readTo: date(2026, 3, 10),
                pageCount: 0
            ),
            makeBook(
                title: "Has More Pages",
                status: .finished,
                createdAt: date(2026, 1, 4),
                readTo: date(2026, 4, 10),
                pageCount: 100
            )
        ]

        let metrics = GoalsYearMetricsBuilder.make(
            selectedYear: 2026,
            books: books,
            goals: [],
            now: now,
            calendar: calendar
        )

        #expect(metrics.pagesReadInSelectedYear == 400)
        #expect(metrics.countedBooksWithPagesCount == 2)
        #expect(metrics.averagePagesPerBook == 200)
    }

    @Test func computesPagesPerMonthForPastCurrentAndFutureYears() {
        let now = date(2026, 4, 15)
        let books = [
            makeBook(
                title: "Past",
                status: .finished,
                createdAt: date(2025, 1, 1),
                readTo: date(2025, 6, 10),
                pageCount: 240
            ),
            makeBook(
                title: "Current",
                status: .finished,
                createdAt: date(2026, 1, 1),
                readTo: date(2026, 2, 10),
                pageCount: 240
            ),
            makeBook(
                title: "Future",
                status: .finished,
                createdAt: date(2027, 1, 1),
                readTo: date(2027, 3, 10),
                pageCount: 240
            )
        ]

        let past = GoalsYearMetricsBuilder.make(
            selectedYear: 2025,
            books: books,
            goals: [],
            now: now,
            calendar: calendar
        )
        let current = GoalsYearMetricsBuilder.make(
            selectedYear: 2026,
            books: books,
            goals: [],
            now: now,
            calendar: calendar
        )
        let future = GoalsYearMetricsBuilder.make(
            selectedYear: 2027,
            books: books,
            goals: [],
            now: now,
            calendar: calendar
        )

        #expect(past.monthsCount == 12)
        #expect(past.pagesPerMonth == 20)
        #expect(current.monthsCount == 4)
        #expect(current.pagesPerMonth == 60)
        #expect(future.monthsCount == 12)
        #expect(future.pagesPerMonth == 20)
    }

    @Test func returnsRobustDefaultsForEmptyData() {
        let now = date(2026, 4, 15)

        let metrics = GoalsYearMetricsBuilder.make(
            selectedYear: 2026,
            books: [],
            goals: [],
            now: now,
            calendar: calendar
        )

        #expect(metrics.availableYears == [2027, 2026])
        #expect(metrics.finishedBooks.isEmpty)
        #expect(metrics.pagesReadInSelectedYear == 0)
        #expect(metrics.countedBooksWithPagesCount == 0)
        #expect(metrics.averagePagesPerBook == nil)
        #expect(metrics.monthsCount == 4)
        #expect(metrics.pagesPerMonth == 0)
    }

    @Test @MainActor func rereadAttemptsCountAsGoalCompletionsWithoutDuplicatingUniqueBooks() {
        let now = date(2026, 6, 15)
        let book = makeBook(
            title: "Repeat",
            status: .reading,
            createdAt: date(2025, 1, 1),
            readFrom: date(2026, 5, 1),
            readTo: nil,
            pageCount: 300,
            author: "Ada"
        )
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

        let metrics = GoalsYearMetricsBuilder.make(
            selectedYear: 2026,
            books: [book],
            goals: [],
            now: now,
            calendar: calendar
        )

        #expect(metrics.finishedCompletionCount == 2)
        #expect(metrics.finishedBooks.map(\.title) == ["Repeat", "Repeat"])
        #expect(metrics.uniqueFinishedBooksCount == 1)
        #expect(metrics.rereadCompletionCount == 1)
        #expect(metrics.pagesReadInSelectedYear == 600)
        #expect(metrics.countedBooksWithPagesCount == 2)
        #expect(metrics.averagePagesPerBook == 300)
    }


    @Test @MainActor func activeRereadWithLegacyReadToKeepsPreviousGoalCompletion() {
        let now = date(2026, 6, 15)
        let book = makeBook(
            title: "Legacy Repeat",
            status: .reading,
            createdAt: date(2025, 1, 1),
            readFrom: date(2026, 1, 1),
            readTo: date(2026, 1, 8),
            pageCount: 280,
            author: "Ada"
        )
        let active = ReadingAttempt(
            book: book,
            sequenceNumber: 2,
            status: .active,
            startedAt: date(2026, 6, 1),
            finishedAt: nil,
            pageCountSnapshot: 280
        )
        book.readingAttempts = [active]

        let metrics = GoalsYearMetricsBuilder.make(
            selectedYear: 2026,
            books: [book],
            goals: [],
            now: now,
            calendar: calendar
        )

        #expect(metrics.finishedCompletionCount == 1)
        #expect(metrics.finishedBooks.map(\.title) == ["Legacy Repeat"])
        #expect(metrics.uniqueFinishedBooksCount == 1)
        #expect(metrics.rereadCompletionCount == 0)
        #expect(metrics.pagesReadInSelectedYear == 280)
    }

}

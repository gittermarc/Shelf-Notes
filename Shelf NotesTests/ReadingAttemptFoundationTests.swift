import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingAttemptFoundationTests {

    @Test @MainActor func finishedBookBackfillCreatesSingleCompletedAttemptAndAssignsSessions() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 2_000)
        let book = Book(title: "Dune", status: .finished)
        book.pageCount = 412
        book.readFrom = start
        book.readTo = end

        let session = ReadingSession(
            book: book,
            startedAt: Date(timeIntervalSince1970: 1_100),
            endedAt: Date(timeIntervalSince1970: 1_200),
            pagesRead: 42,
            note: nil
        )
        book.readingSessionsSafe = [session]

        let didChange = ReadingAttemptRepair.repair(books: [book], now: end)

        #expect(didChange)
        #expect(book.completedReadingAttemptCount == 1)
        #expect(book.activeReadingAttempt == nil)

        let attempt = try #require(book.completedReadingAttempts.first)
        #expect(attempt.sequenceNumber == 1)
        #expect(attempt.status == .finished)
        #expect(attempt.startedAt == start)
        #expect(attempt.finishedAt == end)
        #expect(attempt.pageCountSnapshot == 412)
        #expect(session.readingAttempt?.id == attempt.id)
        #expect(attempt.sessionsSafe.map(\.id).contains(session.id))
    }

    @Test @MainActor func repairIsIdempotentForBackfilledFinishedBook() {
        let start = Date(timeIntervalSince1970: 3_000)
        let end = Date(timeIntervalSince1970: 4_000)
        let book = Book(title: "Hyperion", status: .finished)
        book.readFrom = start
        book.readTo = end

        let firstRunChanged = ReadingAttemptRepair.repair(books: [book], now: end)
        let attemptIDsAfterFirstRun = book.orderedReadingAttempts.map(\.id)
        let secondRunChanged = ReadingAttemptRepair.repair(books: [book], now: end)
        let attemptIDsAfterSecondRun = book.orderedReadingAttempts.map(\.id)

        #expect(firstRunChanged)
        #expect(secondRunChanged == false)
        #expect(attemptIDsAfterFirstRun == attemptIDsAfterSecondRun)
        #expect(book.orderedReadingAttempts.count == 1)
    }

    @Test @MainActor func readingBookBackfillCreatesActiveAttempt() throws {
        let now = Date(timeIntervalSince1970: 5_000)
        let sessionStart = Date(timeIntervalSince1970: 4_500)
        let book = Book(title: "The Expanse", status: .reading)
        book.pageCount = 560
        book.readingSessionsSafe = [
            ReadingSession(
                book: book,
                startedAt: sessionStart,
                endedAt: Date(timeIntervalSince1970: 4_600),
                pagesRead: 20,
                note: nil
            )
        ]

        let didChange = ReadingAttemptRepair.repair(books: [book], now: now)

        #expect(didChange)
        let attempt = try #require(book.activeReadingAttempt)
        #expect(attempt.sequenceNumber == 1)
        #expect(attempt.status == .active)
        #expect(attempt.startedAt == sessionStart)
        #expect(attempt.finishedAt == nil)
        #expect(attempt.pageCountSnapshot == 560)
        #expect(book.completedReadingAttemptCount == 0)
    }

    @Test @MainActor func rereadingBookUsesNextStableSequenceNumber() {
        let now = Date(timeIntervalSince1970: 6_000)
        let book = Book(title: "Foundation", status: .reading)
        let completed = ReadingAttempt(
            book: book,
            sequenceNumber: 3,
            status: .finished,
            startedAt: Date(timeIntervalSince1970: 1_000),
            finishedAt: Date(timeIntervalSince1970: 2_000),
            pageCountSnapshot: 255,
            createdAt: Date(timeIntervalSince1970: 2_000),
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )
        book.readingAttemptsSafe = [completed]

        let didChange = ReadingAttemptRepair.repair(books: [book], now: now)

        #expect(didChange)
        #expect(book.completedReadingAttemptCount == 1)
        #expect(book.isRereading)
        #expect(book.completedReadingAttempts.first?.sequenceNumber == 3)
        #expect(book.activeReadingAttempt?.sequenceNumber == 4)
        #expect(book.currentReadingAttemptDisplayName == "4. Durchgang")
    }

    @Test @MainActor func readingBookWithLegacyCompletionCreatesCompletedAndActiveAttempts() {
        let start = Date(timeIntervalSince1970: 6_100)
        let finish = Date(timeIntervalSince1970: 6_200)
        let now = Date(timeIntervalSince1970: 6_300)
        let book = Book(title: "Again", status: .reading)
        book.readFrom = start
        book.readTo = finish

        let didChange = ReadingAttemptRepair.repair(books: [book], now: now)

        #expect(didChange)
        #expect(book.completedReadingAttemptCount == 1)
        #expect(book.activeReadingAttempt?.sequenceNumber == 2)
        #expect(book.activeReadingAttempt?.startedAt == now)
        #expect(book.isRereading)
        #expect(book.completedReadingAttempts.first?.startedAt == start)
        #expect(book.completedReadingAttempts.first?.finishedAt == finish)
    }

    @Test @MainActor func helpersExposeActiveCompletedAndNextAttemptState() {
        let book = Book(title: "Reusable", status: .reading)
        let first = ReadingAttempt(book: book, sequenceNumber: 1, status: .finished)
        let second = ReadingAttempt(book: book, sequenceNumber: 2, status: .active)
        book.readingAttemptsSafe = [second, first]

        #expect(book.orderedReadingAttempts.map(\.sequenceNumber) == [1, 2])
        #expect(book.completedReadingAttemptCount == 1)
        #expect(book.activeReadingAttempt?.id == second.id)
        #expect(book.isRereading)
        #expect(book.nextReadingAttemptSequenceNumber == 3)
        #expect(book.displayName(for: first) == "1. Durchgang")
        #expect(book.currentReadingAttemptDisplayName == "2. Durchgang")
    }

    @Test @MainActor func switchingFinishedBookToReadingKeepsLegacyCompletionWhenAttemptExists() {
        let start = Date(timeIntervalSince1970: 7_000)
        let end = Date(timeIntervalSince1970: 8_000)
        let book = Book(title: "Reread", status: .finished)
        book.readFrom = start
        book.readTo = end
        book.userRatingPlot = 5

        let completed = ReadingAttempt(
            book: book,
            sequenceNumber: 1,
            status: .finished,
            startedAt: start,
            finishedAt: end,
            pageCountSnapshot: 320
        )
        book.readingAttemptsSafe = [completed]

        book.status = .reading

        #expect(book.status == .reading)
        #expect(book.readFrom == start)
        #expect(book.readTo == end)
        #expect(book.userRatingPlot == 5)
    }
}

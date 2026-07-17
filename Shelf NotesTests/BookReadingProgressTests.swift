import Foundation
import Testing
@testable import Shelf_Notes

struct BookReadingProgressTests {

    @Test @MainActor func finishedBooksAlwaysReturnFullProgress() {
        let book = Book(title: "Finished", status: .finished)
        book.pageCount = nil

        #expect(book.readingProgressFraction == .some(1.0))
    }

    @Test @MainActor func finishedBookStatusRemainsFullWithTransientActiveAttempt() {
        let book = Book(title: "Finished Sync State", status: .finished)
        let attempt = ReadingAttempt(
            book: book,
            sequenceNumber: 1,
            status: .active,
            pageCountSnapshot: 100
        )
        let session = makeSession(book: book, pagesRead: 20)
        session.readingAttempt = attempt
        attempt.sessionsSafe = [session]
        book.readingAttemptsSafe = [attempt]
        book.readingSessionsSafe = [session]

        #expect(book.readingProgressFraction == 1)
        #expect(book.currentReadingProgressSnapshot.isCompleted)
    }

    @Test @MainActor func readingProgressUsesNormalizedSessionPages() {
        let book = Book(title: "Reading", status: .reading)
        book.pageCount = 400
        book.readingSessionsSafe = [
            makeSession(book: book, pagesRead: 50),
            makeSession(book: book, pagesRead: nil),
            makeSession(book: book, pagesRead: -10),
            makeSession(book: book, pagesRead: 70)
        ]

        #expect(book.pagesReadTotalFromSessions == 120)
        #expect(book.readingProgressFraction == .some(0.3))
    }

    @Test @MainActor func progressIsClampedAndNilWithoutValidPageCount() {
        let overRead = Book(title: "Long Book", status: .reading)
        overRead.pageCount = 100
        overRead.readingSessionsSafe = [
            makeSession(book: overRead, pagesRead: 120)
        ]

        let withoutPageCount = Book(title: "Unknown Length", status: .reading)
        withoutPageCount.pageCount = 0
        withoutPageCount.readingSessionsSafe = [
            makeSession(book: withoutPageCount, pagesRead: 20)
        ]

        #expect(overRead.readingProgressFraction == .some(1.0))
        #expect(withoutPageCount.readingProgressFraction == nil)
    }

    @Test @MainActor func toReadStatusDoesNotInheritUnmeasuredFinishedAttemptProgress() {
        let book = Book(title: "Reset Book", status: .toRead)
        book.pageCount = 100
        book.readingAttemptsSafe = [
            ReadingAttempt(
                book: book,
                sequenceNumber: 1,
                status: .finished,
                pageCountSnapshot: 100
            )
        ]

        #expect(book.readingProgressFraction == nil)
        #expect(book.currentReadingProgressSnapshot.hasMeasurableProgress == false)
    }

    @Test @MainActor func activeRereadDoesNotReuseEarlierAttemptProgress() throws {
        let book = Book(title: "Reread", status: .reading)
        book.pageCount = 100
        let completed = ReadingAttempt(
            book: book,
            sequenceNumber: 1,
            status: .finished,
            pageCountSnapshot: 100
        )
        let active = ReadingAttempt(
            book: book,
            sequenceNumber: 2,
            status: .active,
            pageCountSnapshot: 100
        )
        let oldSession = makeSession(book: book, pagesRead: 100)
        oldSession.readingAttempt = completed
        let currentSession = makeSession(book: book, pagesRead: 20)
        currentSession.readingAttempt = active

        completed.sessionsSafe = [oldSession]
        active.sessionsSafe = [currentSession, oldSession]
        book.readingAttemptsSafe = [completed, active]
        book.readingSessionsSafe = [oldSession, currentSession]

        let snapshot = active.readingProgressSnapshot

        #expect(snapshot.pagesRead == 20)
        #expect(snapshot.remainingPages == 80)
        #expect(book.readingProgressFraction == 0.2)
    }

    @MainActor
    private func makeSession(book: Book, pagesRead: Int?) -> ReadingSession {
        ReadingSession(
            book: book,
            startedAt: Date(timeIntervalSince1970: 10),
            endedAt: Date(timeIntervalSince1970: 20),
            pagesRead: pagesRead,
            note: nil
        )
    }
}

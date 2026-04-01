import Foundation
import Testing
@testable import Shelf_Notes

struct BookReadingProgressTests {

    @Test @MainActor func finishedBooksAlwaysReturnFullProgress() {
        let book = Book(title: "Finished", status: .finished)
        book.pageCount = nil

        #expect(book.readingProgressFraction == .some(1.0))
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

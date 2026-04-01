import Foundation
import Testing
@testable import Shelf_Notes

struct BookRatingsTests {

    @Test @MainActor func averageIgnoresZeroValues() {
        let book = Book(title: "The Hobbit", status: .finished)
        book.userRatingPlot = 5
        book.userRatingCharacters = 0
        book.userRatingWritingStyle = 3
        book.userRatingAtmosphere = 0
        book.userRatingGenreFit = 4
        book.userRatingPresentation = 0

        #expect(book.userRatingValues == [5, 0, 3, 0, 4, 0])
        #expect(book.userRatingAverage == .some(4.0))
        #expect(book.userRatingAverage1 == .some(4.0))
    }

    @Test @MainActor func clearUserRatingsResetsAllFields() {
        let book = Book(title: "Neuromancer", status: .finished)
        book.userRatingPlot = 4
        book.userRatingCharacters = 4
        book.userRatingWritingStyle = 5
        book.userRatingAtmosphere = 5
        book.userRatingGenreFit = 4
        book.userRatingPresentation = 3

        book.clearUserRatings()

        #expect(book.userRatingValues == [0, 0, 0, 0, 0, 0])
        #expect(book.userRatingAverage == nil)
        #expect(book.userRatingAverage1 == nil)
    }

    @Test @MainActor func canUserRateDependsOnFinishedStatus() {
        let finished = Book(title: "Finished", status: .finished)
        let reading = Book(title: "Reading", status: .reading)

        #expect(finished.canUserRate)
        #expect(!reading.canUserRate)
    }
}

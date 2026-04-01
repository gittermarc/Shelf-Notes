import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingStatusTests {

    @Test func stableCodesRemainUnchanged() {
        #expect(ReadingStatus.toRead.rawValue == "toRead")
        #expect(ReadingStatus.reading.rawValue == "reading")
        #expect(ReadingStatus.finished.rawValue == "finished")
    }

    @Test func fromPersistedMapsStableCodesAndLegacyLabels() {
        #expect(ReadingStatus.fromPersisted("toRead") == .toRead)
        #expect(ReadingStatus.fromPersisted("reading") == .reading)
        #expect(ReadingStatus.fromPersisted("finished") == .finished)
        #expect(ReadingStatus.fromPersisted("Will ich lesen") == .toRead)
        #expect(ReadingStatus.fromPersisted("Will lesen") == .toRead)
        #expect(ReadingStatus.fromPersisted("Lese ich gerade") == .reading)
        #expect(ReadingStatus.fromPersisted("Lese ich") == .reading)
        #expect(ReadingStatus.fromPersisted("Gelesen") == .finished)
        #expect(ReadingStatus.fromPersisted("unknown") == nil)
    }

    @Test @MainActor func switchingAwayFromFinishedClearsReadRangeAndRatings() {
        let book = Book(title: "Dune", status: .finished)
        book.readFrom = Date(timeIntervalSince1970: 10)
        book.readTo = Date(timeIntervalSince1970: 20)
        book.userRatingPlot = 5
        book.userRatingCharacters = 4

        book.status = .reading

        #expect(book.statusRawValue == ReadingStatus.reading.rawValue)
        #expect(book.readFrom == nil)
        #expect(book.readTo == nil)
        #expect(book.userRatingValues == [0, 0, 0, 0, 0, 0])
        #expect(book.canUserRate == false)
    }

    @Test @MainActor func finishedBooksCanBeRated() {
        let book = Book(title: "Hyperion", status: .finished)

        #expect(book.status == .finished)
        #expect(book.canUserRate)
    }
}

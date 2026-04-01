import Foundation
import Testing
@testable import Shelf_Notes

struct CSVImportDuplicateIndexTests {

    @Test @MainActor func normalizesISBNsFromExistingBooks() {
        let hobbit = makeBook(title: "The Hobbit", isbn13: "978-0-261-10334-4", googleVolumeID: nil)
        let dune = makeBook(title: "Dune", isbn13: " 9780441172719 ", googleVolumeID: nil)

        let index = CSVImportDuplicateIndex(books: [hobbit, dune])

        #expect(index.contains(isbn: "9780261103344"))
        #expect(index.contains(isbn: "9780441172719"))
        #expect(!index.contains(isbn: "9780000000000"))
    }

    @Test @MainActor func normalizesVolumeIDsFromExistingBooks() {
        let first = makeBook(title: "Book A", isbn13: nil, googleVolumeID: "  vol-1  ")
        let second = makeBook(title: "Book B", isbn13: nil, googleVolumeID: "vol-2")

        let index = CSVImportDuplicateIndex(books: [first, second])

        #expect(index.contains(volumeID: "vol-1"))
        #expect(index.contains(volumeID: "vol-2"))
        #expect(!index.contains(volumeID: "vol-3"))
    }

    @Test @MainActor func normalizesTitlesCaseInsensitively() {
        let existing = makeBook(title: "  The Hobbit  ", isbn13: nil, googleVolumeID: nil)
        let index = CSVImportDuplicateIndex(books: [existing])

        #expect(index.contains(title: "the hobbit"))
        #expect(index.contains(title: "  THE HOBBIT"))
        #expect(!index.contains(title: "The Lord of the Rings"))
    }

    @Test @MainActor func registerAddsNormalizedMetadataForNewBook() {
        var index = CSVImportDuplicateIndex()
        let book = makeBook(title: "  Hyperion ", isbn13: "978-0553283686", googleVolumeID: " vol-9 ")

        index.register(book: book)

        #expect(index.contains(title: "hyperion"))
        #expect(index.contains(isbn: "9780553283686"))
        #expect(index.contains(volumeID: "vol-9"))
    }

    @MainActor
    private func makeBook(title: String, isbn13: String?, googleVolumeID: String?) -> Book {
        let book = Book(title: title)
        book.isbn13 = isbn13
        book.googleVolumeID = googleVolumeID
        return book
    }
}

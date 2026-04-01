import Foundation
import Testing
@testable import Shelf_Notes

struct BookCollectionsHelperTests {

    @Test @MainActor func collectionsSafeTreatsNilAsEmptyArray() {
        let book = Book(title: "Collected")

        #expect(book.collections == nil)
        #expect(book.collectionsSafe.isEmpty)
    }

    @Test @MainActor func addAndRemoveCollectionRespectIdentityAndAvoidDuplicates() {
        let book = Book(title: "Collected")
        let favorites = BookCollection(name: "Favorites")

        book.addToCollection(favorites)
        book.addToCollection(favorites)

        #expect(book.collectionsSafe.count == 1)
        #expect(book.isInCollection(favorites))

        book.removeFromCollection(favorites)

        #expect(book.collectionsSafe.isEmpty)
        #expect(!book.isInCollection(favorites))
    }
}

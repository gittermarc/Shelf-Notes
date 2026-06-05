import Foundation
import Testing
@testable import Shelf_Notes

struct CollectionMembershipMutationTests {

    @Test @MainActor func addMultipleBooksKeepsBothRelationshipSidesInSync() {
        let first = Book(title: "Dune")
        let second = Book(title: "Hyperion")
        let collection = BookCollection(name: "Sci-Fi")

        let changedCount = CollectionMembershipMutation.add([first, second, first], to: collection)

        #expect(changedCount == 2)
        #expect(collection.booksSafe.map(\.id) == [first.id, second.id])
        #expect(first.collectionsSafe.map(\.id) == [collection.id])
        #expect(second.collectionsSafe.map(\.id) == [collection.id])
    }

    @Test @MainActor func addDeduplicatesExistingDrift() {
        let book = Book(title: "Dune")
        let duplicateBookReference = Book(title: "Dune")
        duplicateBookReference.id = book.id

        let collection = BookCollection(name: "Sci-Fi")
        let duplicateCollectionReference = BookCollection(name: "Sci-Fi")
        duplicateCollectionReference.id = collection.id

        book.collectionsSafe = [collection, duplicateCollectionReference]
        collection.booksSafe = [book, duplicateBookReference]

        let didChange = CollectionMembershipMutation.add(book, to: collection)

        #expect(didChange)
        #expect(book.collectionsSafe.map(\.id) == [collection.id])
        #expect(collection.booksSafe.map(\.id) == [book.id])
    }

    @Test @MainActor func removeBookKeepsBothRelationshipSidesInSync() {
        let book = Book(title: "Dune")
        let collection = BookCollection(name: "Sci-Fi")
        CollectionMembershipMutation.add(book, to: collection)

        let didChange = CollectionMembershipMutation.remove(book, from: collection)

        #expect(didChange)
        #expect(book.collectionsSafe.isEmpty)
        #expect(collection.booksSafe.isEmpty)
    }

    @Test @MainActor func removingMissingMembershipDoesNothing() {
        let book = Book(title: "Dune")
        let collection = BookCollection(name: "Sci-Fi")

        let didChange = CollectionMembershipMutation.remove(book, from: collection)

        #expect(!didChange)
        #expect(book.collectionsSafe.isEmpty)
        #expect(collection.booksSafe.isEmpty)
    }
}

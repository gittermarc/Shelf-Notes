import Foundation
import Testing
@testable import Shelf_Notes

struct CollectionMembershipRepairTests {

    @Test @MainActor func repairDeduplicatesExistingDrift() {
        let book = Book(title: "Dune")
        let duplicateBookReference = Book(title: "Dune")
        duplicateBookReference.id = book.id

        let collection = BookCollection(name: "Sci-Fi")
        let duplicateCollectionReference = BookCollection(name: "Sci-Fi")
        duplicateCollectionReference.id = collection.id

        book.collectionsSafe = [collection, duplicateCollectionReference]
        collection.booksSafe = [book, duplicateBookReference]
        let now = Date(timeIntervalSince1970: 1_000)

        let didChange = CollectionMembershipRepair.repair(book: book, collection: collection, now: now)

        #expect(didChange)
        #expect(book.collectionsSafe.map(\.id) == [collection.id])
        #expect(collection.booksSafe.map(\.id) == [book.id])
        #expect(collection.updatedAt == now)
    }

    @Test @MainActor func repairAfterBookSideAssignmentIsNoopWhenSwiftDataAlreadyBalancesInverse() {
        let book = Book(title: "Dune")
        let collection = BookCollection(name: "Sci-Fi")
        let unchangedDate = Date(timeIntervalSince1970: 1_000)
        let noOpDate = Date(timeIntervalSince1970: 2_000)

        book.collectionsSafe = [collection]
        collection.updatedAt = unchangedDate

        let didChange = CollectionMembershipRepair.repair(book: book, collection: collection, now: noOpDate)

        #expect(!didChange)
        #expect(book.collectionsSafe.map(\.id) == [collection.id])
        #expect(collection.booksSafe.map(\.id) == [book.id])
        #expect(collection.updatedAt == unchangedDate)
    }

    @Test @MainActor func repairAfterCollectionSideAssignmentIsNoopWhenSwiftDataAlreadyBalancesInverse() {
        let book = Book(title: "Dune")
        let collection = BookCollection(name: "Sci-Fi")
        let unchangedDate = Date(timeIntervalSince1970: 1_000)
        let noOpDate = Date(timeIntervalSince1970: 2_000)

        collection.booksSafe = [book]
        collection.updatedAt = unchangedDate

        let didChange = CollectionMembershipRepair.repair(book: book, collection: collection, now: noOpDate)

        #expect(!didChange)
        #expect(book.collectionsSafe.map(\.id) == [collection.id])
        #expect(collection.booksSafe.map(\.id) == [book.id])
        #expect(collection.updatedAt == unchangedDate)
    }

    @Test @MainActor func repairIsNoopForConsistentMembership() {
        let book = Book(title: "Dune")
        let collection = BookCollection(name: "Sci-Fi")
        let unchangedDate = Date(timeIntervalSince1970: 2_000)
        let noOpDate = Date(timeIntervalSince1970: 3_000)

        CollectionMembershipMutation.add(book, to: collection)
        collection.updatedAt = unchangedDate

        let didChange = CollectionMembershipRepair.repair(book: book, collection: collection, now: noOpDate)

        #expect(!didChange)
        #expect(book.collectionsSafe.map(\.id) == [collection.id])
        #expect(collection.booksSafe.map(\.id) == [book.id])
        #expect(collection.updatedAt == unchangedDate)
    }

    @Test @MainActor func uniqueHelpersPreserveFirstReferenceOrder() {
        let first = Book(title: "Dune")
        let duplicateFirst = Book(title: "Dune duplicate")
        duplicateFirst.id = first.id
        let second = Book(title: "Hyperion")

        let uniqueBooks = CollectionMembershipRepair.uniqueBooks([first, duplicateFirst, second, first])

        #expect(uniqueBooks.map(\.title) == ["Dune", "Hyperion"])
    }
}

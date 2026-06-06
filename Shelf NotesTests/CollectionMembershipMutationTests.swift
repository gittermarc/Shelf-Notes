import Foundation
import Testing
@testable import Shelf_Notes

struct CollectionMembershipMutationTests {

    @Test @MainActor func addBookKeepsBothRelationshipSidesInSync() {
        let book = Book(title: "Dune")
        let collection = BookCollection(name: "Sci-Fi")
        let now = Date(timeIntervalSince1970: 1_000)

        let didChange = CollectionMembershipMutation.add(book, to: collection, now: now)

        #expect(didChange)
        #expect(book.collectionsSafe.map(\.id) == [collection.id])
        #expect(collection.booksSafe.map(\.id) == [book.id])
        #expect(collection.updatedAt == now)
    }

    @Test @MainActor func addExistingMembershipIsNoopAndKeepsUpdatedAt() {
        let book = Book(title: "Dune")
        let collection = BookCollection(name: "Sci-Fi")
        let firstChangeDate = Date(timeIntervalSince1970: 1_000)
        let unchangedDate = Date(timeIntervalSince1970: 2_000)
        let noOpDate = Date(timeIntervalSince1970: 3_000)

        CollectionMembershipMutation.add(book, to: collection, now: firstChangeDate)
        collection.updatedAt = unchangedDate

        let didChange = CollectionMembershipMutation.add(book, to: collection, now: noOpDate)

        #expect(!didChange)
        #expect(book.collectionsSafe.map(\.id) == [collection.id])
        #expect(collection.booksSafe.map(\.id) == [book.id])
        #expect(collection.updatedAt == unchangedDate)
    }

    @Test @MainActor func addAfterCollectionSideAssignmentIsNoopWhenSwiftDataAlreadyBalancesInverse() {
        let book = Book(title: "Dune")
        let collection = BookCollection(name: "Sci-Fi")
        let unchangedDate = Date(timeIntervalSince1970: 1_000)
        let noOpDate = Date(timeIntervalSince1970: 2_000)

        collection.booksSafe = [book]
        collection.updatedAt = unchangedDate

        let didChange = CollectionMembershipMutation.add(book, to: collection, now: noOpDate)

        #expect(!didChange)
        #expect(book.collectionsSafe.map(\.id) == [collection.id])
        #expect(collection.booksSafe.map(\.id) == [book.id])
        #expect(collection.updatedAt == unchangedDate)
    }

    @Test @MainActor func addAfterBookSideAssignmentIsNoopWhenSwiftDataAlreadyBalancesInverse() {
        let book = Book(title: "Dune")
        let collection = BookCollection(name: "Sci-Fi")
        let unchangedDate = Date(timeIntervalSince1970: 1_000)
        let noOpDate = Date(timeIntervalSince1970: 2_000)

        book.collectionsSafe = [collection]
        collection.updatedAt = unchangedDate

        let didChange = CollectionMembershipMutation.add(book, to: collection, now: noOpDate)

        #expect(!didChange)
        #expect(book.collectionsSafe.map(\.id) == [collection.id])
        #expect(collection.booksSafe.map(\.id) == [book.id])
        #expect(collection.updatedAt == unchangedDate)
    }

    @Test @MainActor func removeBookKeepsBothRelationshipSidesInSync() {
        let book = Book(title: "Dune")
        let collection = BookCollection(name: "Sci-Fi")
        let now = Date(timeIntervalSince1970: 2_000)

        CollectionMembershipMutation.add(book, to: collection)
        let didChange = CollectionMembershipMutation.remove(book, from: collection, now: now)

        #expect(didChange)
        #expect(book.collectionsSafe.isEmpty)
        #expect(collection.booksSafe.isEmpty)
        #expect(collection.updatedAt == now)
    }

    @Test @MainActor func removingMissingMembershipDoesNothingAndKeepsUpdatedAt() {
        let book = Book(title: "Dune")
        let collection = BookCollection(name: "Sci-Fi")
        let unchangedDate = Date(timeIntervalSince1970: 2_000)
        let noOpDate = Date(timeIntervalSince1970: 3_000)
        collection.updatedAt = unchangedDate

        let didChange = CollectionMembershipMutation.remove(book, from: collection, now: noOpDate)

        #expect(!didChange)
        #expect(book.collectionsSafe.isEmpty)
        #expect(collection.booksSafe.isEmpty)
        #expect(collection.updatedAt == unchangedDate)
    }

    @Test @MainActor func bulkAddMultipleBooksKeepsBothRelationshipSidesInSync() {
        let first = Book(title: "Dune")
        let second = Book(title: "Hyperion")
        let collection = BookCollection(name: "Sci-Fi")
        let now = Date(timeIntervalSince1970: 1_000)

        let changedCount = CollectionMembershipMutation.add([first, second, first], to: collection, now: now)

        #expect(changedCount == 2)
        #expect(collection.booksSafe.map(\.id) == [first.id, second.id])
        #expect(first.collectionsSafe.map(\.id) == [collection.id])
        #expect(second.collectionsSafe.map(\.id) == [collection.id])
        #expect(collection.updatedAt == now)
    }

    @Test @MainActor func bulkAddSkipsExistingBooksAndDoesNotCreateDuplicates() {
        let first = Book(title: "Dune")
        let second = Book(title: "Hyperion")
        let third = Book(title: "Foundation")
        let collection = BookCollection(name: "Sci-Fi")
        let firstChangeDate = Date(timeIntervalSince1970: 1_000)
        let unchangedDate = Date(timeIntervalSince1970: 2_000)
        let bulkDate = Date(timeIntervalSince1970: 3_000)

        CollectionMembershipMutation.add(first, to: collection, now: firstChangeDate)
        collection.updatedAt = unchangedDate

        let changedCount = CollectionMembershipMutation.add(
            [first, second, third, second],
            to: collection,
            now: bulkDate
        )

        #expect(changedCount == 2)
        #expect(collection.booksSafe.map(\.id) == [first.id, second.id, third.id])
        #expect(first.collectionsSafe.map(\.id) == [collection.id])
        #expect(second.collectionsSafe.map(\.id) == [collection.id])
        #expect(third.collectionsSafe.map(\.id) == [collection.id])
        #expect(collection.updatedAt == bulkDate)
    }

    @Test @MainActor func bulkAddNoopKeepsUpdatedAt() {
        let first = Book(title: "Dune")
        let second = Book(title: "Hyperion")
        let collection = BookCollection(name: "Sci-Fi")
        let firstChangeDate = Date(timeIntervalSince1970: 1_000)
        let unchangedDate = Date(timeIntervalSince1970: 2_000)
        let noOpDate = Date(timeIntervalSince1970: 3_000)

        CollectionMembershipMutation.add([first, second], to: collection, now: firstChangeDate)
        collection.updatedAt = unchangedDate

        let changedCount = CollectionMembershipMutation.add([first, second, first], to: collection, now: noOpDate)

        #expect(changedCount == 0)
        #expect(collection.booksSafe.map(\.id) == [first.id, second.id])
        #expect(collection.updatedAt == unchangedDate)
    }

    @Test @MainActor func bulkAddMatchesRepeatedSingleAddEndState() {
        let bulkBooks = [
            Book(title: "Dune"),
            Book(title: "Hyperion"),
            Book(title: "Foundation")
        ]
        let singleBooks = [
            Book(title: "Dune"),
            Book(title: "Hyperion"),
            Book(title: "Foundation")
        ]
        let bulkCollection = BookCollection(name: "Bulk")
        let singleCollection = BookCollection(name: "Single")
        let now = Date(timeIntervalSince1970: 1_000)

        let bulkCount = CollectionMembershipMutation.add(
            [bulkBooks[0], bulkBooks[1], bulkBooks[2], bulkBooks[1]],
            to: bulkCollection,
            now: now
        )

        var singleCount = 0
        for book in singleBooks {
            if CollectionMembershipMutation.add(book, to: singleCollection, now: now) {
                singleCount += 1
            }
        }

        #expect(bulkCount == singleCount)
        #expect(bulkCollection.booksSafe.count == singleCollection.booksSafe.count)
        #expect(bulkBooks.allSatisfy { $0.collectionsSafe.map(\.id) == [bulkCollection.id] })
        #expect(singleBooks.allSatisfy { $0.collectionsSafe.map(\.id) == [singleCollection.id] })
        #expect(bulkCollection.updatedAt == now)
        #expect(singleCollection.updatedAt == now)
    }

    @Test @MainActor func bulkRemoveBooksKeepsBothRelationshipSidesInSync() {
        let first = Book(title: "Dune")
        let second = Book(title: "Hyperion")
        let third = Book(title: "Foundation")
        let collection = BookCollection(name: "Sci-Fi")
        let now = Date(timeIntervalSince1970: 2_000)

        CollectionMembershipMutation.add([first, second, third], to: collection)
        let changedCount = CollectionMembershipMutation.remove([first, second, first], from: collection, now: now)

        #expect(changedCount == 2)
        #expect(collection.booksSafe.map(\.id) == [third.id])
        #expect(first.collectionsSafe.isEmpty)
        #expect(second.collectionsSafe.isEmpty)
        #expect(third.collectionsSafe.map(\.id) == [collection.id])
        #expect(collection.updatedAt == now)
    }
}

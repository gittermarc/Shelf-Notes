import Foundation
import Testing
@testable import Shelf_Notes

struct LibraryQuickFilterBuilderTests {
    @Test func topTagsAreNormalizedCountedOncePerBookAndLimited() {
        let books = [
            makeBook(id: fixedID(1), title: "One", tags: ["#Crime", "crime", "Noir"]),
            makeBook(id: fixedID(2), title: "Two", tags: ["Crime"]),
            makeBook(id: fixedID(3), title: "Three", tags: ["Fantasy"])
        ]

        let snapshot = LibraryView.LibraryQuickFilterBuilder.makeSnapshot(
            books: books,
            tagLimit: 2,
            collectionLimit: 0
        )

        #expect(snapshot.tagItems.map(\.title) == ["Crime", "Fantasy"])
        #expect(snapshot.tagItems.map(\.count) == [2, 1])
        #expect(snapshot.collectionItems.isEmpty)
    }

    @Test func topCollectionsAreCountedFromSnapshotCollectionNames() {
        let books = [
            makeBook(id: fixedID(1), title: "One", collectionNames: ["Urlaub", "Backlog"]),
            makeBook(id: fixedID(2), title: "Two", collectionNames: ["urlaub"]),
            makeBook(id: fixedID(3), title: "Three", collectionNames: ["Favoriten"])
        ]

        let snapshot = LibraryView.LibraryQuickFilterBuilder.makeSnapshot(
            books: books,
            tagLimit: 0,
            collectionLimit: 3
        )

        #expect(snapshot.tagItems.isEmpty)
        #expect(snapshot.collectionItems.map(\.normalizedValue) == ["urlaub", "backlog", "favoriten"])
        #expect(snapshot.collectionItems.map(\.count) == [2, 1, 1])
    }

    @Test func quickFilterSnapshotIsEmptyWithoutTagsOrCollections() {
        let books = [
            makeBook(id: fixedID(1), title: "One"),
            makeBook(id: fixedID(2), title: "Two")
        ]

        let snapshot = LibraryView.LibraryQuickFilterBuilder.makeSnapshot(books: books)

        #expect(snapshot.isEmpty)
    }

    private func makeBook(
        id: UUID,
        title: String,
        tags: [String] = [],
        collectionNames: [String] = []
    ) -> LibraryView.LibrarySourceSnapshot.BookSnapshot {
        LibraryView.LibrarySourceSnapshot.BookSnapshot(
            id: id,
            title: title,
            tags: tags,
            collectionNames: collectionNames
        )
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
    }
}

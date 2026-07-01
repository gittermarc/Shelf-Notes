import Foundation
import Testing
@testable import Shelf_Notes

struct LibraryBooksIndexTests {
    @Test @MainActor func resolvesBooksInRequestedDisplayOrder() {
        let first = makeBook(id: fixedID(1), title: "Alpha")
        let second = makeBook(id: fixedID(2), title: "Beta")
        let index = LibraryView.LibraryBooksIndex(books: [first, second])

        let resolved = index.books(matching: [second.id, first.id, fixedID(99)])

        #expect(index.orderedBookIDs == [first.id, second.id])
        #expect(resolved.map(\.id) == [second.id, first.id])
        #expect(index.book(for: first.id)?.id == first.id)
        #expect(index.book(for: fixedID(99)) == nil)
    }

    @Test @MainActor func sourceSignatureMatchesSourceSnapshotForSameBooks() {
        let first = makeBook(id: fixedID(1), title: "Noir Nights", author: "Ada", tags: ["Crime", "Noir"])
        first.status = .finished
        first.notes = "Strong atmosphere"
        first.isbn13 = "978000000001"
        first.userRatingPlot = 5
        first.userRatingCharacters = 4

        let second = makeBook(id: fixedID(2), title: "History of Rome", author: "Bea", tags: ["History"])
        second.status = .reading

        let index = LibraryView.LibraryBooksIndex(books: [first, second])
        let source = LibraryView.LibrarySourceSnapshot(books: [first, second])

        #expect(index.sourceSignature == source.signature)
        #expect(index.librarySourceSignature == LibraryView.LibrarySourceSignature(rawValue: source.signature))
        #expect(index.source.books.map(\.id) == source.books.map(\.id))
        #expect(index.source.books.map(\.title) == ["Noir Nights", "History of Rome"])
    }

    @Test @MainActor func sourceStoreReusesIndexForEqualSourceInput() {
        let first = makeBook(id: fixedID(1), title: "Alpha")
        let second = makeBook(id: fixedID(2), title: "Beta")
        let store = LibraryView.LibrarySourceStore()

        store.refreshSourceAndTrack(books: [first, second])
        let initialSignature = store.sourceSignature
        store.refreshSourceAndTrack(books: [first, second])

        #expect(store.completedIndexBuildCount == 1)
        #expect(store.sourceSignature == initialSignature)
        #expect(store.currentIndex.orderedBookIDs == [first.id, second.id])
    }

    @Test @MainActor func sourceStoreInvalidatesWhenTitleChanges() {
        let first = makeBook(id: fixedID(1), title: "Alpha")
        let second = makeBook(id: fixedID(2), title: "Beta")
        let store = LibraryView.LibrarySourceStore()

        store.refreshSourceAndTrack(books: [first, second])
        let originalSignature = store.sourceSignature
        second.title = "Beta Revised"
        store.refreshSourceAndTrack(books: [first, second])

        #expect(store.completedIndexBuildCount == 2)
        #expect(store.sourceSignature != originalSignature)
        #expect(store.currentIndex.source.books.map(\.title) == ["Alpha", "Beta Revised"])
    }

    @Test @MainActor func sourceStoreIgnoresAppearanceOnlyBookFields() {
        let first = makeBook(id: fixedID(1), title: "Alpha")
        let second = makeBook(id: fixedID(2), title: "Beta")
        let store = LibraryView.LibrarySourceStore()

        store.refreshSourceAndTrack(books: [first, second])
        let originalSignature = store.sourceSignature
        first.subtitle = "Shown only outside library indexing"
        first.thumbnailURL = "https://example.com/cover.jpg"
        first.userCoverFileName = "local-cover.jpg"
        store.refreshSourceAndTrack(books: [first, second])

        #expect(store.completedIndexBuildCount == 1)
        #expect(store.sourceSignature == originalSignature)
    }

    @Test @MainActor func alphaSectionsResolveDescriptorIDsThroughIndex() {
        let first = makeBook(id: fixedID(1), title: "Alpha")
        let second = makeBook(id: fixedID(2), title: "Beta")
        let index = LibraryView.LibraryBooksIndex(books: [first, second])
        let descriptors = [
            LibraryView.AlphaSectionDescriptor(id: "B", key: "B", bookIDs: [second.id]),
            LibraryView.AlphaSectionDescriptor(id: "A", key: "A", bookIDs: [first.id, fixedID(99)])
        ]

        let sections = index.alphaSections(for: descriptors)

        #expect(sections.map(\.key) == ["B", "A"])
        #expect(sections[0].books.map(\.id) == [second.id])
        #expect(sections[1].books.map(\.id) == [first.id])
    }

    private func makeBook(
        id: UUID,
        title: String,
        author: String = "",
        tags: [String] = []
    ) -> Book {
        let book = Book(title: title, author: author, tags: tags)
        book.id = id
        book.createdAt = Date(timeIntervalSince1970: 0)
        return book
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
    }
}

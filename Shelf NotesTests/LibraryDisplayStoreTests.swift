import Foundation
import Testing
@testable import Shelf_Notes

struct LibraryDisplayStoreTests {
    @Test @MainActor func resolvesDisplayStateThroughBooksIndex() {
        let first = makeBook(id: fixedID(1), title: "Änne", createdAt: date(2026, 1, 1))
        let second = makeBook(id: fixedID(2), title: "Berlin", createdAt: date(2026, 1, 2))
        let third = makeBook(id: fixedID(3), title: "1Q84", createdAt: date(2026, 1, 3))
        let index = LibraryView.LibraryBooksIndex(books: [third, second, first])
        let input = LibraryView.LibraryDerivedStateBuilder.makeInput(
            searchText: "",
            selectedStatus: nil,
            selectedTag: nil,
            onlyWithNotes: false,
            sortField: .title,
            sortAscending: true,
            buildsAlphaSections: true
        )
        let token = index.token(input: input)
        var store = LibraryView.LibraryDisplayStore()

        let expected = LibraryView.LibraryDerivedStateBuilder.makeDerivedState(
            source: index.source,
            input: input
        )

        store.resolveIfNeeded(for: token, index: index, input: input)
        let state = store.displayState(for: token)

        #expect(state.token == token)
        #expect(state.displayedBookIDs == expected.displayedBookIDs)
        #expect(state.displayedBooks.map(\.id) == expected.displayedBookIDs)
        #expect(state.alphaLetters == expected.alphaLetters)
        #expect(state.alphaSections.map(\.key) == expected.alphaSections.map(\.key))
        #expect(state.alphaSections.map { $0.books.map(\.id) } == expected.alphaSections.map(\.bookIDs))
    }

    @Test @MainActor func keepsLastStableDisplayStateUntilNewTokenResolves() {
        let alpha = makeBook(id: fixedID(1), title: "Alpha")
        let beta = makeBook(id: fixedID(2), title: "Beta")
        let index = LibraryView.LibraryBooksIndex(books: [alpha, beta])
        let originalInput = LibraryView.LibraryDerivedStateBuilder.makeInput(
            searchText: "",
            selectedStatus: nil,
            selectedTag: nil,
            onlyWithNotes: false,
            sortField: .title,
            sortAscending: true,
            buildsAlphaSections: false
        )
        let filteredInput = LibraryView.LibraryDerivedStateBuilder.makeInput(
            searchText: "Beta",
            selectedStatus: nil,
            selectedTag: nil,
            onlyWithNotes: false,
            sortField: .title,
            sortAscending: true,
            buildsAlphaSections: false
        )
        let originalToken = index.token(input: originalInput)
        let filteredToken = index.token(input: filteredInput)
        var store = LibraryView.LibraryDisplayStore()

        store.resolveIfNeeded(for: originalToken, index: index, input: originalInput)
        store.invalidate(for: filteredToken)

        let beforeResolve = store.displayState(for: filteredToken)
        #expect(beforeResolve.token == originalToken)
        #expect(beforeResolve.displayedBookIDs == [alpha.id, beta.id])

        store.resolveIfNeeded(for: filteredToken, index: index, input: filteredInput)
        let afterResolve = store.displayState(for: filteredToken)
        #expect(afterResolve.token == filteredToken)
        #expect(afterResolve.displayedBookIDs == [beta.id])
    }

    @Test @MainActor func largeLibraryDisplayMatchesPureDerivedBuilder() {
        let books = (0..<500).map { index in
            makeBook(
                id: fixedID(index + 1),
                title: index.isMultiple(of: 2) ? "Crime \(index)" : "History \(index)",
                author: index.isMultiple(of: 3) ? "Ada" : "Bea",
                tags: index.isMultiple(of: 5) ? ["Crime", "Noir"] : ["History"],
                createdAt: date(2026, 1, 1).addingTimeInterval(Double(index) * 60)
            )
        }
        let index = LibraryView.LibraryBooksIndex(books: books)
        let input = LibraryView.LibraryDerivedStateBuilder.makeInput(
            searchText: "crime",
            selectedStatus: nil,
            selectedTag: "Noir",
            onlyWithNotes: false,
            sortField: .createdAt,
            sortAscending: false,
            buildsAlphaSections: false
        )
        let token = index.token(input: input)
        let expected = LibraryView.LibraryDerivedStateBuilder.makeDerivedState(
            source: index.source,
            input: input
        )
        var store = LibraryView.LibraryDisplayStore()

        store.resolveIfNeeded(for: token, index: index, input: input)
        let state = store.displayState(for: token)

        #expect(state.token == expected.token)
        #expect(state.displayedBookIDs == expected.displayedBookIDs)
        #expect(state.displayedBooks.map(\.id) == expected.displayedBookIDs)
        #expect(state.counts.toRead == expected.counts.toRead)
        #expect(state.counts.reading == expected.counts.reading)
        #expect(state.counts.finished == expected.counts.finished)
    }

    @Test @MainActor func thousandBookFixtureDisplayUsesMemoizedSourceIndex() {
        let fixture = LargeReadingDatasetBuilder.make1000BookMixedDataset()
        let sourceStore = LibraryView.LibrarySourceStore()
        var displayStore = LibraryView.LibraryDisplayStore()

        sourceStore.refreshSourceAndTrack(books: fixture.books)
        sourceStore.refreshSourceAndTrack(books: fixture.books)

        let index = sourceStore.currentIndex
        let input = LibraryView.LibraryDerivedStateBuilder.makeInput(
            searchText: "Performance Book 0001",
            selectedStatus: nil,
            selectedTag: nil,
            onlyWithNotes: false,
            sortField: .createdAt,
            sortAscending: false,
            buildsAlphaSections: false
        )
        let token = index.token(input: input)
        let expected = LibraryView.LibraryDerivedStateBuilder.makeDerivedState(
            source: index.source,
            input: input
        )

        displayStore.resolveIfNeeded(for: token, index: index, input: input)
        let state = displayStore.displayState(for: token)

        #expect(sourceStore.completedIndexBuildCount == 1)
        #expect(index.source.books.count == 1000)
        #expect(state.token == expected.token)
        #expect(state.displayedBookIDs == expected.displayedBookIDs)
        #expect(state.displayedBooks.map(\.id) == expected.displayedBookIDs)
        #expect(state.displayedBookIDs == [fixture.books[1].id])
    }

    private func makeBook(
        id: UUID,
        title: String,
        author: String = "",
        tags: [String] = [],
        createdAt: Date = Date(timeIntervalSince1970: 0)
    ) -> Book {
        let book = Book(title: title, author: author, tags: tags)
        book.id = id
        book.createdAt = createdAt
        return book
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
    }
}

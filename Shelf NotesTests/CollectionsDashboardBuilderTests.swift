import Foundation
import Testing
@testable import Shelf_Notes

struct CollectionsDashboardBuilderTests {

    @Test func buildsSummaryAndCountsBooksWithoutCollection() {
        let books = [
            makeBook(id: fixedID(1), title: "Finished", status: .finished),
            makeBook(id: fixedID(2), title: "Reading", status: .reading),
            makeBook(id: fixedID(3), title: "Unassigned", status: .toRead)
        ]
        let collections = [
            makeCollection(
                id: fixedID(101),
                name: "Sommerliste",
                updatedAt: date(2026, 6, 1),
                books: [books[0], books[1]]
            ),
            makeCollection(
                id: fixedID(102),
                name: "Leer",
                updatedAt: date(2026, 5, 1),
                books: []
            )
        ]

        let dashboard = CollectionsDashboardBuilder.build(
            collections: collections,
            allBooks: books
        )

        #expect(dashboard.summary.totalBooks == 3)
        #expect(dashboard.summary.totalCollections == 2)
        #expect(dashboard.summary.booksInCollectionsCount == 2)
        #expect(dashboard.summary.unassignedBooksCount == 1)
        #expect(dashboard.summary.activeCollectionsCount == 1)
        #expect(dashboard.summary.largestCollection == CollectionsDashboardHighlight(id: fixedID(101), name: "Sommerliste", bookCount: 2))
        #expect(dashboard.unassignedBookIDs == [fixedID(3)])
    }

    @Test func statusCountsAreBuiltPerCollection() {
        let books = [
            makeBook(id: fixedID(1), status: .finished),
            makeBook(id: fixedID(2), status: .finished),
            makeBook(id: fixedID(3), status: .reading),
            makeBook(id: fixedID(4), status: .toRead)
        ]
        let collection = makeCollection(
            id: fixedID(101),
            name: "Status Mix",
            books: books
        )

        let dashboard = CollectionsDashboardBuilder.build(
            collections: [collection],
            allBooks: books
        )
        let entry = dashboard.entries.first

        #expect(entry?.statusCounts.finished == 2)
        #expect(entry?.statusCounts.reading == 1)
        #expect(entry?.statusCounts.toRead == 1)
        #expect(entry?.statusCounts.total == 4)
        #expect(entry?.statusCounts.progressFraction == 0.5)
    }

    @Test func filtersAndSortsEntries() {
        let entries = [
            makeEntry(id: fixedID(1), name: "NYC", bookCount: 4, finished: 1, updatedAt: date(2026, 5, 1)),
            makeEntry(id: fixedID(2), name: "Crime", bookCount: 8, finished: 8, updatedAt: date(2026, 4, 1)),
            makeEntry(id: fixedID(3), name: "Cosy Crime", bookCount: 2, finished: 0, updatedAt: date(2026, 6, 1))
        ]

        let searched = CollectionsDashboardBuilder.filteredEntries(
            entries,
            searchText: "crime",
            sortMode: .name
        )
        let mostBooks = CollectionsDashboardBuilder.filteredEntries(
            entries,
            searchText: "",
            sortMode: .mostBooks
        )
        let progress = CollectionsDashboardBuilder.filteredEntries(
            entries,
            searchText: "",
            sortMode: .progress
        )

        #expect(searched.map(\.displayName) == ["Cosy Crime", "Crime"])
        #expect(mostBooks.map(\.displayName) == ["Crime", "NYC", "Cosy Crime"])
        #expect(progress.map(\.displayName) == ["Crime", "NYC", "Cosy Crime"])
    }

    @Test func recentActivitySortUsesUpdatedAtBeforeName() {
        let entries = [
            makeEntry(id: fixedID(1), name: "Alt", updatedAt: date(2026, 5, 1)),
            makeEntry(id: fixedID(2), name: "Neu", updatedAt: date(2026, 6, 1)),
            makeEntry(id: fixedID(3), name: "Mitte", updatedAt: date(2026, 5, 15))
        ]

        let sorted = CollectionsDashboardBuilder.filteredEntries(
            entries,
            searchText: "",
            sortMode: .recentActivity
        )

        #expect(sorted.map(\.displayName) == ["Neu", "Mitte", "Alt"])
    }

    private func makeBook(
        id: UUID,
        title: String = "Test Book",
        author: String = "Test Author",
        status: ReadingStatus = .toRead
    ) -> CollectionsDashboardBookSnapshot {
        CollectionsDashboardBookSnapshot(
            id: id,
            title: title,
            author: author,
            statusRawValue: status.rawValue
        )
    }

    private func makeCollection(
        id: UUID,
        name: String,
        createdAt: Date = Date(timeIntervalSince1970: 0),
        updatedAt: Date = Date(timeIntervalSince1970: 0),
        books: [CollectionsDashboardBookSnapshot]
    ) -> CollectionsDashboardCollectionSnapshot {
        CollectionsDashboardCollectionSnapshot(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            books: books
        )
    }

    private func makeEntry(
        id: UUID,
        name: String,
        bookCount: Int = 0,
        finished: Int = 0,
        updatedAt: Date = Date(timeIntervalSince1970: 0)
    ) -> CollectionsDashboardEntry {
        let counts = CollectionsDashboardStatusCounts(
            toRead: max(0, bookCount - finished),
            reading: 0,
            finished: finished,
            unknown: 0
        )

        return CollectionsDashboardEntry(
            id: id,
            name: name,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: updatedAt,
            bookCount: bookCount,
            statusCounts: counts,
            representativeBookIDs: []
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}

import Foundation
import Testing
@testable import Shelf_Notes

struct CollectionDetailBuilderTests {

    @Test func buildsHeaderStateAndStatusCounts() {
        let books = [
            makeBook(id: fixedID(1), title: "Finished", status: .finished),
            makeBook(id: fixedID(2), title: "Reading", status: .reading),
            makeBook(id: fixedID(3), title: "Planned", status: .toRead)
        ]

        let state = CollectionDetailBuilder.build(
            collectionName: " Urlaub ",
            books: books
        )

        #expect(state.displayName == "Urlaub")
        #expect(state.bookCount == 3)
        #expect(state.statusCounts.finished == 1)
        #expect(state.statusCounts.reading == 1)
        #expect(state.statusCounts.toRead == 1)
        #expect(state.statusCounts.progressFraction == 1.0 / 3.0)
        #expect(state.representativeBookIDs == [fixedID(1), fixedID(2), fixedID(3)])
    }

    @Test func filtersBySearchAndStatus() {
        let books = [
            makeBook(id: fixedID(1), title: "Dune", author: "Frank Herbert", status: .finished),
            makeBook(id: fixedID(2), title: "The Stand", author: "Stephen King", status: .reading),
            makeBook(id: fixedID(3), title: "Carrie", author: "Stephen King", status: .toRead)
        ]

        let searched = CollectionDetailBuilder.filteredBooks(
            books,
            searchText: "king",
            statusFilter: .all,
            sortMode: .title
        )
        let activeOnly = CollectionDetailBuilder.filteredBooks(
            books,
            searchText: "",
            statusFilter: .reading,
            sortMode: .title
        )

        #expect(searched.map(\.title) == ["Carrie", "The Stand"])
        #expect(activeOnly.map(\.title) == ["The Stand"])
    }

    @Test func sortsByStatusRatingAndReadDate() {
        let books = [
            makeBook(
                id: fixedID(1),
                title: "Finished Low",
                status: .finished,
                readTo: date(2026, 4, 1),
                rating: 3.0
            ),
            makeBook(
                id: fixedID(2),
                title: "Reading",
                status: .reading,
                rating: nil
            ),
            makeBook(
                id: fixedID(3),
                title: "Finished High",
                status: .finished,
                readTo: date(2026, 6, 1),
                rating: 4.5
            ),
            makeBook(
                id: fixedID(4),
                title: "Planned",
                status: .toRead,
                rating: nil
            )
        ]

        let byStatus = CollectionDetailBuilder.filteredBooks(
            books,
            searchText: "",
            statusFilter: .all,
            sortMode: .status
        )
        let byRating = CollectionDetailBuilder.filteredBooks(
            books,
            searchText: "",
            statusFilter: .all,
            sortMode: .rating
        )
        let byReadDate = CollectionDetailBuilder.filteredBooks(
            books,
            searchText: "",
            statusFilter: .all,
            sortMode: .readDate
        )

        #expect(byStatus.map(\.title) == ["Reading", "Planned", "Finished High", "Finished Low"])
        #expect(Array(byRating.map(\.title).prefix(2)) == ["Finished High", "Finished Low"])
        #expect(Array(byReadDate.map(\.title).prefix(2)) == ["Finished High", "Finished Low"])
    }

    @Test func emptyCollectionUsesFallbackNameAndNoProgress() {
        let state = CollectionDetailBuilder.build(collectionName: "   ", books: [])

        #expect(state.displayName == "Ohne Namen")
        #expect(state.isEmpty)
        #expect(state.statusCounts.total == 0)
        #expect(state.statusCounts.progressFraction == 0)
        #expect(state.representativeBookIDs.isEmpty)
    }

    private func makeBook(
        id: UUID,
        title: String = "Test Book",
        author: String = "Test Author",
        status: ReadingStatus = .toRead,
        createdAt: Date = Date(timeIntervalSince1970: 0),
        readFrom: Date? = nil,
        readTo: Date? = nil,
        rating: Double? = nil
    ) -> CollectionDetailBookSnapshot {
        CollectionDetailBookSnapshot(
            id: id,
            title: title,
            author: author,
            statusRawValue: status.rawValue,
            createdAt: createdAt,
            readFrom: readFrom,
            readTo: readTo,
            userRatingAverage: rating
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

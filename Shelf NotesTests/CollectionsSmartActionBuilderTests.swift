import Foundation
import Testing
@testable import Shelf_Notes

struct CollectionsSmartActionBuilderTests {

    @Test func hubActionsRecognizeUnassignedEmptyAndActiveCollections() {
        let finished = makeDashboardBook(id: fixedID(1), title: "Finished", status: .finished, rating: 4.0)
        let reading = makeDashboardBook(id: fixedID(2), title: "Reading", status: .reading)
        let unassigned = makeDashboardBook(id: fixedID(3), title: "Loose", status: .toRead)
        let activeCollection = makeDashboardCollection(
            id: fixedID(101),
            name: "Aktive Reihe",
            updatedAt: date(2026, 6, 1),
            books: [finished, reading]
        )
        let emptyCollection = makeDashboardCollection(
            id: fixedID(102),
            name: "Leer",
            updatedAt: date(2026, 5, 1),
            books: []
        )
        let dashboard = CollectionsDashboardBuilder.build(
            collections: [activeCollection, emptyCollection],
            allBooks: [finished, reading, unassigned]
        )

        let actions = CollectionsSmartActionBuilder.makeHubActions(
            dashboard: dashboard,
            collections: [activeCollection, emptyCollection],
            allBooks: [finished, reading, unassigned],
            limit: 5
        )

        #expect(actions.map(\.kind).contains(.unassignedBooks))
        #expect(actions.map(\.kind).contains(.emptyCollections))
        #expect(actions.map(\.kind).contains(.activeCollection))
        #expect(actions.first?.kind == .unassignedBooks)
        #expect(actions.first(where: { $0.kind == .emptyCollections })?.collectionID == fixedID(102))
        #expect(actions.first(where: { $0.kind == .activeCollection })?.collectionID == fixedID(101))
    }

    @Test func hubActionsRecognizeUnratedFinishedBooksInCollections() {
        let unrated = makeDashboardBook(id: fixedID(1), title: "Unrated", status: .finished, rating: nil)
        let rated = makeDashboardBook(id: fixedID(2), title: "Rated", status: .finished, rating: 4.2)
        let collection = makeDashboardCollection(
            id: fixedID(101),
            name: "Gelesen",
            books: [unrated, rated]
        )
        let dashboard = CollectionsDashboardBuilder.build(
            collections: [collection],
            allBooks: [unrated, rated]
        )

        let actions = CollectionsSmartActionBuilder.makeHubActions(
            dashboard: dashboard,
            collections: [collection],
            allBooks: [unrated, rated],
            limit: 5
        )
        let action = actions.first { $0.kind == .unratedFinishedBooks }

        #expect(action?.relatedBookIDs == [fixedID(1)])
        #expect(action?.collectionID == fixedID(101))
    }

    @Test func hubActionsSuggestTagClusterWhenItIsStable() {
        let books = [
            makeDashboardBook(id: fixedID(1), title: "A", tags: ["Thriller"]),
            makeDashboardBook(id: fixedID(2), title: "B", tags: ["thriller"]),
            makeDashboardBook(id: fixedID(3), title: "C", tags: [" Thriller "])
        ]
        let dashboard = CollectionsDashboardBuilder.build(collections: [], allBooks: books)

        let actions = CollectionsSmartActionBuilder.makeHubActions(
            dashboard: dashboard,
            collections: [],
            allBooks: books,
            limit: 5
        )

        #expect(actions.first(where: { $0.kind == .tagCluster })?.relatedBookIDs == books.map(\.id))
    }

    @Test func nextActionPrefersActiveBook() {
        let planned = makeDetailBook(id: fixedID(1), title: "Planned", status: .toRead)
        let active = makeDetailBook(
            id: fixedID(2),
            title: "Active",
            status: .reading,
            readFrom: date(2026, 6, 1)
        )
        let finishedUnrated = makeDetailBook(id: fixedID(3), title: "Finished", status: .finished, rating: nil)

        let action = CollectionsSmartActionBuilder.makeNextAction(
            collectionName: "Mix",
            books: [planned, active, finishedUnrated]
        )

        #expect(action?.kind == .continueReading)
        #expect(action?.bookID == fixedID(2))
    }

    @Test func nextActionHandlesEmptyPlannedUnratedAndCompletedStates() {
        let emptyAction = CollectionsSmartActionBuilder.makeNextAction(collectionName: "Leer", books: [])
        let plannedAction = CollectionsSmartActionBuilder.makeNextAction(
            collectionName: "Plan",
            books: [makeDetailBook(id: fixedID(1), title: "Next", status: .toRead)]
        )
        let unratedAction = CollectionsSmartActionBuilder.makeNextAction(
            collectionName: "Gelesen",
            books: [makeDetailBook(id: fixedID(2), title: "Done", status: .finished, rating: nil)]
        )
        let completedAction = CollectionsSmartActionBuilder.makeNextAction(
            collectionName: "Fertig",
            books: [makeDetailBook(id: fixedID(3), title: "Rated", status: .finished, rating: 4.5)]
        )

        #expect(emptyAction?.kind == .addBooks)
        #expect(plannedAction?.kind == .startPlannedBook)
        #expect(unratedAction?.kind == .rateFinishedBook)
        #expect(completedAction?.kind == .completed)
    }

    @Test func hubActionsReturnEmptyWhenNothingIsUseful() {
        let dashboard = CollectionsDashboardBuilder.build(collections: [], allBooks: [])
        let actions = CollectionsSmartActionBuilder.makeHubActions(
            dashboard: dashboard,
            collections: [],
            allBooks: [],
            limit: 5
        )

        #expect(actions.isEmpty)
    }

    private func makeDashboardBook(
        id: UUID,
        title: String = "Test Book",
        author: String = "Test Author",
        status: ReadingStatus = .toRead,
        tags: [String] = [],
        rating: Double? = nil
    ) -> CollectionsDashboardBookSnapshot {
        CollectionsDashboardBookSnapshot(
            id: id,
            title: title,
            author: author,
            statusRawValue: status.rawValue,
            tags: tags,
            userRatingAverage: rating
        )
    }

    private func makeDashboardCollection(
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

    private func makeDetailBook(
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

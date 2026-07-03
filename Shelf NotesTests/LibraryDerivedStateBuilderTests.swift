import Foundation
import Testing
@testable import Shelf_Notes

struct LibraryDerivedStateBuilderTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private func makeSource(
        _ books: [LibraryView.LibrarySourceSnapshot.BookSnapshot]
    ) -> LibraryView.LibrarySourceSnapshot {
        LibraryView.LibrarySourceSnapshot(
            signature: LibraryView.LibrarySourceSnapshot.computeSignature(snapshot: books),
            books: books
        )
    }

    @Test func filtersByStatusTagNotesAndSearchWhileKeepingGlobalCounts() {
        let matchingID = UUID()
        let books = [
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: matchingID,
                title: "Noir Nights",
                author: "Ada",
                createdAt: date(2026, 3, 1),
                statusRawValue: ReadingStatus.finished.rawValue,
                tags: ["Crime", "Noir"],
                hasNotes: true,
                isbn13: "978000000001",
                readFrom: date(2026, 2, 1),
                readTo: date(2026, 2, 3),
                userRatingAverage1: 4.4
            ),
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                title: "History of Rome",
                author: "Bea",
                createdAt: date(2026, 1, 1),
                statusRawValue: ReadingStatus.finished.rawValue,
                tags: ["History"],
                hasNotes: true,
                isbn13: "978000000002",
                readFrom: date(2026, 1, 2),
                readTo: date(2026, 1, 6),
                userRatingAverage1: 4.8
            ),
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                title: "Crime without notes",
                author: "Cara",
                createdAt: date(2026, 4, 1),
                statusRawValue: ReadingStatus.finished.rawValue,
                tags: ["Crime"],
                hasNotes: false,
                isbn13: "978000000003",
                readFrom: date(2026, 3, 1),
                readTo: date(2026, 3, 2),
                userRatingAverage1: 4.0
            ),
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                title: "Current Crime",
                author: "Dan",
                createdAt: date(2026, 5, 1),
                statusRawValue: ReadingStatus.reading.rawValue,
                tags: ["Crime"],
                hasNotes: true,
                isbn13: "978000000004"
            )
        ]

        let source = makeSource(books)
        let input = LibraryView.LibraryDerivedStateBuilder.makeInput(
            searchText: " noir ",
            selectedStatus: .finished,
            selectedTag: "crime",
            onlyWithNotes: true,
            sortField: .createdAt,
            sortAscending: false,
            buildsAlphaSections: false
        )

        let state = LibraryView.LibraryDerivedStateBuilder.makeDerivedState(source: source, input: input)

        #expect(state.displayedBookIDs == [matchingID])
        #expect(state.counts.toRead == 0)
        #expect(state.counts.reading == 1)
        #expect(state.counts.finished == 3)
        #expect(state.alphaSections.isEmpty)
    }

    @Test func sortsByRatingAndUsesReadDateThenIDAsTieBreaker() {
        let firstID = UUID()
        let secondID = UUID()
        let thirdID = UUID()

        let books = [
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: firstID,
                title: "First",
                createdAt: date(2026, 1, 1),
                statusRawValue: ReadingStatus.finished.rawValue,
                readFrom: date(2026, 1, 1),
                readTo: date(2026, 1, 10),
                userRatingAverage1: 4.5
            ),
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: secondID,
                title: "Second",
                createdAt: date(2026, 1, 2),
                statusRawValue: ReadingStatus.finished.rawValue,
                readFrom: date(2026, 1, 1),
                readTo: date(2026, 1, 12),
                userRatingAverage1: 4.5
            ),
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: thirdID,
                title: "Third",
                createdAt: date(2026, 1, 3),
                statusRawValue: ReadingStatus.finished.rawValue,
                readFrom: date(2026, 1, 1),
                readTo: date(2026, 1, 15),
                userRatingAverage1: nil
            )
        ]

        let state = LibraryView.LibraryDerivedStateBuilder.makeDerivedState(
            source: makeSource(books),
            input: LibraryView.LibraryDerivedStateBuilder.makeInput(
                searchText: "",
                selectedStatus: nil,
                selectedTag: nil,
                onlyWithNotes: false,
                sortField: .rating,
                sortAscending: false,
                buildsAlphaSections: false
            )
        )

        #expect(state.displayedBookIDs == [secondID, firstID, thirdID])
    }

    @Test func buildsAlphaSectionsFromTitleSortedBooks() {
        let alphaID = UUID()
        let betaID = UUID()
        let hashID = UUID()

        let books = [
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: hashID,
                title: "1Q84",
                createdAt: date(2026, 1, 3)
            ),
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: betaID,
                title: "Berlin",
                createdAt: date(2026, 1, 2)
            ),
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: alphaID,
                title: "Änne",
                createdAt: date(2026, 1, 1)
            )
        ]

        let state = LibraryView.LibraryDerivedStateBuilder.makeDerivedState(
            source: makeSource(books),
            input: LibraryView.LibraryDerivedStateBuilder.makeInput(
                searchText: "",
                selectedStatus: nil,
                selectedTag: nil,
                onlyWithNotes: false,
                sortField: .title,
                sortAscending: true,
                buildsAlphaSections: true
            )
        )

        #expect(state.alphaLetters == ["A", "B", "#"])
        #expect(state.alphaSections.map(\.key) == ["A", "B", "#"])
        #expect(state.alphaSections[0].bookIDs == [alphaID])
        #expect(state.alphaSections[1].bookIDs == [betaID])
        #expect(state.alphaSections[2].bookIDs == [hashID])
    }

    @Test func searchUsesPreparedSourceTokens() {
        let matchingID = UUID()
        let books = [
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: matchingID,
                title: "Visible Title",
                author: "Visible Author",
                createdAt: date(2026, 1, 1),
                searchTokens: ["prepared hidden crime token"]
            ),
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                title: "Another Title",
                author: "Another Author",
                createdAt: date(2026, 1, 2),
                searchTokens: ["prepared history token"]
            )
        ]
        let state = LibraryView.LibraryDerivedStateBuilder.makeDerivedState(
            source: makeSource(books),
            input: LibraryView.LibraryDerivedStateBuilder.makeInput(
                searchText: "Crime",
                selectedStatus: nil,
                selectedTag: nil,
                onlyWithNotes: false,
                sortField: .createdAt,
                sortAscending: true,
                buildsAlphaSections: false
            )
        )

        #expect(state.displayedBookIDs == [matchingID])
    }

    @Test func sourceSignatureIsOrderIndependentButChangesForRelevantMutations() {
        let first = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
            title: "Alpha",
            author: "Ada",
            createdAt: date(2026, 1, 1),
            statusRawValue: ReadingStatus.finished.rawValue,
            tags: ["Crime"],
            hasNotes: true,
            isbn13: "978000000001",
            readFrom: date(2026, 1, 1),
            readTo: date(2026, 1, 2),
            userRatingAverage1: 4.4
        )
        let second = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
            title: "Beta",
            author: "Bea",
            createdAt: date(2026, 1, 2),
            statusRawValue: ReadingStatus.reading.rawValue,
            tags: ["History"],
            hasNotes: false,
            isbn13: "978000000002"
        )
        let mutatedSecond = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            id: second.id,
            title: "Beta Revised",
            author: second.author,
            createdAt: second.createdAt,
            statusRawValue: second.statusRawValue,
            tags: second.tags,
            hasNotes: second.hasNotes,
            isbn13: second.isbn13,
            readFrom: second.readFrom,
            readTo: second.readTo,
            userRatingAverage1: second.userRatingAverage1
        )

        let original = LibraryView.LibrarySourceSnapshot.computeSignature(snapshot: [first, second])
        let reordered = LibraryView.LibrarySourceSnapshot.computeSignature(snapshot: [second, first])
        let mutated = LibraryView.LibrarySourceSnapshot.computeSignature(snapshot: [first, mutatedSecond])
        let wrapped = LibraryView.LibrarySourceSignature(bookSnapshots: [first, second])

        #expect(original == reordered)
        #expect(original != mutated)
        #expect(wrapped.rawValue == original)
    }

    @Test func sortsByActivityUsingSessionReadDatesAndCreatedDateFallback() {
        let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
        let readToID = UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()
        let readFromID = UUID(uuidString: "00000000-0000-0000-0000-000000000003") ?? UUID()
        let createdID = UUID(uuidString: "00000000-0000-0000-0000-000000000004") ?? UUID()
        let books = [
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: createdID,
                title: "Created fallback",
                createdAt: date(2026, 1, 4)
            ),
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: readFromID,
                title: "Read from fallback",
                createdAt: date(2026, 1, 1),
                readFrom: date(2026, 1, 5)
            ),
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: readToID,
                title: "Read to fallback",
                createdAt: date(2026, 1, 1),
                readTo: date(2026, 1, 6)
            ),
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: sessionID,
                title: "Session wins",
                createdAt: date(2026, 1, 1),
                readTo: date(2026, 1, 2),
                lastSessionAt: date(2026, 1, 7)
            )
        ]

        let descending = LibraryView.LibraryDerivedStateBuilder.makeDerivedState(
            source: makeSource(books),
            input: LibraryView.LibraryDerivedStateBuilder.makeInput(
                searchText: "",
                selectedStatus: nil,
                selectedTag: nil,
                onlyWithNotes: false,
                sortField: .activity,
                sortAscending: false,
                buildsAlphaSections: false
            )
        )
        let ascending = LibraryView.LibraryDerivedStateBuilder.makeDerivedState(
            source: makeSource(books),
            input: LibraryView.LibraryDerivedStateBuilder.makeInput(
                searchText: "",
                selectedStatus: nil,
                selectedTag: nil,
                onlyWithNotes: false,
                sortField: .activity,
                sortAscending: true,
                buildsAlphaSections: false
            )
        )

        #expect(descending.displayedBookIDs == [sessionID, readToID, readFromID, createdID])
        #expect(ascending.displayedBookIDs == [createdID, readFromID, readToID, sessionID])
    }

    @Test func filtersBySmartShelfMaintenanceStates() {
        let withoutCoverID = UUID(uuidString: "00000000-0000-0000-0000-000000000011") ?? UUID()
        let withoutTagsID = UUID(uuidString: "00000000-0000-0000-0000-000000000012") ?? UUID()
        let withoutPageCountID = UUID(uuidString: "00000000-0000-0000-0000-000000000013") ?? UUID()
        let unratedID = UUID(uuidString: "00000000-0000-0000-0000-000000000014") ?? UUID()
        let withNotesID = UUID(uuidString: "00000000-0000-0000-0000-000000000015") ?? UUID()
        let rereadID = UUID(uuidString: "00000000-0000-0000-0000-000000000016") ?? UUID()
        let books = [
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: withoutCoverID,
                title: "No cover",
                createdAt: date(2026, 1, 1),
                tags: ["Crime"],
                pageCount: 300,
                hasCover: false,
                coverRevision: 0,
                userRatingAverage1: 4.0
            ),
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: withoutTagsID,
                title: "No tags",
                createdAt: date(2026, 1, 2),
                tags: [],
                pageCount: 300,
                hasCover: true,
                coverRevision: 7,
                userRatingAverage1: 4.0
            ),
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: withoutPageCountID,
                title: "No page count",
                createdAt: date(2026, 1, 3),
                tags: ["History"],
                pageCount: nil,
                hasCover: true,
                coverRevision: 8,
                userRatingAverage1: 4.0
            ),
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: unratedID,
                title: "Unrated finished",
                createdAt: date(2026, 1, 4),
                statusRawValue: ReadingStatus.finished.rawValue,
                tags: ["Essay"],
                pageCount: 180,
                hasCover: true,
                coverRevision: 9,
                userRatingAverage1: nil
            ),
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: withNotesID,
                title: "With notes",
                createdAt: date(2026, 1, 5),
                tags: ["Notes"],
                hasNotes: true,
                pageCount: 220,
                hasCover: true,
                coverRevision: 10,
                userRatingAverage1: 3.8
            ),
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: rereadID,
                title: "Reread",
                createdAt: date(2026, 1, 6),
                tags: ["Favorite"],
                pageCount: 420,
                hasCover: true,
                coverRevision: 11,
                userRatingAverage1: 4.9,
                isRereading: true,
                completedReadingAttemptCount: 1
            )
        ]
        let source = makeSource(books)

        #expect(filteredIDs(source, smartFilter: .withoutCover) == [withoutCoverID])
        #expect(filteredIDs(source, smartFilter: .withoutTags) == [withoutTagsID])
        #expect(filteredIDs(source, smartFilter: .withoutPageCount) == [withoutPageCountID])
        #expect(filteredIDs(source, smartFilter: .unrated) == [unratedID])
        #expect(filteredIDs(source, smartFilter: .withNotes) == [withNotesID])
        #expect(filteredIDs(source, smartFilter: .rereads) == [rereadID])
    }

    @Test func longInactiveSmartFilterUsesProvidedCutoffDeterministically() {
        let inactiveID = UUID(uuidString: "00000000-0000-0000-0000-000000000021") ?? UUID()
        let activeID = UUID(uuidString: "00000000-0000-0000-0000-000000000022") ?? UUID()
        let finishedID = UUID(uuidString: "00000000-0000-0000-0000-000000000023") ?? UUID()
        let books = [
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: inactiveID,
                title: "Quiet current read",
                createdAt: date(2026, 1, 1),
                statusRawValue: ReadingStatus.reading.rawValue,
                lastSessionAt: date(2026, 1, 10)
            ),
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: activeID,
                title: "Fresh current read",
                createdAt: date(2026, 1, 1),
                statusRawValue: ReadingStatus.reading.rawValue,
                lastSessionAt: date(2026, 2, 10)
            ),
            LibraryView.LibrarySourceSnapshot.BookSnapshot(
                id: finishedID,
                title: "Old but finished",
                createdAt: date(2026, 1, 1),
                statusRawValue: ReadingStatus.finished.rawValue,
                lastSessionAt: date(2026, 1, 10)
            )
        ]
        let source = makeSource(books)
        let input = LibraryView.LibraryDerivedStateBuilder.makeInput(
            searchText: "",
            selectedStatus: nil,
            selectedTag: nil,
            onlyWithNotes: false,
            smartFilter: .longInactive,
            longInactiveCutoff: date(2026, 2, 1),
            sortField: .activity,
            sortAscending: false,
            buildsAlphaSections: false
        )

        let state = LibraryView.LibraryDerivedStateBuilder.makeDerivedState(source: source, input: input)

        #expect(state.displayedBookIDs == [inactiveID])
    }

    private func filteredIDs(
        _ source: LibraryView.LibrarySourceSnapshot,
        smartFilter: LibraryView.LibrarySmartFilter
    ) -> [UUID] {
        let input = LibraryView.LibraryDerivedStateBuilder.makeInput(
            searchText: "",
            selectedStatus: nil,
            selectedTag: nil,
            onlyWithNotes: false,
            smartFilter: smartFilter,
            sortField: .createdAt,
            sortAscending: true,
            buildsAlphaSections: false
        )
        return LibraryView.LibraryDerivedStateBuilder.makeDerivedState(
            source: source,
            input: input
        ).displayedBookIDs
    }

}

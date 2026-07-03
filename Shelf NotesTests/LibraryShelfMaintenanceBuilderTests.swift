import Foundation
import Testing
@testable import Shelf_Notes

struct LibraryShelfMaintenanceBuilderTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    @Test func countsShelfMaintenanceStates() {
        let books = [
            makeBook(
                id: fixedID(1),
                title: "No Cover",
                tags: ["Crime"],
                pageCount: 320,
                hasCover: false,
                hasUserRating: true,
                userRatingAverage1: 4.0
            ),
            makeBook(
                id: fixedID(2),
                title: "No Tags",
                tags: [],
                pageCount: 280,
                hasCover: true,
                coverRevision: 2,
                hasUserRating: true,
                userRatingAverage1: 4.0
            ),
            makeBook(
                id: fixedID(3),
                title: "No Pages",
                tags: ["Essay"],
                pageCount: nil,
                hasCover: true,
                coverRevision: 3,
                hasUserRating: true,
                userRatingAverage1: 4.0
            ),
            makeBook(
                id: fixedID(4),
                title: "Unrated Finished",
                status: .finished,
                tags: ["Done"],
                pageCount: 190,
                hasCover: true,
                coverRevision: 4,
                hasUserRating: false
            ),
            makeBook(
                id: fixedID(5),
                title: "Reread",
                tags: ["Favorite"],
                pageCount: 420,
                hasCover: true,
                coverRevision: 5,
                hasUserRating: true,
                userRatingAverage1: 4.8,
                isRereading: true,
                completedReadingAttemptCount: 1
            ),
            makeBook(
                id: fixedID(6),
                title: "Inactive Reading",
                status: .reading,
                tags: ["Slow"],
                pageCount: 260,
                lastSessionAt: date(2026, 1, 10),
                hasCover: true,
                coverRevision: 6,
                hasUserRating: false
            ),
            makeBook(
                id: fixedID(7),
                title: "Clean",
                status: .finished,
                tags: ["Clean"],
                pageCount: 300,
                hasCover: true,
                coverRevision: 7,
                hasUserRating: true,
                userRatingAverage1: 4.2
            )
        ]

        let summary = LibraryView.LibraryShelfMaintenanceBuilder.makeSummary(
            books: books,
            longInactiveCutoff: date(2026, 2, 1)
        )

        #expect(summary.count(for: .withoutCover) == 1)
        #expect(summary.count(for: .withoutTags) == 1)
        #expect(summary.count(for: .withoutPageCount) == 1)
        #expect(summary.count(for: .unrated) == 1)
        #expect(summary.count(for: .rereads) == 1)
        #expect(summary.count(for: .longInactive) == 1)
        #expect(summary.count(for: .withNotes) == 0)
        #expect(summary.items.map(\.smartFilter) == LibraryView.LibrarySmartFilter.maintenanceFilters)
    }

    @Test func hidesZeroCountItems() {
        let cleanBook = makeBook(
            id: fixedID(1),
            title: "Clean",
            status: .finished,
            tags: ["Clean"],
            pageCount: 300,
            hasCover: true,
            coverRevision: 1,
            hasUserRating: true,
            userRatingAverage1: 4.0
        )

        let summary = LibraryView.LibraryShelfMaintenanceBuilder.makeSummary(
            books: [cleanBook],
            longInactiveCutoff: date(2026, 2, 1)
        )

        #expect(summary.isEmpty)
        #expect(summary.totalCount == 0)
    }

    @Test func smartFilterResultsMatchMaintenanceCounts() {
        let books = [
            makeBook(id: fixedID(1), title: "No Cover", tags: ["Crime"], pageCount: 300, hasCover: false, coverRevision: 0),
            makeBook(id: fixedID(2), title: "No Tags", tags: [], pageCount: 240, hasCover: true, coverRevision: 2),
            makeBook(id: fixedID(3), title: "No Pages", tags: ["History"], pageCount: nil, hasCover: true, coverRevision: 3),
            makeBook(id: fixedID(4), title: "Unrated", status: .finished, tags: ["Done"], pageCount: 190, hasCover: true, coverRevision: 4, hasUserRating: false),
            makeBook(id: fixedID(5), title: "Inactive", status: .reading, tags: ["Slow"], pageCount: 260, lastSessionAt: date(2026, 1, 10), hasCover: true, coverRevision: 5)
        ]
        let source = LibraryView.LibrarySourceSnapshot(
            signature: LibraryView.LibrarySourceSnapshot.computeSignature(snapshot: books),
            books: books
        )
        let summary = LibraryView.LibraryShelfMaintenanceBuilder.makeSummary(
            source: source,
            longInactiveCutoff: date(2026, 2, 1)
        )

        for item in summary.items {
            let input = LibraryView.LibraryDerivedStateBuilder.makeInput(
                searchText: "",
                selectedStatus: nil,
                selectedTag: nil,
                onlyWithNotes: false,
                smartFilter: item.smartFilter,
                longInactiveCutoff: date(2026, 2, 1),
                sortField: .createdAt,
                sortAscending: true,
                buildsAlphaSections: false
            )
            let state = LibraryView.LibraryDerivedStateBuilder.makeDerivedState(source: source, input: input)

            #expect(state.displayedBookIDs.count == item.count)
        }
    }

    @Test func longInactiveRequiresDeterministicCutoff() {
        let inactive = makeBook(
            id: fixedID(1),
            title: "Inactive",
            status: .reading,
            lastSessionAt: date(2026, 1, 10)
        )
        let active = makeBook(
            id: fixedID(2),
            title: "Active",
            status: .reading,
            lastSessionAt: date(2026, 2, 10)
        )

        let withoutCutoff = LibraryView.LibraryShelfMaintenanceBuilder.makeSummary(
            books: [inactive, active],
            longInactiveCutoff: nil
        )
        let withCutoff = LibraryView.LibraryShelfMaintenanceBuilder.makeSummary(
            books: [inactive, active],
            longInactiveCutoff: date(2026, 2, 1)
        )

        #expect(withoutCutoff.count(for: .longInactive) == 0)
        #expect(withCutoff.count(for: .longInactive) == 1)
    }

    private func makeBook(
        id: UUID,
        title: String,
        status: ReadingStatus = .toRead,
        tags: [String] = [],
        hasNotes: Bool = false,
        pageCount: Int? = 300,
        lastSessionAt: Date? = nil,
        hasCover: Bool = true,
        coverRevision: Int = 1,
        hasUserRating: Bool = false,
        userRatingAverage1: Double? = nil,
        isRereading: Bool = false,
        completedReadingAttemptCount: Int = 0
    ) -> LibraryView.LibrarySourceSnapshot.BookSnapshot {
        let normalizedCoverRevision = hasCover ? coverRevision : 0

        return LibraryView.LibrarySourceSnapshot.BookSnapshot(
            id: id,
            title: title,
            statusRawValue: status.rawValue,
            tags: tags,
            hasNotes: hasNotes,
            pageCount: pageCount,
            lastSessionAt: lastSessionAt,
            hasCover: hasCover,
            coverRevision: normalizedCoverRevision,
            hasUserRating: hasUserRating,
            userRatingAverage1: userRatingAverage1,
            isRereading: isRereading,
            completedReadingAttemptCount: completedReadingAttemptCount
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
    }
}

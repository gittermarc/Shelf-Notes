import Foundation
import Testing
@testable import Shelf_Notes

struct TagsDashboardBuilderTests {

    @Test func buildsSummaryAndCountsUntaggedBooks() {
        let snapshots = [
            makeSnapshot(id: fixedID(1), status: .finished, tags: ["Crime", "Noir"]),
            makeSnapshot(id: fixedID(2), status: .reading, tags: ["crime", "History"]),
            makeSnapshot(id: fixedID(3), status: .toRead, tags: ["   ", ""]),
            makeSnapshot(id: fixedID(4), status: .finished, tags: ["#Noir"])
        ]

        let dashboard = TagsDashboardBuilder.build(snapshots: snapshots)

        #expect(dashboard.summary.totalBooks == 4)
        #expect(dashboard.summary.totalTags == 3)
        #expect(dashboard.summary.taggedBooksCount == 3)
        #expect(dashboard.summary.untaggedBooksCount == 1)
        #expect(dashboard.summary.topTag == TagsDashboardTopTag(tag: "Crime", count: 2))
        #expect(dashboard.untaggedBookIDs == [fixedID(3)])
    }

    @Test func statusCountsAreBuiltPerTag() {
        let snapshots = [
            makeSnapshot(id: fixedID(1), status: .finished, tags: ["Crime"]),
            makeSnapshot(id: fixedID(2), status: .reading, tags: ["Crime"]),
            makeSnapshot(id: fixedID(3), status: .toRead, tags: ["Crime"]),
            makeSnapshot(id: fixedID(4), status: .finished, tags: ["History"])
        ]

        let dashboard = TagsDashboardBuilder.build(snapshots: snapshots)
        let crime = dashboard.entries.first { $0.tag == "Crime" }

        #expect(crime?.bookCount == 3)
        #expect(crime?.statusCounts.finished == 1)
        #expect(crime?.statusCounts.reading == 1)
        #expect(crime?.statusCounts.toRead == 1)
    }

    @Test func filtersAndSortsEntries() {
        let entries = [
            TagsDashboardEntry(tag: "Crime", bookCount: 5, statusCounts: TagsDashboardStatusCounts()),
            TagsDashboardEntry(tag: "Noir", bookCount: 2, statusCounts: TagsDashboardStatusCounts()),
            TagsDashboardEntry(tag: "Cosy Crime", bookCount: 1, statusCounts: TagsDashboardStatusCounts())
        ]

        let searched = TagsDashboardBuilder.filteredEntries(
            entries,
            searchText: "crime",
            sortMode: .alphabetic
        )
        let leastUsed = TagsDashboardBuilder.filteredEntries(
            entries,
            searchText: "",
            sortMode: .leastUsed
        )

        #expect(searched.map(\.tag) == ["Cosy Crime", "Crime"])
        #expect(leastUsed.map(\.tag) == ["Cosy Crime", "Noir", "Crime"])
    }

    @Test func returnsBookIDsForMatchingTagCaseInsensitively() {
        let snapshots = [
            makeSnapshot(id: fixedID(1), tags: ["Crime"]),
            makeSnapshot(id: fixedID(2), tags: ["crime", "Noir"]),
            makeSnapshot(id: fixedID(3), tags: ["History"])
        ]

        let ids = TagsDashboardBuilder.bookIDs(matching: "#CRIME", snapshots: snapshots)

        #expect(ids == [fixedID(1), fixedID(2)])
    }

    @Test func relatedTagsAreCountedFromSharedBooks() {
        let snapshots = [
            makeSnapshot(id: fixedID(1), tags: ["Crime", "Noir", "NYC"]),
            makeSnapshot(id: fixedID(2), tags: ["crime", "Noir"]),
            makeSnapshot(id: fixedID(3), tags: ["Crime", "History"]),
            makeSnapshot(id: fixedID(4), tags: ["History", "Memoir"])
        ]

        let related = TagsDashboardBuilder.relatedTags(for: "Crime", snapshots: snapshots)

        #expect(related.map(\.tag) == ["Noir", "History", "NYC"])
        #expect(related.map(\.sharedBookCount) == [2, 1, 1])
    }

    @Test func untaggedDetectionUsesNormalizedTags() {
        let blank = makeSnapshot(id: fixedID(1), tags: [" ", "#"])
        let tagged = makeSnapshot(id: fixedID(2), tags: [" #Sci-Fi "])

        #expect(TagsDashboardBuilder.isUntagged(blank))
        #expect(!TagsDashboardBuilder.isUntagged(tagged))
    }

    private func makeSnapshot(
        id: UUID,
        title: String = "Test Book",
        author: String = "Test Author",
        status: ReadingStatus = .toRead,
        tags: [String]
    ) -> TagsDashboardBookSnapshot {
        TagsDashboardBookSnapshot(
            id: id,
            title: title,
            author: author,
            statusRawValue: status.rawValue,
            tags: tags
        )
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}

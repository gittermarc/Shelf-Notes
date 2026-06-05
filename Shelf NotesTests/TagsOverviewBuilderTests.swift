import Foundation
import Testing
@testable import Shelf_Notes

struct TagsOverviewBuilderTests {

    @Test func buildsDashboardHygieneAndVisibleEntriesFromSharedSnapshots() {
        let snapshots = [
            makeSnapshot(1, status: .finished, tags: ["Crime", "Noir"]),
            makeSnapshot(2, status: .reading, tags: ["crime", "History"]),
            makeSnapshot(3, status: .toRead, tags: []),
            makeSnapshot(4, status: .finished, tags: ["Sci-Fi"])
        ]

        let overview = TagsOverviewBuilder.build(
            snapshots: snapshots,
            searchText: "cri",
            sortMode: .alphabetic
        )
        let directDashboard = TagsDashboardBuilder.build(snapshots: snapshots)
        let directVisibleEntries = TagsDashboardBuilder.filteredEntries(
            directDashboard.entries,
            searchText: "cri",
            sortMode: .alphabetic
        )

        #expect(overview.dashboard.summary.totalBooks == directDashboard.summary.totalBooks)
        #expect(overview.dashboard.summary.totalTags == directDashboard.summary.totalTags)
        #expect(overview.dashboard.summary.taggedBooksCount == directDashboard.summary.taggedBooksCount)
        #expect(overview.dashboard.summary.untaggedBooksCount == directDashboard.summary.untaggedBooksCount)
        #expect(overview.dashboard.summary.topTag?.tag == directDashboard.summary.topTag?.tag)
        #expect(overview.dashboard.summary.topTag?.count == directDashboard.summary.topTag?.count)
        #expect(overview.dashboard.entries.map(\.tag) == directDashboard.entries.map(\.tag))
        #expect(overview.dashboard.entries.map(\.bookCount) == directDashboard.entries.map(\.bookCount))
        #expect(overview.dashboard.untaggedBookIDs == directDashboard.untaggedBookIDs)

        #expect(overview.hygieneReport.untaggedBookIDs == directDashboard.untaggedBookIDs)
        #expect(overview.hygieneReport.insights.map(\.kind) == [
            .formattingConflict,
            .singleUseTags,
            .untaggedBooks
        ])
        #expect(overview.hygieneReport.insights.first?.primaryTag == "Crime")
        #expect(Set(overview.hygieneReport.insights.first?.affectedTags ?? []) == Set(["Crime", "crime"]))
        #expect(overview.visibleEntries.map(\.tag) == directVisibleEntries.map(\.tag))
        #expect(overview.visibleEntries.map(\.bookCount) == directVisibleEntries.map(\.bookCount))
        #expect(overview.visibleEntries.map(\.tag) == ["Crime"])
    }

    @Test func reusesDashboardUntaggedBookIDsForHygieneReport() {
        let snapshots = [
            makeSnapshot(1, tags: ["Crime"]),
            makeSnapshot(2, tags: [" ", "#"]),
            makeSnapshot(3, tags: [])
        ]

        let overview = TagsOverviewBuilder.build(
            snapshots: snapshots,
            searchText: "",
            sortMode: .mostUsed
        )

        #expect(overview.dashboard.untaggedBookIDs == [fixedID(2), fixedID(3)])
        #expect(overview.hygieneReport.untaggedBookIDs == overview.dashboard.untaggedBookIDs)
        #expect(overview.dashboard.summary.untaggedBooksCount == 2)
    }

    private func makeSnapshot(
        _ value: Int,
        title: String = "Test Book",
        author: String = "Test Author",
        status: ReadingStatus = .toRead,
        tags: [String]
    ) -> TagsDashboardBookSnapshot {
        TagsDashboardBookSnapshot(
            id: fixedID(value),
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

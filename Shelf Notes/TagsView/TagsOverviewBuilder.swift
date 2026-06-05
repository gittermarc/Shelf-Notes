import Foundation

struct TagsOverview: Hashable {
    let dashboard: TagsDashboard
    let hygieneReport: TagHygieneReport
    let visibleEntries: [TagsDashboardEntry]
}

enum TagsOverviewBuilder {
    static func build(
        books: [Book],
        searchText: String,
        sortMode: TagsDashboardSortMode
    ) -> TagsOverview {
        build(
            snapshots: TagsDashboardBuilder.makeSnapshots(books: books),
            searchText: searchText,
            sortMode: sortMode
        )
    }

    static func build(
        snapshots: [TagsDashboardBookSnapshot],
        searchText: String,
        sortMode: TagsDashboardSortMode
    ) -> TagsOverview {
        let dashboard = TagsDashboardBuilder.build(snapshots: snapshots)
        let hygieneReport = TagHygieneBuilder.build(
            snapshots: snapshots,
            untaggedBookIDs: dashboard.untaggedBookIDs
        )
        let visibleEntries = TagsDashboardBuilder.filteredEntries(
            dashboard.entries,
            searchText: searchText,
            sortMode: sortMode
        )

        return TagsOverview(
            dashboard: dashboard,
            hygieneReport: hygieneReport,
            visibleEntries: visibleEntries
        )
    }
}

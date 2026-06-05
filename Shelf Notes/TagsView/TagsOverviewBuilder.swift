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
        build(
            index: TagsDomainIndex(snapshots: snapshots),
            searchText: searchText,
            sortMode: sortMode
        )
    }

    static func build(
        index: TagsDomainIndex,
        searchText: String,
        sortMode: TagsDashboardSortMode
    ) -> TagsOverview {
        let dashboard = TagsDashboardBuilder.build(index: index)
        let hygieneReport = TagHygieneBuilder.build(index: index)
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

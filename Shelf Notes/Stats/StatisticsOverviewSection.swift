import SwiftUI

struct StatisticsOverviewSection: View {
    let summary: StatisticsStatsCache.Summary?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        let overview = summary?.overview

        LazyVGrid(columns: columns, spacing: 10) {
            MetricCard(title: "Bücher", value: overview.map { "\($0.scopedBooksCount)" } ?? "–", systemImage: "books.vertical")
            MetricCard(title: "Gelesen", value: overview.map { "\($0.finishedScopedBooksCount)" } ?? "–", systemImage: "checkmark.seal")

            MetricCard(title: "Autoren", value: overview.map { "\($0.uniqueAuthorsCount)" } ?? "–", systemImage: "person.2")
            MetricCard(title: "Verlage", value: overview.map { "\($0.uniquePublishersCount)" } ?? "–", systemImage: "building.2")

            MetricCard(
                title: "Seiten (Jahr)",
                value: overview.map { StatisticsSectionFormatting.formatInt($0.pagesInSelectedYear) } ?? "–",
                systemImage: "doc.plaintext"
            )
            MetricCard(title: "Bücher (Jahr)", value: overview.map { "\($0.finishedInSelectedYearCount)" } ?? "–", systemImage: "calendar")

            MetricCard(title: "Ø Seiten/Buch", value: overview?.avgPagesPerBookText ?? "–", systemImage: "divide")
            MetricCard(title: "Ø Tage/Buch", value: overview?.avgDaysPerBookText ?? "–", systemImage: "clock")
        }
    }
}

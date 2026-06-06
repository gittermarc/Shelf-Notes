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
            MetricCard(title: "Abschlüsse", value: overview.map { "\($0.readingCompletionCount)" } ?? "–", systemImage: "checkmark.seal")

            MetricCard(title: "Gelesene Bücher", value: overview.map { "\($0.finishedScopedBooksCount)" } ?? "–", systemImage: "book.closed")
            MetricCard(title: "Re-Reads", value: overview.map { "\($0.rereadCompletionCount)" } ?? "–", systemImage: "arrow.triangle.2.circlepath")

            MetricCard(
                title: "Seiten (Jahr)",
                value: overview.map { StatisticsSectionFormatting.formatInt($0.pagesInSelectedYear) } ?? "–",
                systemImage: "doc.plaintext"
            )
            MetricCard(title: "Abschlüsse (Jahr)", value: overview.map { "\($0.finishedInSelectedYearCount)" } ?? "–", systemImage: "calendar")

            MetricCard(title: "Ø Seiten/Abschluss", value: overview?.avgPagesPerBookText ?? "–", systemImage: "divide")
            MetricCard(title: "Ø Tage/Abschluss", value: overview?.avgDaysPerBookText ?? "–", systemImage: "clock")
        }
    }
}

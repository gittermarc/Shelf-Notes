import SwiftUI

struct StatisticsTopListsSection: View {
    let cache: StatisticsStatsCache?
    let isUpdating: Bool

    var body: some View {
        StatisticsSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top-Listen")
                    .font(.headline)

                if cache == nil {
                    HStack(spacing: 8) {
                        if isUpdating {
                            ProgressView()
                                .controlSize(.mini)
                        }

                        Text("Berechne Top-Listen …")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if isEmpty {
                    Text("Noch nicht genug Metadaten — gib Büchern Kategorien/Verlage/Tags, dann wird’s hier richtig gut.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    if !topGenres.isEmpty {
                        StatisticsTopListDisclosureGroup(title: "Genres / Kategorien", items: topGenres, valueLabel: "Bücher")
                    }

                    if !topSubgenres.isEmpty {
                        StatisticsTopListDisclosureGroup(title: "Subgenres", items: topSubgenres, valueLabel: "Bücher")
                    }

                    if !topAuthors.isEmpty {
                        StatisticsTopListDisclosureGroup(title: "Autoren", items: topAuthors, valueLabel: "Bücher")
                    }

                    if !topPublishers.isEmpty {
                        StatisticsTopListDisclosureGroup(title: "Verlage", items: topPublishers, valueLabel: "Bücher")
                    }

                    if !topLanguages.isEmpty {
                        StatisticsTopListDisclosureGroup(title: "Sprachen", items: topLanguages, valueLabel: "Bücher")
                    }

                    if !topTags.isEmpty {
                        StatisticsTopListDisclosureGroup(title: "Tags", items: topTags, valueLabel: "Treffer")
                    }
                }
            }
        }
    }

    private var topGenres: [(label: String, count: Int)] { cache?.topGenres ?? [] }
    private var topSubgenres: [(label: String, count: Int)] { cache?.topSubgenres ?? [] }
    private var topAuthors: [(label: String, count: Int)] { cache?.topAuthors ?? [] }
    private var topPublishers: [(label: String, count: Int)] { cache?.topPublishers ?? [] }
    private var topLanguages: [(label: String, count: Int)] { cache?.topLanguages ?? [] }
    private var topTags: [(label: String, count: Int)] { cache?.topTags ?? [] }

    private var isEmpty: Bool {
        topGenres.isEmpty &&
        topSubgenres.isEmpty &&
        topAuthors.isEmpty &&
        topPublishers.isEmpty &&
        topLanguages.isEmpty &&
        topTags.isEmpty
    }
}

private struct StatisticsTopListDisclosureGroup: View {
    let title: String
    let items: [(label: String, count: Int)]
    let valueLabel: String

    var body: some View {
        DisclosureGroup(title) {
            TopListView(items: items, valueLabel: valueLabel)
        }
    }
}

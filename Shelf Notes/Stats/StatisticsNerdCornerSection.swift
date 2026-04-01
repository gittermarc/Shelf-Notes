import SwiftUI

struct StatisticsNerdCornerSection: View {
    let summary: StatisticsStatsCache.Summary?
    let cache: StatisticsStatsCache?
    let isUpdating: Bool

    var body: some View {
        StatisticsSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Nerd Corner")
                    .font(.headline)

                if cache == nil && isUpdating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("Aktualisiere Nerd-Stats …")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                NerdStatRow(title: "Schnellstes Buch", value: cache?.fastest?.label ?? "–", systemImage: "bolt")
                NerdStatRow(title: "Langsamstes Buch", value: cache?.slowest?.label ?? "–", systemImage: "tortoise")
                NerdStatRow(title: "Dickstes Buch", value: cache?.biggest?.label ?? "–", systemImage: "book.closed")
                NerdStatRow(title: "Bestbewertet", value: cache?.highestRated?.label ?? "–", systemImage: "star.bubble")

                if summary?.overview.finishedInSelectedYearCount == 0 {
                    Text("Für „Schnell/Langsam“ brauchst du bei gelesenen Büchern `Von/Bis`.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

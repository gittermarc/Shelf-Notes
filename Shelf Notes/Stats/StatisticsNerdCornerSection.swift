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
                        Text("Aktualisiere Nerd-Stats")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                NerdStatRow(title: "Schnellster Abschluss", value: cache?.fastest?.label ?? "–", systemImage: "bolt")
                NerdStatRow(title: "Langsamster Abschluss", value: cache?.slowest?.label ?? "–", systemImage: "tortoise")
                NerdStatRow(title: "Umfangreichster Abschluss", value: cache?.biggest?.label ?? "–", systemImage: "book.closed")
                NerdStatRow(title: "Bestbewertet", value: cache?.highestRated?.label ?? "–", systemImage: "star.bubble")

                if summary?.overview.finishedInSelectedYearCount == 0 {
                    Text("Für „Schnell/Langsam“ brauchen abgeschlossene Lesedurchgänge einen Zeitraum.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

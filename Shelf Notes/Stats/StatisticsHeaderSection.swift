import SwiftUI

struct StatisticsHeaderSection: View {
    let summary: StatisticsStatsCache.Summary?

    var body: some View {
        StatisticsSectionCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dein Lese-Dashboard")
                            .font(.title3.weight(.semibold))

                        Text(summary?.heroSubtitle ?? "Berechne Übersicht …")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "sparkline")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                if let teaser = summary?.tinyTeaserLine {
                    Text(teaser)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

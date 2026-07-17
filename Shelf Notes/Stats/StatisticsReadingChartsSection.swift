import SwiftUI

#if canImport(Charts)
import Charts
#endif

struct StatisticsReadingChartsSection: View {
    let selectedYear: Int
    let monthsCount: Int
    let series: [StatisticsMonthSeriesPoint]
    let isValid: Bool
    let isUpdating: Bool

    var body: some View {
        StatisticsSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Lesen pro Monat (\(selectedYear))")
                        .font(.headline)
                    Spacer()

                    if !isValid && isUpdating {
                        ProgressView()
                            .controlSize(.mini)
                    }

                    Text("\(monthsCount) Monate")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                if !isValid {
                    Text("Berechne Monats-Statistiken")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                #if canImport(Charts)
                Chart {
                    ForEach(series) { month in
                        BarMark(
                            x: .value("Monat", month.monthLabel),
                            y: .value("Abschlüsse", month.finishedCount)
                        )
                        .opacity(0.9)
                    }
                }
                .frame(height: 180)

                Divider().opacity(0.6)

                Chart {
                    ForEach(series) { month in
                        LineMark(
                            x: .value("Monat", month.monthLabel),
                            y: .value("Seiten", month.pages)
                        )
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Monat", month.monthLabel),
                            y: .value("Seiten", month.pages)
                        )
                        .opacity(0.12)
                    }
                }
                .frame(height: 160)
                #else
                VStack(alignment: .leading, spacing: 8) {
                    Text("Charts sind auf dieser Plattform nicht verfügbar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    let maxCompletions = series.map(\.finishedCount).max() ?? 1

                    ForEach(series) { month in
                        BarListRow(
                            title: month.monthLabel,
                            valueLeft: "\(month.finishedCount) Abschlüsse",
                            valueRight: "\(StatisticsSectionFormatting.formatInt(month.pages)) Seiten",
                            fraction: StatisticsSectionFormatting.fraction(month.finishedCount, maxValue: maxCompletions)
                        )
                    }
                }
                #endif

                Text("Seiten zählen nur bei seitenbasierten Lesedurchgängen. Prozentstände werden nicht addiert; Re-Reads zählen als eigene Abschlüsse.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

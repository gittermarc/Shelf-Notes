import SwiftUI

struct StatisticsActivityHeatmapSection: View {
    @Binding var activityMetric: StatisticsActivityMetric
    let stats: StatisticsHeatmapStats
    let weeks: [StatisticsHeatmapWeek]
    let hintText: String
    let isValid: Bool
    let isUpdating: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        StatisticsSectionCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Aktivität (Heatmap)")
                        .font(.headline)

                    Spacer()

                    Picker("Metrik", selection: $activityMetric) {
                        ForEach(StatisticsActivityMetric.allCases) { metric in
                            Text(metric.rawValue).tag(metric)
                        }
                    }
                    .pickerStyle(.menu)

                    if !isValid && isUpdating {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }

                if !isValid {
                    Text("Berechne Aktivitäts-Heatmap …")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    MetricCard(title: "Aktive Tage", value: "\(stats.activeDays)", systemImage: "calendar.badge.clock")
                    MetricCard(
                        title: "Max/Tag",
                        value: "\(StatisticsSectionFormatting.formatInt(stats.maxCount))\(activityMetric.unitSuffix)",
                        systemImage: "sparkles"
                    )

                    MetricCard(title: "Aktueller Streak", value: "\(stats.currentStreak) Tage", systemImage: "flame")
                    MetricCard(title: "Längster Streak", value: "\(stats.longestStreak) Tage", systemImage: "trophy")
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Bester Tag:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(stats.bestDayLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()

                        Spacer()

                        Text("Bester Wochentag:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(stats.bestWeekdayLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if stats.bestWeekLabel != "–" {
                        Text("Beste Woche: \(stats.bestWeekLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    WeekdayRail()
                        .padding(.top, 2)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 4) {
                            ForEach(weeks) { week in
                                VStack(spacing: 4) {
                                    ForEach(week.days) { day in
                                        HeatmapCellView(
                                            date: day.date,
                                            count: day.count,
                                            level: day.level,
                                            isInRange: day.isInRange,
                                            unitSuffix: activityMetric.unitSuffix
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 2)
                        .padding(.trailing, 2)
                    }
                }

                HeatmapLegend(maxCount: stats.maxCount, unitSuffix: activityMetric.unitSuffix)
                    .padding(.top, 2)

                Text(hintText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

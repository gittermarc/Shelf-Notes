import SwiftUI

extension StatisticsView {

    func headerCard(summary: StatisticsStatsCache.Summary?) -> some View {
        StatisticsHeaderSection(summary: summary)
    }

    func yearAndScopeCard(yearOptions: [Int]) -> some View {
        StatisticsControlsSection(
            yearOptions: yearOptions,
            selectedYear: $selectedYear,
            scope: $scope
        )
    }

    func overviewGrid(summary: StatisticsStatsCache.Summary?) -> some View {
        StatisticsOverviewSection(summary: summary)
    }

    func readingChartsCard(statsKey: StatisticsStatsCacheKey, cache: StatisticsStatsCache?) -> some View {
        let isValid = cache?.key == statsKey
        let effectiveCache = isValid ? cache : nil

        return StatisticsReadingChartsSection(
            selectedYear: selectedYear,
            monthsCount: effectiveCache?.monthsCount ?? fallbackMonthsCount(for: statsKey.selectedYear),
            series: effectiveCache?.monthlySeries ?? [],
            isValid: isValid,
            isUpdating: !isValid && isUpdatingStatsCache
        )
    }

    func activityHeatmapCard(heatmapKey: StatisticsHeatmapCacheKey, cache: StatisticsHeatmapCache?) -> some View {
        let isValid = cache?.key == heatmapKey
        let effectiveCache = isValid ? cache : nil
        let range = effectiveCache?.range ?? heatmapRange(for: heatmapKey.selectedYear)
        let stats = effectiveCache?.stats ?? StatisticsHeatmapStats(
            activeDays: 0,
            maxCount: 0,
            currentStreak: 0,
            longestStreak: 0,
            bestDayLabel: "–",
            bestWeekdayLabel: "–",
            bestWeekLabel: "–"
        )

        return StatisticsActivityHeatmapSection(
            activityMetric: $activityMetric,
            stats: stats,
            weeks: effectiveCache?.weeks ?? [],
            hintText: heatmapHintText(range: range),
            isValid: isValid,
            isUpdating: !isValid && isUpdatingHeatmapCache
        )
    }

    func topListsCard(cache: StatisticsStatsCache?) -> some View {
        StatisticsTopListsSection(
            cache: cache,
            isUpdating: isUpdatingStatsCache
        )
    }

    func nerdCornerCard(summary: StatisticsStatsCache.Summary?, cache: StatisticsStatsCache?) -> some View {
        StatisticsNerdCornerSection(
            summary: summary,
            cache: cache,
            isUpdating: isUpdatingStatsCache
        )
    }
}

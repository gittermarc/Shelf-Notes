import Foundation

nonisolated enum StatisticsScope: String, CaseIterable, Identifiable, Sendable {
    case all = "Alle"
    case finished = "Gelesen"
    case reading = "Lese ich"
    case toRead = "Will lesen"

    var id: String { rawValue }
}

nonisolated enum StatisticsActivityMetric: String, CaseIterable, Identifiable, Sendable {
    case readingDays = "Lesetage"
    case readingMinutes = "Leseminuten"
    case completions = "Abschlüsse"

    var id: String { rawValue }

    var unitSuffix: String {
        switch self {
        case .readingMinutes:
            return " min"
        case .readingDays, .completions:
            return ""
        }
    }
}

nonisolated struct StatisticsStatsCacheKey: Hashable, Sendable {
    let selectedYear: Int
    let scope: StatisticsScope
    let booksSignature: Int
}

nonisolated struct StatisticsHeatmapCacheKey: Hashable, Sendable {
    let selectedYear: Int
    let scope: StatisticsScope
    let activityMetric: StatisticsActivityMetric
    let booksSignature: Int
    let activitySignature: Int

    init(
        selectedYear: Int,
        scope: StatisticsScope,
        activityMetric: StatisticsActivityMetric,
        booksSignature: Int,
        activitySignature: Int? = nil
    ) {
        self.selectedYear = selectedYear
        self.scope = scope
        self.activityMetric = activityMetric
        self.booksSignature = booksSignature
        self.activitySignature = activitySignature ?? booksSignature
    }
}

nonisolated struct StatisticsMonthSeriesPoint: Identifiable, Equatable, Sendable {
    let id: String
    let monthLabel: String
    let finishedCount: Int
    let pages: Int
}

nonisolated struct StatisticsNerdPick: Equatable, Sendable {
    let label: String
    let sortKey: Int
}

nonisolated struct StatisticsHeatmapRange: Sendable {
    let start: Date
    let end: Date
    let gridStart: Date
    let gridEnd: Date
}

nonisolated struct StatisticsHeatmapDay: Identifiable, Sendable {
    let id: Date
    let date: Date
    let count: Int
    let level: Int
    let isInRange: Bool
}

nonisolated struct StatisticsHeatmapWeek: Identifiable, Sendable {
    let id: Int
    let days: [StatisticsHeatmapDay]
}

nonisolated struct StatisticsHeatmapStats: Sendable {
    let activeDays: Int
    let maxCount: Int
    let currentStreak: Int
    let longestStreak: Int
    let bestDayLabel: String
    let bestWeekdayLabel: String
    let bestWeekLabel: String
}

nonisolated struct StatisticsStatsCache: Sendable {
    nonisolated struct Summary: Sendable {
        nonisolated struct Overview: Sendable {
            let scopedBooksCount: Int
            let finishedScopedBooksCount: Int
            let uniqueAuthorsCount: Int
            let uniquePublishersCount: Int
            let pagesInSelectedYear: Int
            let finishedInSelectedYearCount: Int
            let avgPagesPerBookText: String
            let avgDaysPerBookText: String
        }

        let yearOptions: [Int]
        let heroSubtitle: String
        let tinyTeaserLine: String?
        let overview: Overview
    }

    let key: StatisticsStatsCacheKey
    let summary: Summary
    let monthsCount: Int
    let monthlySeries: [StatisticsMonthSeriesPoint]
    let topGenres: [(label: String, count: Int)]
    let topSubgenres: [(label: String, count: Int)]
    let topAuthors: [(label: String, count: Int)]
    let topPublishers: [(label: String, count: Int)]
    let topLanguages: [(label: String, count: Int)]
    let topTags: [(label: String, count: Int)]
    let fastest: StatisticsNerdPick?
    let slowest: StatisticsNerdPick?
    let biggest: StatisticsNerdPick?
    let highestRated: StatisticsNerdPick?
}

nonisolated struct StatisticsHeatmapCache: Sendable {
    let key: StatisticsHeatmapCacheKey
    let range: StatisticsHeatmapRange
    let counts: [Date: Int]
    let stats: StatisticsHeatmapStats
    let weeks: [StatisticsHeatmapWeek]
}

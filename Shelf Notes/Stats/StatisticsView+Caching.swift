import SwiftUI

extension StatisticsView {

    // MARK: - Caching

    /// A lightweight signature to invalidate cached aggregations when the underlying data changes.
    ///
    /// This is evaluated on every view update, so we keep it relatively cheap:
    /// - O(n) over books
    /// - O(tags+categories) per book (usually tiny)
    /// - **No** deep iteration over readingSessions durations
    func booksSignature(_ books: [Book]) -> Int {
        // PERF: The previous implementation sorted `books` by UUID to keep the signature deterministic.
        // Sorting is O(n log n) and can show up as UI hitching on frequent view updates.
        //
        // Instead we compute a per-book hash and aggregate it in an order-independent way (XOR + sum).
        // This keeps the signature stable even if SwiftData returns the array in a different order.

        func dayStamp(_ d: Date?) -> Int {
            guard let d else { return -1 }
            return Int(d.timeIntervalSince1970 / 86_400) // coarse day resolution
        }

        var finished = 0
        var reading = 0
        var toRead = 0
        var withReadDates = 0
        var pageSum = 0
        var tagTotal = 0
        var categoryTotal = 0

        var xorAgg: Int = 0
        var sumAgg: Int = 0

        for b in books {
            var h = Hasher()

            h.combine(b.id)
            h.combine(b.statusRawValue)

            h.combine(dayStamp(b.readFrom))
            h.combine(dayStamp(b.readTo))

            h.combine(b.pageCount ?? 0)
            h.combine(b.author)
            h.combine(b.publisher ?? "")
            h.combine(b.language ?? "")
            h.combine(b.mainCategory ?? "")

            // User ratings (6 criteria, 0 = not rated)
            h.combine(b.userRatingPlot)
            h.combine(b.userRatingCharacters)
            h.combine(b.userRatingWritingStyle)
            h.combine(b.userRatingAtmosphere)
            h.combine(b.userRatingGenreFit)
            h.combine(b.userRatingPresentation)

            // Order shouldn't matter.
            if !b.categories.isEmpty {
                for c in b.categories.sorted() { h.combine(c) }
            }
            if !b.tags.isEmpty {
                for t in b.tags.sorted() { h.combine(t) }
            }

            // We include only the session count (not durations) to keep this cheap.
            h.combine(b.readingSessionsSafe.count)

            let bookHash = h.finalize()
            xorAgg ^= bookHash
            sumAgg &+= bookHash

            switch b.status {
            case .finished: finished += 1
            case .reading: reading += 1
            case .toRead: toRead += 1
            }

            if b.readFrom != nil || b.readTo != nil { withReadDates += 1 }
            pageSum += (b.pageCount ?? 0)
            tagTotal += b.tags.count
            categoryTotal += b.categories.count
        }

        var hasher = Hasher()
        hasher.combine(books.count)
        hasher.combine(xorAgg)
        hasher.combine(sumAgg)

        hasher.combine(finished)
        hasher.combine(reading)
        hasher.combine(toRead)
        hasher.combine(withReadDates)
        hasher.combine(pageSum)
        hasher.combine(tagTotal)
        hasher.combine(categoryTotal)

        return hasher.finalize()
    }

    struct StatsCacheKey: Hashable {
        let selectedYear: Int
        let scope: Scope
        let booksSignature: Int
    }

    struct HeatmapCacheKey: Hashable {
        let selectedYear: Int
        let scope: Scope
        let activityMetric: ActivityMetric
        let booksSignature: Int
    }

    struct StatsCache {
        struct Summary {
            struct Overview {
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

        let key: StatsCacheKey
        let summary: Summary

        // Reading charts
        let monthsCount: Int
        let monthlySeries: [MonthSeriesPoint]

        // Top lists
        let topGenres: [(label: String, count: Int)]
        let topSubgenres: [(label: String, count: Int)]
        let topAuthors: [(label: String, count: Int)]
        let topPublishers: [(label: String, count: Int)]
        let topLanguages: [(label: String, count: Int)]
        let topTags: [(label: String, count: Int)]

        // Nerd corner
        let fastest: NerdPick?
        let slowest: NerdPick?
        let biggest: NerdPick?
        let highestRated: NerdPick?
    }

    struct HeatmapCache {
        let key: HeatmapCacheKey
        let range: HeatmapRange
        let counts: [Date: Int]
        let stats: HeatmapStats
        let weeks: [HeatmapWeek]
    }

    func makeStatsCacheKey(signature: Int) -> StatsCacheKey {
        StatsCacheKey(
            selectedYear: selectedYear,
            scope: scope,
            booksSignature: signature
        )
    }

    func makeHeatmapCacheKey(signature: Int) -> HeatmapCacheKey {
        HeatmapCacheKey(
            selectedYear: selectedYear,
            scope: scope,
            activityMetric: activityMetric,
            booksSignature: signature
        )
    }

    func makeStatsCacheKey() -> StatsCacheKey {
        makeStatsCacheKey(signature: booksSignature(books))
    }

    func makeHeatmapCacheKey() -> HeatmapCacheKey {
        makeHeatmapCacheKey(signature: booksSignature(books))
    }

    func computeStatsCache(for key: StatsCacheKey) -> StatsCache {
        let snapshots = books.map(StatisticsBookSnapshot.init)
        let builder = StatisticsSnapshotBuilder(now: Date(), calendar: Calendar.current)
        return builder.makeStatsCache(for: key, books: snapshots)
    }


    func computeHeatmapCache(for key: HeatmapCacheKey) -> HeatmapCache {
        let scoped: [Book]
        switch key.scope {
        case .all:
            scoped = books
        case .finished:
            scoped = books.filter { $0.status == .finished }
        case .reading:
            scoped = books.filter { $0.status == .reading }
        case .toRead:
            scoped = books.filter { $0.status == .toRead }
        }

        let range = heatmapRange(for: key.selectedYear)
        let counts = activityDailyCounts(metric: key.activityMetric, range: range, books: scoped)
        let stats = heatmapStats(counts: counts, range: range, metric: key.activityMetric, fallbackYear: key.selectedYear)
        let weeks = heatmapWeeks(counts: counts, range: range)

        return HeatmapCache(
            key: key,
            range: range,
            counts: counts,
            stats: stats,
            weeks: weeks
        )
    }

    // MARK: - Helpers (parameterized variants)

    func monthsForYear(_ year: Int) -> [MonthKey] {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        let currentMonth = cal.component(.month, from: Date())

        let maxMonth: Int
        if year < currentYear { maxMonth = 12 }
        else if year > currentYear { maxMonth = 12 }
        else { maxMonth = max(1, currentMonth) }

        return (1...maxMonth).map { MonthKey(year: year, month: $0) }
    }

}

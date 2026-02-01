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
        var hasher = Hasher()
        hasher.combine(books.count)

        func dayStamp(_ d: Date?) -> Int {
            guard let d else { return -1 }
            return Int(d.timeIntervalSince1970 / 86_400) // coarse day resolution
        }

        // Aggregate common fields that influence the visible stats.
        var finished = 0
        var reading = 0
        var toRead = 0
        var withReadDates = 0
        var pageSum = 0
        var tagTotal = 0
        var categoryTotal = 0

        // Deterministic order so signature doesn't fluctuate.
        for b in books.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            hasher.combine(b.id)
            hasher.combine(b.statusRawValue)

            hasher.combine(dayStamp(b.readFrom))
            hasher.combine(dayStamp(b.readTo))

            hasher.combine(b.pageCount ?? 0)
            hasher.combine(b.author)
            hasher.combine(b.publisher ?? "")
            hasher.combine(b.language ?? "")
            hasher.combine(b.mainCategory ?? "")

            // User ratings (6 criteria, 0 = not rated)
            hasher.combine(b.userRatingPlot)
            hasher.combine(b.userRatingCharacters)
            hasher.combine(b.userRatingWritingStyle)
            hasher.combine(b.userRatingAtmosphere)
            hasher.combine(b.userRatingGenreFit)
            hasher.combine(b.userRatingPresentation)

            // Order shouldn't matter.
            if !b.categories.isEmpty {
                for c in b.categories.sorted() { hasher.combine(c) }
            }
            if !b.tags.isEmpty {
                for t in b.tags.sorted() { hasher.combine(t) }
            }

            // We include only the session count (not durations) to keep this cheap.
            hasher.combine(b.readingSessionsSafe.count)

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
        let key: StatsCacheKey

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
        // 1) Scope + year slices
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

        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: key.selectedYear, month: 1, day: 1)) ?? Date.distantPast
        let end = cal.date(from: DateComponents(year: key.selectedYear + 1, month: 1, day: 1)) ?? Date.distantFuture

        let finishedInYear: [Book] = scoped.filter { b in
            guard b.status == .finished else { return false }
            guard let d = (b.readTo ?? b.readFrom) else { return false }
            return d >= start && d < end
        }

        // 2) Monthly charts
        let months = monthsForYear(key.selectedYear)
        let series = monthlySeriesFor(months: months, finishedBooks: finishedInYear)

        // 3) Top lists (use scoped books)
        let topGenres = topGenresList(scoped, limit: 8)
        let topSubgenres = topSubgenresList(scoped, limit: 8)
        let topAuthors = topAuthorsList(scoped, limit: 8)
        let topPublishers = topPublishersList(scoped, limit: 8)
        let topLanguages = topLanguagesList(scoped, limit: 8)
        let topTags = topTagsList(scoped, limit: 10)

        // 4) Nerd corner
        let fastest = fastestBook(finishedInYear)
        let slowest = slowestBook(finishedInYear)
        let biggest = biggestBook(finishedInYear)
        let highestRated = highestRatedBook(scoped)

        return StatsCache(
            key: key,
            monthsCount: months.count,
            monthlySeries: series,
            topGenres: topGenres,
            topSubgenres: topSubgenres,
            topAuthors: topAuthors,
            topPublishers: topPublishers,
            topLanguages: topLanguages,
            topTags: topTags,
            fastest: fastest,
            slowest: slowest,
            biggest: biggest,
            highestRated: highestRated
        )
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

    func monthlySeriesFor(months: [MonthKey], finishedBooks: [Book]) -> [MonthSeriesPoint] {
        let cal = Calendar.current
        var countBy: [MonthKey: Int] = [:]
        var pagesBy: [MonthKey: Int] = [:]

        for b in finishedBooks {
            guard let d = (b.readTo ?? b.readFrom) else { continue }
            let y = cal.component(.year, from: d)
            let m = cal.component(.month, from: d)
            let key = MonthKey(year: y, month: m)

            countBy[key, default: 0] += 1
            pagesBy[key, default: 0] += (b.pageCount ?? 0)
        }

        return months.map { mk in
            MonthSeriesPoint(
                id: mk.id,
                monthLabel: mk.monthLabel,
                finishedCount: countBy[mk, default: 0],
                pages: pagesBy[mk, default: 0]
            )
        }
    }
}

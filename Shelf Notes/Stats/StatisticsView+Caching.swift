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
        let scoped = scopedBooks(for: key.scope, in: books)
        let finishedInYear = finishedBooks(in: key.selectedYear, from: scoped)
        let summary = makeStatsSummary(allBooks: books, scopedBooks: scoped, finishedInYear: finishedInYear)

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
            summary: summary,
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

    func computeStatsSummary(for key: StatsCacheKey) -> StatsCache.Summary {
        let scoped = scopedBooks(for: key.scope, in: books)
        let finishedInYear = finishedBooks(in: key.selectedYear, from: scoped)
        return makeStatsSummary(allBooks: books, scopedBooks: scoped, finishedInYear: finishedInYear)
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

    func makeStatsSummary(
        allBooks: [Book],
        scopedBooks: [Book],
        finishedInYear: [Book]
    ) -> StatsCache.Summary {
        let scopedCount = scopedBooks.count
        let finishedScopedCount = scopedBooks.reduce(into: 0) { partial, book in
            if book.status == .finished { partial += 1 }
        }
        let scopedPages = totalPages(scopedBooks)
        let uniqueAuthorsCount = uniqueAuthors(scopedBooks).count
        let uniquePublishersCount = uniquePublishers(scopedBooks).count
        let pagesInSelectedYear = totalPages(finishedInYear)
        let avgPagesPerBook = avgPagesPerBookText(for: finishedInYear)
        let avgDaysPerBook = avgDaysPerBookText(for: finishedInYear)
        let avgPagesPerDay = avgPagesPerDayText(for: finishedInYear)

        let tinyTeaserLine: String?
        if finishedInYear.count >= 2, avgPagesPerBook != "–" || avgDaysPerBook != "–" || avgPagesPerDay != "–" {
            if avgPagesPerDay == "–" && avgDaysPerBook == "–" {
                tinyTeaserLine = nil
            } else {
                tinyTeaserLine = "Ø \(avgPagesPerDay) Seiten/Tag • Ø \(avgDaysPerBook) Tage/Buch (für „Gelesen“ mit Zeitraum)"
            }
        } else {
            tinyTeaserLine = nil
        }

        return StatsCache.Summary(
            yearOptions: availableYears(from: allBooks),
            heroSubtitle: "\(scopedCount) Bücher • \(finishedScopedCount) gelesen • \(formatInt(scopedPages)) Seiten (wo vorhanden)",
            tinyTeaserLine: tinyTeaserLine,
            overview: StatsCache.Summary.Overview(
                scopedBooksCount: scopedCount,
                finishedScopedBooksCount: finishedScopedCount,
                uniqueAuthorsCount: uniqueAuthorsCount,
                uniquePublishersCount: uniquePublishersCount,
                pagesInSelectedYear: pagesInSelectedYear,
                finishedInSelectedYearCount: finishedInYear.count,
                avgPagesPerBookText: avgPagesPerBook,
                avgDaysPerBookText: avgDaysPerBook
            )
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

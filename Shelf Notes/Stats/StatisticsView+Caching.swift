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
        func dayStamp(_ date: Date?) -> Int {
            guard let date else { return -1 }
            return Int(date.timeIntervalSince1970 / 86_400)
        }

        var finished = 0
        var reading = 0
        var toRead = 0
        var withReadDates = 0
        var pageSum = 0
        var tagTotal = 0
        var categoryTotal = 0

        var xorAggregate = 0
        var sumAggregate = 0

        for book in books {
            var hasher = Hasher()
            hasher.combine(book.id)
            hasher.combine(book.statusRawValue)
            hasher.combine(dayStamp(book.readFrom))
            hasher.combine(dayStamp(book.readTo))
            hasher.combine(book.pageCount ?? 0)
            hasher.combine(book.author)
            hasher.combine(book.publisher ?? "")
            hasher.combine(book.language ?? "")
            hasher.combine(book.mainCategory ?? "")
            hasher.combine(book.userRatingPlot)
            hasher.combine(book.userRatingCharacters)
            hasher.combine(book.userRatingWritingStyle)
            hasher.combine(book.userRatingAtmosphere)
            hasher.combine(book.userRatingGenreFit)
            hasher.combine(book.userRatingPresentation)

            if !book.categories.isEmpty {
                for category in book.categories.sorted() {
                    hasher.combine(category)
                }
            }

            if !book.tags.isEmpty {
                for tag in book.tags.sorted() {
                    hasher.combine(tag)
                }
            }

            hasher.combine(book.readingSessionsSafe.count)

            let bookHash = hasher.finalize()
            xorAggregate ^= bookHash
            sumAggregate &+= bookHash

            switch book.status {
            case .finished:
                finished += 1
            case .reading:
                reading += 1
            case .toRead:
                toRead += 1
            }

            if book.readFrom != nil || book.readTo != nil {
                withReadDates += 1
            }
            pageSum += book.pageCount ?? 0
            tagTotal += book.tags.count
            categoryTotal += book.categories.count
        }

        var signatureHasher = Hasher()
        signatureHasher.combine(books.count)
        signatureHasher.combine(xorAggregate)
        signatureHasher.combine(sumAggregate)
        signatureHasher.combine(finished)
        signatureHasher.combine(reading)
        signatureHasher.combine(toRead)
        signatureHasher.combine(withReadDates)
        signatureHasher.combine(pageSum)
        signatureHasher.combine(tagTotal)
        signatureHasher.combine(categoryTotal)

        return signatureHasher.finalize()
    }

    struct StatsCacheKey: Hashable, Sendable {
        let selectedYear: Int
        let scope: Scope
        let booksSignature: Int
    }

    struct HeatmapCacheKey: Hashable, Sendable {
        let selectedYear: Int
        let scope: Scope
        let activityMetric: ActivityMetric
        let booksSignature: Int
    }

    struct StatsCache: Sendable {
        struct Summary: Sendable {
            struct Overview: Sendable {
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
        let monthsCount: Int
        let monthlySeries: [MonthSeriesPoint]
        let topGenres: [(label: String, count: Int)]
        let topSubgenres: [(label: String, count: Int)]
        let topAuthors: [(label: String, count: Int)]
        let topPublishers: [(label: String, count: Int)]
        let topLanguages: [(label: String, count: Int)]
        let topTags: [(label: String, count: Int)]
        let fastest: NerdPick?
        let slowest: NerdPick?
        let biggest: NerdPick?
        let highestRated: NerdPick?
    }

    struct HeatmapCache: Sendable {
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

    func currentSourceSnapshot(for signature: Int) -> StatisticsSourceSnapshot {
        if let sourceSnapshot, sourceSnapshot.booksSignature == signature {
            return sourceSnapshot
        }

        let snapshot = StatisticsSourceSnapshot(signature: signature, books: books)
        sourceSnapshot = snapshot
        return snapshot
    }

    func makeComputePipeline(for source: StatisticsSourceSnapshot) -> StatisticsComputePipeline {
        StatisticsComputePipeline(source: source, now: Date(), calendar: Calendar.current)
    }

    func monthsForYear(_ year: Int) -> [MonthKey] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let currentMonth = calendar.component(.month, from: Date())

        let maxMonth: Int
        if year < currentYear {
            maxMonth = 12
        } else if year > currentYear {
            maxMonth = 12
        } else {
            maxMonth = max(1, currentMonth)
        }

        return (1...maxMonth).map { MonthKey(year: year, month: $0) }
    }
}

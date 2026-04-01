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

    func makeStatsCacheKey(signature: Int) -> StatisticsStatsCacheKey {
        StatisticsStatsCacheKey(
            selectedYear: selectedYear,
            scope: scope,
            booksSignature: signature
        )
    }

    func makeHeatmapCacheKey(signature: Int) -> StatisticsHeatmapCacheKey {
        StatisticsHeatmapCacheKey(
            selectedYear: selectedYear,
            scope: scope,
            activityMetric: activityMetric,
            booksSignature: signature
        )
    }


    func resolvedStatsCache(for key: StatisticsStatsCacheKey) -> StatisticsStatsCache? {
        guard let statsCache, statsCache.key == key else { return nil }
        return statsCache
    }

    func resolvedStatsCacheForCurrentBooks(signature: Int) -> StatisticsStatsCache? {
        guard let statsCache, statsCache.key.booksSignature == signature else { return nil }
        return statsCache
    }

    func resolvedScopeStatsCache(signature: Int) -> StatisticsStatsCache? {
        guard let statsCache,
              statsCache.key.scope == scope,
              statsCache.key.booksSignature == signature else {
            return nil
        }
        return statsCache
    }

    func resolvedHeatmapCache(for key: StatisticsHeatmapCacheKey) -> StatisticsHeatmapCache? {
        guard let heatmapCache, heatmapCache.key == key else { return nil }
        return heatmapCache
    }

    func availableYearOptions(signature: Int) -> [Int] {
        resolvedStatsCacheForCurrentBooks(signature: signature)?.summary.yearOptions ?? [selectedYear]
    }

    func fallbackMonthsCount(for year: Int) -> Int {
        StatisticsMonthAxisBuilder
            .months(for: year, now: Date(), calendar: Calendar.current)
            .count
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
}

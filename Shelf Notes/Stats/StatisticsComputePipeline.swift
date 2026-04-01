import Foundation

struct StatisticsSourceSnapshot: Sendable {
    let booksSignature: Int
    let books: [StatisticsBookSnapshot]

    init(signature: Int, books: [Book]) {
        self.booksSignature = signature
        self.books = books.map(StatisticsBookSnapshot.init)
    }

    init(booksSignature: Int, books: [StatisticsBookSnapshot]) {
        self.booksSignature = booksSignature
        self.books = books
    }
}

struct StatisticsComputePipeline {
    let source: StatisticsSourceSnapshot
    let now: Date
    let calendar: Calendar

    init(
        source: StatisticsSourceSnapshot,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.source = source
        self.now = now
        self.calendar = calendar
    }

    func makeStatsCache(
        for key: StatisticsView.StatsCacheKey
    ) async -> StatisticsView.StatsCache {
        let source = source
        let now = now
        let calendar = calendar

        let task = Task.detached(priority: .utility) {
            let builder = StatisticsSnapshotBuilder(now: now, calendar: calendar)
            return builder.makeStatsCache(for: key, books: source.books)
        }

        return await withTaskCancellationHandler(operation: {
            await task.value
        }, onCancel: {
            task.cancel()
        })
    }

    func makeHeatmapCache(
        for key: StatisticsView.HeatmapCacheKey
    ) async -> StatisticsView.HeatmapCache {
        let source = source
        let now = now
        let calendar = calendar

        let task = Task.detached(priority: .utility) {
            let builder = StatisticsHeatmapBuilder(now: now, calendar: calendar)
            return builder.makeHeatmapCache(for: key, books: source.books)
        }

        return await withTaskCancellationHandler(operation: {
            await task.value
        }, onCancel: {
            task.cancel()
        })
    }
}

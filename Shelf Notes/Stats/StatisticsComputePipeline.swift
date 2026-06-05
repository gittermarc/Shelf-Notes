import Foundation

nonisolated struct StatisticsSourceSnapshot: Sendable {
    let booksSignature: Int
    let books: [StatisticsBookSnapshot]

    @MainActor init(signature: Int, books: [Book]) {
        self.booksSignature = signature
        self.books = books.map { StatisticsBookSnapshot(book: $0) }
    }

    init(booksSignature: Int, books: [StatisticsBookSnapshot]) {
        self.booksSignature = booksSignature
        self.books = books
    }
}

nonisolated struct StatisticsSessionSourceSnapshot: Sendable {
    let booksSignature: Int
    let sessionsSignature: Int
    let sessionBooks: [StatisticsSessionBookSnapshot]

    @MainActor init(booksSignature: Int, sessionsSignature: Int, books: [Book]) {
        self.booksSignature = booksSignature
        self.sessionsSignature = sessionsSignature
        self.sessionBooks = books.map { StatisticsSessionBookSnapshot(book: $0) }
    }

    init(
        booksSignature: Int,
        sessionsSignature: Int,
        sessionBooks: [StatisticsSessionBookSnapshot]
    ) {
        self.booksSignature = booksSignature
        self.sessionsSignature = sessionsSignature
        self.sessionBooks = sessionBooks
    }
}

nonisolated struct StatisticsComputePipeline {
    let source: StatisticsSourceSnapshot
    let sessionSource: StatisticsSessionSourceSnapshot?
    let now: Date
    let calendar: Calendar

    init(
        source: StatisticsSourceSnapshot,
        sessionSource: StatisticsSessionSourceSnapshot? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.source = source
        self.sessionSource = sessionSource
        self.now = now
        self.calendar = calendar
    }

    func makeStatsCache(
        for key: StatisticsStatsCacheKey
    ) async -> StatisticsStatsCache {
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
        for key: StatisticsHeatmapCacheKey
    ) async -> StatisticsHeatmapCache {
        let source = source
        let sessionSource = sessionSource
        let now = now
        let calendar = calendar

        let task = Task.detached(priority: .utility) {
            let builder = StatisticsHeatmapBuilder(now: now, calendar: calendar)
            return builder.makeHeatmapCache(
                for: key,
                books: source.books,
                sessionBooks: sessionSource?.sessionBooks ?? []
            )
        }

        return await withTaskCancellationHandler(operation: {
            await task.value
        }, onCancel: {
            task.cancel()
        })
    }
}

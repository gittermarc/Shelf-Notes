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
    let scopeSignature: Int
    let sessionsSignature: Int
    let sessionBooks: [StatisticsSessionBookSnapshot]
    let aggregates: ReadingSessionAggregateSnapshot

    @MainActor init(
        booksSignature: Int,
        scopeSignature: Int? = nil,
        sessionsSignature: Int,
        books: [Book],
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.booksSignature = booksSignature
        self.scopeSignature = scopeSignature ?? StatisticsSourceStore.sessionScopeSignature(books)
        self.sessionsSignature = sessionsSignature
        let sessionBooks = books.map { StatisticsSessionBookSnapshot(book: $0) }
        self.sessionBooks = sessionBooks
        self.aggregates = Self.makeAggregates(
            sessionBooks: sessionBooks,
            now: now,
            calendar: calendar
        )
    }

    init(
        booksSignature: Int,
        scopeSignature: Int? = nil,
        sessionsSignature: Int,
        sessionBooks: [StatisticsSessionBookSnapshot],
        aggregates: ReadingSessionAggregateSnapshot? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.booksSignature = booksSignature
        self.scopeSignature = scopeSignature ?? booksSignature
        self.sessionsSignature = sessionsSignature
        self.sessionBooks = sessionBooks
        self.aggregates = aggregates ?? Self.makeAggregates(
            sessionBooks: sessionBooks,
            now: now,
            calendar: calendar
        )
    }

    func rebased(booksSignature: Int) -> StatisticsSessionSourceSnapshot {
        StatisticsSessionSourceSnapshot(
            booksSignature: booksSignature,
            scopeSignature: scopeSignature,
            sessionsSignature: sessionsSignature,
            sessionBooks: sessionBooks,
            aggregates: aggregates
        )
    }

    static func makeAggregates(
        sessionBooks: [StatisticsSessionBookSnapshot],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ReadingSessionAggregateSnapshot {
        let records = sessionBooks.flatMap { book in
            book.readingSessions.map { session in
                ReadingSessionAggregateRecord(
                    id: session.id,
                    bookID: book.bookID,
                    statusRawValue: book.statusRawValue,
                    hasCompletedReading: book.hasCompletedReading,
                    startedAt: session.startedAt,
                    endedAt: session.endedAt,
                    durationSeconds: session.durationSeconds,
                    pagesRead: session.pagesRead,
                    createdAt: session.createdAt
                )
            }
        }
        return ReadingSessionAggregateBuilder.make(
            records: records,
            now: now,
            calendar: calendar
        )
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
                sessionBooks: sessionSource?.sessionBooks ?? [],
                sessionAggregates: sessionSource?.aggregates
            )
        }

        return await withTaskCancellationHandler(operation: {
            await task.value
        }, onCancel: {
            task.cancel()
        })
    }
}

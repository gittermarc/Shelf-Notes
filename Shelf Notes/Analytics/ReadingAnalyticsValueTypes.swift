import Foundation

nonisolated struct ReadingAnalyticsBookRecord: Hashable, Sendable {
    let id: UUID
    let statusRawValue: String
    let createdAt: Date
    let readFrom: Date?
    let readTo: Date?
    let pageCount: Int?
    let readingCompletions: [ReadingCompletionRecord]

    init(
        id: UUID,
        statusRawValue: String,
        createdAt: Date,
        readFrom: Date?,
        readTo: Date?,
        pageCount: Int?,
        readingCompletions: [ReadingCompletionRecord]? = nil
    ) {
        self.id = id
        self.statusRawValue = statusRawValue
        self.createdAt = createdAt
        self.readFrom = readFrom
        self.readTo = readTo
        self.pageCount = pageCount
        self.readingCompletions = readingCompletions ?? ReadingAnalyticsBookRecord.legacyCompletions(
            id: id,
            statusRawValue: statusRawValue,
            createdAt: createdAt,
            readFrom: readFrom,
            readTo: readTo,
            pageCount: pageCount
        )
    }

    @MainActor init(book: Book) {
        self.init(
            id: book.id,
            statusRawValue: book.statusRawValue,
            createdAt: book.createdAt,
            readFrom: book.readFrom,
            readTo: book.readTo,
            pageCount: book.pageCount,
            readingCompletions: ReadingCompletionRecordBuilder.records(from: book)
        )
    }

    var isFinished: Bool {
        ReadingStatus.fromPersisted(statusRawValue) == .finished
    }

    var readKeyDate: Date? {
        readTo ?? readFrom
    }

    var normalizedPageCount: Int {
        max(0, pageCount ?? 0)
    }

    private static func legacyCompletions(
        id: UUID,
        statusRawValue: String,
        createdAt: Date,
        readFrom: Date?,
        readTo: Date?,
        pageCount: Int?
    ) -> [ReadingCompletionRecord] {
        guard let record = ReadingCompletionRecord.legacyRecord(
            bookID: id,
            title: "",
            author: "",
            createdAt: createdAt,
            statusRawValue: statusRawValue,
            readFrom: readFrom,
            readTo: readTo,
            pageCount: pageCount
        ) else {
            return []
        }
        return [record]
    }
}

nonisolated struct ReadingAnalyticsSessionRecord: Hashable, Sendable {
    let id: UUID
    let startedAt: Date
    let durationSeconds: Int
    let createdAt: Date
    let progressUnitRawValue: String
    let originRawValue: String

    init(
        id: UUID,
        startedAt: Date,
        durationSeconds: Int,
        createdAt: Date,
        progressUnitRawValue: String = ReadingProgressUnit.pages.rawValue,
        originRawValue: String = ReadingSessionOrigin.legacy.rawValue
    ) {
        self.id = id
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.createdAt = createdAt
        self.progressUnitRawValue = progressUnitRawValue
        self.originRawValue = originRawValue
    }

    @MainActor init(session: ReadingSession) {
        self.init(
            id: session.id,
            startedAt: session.startedAt,
            durationSeconds: session.durationSeconds,
            createdAt: session.createdAt,
            progressUnitRawValue: session.progressUnitRawValue,
            originRawValue: session.originRawValue
        )
    }

    var normalizedDurationSeconds: Int {
        metricContribution.durationSeconds
    }

    var metricContribution: ReadingMetricContribution {
        ReadingSessionMetricMapper.contribution(
            from: ReadingSessionMetricInput(
                startedAt: startedAt,
                durationSeconds: durationSeconds,
                pagesRead: nil,
                progressUnitRawValue: progressUnitRawValue,
                originRawValue: originRawValue
            )
        )
    }
}

nonisolated struct ReadingAnalyticsYearSummary: Equatable, Sendable {
    let year: Int
    let finishedBookCount: Int
    let uniqueFinishedBookCount: Int
    let rereadCompletionCount: Int
    let pagesRead: Int
    let pageBasedCompletionCount: Int
    let nonPageCompletionCount: Int
    let countedBooksWithPagesCount: Int
    let averagePagesPerBook: Int?
    let pagesByMonth: [Int: Int]

    static func empty(year: Int) -> ReadingAnalyticsYearSummary {
        ReadingAnalyticsYearSummary(
            year: year,
            finishedBookCount: 0,
            uniqueFinishedBookCount: 0,
            rereadCompletionCount: 0,
            pagesRead: 0,
            pageBasedCompletionCount: 0,
            nonPageCompletionCount: 0,
            countedBooksWithPagesCount: 0,
            averagePagesPerBook: nil,
            pagesByMonth: [:]
        )
    }
}

nonisolated struct ReadingAnalyticsRecentActivity: Equatable, Sendable {
    let minutesLast7: Int
    let activeDaysLast7: Int
    let currentStreak: Int

    static let empty = ReadingAnalyticsRecentActivity(
        minutesLast7: 0,
        activeDaysLast7: 0,
        currentStreak: 0
    )
}

nonisolated struct ReadingAnalyticsIndex: Equatable, Sendable {
    let finishedBookYears: [Int]
    let yearSummaries: [Int: ReadingAnalyticsYearSummary]
    let recentActivity: ReadingAnalyticsRecentActivity

    func summary(forYear year: Int) -> ReadingAnalyticsYearSummary {
        yearSummaries[year] ?? .empty(year: year)
    }
}

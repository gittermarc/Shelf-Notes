import Foundation

struct ReadingAnalyticsBookRecord: Hashable, Sendable {
    let id: UUID
    let statusRawValue: String
    let createdAt: Date
    let readFrom: Date?
    let readTo: Date?
    let pageCount: Int?

    init(
        id: UUID,
        statusRawValue: String,
        createdAt: Date,
        readFrom: Date?,
        readTo: Date?,
        pageCount: Int?
    ) {
        self.id = id
        self.statusRawValue = statusRawValue
        self.createdAt = createdAt
        self.readFrom = readFrom
        self.readTo = readTo
        self.pageCount = pageCount
    }

    init(book: Book) {
        self.init(
            id: book.id,
            statusRawValue: book.statusRawValue,
            createdAt: book.createdAt,
            readFrom: book.readFrom,
            readTo: book.readTo,
            pageCount: book.pageCount
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
}

struct ReadingAnalyticsSessionRecord: Hashable, Sendable {
    let id: UUID
    let startedAt: Date
    let durationSeconds: Int
    let createdAt: Date

    init(
        id: UUID,
        startedAt: Date,
        durationSeconds: Int,
        createdAt: Date
    ) {
        self.id = id
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.createdAt = createdAt
    }

    init(session: ReadingSession) {
        self.init(
            id: session.id,
            startedAt: session.startedAt,
            durationSeconds: session.durationSeconds,
            createdAt: session.createdAt
        )
    }

    var normalizedDurationSeconds: Int {
        max(0, durationSeconds)
    }
}

struct ReadingAnalyticsYearSummary: Equatable, Sendable {
    let year: Int
    let finishedBookCount: Int
    let pagesRead: Int
    let countedBooksWithPagesCount: Int
    let averagePagesPerBook: Int?
    let pagesByMonth: [Int: Int]

    static func empty(year: Int) -> ReadingAnalyticsYearSummary {
        ReadingAnalyticsYearSummary(
            year: year,
            finishedBookCount: 0,
            pagesRead: 0,
            countedBooksWithPagesCount: 0,
            averagePagesPerBook: nil,
            pagesByMonth: [:]
        )
    }
}

struct ReadingAnalyticsRecentActivity: Equatable, Sendable {
    let minutesLast7: Int
    let activeDaysLast7: Int
    let currentStreak: Int

    static let empty = ReadingAnalyticsRecentActivity(
        minutesLast7: 0,
        activeDaysLast7: 0,
        currentStreak: 0
    )
}

struct ReadingAnalyticsIndex: Equatable, Sendable {
    let finishedBookYears: [Int]
    let yearSummaries: [Int: ReadingAnalyticsYearSummary]
    let recentActivity: ReadingAnalyticsRecentActivity

    func summary(forYear year: Int) -> ReadingAnalyticsYearSummary {
        yearSummaries[year] ?? .empty(year: year)
    }
}

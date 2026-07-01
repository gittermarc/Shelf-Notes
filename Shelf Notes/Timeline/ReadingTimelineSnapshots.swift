import Foundation

nonisolated struct ReadingTimelineBookSnapshot: Hashable, Sendable, Identifiable {
    let id: UUID
    let title: String
    let author: String
    let createdAt: Date
    let statusRawValue: String
    let readFrom: Date?
    let readTo: Date?
    let pageCount: Int?
    let userRatingAverage: Double?
    let completions: [ReadingTimelineCompletionSnapshot]

    init(
        id: UUID,
        title: String,
        author: String,
        createdAt: Date,
        statusRawValue: String,
        readFrom: Date?,
        readTo: Date?,
        pageCount: Int?,
        userRatingAverage: Double?,
        completions: [ReadingTimelineCompletionSnapshot]
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.createdAt = createdAt
        self.statusRawValue = statusRawValue
        self.readFrom = readFrom
        self.readTo = readTo
        self.pageCount = pageCount
        self.userRatingAverage = userRatingAverage
        self.completions = completions
    }

    init(book: Book) {
        self.init(
            id: book.id,
            title: book.title,
            author: book.author,
            createdAt: book.createdAt,
            statusRawValue: book.statusRawValue,
            readFrom: book.readFrom,
            readTo: book.readTo,
            pageCount: book.pageCount,
            userRatingAverage: book.userRatingAverage,
            completions: ReadingCompletionRecordBuilder.records(from: book).map(ReadingTimelineCompletionSnapshot.init(record:))
        )
    }

    static func snapshots(from books: [Book]) -> [ReadingTimelineBookSnapshot] {
        books.map(ReadingTimelineBookSnapshot.init(book:))
    }
}

nonisolated struct ReadingTimelineCompletionSnapshot: Hashable, Sendable, Identifiable {
    let id: String
    let bookID: UUID
    let attemptID: UUID?
    let sequenceNumber: Int
    let title: String
    let author: String
    let startedAt: Date?
    let finishedAt: Date
    let pageCount: Int?
    let isReread: Bool
    let isLegacyFallback: Bool

    init(
        id: String,
        bookID: UUID,
        attemptID: UUID? = nil,
        sequenceNumber: Int,
        title: String,
        author: String,
        startedAt: Date?,
        finishedAt: Date,
        pageCount: Int?,
        isReread: Bool,
        isLegacyFallback: Bool = false
    ) {
        self.id = id
        self.bookID = bookID
        self.attemptID = attemptID
        self.sequenceNumber = max(1, sequenceNumber)
        self.title = title
        self.author = author
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.pageCount = ReadingCompletionRecord.normalizedPageCount(pageCount)
        self.isReread = isReread
        self.isLegacyFallback = isLegacyFallback
    }

    init(record: ReadingCompletionRecord) {
        self.init(
            id: record.id,
            bookID: record.bookID,
            attemptID: record.attemptID,
            sequenceNumber: record.sequenceNumber,
            title: record.title,
            author: record.author,
            startedAt: record.startedAt,
            finishedAt: record.finishedAt,
            pageCount: record.pageCount,
            isReread: record.isReread,
            isLegacyFallback: record.isLegacyFallback
        )
    }

    var normalizedPageCount: Int {
        max(0, pageCount ?? 0)
    }

    var displayName: String {
        "\(sequenceNumber). Durchgang"
    }

    var asCompletionRecord: ReadingCompletionRecord {
        ReadingCompletionRecord(
            id: id,
            bookID: bookID,
            attemptID: attemptID,
            sequenceNumber: sequenceNumber,
            title: title,
            author: author,
            startedAt: startedAt,
            finishedAt: finishedAt,
            pageCount: pageCount,
            isReread: isReread,
            isLegacyFallback: isLegacyFallback
        )
    }

    static func compare(_ lhs: ReadingTimelineCompletionSnapshot, _ rhs: ReadingTimelineCompletionSnapshot) -> Bool {
        if lhs.finishedAt != rhs.finishedAt {
            return lhs.finishedAt < rhs.finishedAt
        }
        if lhs.startedAt != rhs.startedAt {
            return (lhs.startedAt ?? .distantPast) < (rhs.startedAt ?? .distantPast)
        }
        if lhs.sequenceNumber != rhs.sequenceNumber {
            return lhs.sequenceNumber < rhs.sequenceNumber
        }
        if lhs.title.localizedCaseInsensitiveCompare(rhs.title) != .orderedSame {
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        if lhs.author.localizedCaseInsensitiveCompare(rhs.author) != .orderedSame {
            return lhs.author.localizedCaseInsensitiveCompare(rhs.author) == .orderedAscending
        }
        return lhs.id < rhs.id
    }
}

import Foundation

nonisolated struct ReadingCompletionRecord: Hashable, Sendable, Identifiable {
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

    var normalizedPageCount: Int {
        max(0, pageCount ?? 0)
    }

    var displayName: String {
        "\(sequenceNumber). Durchgang"
    }

    static func normalizedPageCount(_ raw: Int?) -> Int? {
        guard let raw, raw > 0 else { return nil }
        return raw
    }

    static func legacyRecord(
        bookID: UUID,
        title: String,
        author: String,
        createdAt: Date,
        statusRawValue: String,
        readFrom: Date?,
        readTo: Date?,
        pageCount: Int?,
        allowReadingStatusWithReadTo: Bool = false
    ) -> ReadingCompletionRecord? {
        let status = ReadingStatus.fromPersisted(statusRawValue)
        let hasFinishedStatus = status == .finished
        let hasReadingStatusWithPreviousFinish = allowReadingStatusWithReadTo && status == .reading && readTo != nil
        guard hasFinishedStatus || hasReadingStatusWithPreviousFinish else { return nil }
        guard let finishedAt = readTo ?? (hasFinishedStatus ? readFrom : nil) else { return nil }

        return ReadingCompletionRecord(
            id: "legacy-\(bookID.uuidString)-\(Int(finishedAt.timeIntervalSince1970.rounded()))",
            bookID: bookID,
            attemptID: nil,
            sequenceNumber: 1,
            title: title,
            author: author,
            startedAt: readFrom ?? createdAt,
            finishedAt: finishedAt,
            pageCount: pageCount,
            isReread: false,
            isLegacyFallback: true
        )
    }
}

nonisolated enum ReadingCompletionRecordBuilder {
    static func records(from books: [Book]) -> [ReadingCompletionRecord] {
        books.flatMap { records(from: $0) }
    }

    static func records(from book: Book) -> [ReadingCompletionRecord] {
        let attemptRecords = book.orderedReadingAttempts.compactMap { attempt in
            record(from: attempt, book: book)
        }

        if !attemptRecords.isEmpty {
            return attemptRecords.sorted(by: compare)
        }

        guard let legacy = ReadingCompletionRecord.legacyRecord(
            bookID: book.id,
            title: book.title,
            author: book.author,
            createdAt: book.createdAt,
            statusRawValue: book.statusRawValue,
            readFrom: book.readFrom,
            readTo: book.readTo,
            pageCount: book.pageCount,
            allowReadingStatusWithReadTo: book.activeReadingAttempt != nil
        ) else {
            return []
        }

        return [legacy]
    }

    static func compare(_ lhs: ReadingCompletionRecord, _ rhs: ReadingCompletionRecord) -> Bool {
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

    private static func record(from attempt: ReadingAttempt, book: Book) -> ReadingCompletionRecord? {
        guard attempt.status == .finished else { return nil }
        guard let finishedAt = attempt.finishedAt else { return nil }

        let pageCount = attempt.pageCountSnapshot ?? book.pageCount
        let sequenceNumber = max(1, attempt.sequenceNumber)

        return ReadingCompletionRecord(
            id: "attempt-\(attempt.id.uuidString)",
            bookID: book.id,
            attemptID: attempt.id,
            sequenceNumber: sequenceNumber,
            title: book.title,
            author: book.author,
            startedAt: attempt.startedAt ?? book.readFrom,
            finishedAt: finishedAt,
            pageCount: pageCount,
            isReread: sequenceNumber > 1,
            isLegacyFallback: false
        )
    }
}

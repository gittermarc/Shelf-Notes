//
//  LibraryWidgetSnapshotBuilder.swift
//  Shelf Notes
//
//  Pure snapshot builder for the future Library Home Screen widget.
//

import Foundation

nonisolated struct LibraryWidgetCompletionRecord: Hashable, Sendable {
    var id: String
    var bookID: UUID
    var sequenceNumber: Int
    var finishedAt: Date
    var pageCount: Int?
    var isReread: Bool

    init(
        id: String,
        bookID: UUID,
        sequenceNumber: Int = 1,
        finishedAt: Date,
        pageCount: Int? = nil,
        isReread: Bool = false
    ) {
        self.id = id
        self.bookID = bookID
        self.sequenceNumber = max(1, sequenceNumber)
        self.finishedAt = finishedAt
        self.pageCount = Self.normalizedPositiveInt(pageCount)
        self.isReread = isReread
    }

    private static func normalizedPositiveInt(_ raw: Int?) -> Int? {
        guard let raw, raw > 0 else { return nil }
        return raw
    }
}

nonisolated struct LibraryWidgetBookRecord: Hashable, Sendable {
    var id: UUID
    var title: String
    var author: String
    var statusRawValue: String
    var createdAt: Date
    var readFrom: Date?
    var readTo: Date?
    var pageCount: Int?
    var pagesRead: Int
    var lastSessionAt: Date?
    var hasCover: Bool
    var coverRevision: Int?
    var completions: [LibraryWidgetCompletionRecord]

    init(
        id: UUID,
        title: String,
        author: String = "",
        statusRawValue: String = ReadingStatus.toRead.rawValue,
        createdAt: Date,
        readFrom: Date? = nil,
        readTo: Date? = nil,
        pageCount: Int? = nil,
        pagesRead: Int = 0,
        lastSessionAt: Date? = nil,
        hasCover: Bool = false,
        coverRevision: Int? = nil,
        completions: [LibraryWidgetCompletionRecord] = []
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.statusRawValue = statusRawValue
        self.createdAt = createdAt
        self.readFrom = readFrom
        self.readTo = readTo
        self.pageCount = Self.normalizedPositiveInt(pageCount)
        self.pagesRead = max(0, pagesRead)
        self.lastSessionAt = lastSessionAt
        self.hasCover = hasCover
        self.coverRevision = Self.normalizedPositiveInt(coverRevision)
        self.completions = completions.sorted(by: Self.compareCompletionsAscending)
    }

    var status: ReadingStatus {
        ReadingStatus.fromPersisted(statusRawValue) ?? .toRead
    }

    var latestCompletionDate: Date? {
        completions.map(\.finishedAt).max()
    }

    var currentProgressFraction: Double? {
        if status == .finished {
            return 1.0
        }

        guard let pageCount, pageCount > 0 else { return nil }
        return min(1.0, max(0.0, Double(max(0, pagesRead)) / Double(pageCount)))
    }

    var remainingPages: Int? {
        guard let pageCount, pageCount > 0 else { return nil }
        if status == .finished {
            return 0
        }
        return max(0, pageCount - max(0, pagesRead))
    }

    func makeSnapshot(kind: LibraryWidgetShelfItemKind, referenceDate: Date?) -> LibraryWidgetBookSnapshot {
        let normalizedPagesRead: Int?
        if pagesRead > 0 {
            if let pageCount, pageCount > 0 {
                normalizedPagesRead = min(pagesRead, pageCount)
            } else {
                normalizedPagesRead = pagesRead
            }
        } else {
            normalizedPagesRead = status == .finished ? pageCount : nil
        }

        return LibraryWidgetBookSnapshot(
            id: id,
            title: title,
            author: author,
            kind: kind,
            statusRawValue: statusRawValue,
            pageCount: pageCount,
            pagesRead: normalizedPagesRead,
            remainingPages: remainingPages,
            progressFraction: currentProgressFraction,
            referenceDate: referenceDate,
            hasCover: hasCover,
            coverRevision: coverRevision
        )
    }

    private static func normalizedPositiveInt(_ raw: Int?) -> Int? {
        guard let raw, raw > 0 else { return nil }
        return raw
    }

    private static func compareCompletionsAscending(
        _ lhs: LibraryWidgetCompletionRecord,
        _ rhs: LibraryWidgetCompletionRecord
    ) -> Bool {
        if lhs.finishedAt != rhs.finishedAt {
            return lhs.finishedAt < rhs.finishedAt
        }
        if lhs.sequenceNumber != rhs.sequenceNumber {
            return lhs.sequenceNumber < rhs.sequenceNumber
        }
        return lhs.id < rhs.id
    }
}

nonisolated struct LibraryWidgetGoalRecord: Hashable, Sendable {
    var year: Int
    var targetCount: Int
    var updatedAt: Date

    init(year: Int, targetCount: Int, updatedAt: Date) {
        self.year = year
        self.targetCount = max(0, targetCount)
        self.updatedAt = updatedAt
    }
}

nonisolated struct LibraryWidgetSessionRecord: Hashable, Sendable {
    var id: UUID
    var startedAt: Date
    var durationSeconds: Int
    var createdAt: Date

    init(
        id: UUID,
        startedAt: Date,
        durationSeconds: Int,
        createdAt: Date
    ) {
        self.id = id
        self.startedAt = startedAt
        self.durationSeconds = max(0, durationSeconds)
        self.createdAt = createdAt
    }

    var analyticsRecord: ReadingAnalyticsSessionRecord {
        ReadingAnalyticsSessionRecord(
            id: id,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            createdAt: createdAt
        )
    }
}

nonisolated enum LibraryWidgetSnapshotBuilder {
    static let recentShelfItemLimit = 5

    static func make(
        books: [LibraryWidgetBookRecord],
        goals: [LibraryWidgetGoalRecord],
        sessions: [LibraryWidgetSessionRecord],
        activeBookID: UUID? = nil,
        generatedAt: Date = Date(),
        calendar: Calendar = .current
    ) -> LibraryWidgetSnapshot {
        let recentActivity = ReadingAnalyticsRecentActivityBuilder.make(
            sessions: sessions.map(\.analyticsRecord),
            now: generatedAt,
            calendar: calendar
        )

        return make(
            books: books,
            goals: goals,
            recentActivity: recentActivity,
            activeBookID: activeBookID,
            generatedAt: generatedAt,
            calendar: calendar
        )
    }

    static func make(
        books: [LibraryWidgetBookRecord],
        goals: [LibraryWidgetGoalRecord],
        recentActivity: ReadingAnalyticsRecentActivity,
        activeBookID: UUID? = nil,
        generatedAt: Date = Date(),
        calendar: Calendar = .current
    ) -> LibraryWidgetSnapshot {
        let normalizedBooks = books.sorted(by: compareBooksForStableInput)
        guard !normalizedBooks.isEmpty else {
            return .empty(generatedAt: generatedAt)
        }

        let totalBooks = normalizedBooks.count
        let readBooks = normalizedBooks.filter { $0.status == .finished }.count
        let readingBooks = normalizedBooks.filter { $0.status == .reading }.count
        let wantToReadBooks = normalizedBooks.filter { $0.status == .toRead }.count
        let currentYear = calendar.component(.year, from: generatedAt)
        let currentBook = selectCurrentBook(from: normalizedBooks, activeBookID: activeBookID)
        let currentBookSnapshot = currentBook?.makeSnapshot(
            kind: .currentReading,
            referenceDate: currentBook?.lastSessionAt ?? currentBook?.readFrom ?? currentBook?.createdAt
        )
        let yearlyGoal = makeYearlyGoal(
            from: goals,
            books: normalizedBooks,
            year: currentYear,
            calendar: calendar
        )
        let recentShelfItems = makeRecentShelfItems(
            from: normalizedBooks,
            excludingCurrentBookID: currentBook?.id
        )

        return LibraryWidgetSnapshot(
            generatedAt: generatedAt,
            state: .ready,
            totalBooks: totalBooks,
            readBooks: readBooks,
            readingBooks: readingBooks,
            wantToReadBooks: wantToReadBooks,
            currentBook: currentBookSnapshot,
            yearlyGoal: yearlyGoal,
            last7DaysReadingMinutes: recentActivity.minutesLast7,
            last7DaysReadingDays: recentActivity.activeDaysLast7,
            currentReadingStreakDays: recentActivity.currentStreak,
            recentShelfItems: recentShelfItems
        )
    }

    private static func selectCurrentBook(
        from books: [LibraryWidgetBookRecord],
        activeBookID: UUID?
    ) -> LibraryWidgetBookRecord? {
        if let activeBookID, let active = books.first(where: { $0.id == activeBookID }) {
            return active
        }

        return books
            .filter { $0.status == .reading }
            .sorted(by: compareCurrentReadingBooks)
            .first
    }

    private static func makeYearlyGoal(
        from goals: [LibraryWidgetGoalRecord],
        books: [LibraryWidgetBookRecord],
        year: Int,
        calendar: Calendar
    ) -> LibraryWidgetYearlyGoalSnapshot? {
        guard let goal = goals
            .filter({ $0.year == year && $0.targetCount > 0 })
            .sorted(by: compareGoals)
            .first
        else {
            return nil
        }

        let finishedCount = books.reduce(0) { partialResult, book in
            partialResult + book.completions.filter { completion in
                calendar.component(.year, from: completion.finishedAt) == year
            }.count
        }

        return LibraryWidgetYearlyGoalSnapshot(
            year: year,
            targetCount: goal.targetCount,
            finishedCount: finishedCount
        )
    }

    private static func makeRecentShelfItems(
        from books: [LibraryWidgetBookRecord],
        excludingCurrentBookID: UUID?
    ) -> [LibraryWidgetBookSnapshot] {
        let recentlyFinished = books
            .compactMap { book -> (book: LibraryWidgetBookRecord, date: Date)? in
                guard book.id != excludingCurrentBookID else { return nil }
                guard let finishedAt = book.latestCompletionDate else { return nil }
                return (book, finishedAt)
            }
            .sorted(by: compareRecentFinishedItems)
            .prefix(recentShelfItemLimit)
            .map { item in
                item.book.makeSnapshot(kind: .recentlyFinished, referenceDate: item.date)
            }

        if !recentlyFinished.isEmpty {
            return Array(recentlyFinished)
        }

        return books
            .filter { $0.id != excludingCurrentBookID }
            .sorted(by: compareRecentlyAddedBooks)
            .prefix(recentShelfItemLimit)
            .map { book in
                book.makeSnapshot(kind: .recentlyAdded, referenceDate: book.createdAt)
            }
    }

    private static func compareBooksForStableInput(
        _ lhs: LibraryWidgetBookRecord,
        _ rhs: LibraryWidgetBookRecord
    ) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return compareBookIdentity(lhs, rhs)
    }

    private static func compareCurrentReadingBooks(
        _ lhs: LibraryWidgetBookRecord,
        _ rhs: LibraryWidgetBookRecord
    ) -> Bool {
        let lhsActivity = lhs.lastSessionAt ?? lhs.readFrom ?? lhs.createdAt
        let rhsActivity = rhs.lastSessionAt ?? rhs.readFrom ?? rhs.createdAt

        if lhsActivity != rhsActivity {
            return lhsActivity > rhsActivity
        }

        return compareBookIdentity(lhs, rhs)
    }

    private static func compareRecentlyAddedBooks(
        _ lhs: LibraryWidgetBookRecord,
        _ rhs: LibraryWidgetBookRecord
    ) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }
        return compareBookIdentity(lhs, rhs)
    }

    private static func compareRecentFinishedItems(
        _ lhs: (book: LibraryWidgetBookRecord, date: Date),
        _ rhs: (book: LibraryWidgetBookRecord, date: Date)
    ) -> Bool {
        if lhs.date != rhs.date {
            return lhs.date > rhs.date
        }
        if lhs.book.createdAt != rhs.book.createdAt {
            return lhs.book.createdAt > rhs.book.createdAt
        }
        return compareBookIdentity(lhs.book, rhs.book)
    }

    private static func compareGoals(
        _ lhs: LibraryWidgetGoalRecord,
        _ rhs: LibraryWidgetGoalRecord
    ) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.targetCount > rhs.targetCount
    }

    private static func compareBookIdentity(
        _ lhs: LibraryWidgetBookRecord,
        _ rhs: LibraryWidgetBookRecord
    ) -> Bool {
        let titleComparison = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
        if titleComparison != .orderedSame {
            return titleComparison == .orderedAscending
        }

        let authorComparison = lhs.author.localizedCaseInsensitiveCompare(rhs.author)
        if authorComparison != .orderedSame {
            return authorComparison == .orderedAscending
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }
}

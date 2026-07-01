import Foundation
@testable import Shelf_Notes

@MainActor
enum LargeReadingDatasetBuilder {
    static func make300BookTimelineDataset() -> LargeReadingDatasetFixture {
        makeDataset(bookCount: 300, sessionCount: 500)
    }

    static func make1000BookMixedDataset() -> LargeReadingDatasetFixture {
        makeDataset(bookCount: 1000, sessionCount: 500)
    }

    static func makeDataset(
        bookCount: Int,
        sessionCount: Int,
        now: Date = PerformanceFixtureClock.now,
        calendar: Calendar = PerformanceFixtureClock.calendar
    ) -> LargeReadingDatasetFixture {
        let normalizedBookCount = max(0, bookCount)
        let books = (0..<normalizedBookCount).map { index in
            makeBook(index: index, calendar: calendar)
        }
        let sessions = makeSessions(
            count: max(0, sessionCount),
            books: books,
            now: now,
            calendar: calendar
        )
        let challenges = makeChallenges(now: now, calendar: calendar)
        let completionRecords = ReadingCompletionRecordBuilder.records(from: books)
        let expectedYears = Array(Set(completionRecords.map { record in
            calendar.component(.year, from: record.finishedAt)
        })).sorted()
        let activeChallengeIDsByMetric = Dictionary(
            uniqueKeysWithValues: challenges
                .filter { $0.completedAt == nil }
                .map { ($0.metric, $0.id) }
        )

        return LargeReadingDatasetFixture(
            books: books,
            sessions: sessions,
            challenges: challenges,
            now: now,
            calendar: calendar,
            expectedCompletionCount: completionRecords.count,
            expectedRereadCompletionCount: completionRecords.filter(\.isReread).count,
            expectedTimelineYears: expectedYears,
            activeChallengeIDsByMetric: activeChallengeIDsByMetric
        )
    }
}

private extension LargeReadingDatasetBuilder {
    static func makeBook(index: Int, calendar: Calendar) -> Book {
        let year = 2017 + (index % 10)
        let month = (index % 12) + 1
        let day = (index % 27) + 1
        let createdAt = PerformanceFixtureClock.date(year, month, day, hour: 9)
        let title = String(format: "Performance Book %04d", index)
        let author = "Fixture Author \(index % 17)"
        let book = Book(
            title: title,
            author: author,
            status: status(for: index),
            tags: tags(for: index),
            notes: notes(for: index)
        )
        book.id = PerformanceFixtureClock.stableUUID(category: 1, index: index)
        book.createdAt = createdAt
        book.pageCount = 160 + (index % 480)
        book.mainCategory = mainCategory(for: index)
        book.categories = categories(for: index)
        book.readFrom = nil
        book.readTo = nil
        book.userRatingPlot = ratingValue(index: index, offset: 0)
        book.userRatingCharacters = ratingValue(index: index, offset: 1)
        book.userRatingWritingStyle = ratingValue(index: index, offset: 2)
        book.userRatingAtmosphere = ratingValue(index: index, offset: 3)
        book.userRatingGenreFit = ratingValue(index: index, offset: 4)
        book.userRatingPresentation = ratingValue(index: index, offset: 5)

        configureReadingState(for: book, index: index, year: year, calendar: calendar)
        return book
    }

    static func configureReadingState(for book: Book, index: Int, year: Int, calendar: Calendar) {
        if index % 5 == 0 {
            let firstStart = PerformanceFixtureClock.date(year, 1 + (index % 6), 2 + (index % 20), hour: 20)
            let firstFinish = calendar.date(byAdding: .day, value: 6, to: firstStart) ?? firstStart
            let secondStart = calendar.date(byAdding: .day, value: 30 + (index % 12), to: firstFinish) ?? firstFinish
            let secondFinish = calendar.date(byAdding: .day, value: 7, to: secondStart) ?? secondStart
            let thirdStart = calendar.date(byAdding: .day, value: 30, to: secondFinish) ?? secondFinish
            let attempts = [
                makeAttempt(book: book, bookIndex: index, sequenceNumber: 1, status: .finished, startedAt: firstStart, finishedAt: firstFinish),
                makeAttempt(book: book, bookIndex: index, sequenceNumber: 2, status: .finished, startedAt: secondStart, finishedAt: secondFinish),
                makeAttempt(book: book, bookIndex: index, sequenceNumber: 3, status: .active, startedAt: thirdStart, finishedAt: nil)
            ]
            book.statusRawValue = ReadingStatus.reading.rawValue
            book.readFrom = thirdStart
            book.readTo = secondFinish
            book.readingAttempts = attempts
            return
        }

        if index % 3 == 0 {
            let start = PerformanceFixtureClock.date(year, 2 + (index % 8), 1 + (index % 21), hour: 19)
            let finish = calendar.date(byAdding: .day, value: 8 + (index % 9), to: start) ?? start
            let attempt = makeAttempt(book: book, bookIndex: index, sequenceNumber: 1, status: .finished, startedAt: start, finishedAt: finish)
            book.statusRawValue = ReadingStatus.finished.rawValue
            book.readFrom = start
            book.readTo = finish
            book.readingAttempts = [attempt]
            return
        }

        if index % 3 == 1 {
            let start = PerformanceFixtureClock.date(year, 3 + (index % 7), 1 + (index % 22), hour: 18)
            let finish = calendar.date(byAdding: .day, value: 5 + (index % 11), to: start) ?? start
            book.statusRawValue = ReadingStatus.finished.rawValue
            book.readFrom = start
            book.readTo = finish
            return
        }

        if index % 2 == 0 {
            let start = PerformanceFixtureClock.date(year, 5 + (index % 6), 1 + (index % 20), hour: 17)
            let activeAttempt = makeAttempt(book: book, bookIndex: index, sequenceNumber: 1, status: .active, startedAt: start, finishedAt: nil)
            book.statusRawValue = ReadingStatus.reading.rawValue
            book.readFrom = start
            book.readingAttempts = [activeAttempt]
            return
        }

        book.statusRawValue = ReadingStatus.toRead.rawValue
    }

    static func makeAttempt(
        book: Book,
        bookIndex: Int,
        sequenceNumber: Int,
        status: ReadingAttemptStatus,
        startedAt: Date?,
        finishedAt: Date?
    ) -> ReadingAttempt {
        let updatedAt = finishedAt ?? startedAt ?? book.createdAt
        let attempt = ReadingAttempt(
            book: book,
            sequenceNumber: sequenceNumber,
            status: status,
            startedAt: startedAt,
            finishedAt: finishedAt,
            pageCountSnapshot: book.pageCount,
            createdAt: startedAt ?? book.createdAt,
            updatedAt: updatedAt
        )
        attempt.id = PerformanceFixtureClock.stableUUID(category: 2, index: bookIndex * 10 + sequenceNumber)
        return attempt
    }

    static func makeSessions(
        count: Int,
        books: [Book],
        now: Date,
        calendar: Calendar
    ) -> [ReadingSession] {
        guard !books.isEmpty, count > 0 else { return [] }

        let baseDay = calendar.startOfDay(for: now)
        var sessions: [ReadingSession] = []
        sessions.reserveCapacity(count)

        for index in 0..<count {
            let book = books[index % books.count]
            let dayOffset = -(index % 45)
            let hourOffset = 6 + (index % 12)
            let startOfSessionDay = calendar.date(byAdding: .day, value: dayOffset, to: baseDay) ?? baseDay
            let startedAt = calendar.date(byAdding: .hour, value: hourOffset, to: startOfSessionDay) ?? startOfSessionDay
            let durationMinutes = 10 + ((index % 6) * 10)
            let endedAt = startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
            let session = ReadingSession(
                book: book,
                startedAt: startedAt,
                endedAt: endedAt,
                pagesRead: 5 + (index % 30),
                note: index % 7 == 0 ? "Fixture note \(index)" : nil
            )
            session.id = PerformanceFixtureClock.stableUUID(category: 3, index: index)
            session.createdAt = startedAt.addingTimeInterval(60)
            book.readingSessionsSafe = book.readingSessionsSafe + [session]

            if let attempt = book.activeReadingAttempt ?? book.orderedReadingAttempts.last {
                session.readingAttempt = attempt
                attempt.sessionsSafe = attempt.sessionsSafe + [session]
                attempt.updatedAt = attempt.finishedAt ?? attempt.startedAt ?? book.createdAt
            }

            sessions.append(session)
        }

        return sessions
    }

    static func makeChallenges(now: Date, calendar: Calendar) -> [ChallengeRecord] {
        let activeDefinitions: [(ChallengeKind, ChallengeMetric, Int)] = [
            (.daily, .readingMinutes, 30),
            (.weekly, .sessions, 12),
            (.monthly, .pagesRead, 400),
            (.yearly, .booksFinished, 40)
        ]
        let completedDefinitions: [(ChallengeKind, ChallengeMetric, Int)] = [
            (.daily, .sessionNotes, 1),
            (.weekly, .readingDays, 3),
            (.monthly, .booksProgressed, 10),
            (.yearly, .finishedBooksRated, 12)
        ]
        var records: [ChallengeRecord] = []

        for (index, definition) in activeDefinitions.enumerated() {
            let period = ChallengeCadence.periodBounds(for: definition.0, now: now, calendar: calendar)
            let record = ChallengeRecord(
                kind: definition.0,
                metric: definition.1,
                periodStart: period.start,
                periodEnd: period.end,
                title: "Active \(definition.0.displayName)",
                detail: "Performance fixture active challenge",
                targetValue: definition.2
            )
            record.id = PerformanceFixtureClock.stableUUID(category: 4, index: index)
            record.createdAt = period.start
            records.append(record)
        }

        for (index, definition) in completedDefinitions.enumerated() {
            let currentPeriod = ChallengeCadence.periodBounds(for: definition.0, now: now, calendar: calendar)
            let periodLength = currentPeriod.end.timeIntervalSince(currentPeriod.start)
            let periodStart = currentPeriod.start.addingTimeInterval(-periodLength)
            let periodEnd = currentPeriod.start
            let record = ChallengeRecord(
                kind: definition.0,
                metric: definition.1,
                periodStart: periodStart,
                periodEnd: periodEnd,
                title: "Completed \(definition.0.displayName)",
                detail: "Performance fixture completed challenge",
                targetValue: definition.2
            )
            record.id = PerformanceFixtureClock.stableUUID(category: 5, index: index)
            record.createdAt = periodStart
            record.completedAt = periodEnd.addingTimeInterval(-3600)
            record.acknowledgedAt = periodEnd.addingTimeInterval(-1800)
            records.append(record)
        }

        return records
    }

    static func status(for index: Int) -> ReadingStatus {
        if index % 5 == 0 { return .reading }
        if index % 3 == 0 { return .finished }
        if index % 3 == 1 { return .finished }
        if index % 2 == 0 { return .reading }
        return .toRead
    }

    static func tags(for index: Int) -> [String] {
        ["tag-\(index % 9)", "mood-\(index % 5)"]
    }

    static func categories(for index: Int) -> [String] {
        [mainCategory(for: index), "Category \(index % 11)"]
    }

    static func mainCategory(for index: Int) -> String {
        switch index % 5 {
        case 0:
            return "Thriller"
        case 1:
            return "Biografie"
        case 2:
            return "Krimi"
        case 3:
            return "Science Fiction"
        default:
            return "Sachbuch"
        }
    }

    static func notes(for index: Int) -> String {
        index % 4 == 0 ? "Fixture note for performance book \(index)" : ""
    }

    static func ratingValue(index: Int, offset: Int) -> Int {
        let rawValue = (index + offset) % 6
        return rawValue == 0 ? 0 : rawValue
    }
}
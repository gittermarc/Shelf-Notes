import Foundation
import Testing
@testable import Shelf_Notes

struct ProgressHubMetricsModelTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    @MainActor
    private func makeBook(
        title: String,
        status: ReadingStatus,
        createdAt: Date,
        readFrom: Date? = nil,
        readTo: Date? = nil,
        pageCount: Int? = nil
    ) -> Book {
        let book = Book(title: title, author: "", status: status)
        book.createdAt = createdAt
        book.readFrom = readFrom
        book.readTo = readTo
        book.pageCount = pageCount
        return book
    }

    @MainActor
    private func makeSession(
        startedAt: Date,
        durationSeconds: Int
    ) -> ReadingSession {
        let session = ReadingSession(startAt: startedAt, durationSeconds: durationSeconds)
        session.createdAt = startedAt
        return session
    }

    @Test @MainActor func makeMetricsUsesSharedAnalyticsIndexAndGoalTarget() {
        let year = 2026
        let books = [
            makeBook(
                title: "Done One",
                status: .finished,
                createdAt: date(2026, 1, 1),
                readTo: date(2026, 2, 10),
                pageCount: 300
            ),
            makeBook(
                title: "Done Two",
                status: .finished,
                createdAt: date(2026, 1, 2),
                readFrom: date(2026, 3, 4),
                readTo: nil,
                pageCount: 180
            ),
            makeBook(
                title: "Old",
                status: .finished,
                createdAt: date(2025, 1, 2),
                readTo: date(2025, 11, 10),
                pageCount: 220
            )
        ]
        let goals = [ReadingGoal(year: 2026, targetCount: 12)]
        let sessions = [
            makeSession(startedAt: date(2026, 4, 15, 8), durationSeconds: 1800),
            makeSession(startedAt: date(2026, 4, 14, 8), durationSeconds: 1200),
            makeSession(startedAt: date(2026, 4, 13, 8), durationSeconds: 600)
        ]

        let recentActivity = ReadingAnalyticsRecentActivityBuilder.make(
            sessions: ReadingAnalyticsInputMapper.sessionRecords(from: sessions),
            now: date(2026, 4, 15, 9),
            calendar: calendar
        )

        let metrics = ProgressHubMetricsModel.makeMetrics(
            year: year,
            books: books,
            goals: goals,
            recentActivity: recentActivity,
            now: date(2026, 4, 15, 9),
            calendar: calendar
        )

        #expect(metrics.year == 2026)
        #expect(metrics.finishedThisYear == 2)
        #expect(metrics.goalTarget == 12)
        #expect(metrics.minutesLast7 == 60)
        #expect(metrics.activeDaysLast7 == 3)
        #expect(metrics.currentStreak == 3)
    }

    @Test @MainActor func makeMetricsHandlesMissingGoalAndEmptySessions() {
        let books = [
            makeBook(
                title: "Done One",
                status: .finished,
                createdAt: date(2026, 1, 1),
                readTo: date(2026, 1, 10),
                pageCount: 300
            )
        ]

        let metrics = ProgressHubMetricsModel.makeMetrics(
            year: 2026,
            books: books,
            goals: [],
            recentActivity: .empty,
            now: date(2026, 4, 15, 9),
            calendar: calendar
        )

        #expect(metrics.finishedThisYear == 1)
        #expect(metrics.goalTarget == nil)
        #expect(metrics.minutesLast7 == 0)
        #expect(metrics.activeDaysLast7 == 0)
        #expect(metrics.currentStreak == 0)
    }

    @Test @MainActor func makeMetricsBreaksStreakAfterGapButKeepsLast7Window() {
        let sessions = [
            makeSession(startedAt: date(2026, 4, 15, 8), durationSeconds: 1200),
            makeSession(startedAt: date(2026, 4, 13, 8), durationSeconds: 600),
            makeSession(startedAt: date(2026, 4, 10, 8), durationSeconds: 900)
        ]

        let recentActivity = ReadingAnalyticsRecentActivityBuilder.make(
            sessions: ReadingAnalyticsInputMapper.sessionRecords(from: sessions),
            now: date(2026, 4, 15, 9),
            calendar: calendar
        )

        let metrics = ProgressHubMetricsModel.makeMetrics(
            year: 2026,
            books: [],
            goals: [],
            recentActivity: recentActivity,
            now: date(2026, 4, 15, 9),
            calendar: calendar
        )

        #expect(metrics.minutesLast7 == 45)
        #expect(metrics.activeDaysLast7 == 3)
        #expect(metrics.currentStreak == 1)
    }

    @Test func sessionAggregatesMatchRecentActivityBuilderForProgressHub() {
        let records = [
            ReadingSessionAggregateRecord(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
                bookID: UUID(uuidString: "00000000-0000-0000-0000-000000000101"),
                statusRawValue: ReadingStatus.reading.rawValue,
                startedAt: date(2026, 4, 15, 8),
                endedAt: date(2026, 4, 15, 8, 20),
                durationSeconds: 1_200,
                pagesRead: 12,
                createdAt: date(2026, 4, 15, 8)
            ),
            ReadingSessionAggregateRecord(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
                bookID: UUID(uuidString: "00000000-0000-0000-0000-000000000101"),
                statusRawValue: ReadingStatus.reading.rawValue,
                startedAt: date(2026, 4, 14, 8),
                endedAt: date(2026, 4, 14, 8, 30),
                durationSeconds: 1_800,
                pagesRead: 18,
                createdAt: date(2026, 4, 14, 8)
            )
        ]

        let aggregate = ReadingSessionAggregateBuilder.make(
            records: records,
            now: date(2026, 4, 15, 9),
            calendar: calendar
        )
        let recent = ReadingAnalyticsRecentActivityBuilder.make(
            sessions: records.map(\.sessionRecord),
            now: date(2026, 4, 15, 9),
            calendar: calendar
        )

        #expect(aggregate.recentActivity == recent)
        #expect(aggregate.recentActivity.minutesLast7 == 50)
        #expect(aggregate.recentActivity.activeDaysLast7 == 2)
        #expect(aggregate.booksByID.values.first?.totalPages == 30)
        #expect(aggregate.yearsByYear[2026]?.activeDays == 2)
    }

    @Test @MainActor func mixedMediaCompletionsAndProviderImportsKeepUniversalProgressHubMetrics() {
        let ebook = makeBook(
            title: "Digital",
            status: .finished,
            createdAt: date(2026, 1, 1),
            pageCount: 500
        )
        let attempt = ReadingAttempt(
            book: ebook,
            sequenceNumber: 1,
            status: .finished,
            startedAt: date(2026, 1, 1),
            finishedAt: date(2026, 1, 8),
            pageCountSnapshot: 500,
            readingMedium: .ebook,
            defaultProvider: .googleBooks,
            progressUnit: .percentage,
            totalValueSnapshot: 100
        )
        ebook.readingAttempts = [attempt]

        let providerImport = ReadingSession(
            book: ebook,
            startedAt: date(2026, 4, 15, 8),
            endedAt: date(2026, 4, 15, 8, 30),
            origin: .providerImport,
            progressUnit: .percentage
        )
        let realSession = ReadingSession(
            book: ebook,
            startedAt: date(2026, 4, 14, 8),
            endedAt: date(2026, 4, 14, 8, 20),
            origin: .quickLog,
            progressUnit: .percentage
        )
        let recent = ReadingAnalyticsRecentActivityBuilder.make(
            sessions: ReadingAnalyticsInputMapper.sessionRecords(from: [providerImport, realSession]),
            now: date(2026, 4, 15, 9),
            calendar: calendar
        )

        let metrics = ProgressHubMetricsModel.makeMetrics(
            year: 2026,
            books: [ebook],
            goals: [ReadingGoal(year: 2026, targetCount: 12)],
            recentActivity: recent,
            now: date(2026, 4, 15, 9),
            calendar: calendar
        )

        #expect(metrics.finishedThisYear == 1)
        #expect(metrics.goalTarget == 12)
        #expect(metrics.minutesLast7 == 20)
        #expect(metrics.activeDaysLast7 == 1)
        #expect(metrics.currentStreak == 0)
    }
}

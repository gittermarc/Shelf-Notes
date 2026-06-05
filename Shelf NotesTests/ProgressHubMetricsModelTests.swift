import Foundation
import Testing
@testable import Shelf_Notes

struct ProgressHubMetricsModelTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
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
}

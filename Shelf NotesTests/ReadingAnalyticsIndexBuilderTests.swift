import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingAnalyticsIndexBuilderTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    @Test func yearSummaryUsesReadToOrReadFromAndBuildsMonthlyPages() {
        let books = [
            ReadingAnalyticsBookRecord(
                id: UUID(),
                statusRawValue: ReadingStatus.finished.rawValue,
                createdAt: date(2026, 1, 1),
                readFrom: date(2026, 2, 2),
                readTo: nil,
                pageCount: 320
            ),
            ReadingAnalyticsBookRecord(
                id: UUID(),
                statusRawValue: ReadingStatus.finished.rawValue,
                createdAt: date(2026, 1, 2),
                readFrom: date(2026, 2, 10),
                readTo: date(2026, 3, 1),
                pageCount: 180
            ),
            ReadingAnalyticsBookRecord(
                id: UUID(),
                statusRawValue: ReadingStatus.finished.rawValue,
                createdAt: date(2025, 1, 2),
                readFrom: date(2025, 7, 10),
                readTo: date(2025, 7, 20),
                pageCount: 100
            )
        ]

        let index = ReadingAnalyticsIndexBuilder.make(
            books: books,
            sessions: [],
            now: date(2026, 4, 15),
            calendar: calendar
        )

        let summary2026 = index.summary(forYear: 2026)
        #expect(index.finishedBookYears == [2026, 2025])
        #expect(summary2026.finishedBookCount == 2)
        #expect(summary2026.pagesRead == 500)
        #expect(summary2026.countedBooksWithPagesCount == 2)
        #expect(summary2026.averagePagesPerBook == 250)
        #expect(summary2026.pagesByMonth[2] == 320)
        #expect(summary2026.pagesByMonth[3] == 180)
    }

    @Test func yearSummaryIgnoresNonFinishedBooksAndMissingReadDates() {
        let books = [
            ReadingAnalyticsBookRecord(
                id: UUID(),
                statusRawValue: ReadingStatus.reading.rawValue,
                createdAt: date(2026, 1, 1),
                readFrom: date(2026, 1, 5),
                readTo: date(2026, 1, 10),
                pageCount: 250
            ),
            ReadingAnalyticsBookRecord(
                id: UUID(),
                statusRawValue: ReadingStatus.finished.rawValue,
                createdAt: date(2026, 1, 2),
                readFrom: nil,
                readTo: nil,
                pageCount: 150
            ),
            ReadingAnalyticsBookRecord(
                id: UUID(),
                statusRawValue: ReadingStatus.finished.rawValue,
                createdAt: date(2026, 1, 3),
                readFrom: date(2026, 4, 1),
                readTo: nil,
                pageCount: nil
            )
        ]

        let index = ReadingAnalyticsIndexBuilder.make(
            books: books,
            sessions: [],
            now: date(2026, 4, 15),
            calendar: calendar
        )

        let summary2026 = index.summary(forYear: 2026)
        #expect(summary2026.finishedBookCount == 1)
        #expect(summary2026.pagesRead == 0)
        #expect(summary2026.countedBooksWithPagesCount == 0)
        #expect(summary2026.averagePagesPerBook == nil)
        #expect(summary2026.pagesByMonth[4] == 0)
    }

    @Test func recentActivityComputesLast7DaysAndCurrentStreak() {
        let now = date(2026, 4, 15, 9)
        let sessions = [
            ReadingAnalyticsSessionRecord(
                id: UUID(),
                startedAt: date(2026, 4, 13, 20),
                durationSeconds: 600,
                createdAt: date(2026, 4, 13, 20)
            ),
            ReadingAnalyticsSessionRecord(
                id: UUID(),
                startedAt: date(2026, 4, 15, 8),
                durationSeconds: 1200,
                createdAt: date(2026, 4, 15, 8)
            ),
            ReadingAnalyticsSessionRecord(
                id: UUID(),
                startedAt: date(2026, 4, 14, 7),
                durationSeconds: 1800,
                createdAt: date(2026, 4, 14, 7)
            ),
            ReadingAnalyticsSessionRecord(
                id: UUID(),
                startedAt: date(2026, 4, 10, 18),
                durationSeconds: 900,
                createdAt: date(2026, 4, 10, 18)
            )
        ]

        let index = ReadingAnalyticsIndexBuilder.make(
            books: [],
            sessions: sessions,
            now: now,
            calendar: calendar
        )

        #expect(index.recentActivity.minutesLast7 == 75)
        #expect(index.recentActivity.activeDaysLast7 == 4)
        #expect(index.recentActivity.currentStreak == 3)
    }

    @Test func recentActivityReturnsEmptyValuesForGapsAndZeroDuration() {
        let now = date(2026, 4, 15, 9)
        let sessions = [
            ReadingAnalyticsSessionRecord(
                id: UUID(),
                startedAt: date(2026, 4, 13, 20),
                durationSeconds: 0,
                createdAt: date(2026, 4, 13, 20)
            ),
            ReadingAnalyticsSessionRecord(
                id: UUID(),
                startedAt: date(2026, 4, 12, 20),
                durationSeconds: 1800,
                createdAt: date(2026, 4, 12, 20)
            )
        ]

        let index = ReadingAnalyticsIndexBuilder.make(
            books: [],
            sessions: sessions,
            now: now,
            calendar: calendar
        )

        #expect(index.recentActivity.minutesLast7 == 30)
        #expect(index.recentActivity.activeDaysLast7 == 1)
        #expect(index.recentActivity.currentStreak == 0)
    }
}

import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingMetricCompatibilityTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 4, day: day, hour: hour)) ?? .distantPast
    }

    @Test func mixedSessionsKeepUniversalActivityButOnlyPagesContributeToPageMetrics() {
        let pageSession = ReadingSessionMetricMapper.contribution(
            from: ReadingSessionMetricInput(
                startedAt: date(1),
                durationSeconds: 3_600,
                pagesRead: 120,
                progressUnitRawValue: ReadingProgressUnit.pages.rawValue,
                originRawValue: ReadingSessionOrigin.timer.rawValue
            )
        )
        let percentageSession = ReadingSessionMetricMapper.contribution(
            from: ReadingSessionMetricInput(
                startedAt: date(2),
                durationSeconds: 1_800,
                pagesRead: 75,
                normalizedProgress: 0.4,
                progressUnitRawValue: ReadingProgressUnit.percentage.rawValue,
                originRawValue: ReadingSessionOrigin.quickLog.rawValue
            )
        )

        #expect(pageSession.sessionCount == 1)
        #expect(pageSession.durationSeconds == 3_600)
        #expect(pageSession.pageBasedDurationSeconds == 3_600)
        #expect(pageSession.pagesRead == 120)
        #expect(percentageSession.sessionCount == 1)
        #expect(percentageSession.durationSeconds == 1_800)
        #expect(percentageSession.pageBasedDurationSeconds == 0)
        #expect(percentageSession.pagesRead == 0)
        #expect(percentageSession.hasMeasuredProgress)
    }

    @Test func providerImportContributesBookProgressButNoSessionActivity() {
        let event = ReadingProgressMetricMapper.contribution(
            from: ReadingProgressMetricInput(
                progressUnitRawValue: ReadingProgressUnit.percentage.rawValue,
                originRawValue: ReadingSessionOrigin.providerImport.rawValue,
                nativeValue: 40,
                normalizedProgress: 0.4
            )
        )

        #expect(event.sessionCount == 0)
        #expect(event.durationSeconds == 0)
        #expect(event.pageBasedDurationSeconds == 0)
        #expect(event.readingDay == nil)
        #expect(event.pagesRead == 0)
        #expect(event.hasMeasuredProgress)
        #expect(event.normalizedProgress == 0.4)
    }

    @Test func providerImportOriginOnMalformedSessionIsIgnoredSafely() {
        let contribution = ReadingSessionMetricMapper.contribution(
            from: ReadingSessionMetricInput(
                startedAt: date(3),
                durationSeconds: 2_400,
                pagesRead: 80,
                progressUnitRawValue: ReadingProgressUnit.pages.rawValue,
                originRawValue: ReadingSessionOrigin.providerImport.rawValue
            )
        )

        #expect(contribution.sessionCount == 0)
        #expect(contribution.durationSeconds == 0)
        #expect(contribution.pageBasedDurationSeconds == 0)
        #expect(contribution.readingDay == nil)
        #expect(contribution.pagesRead == 0)
    }

    @Test func sessionAggregatesExcludePercentageTimeFromPagesPerHour() throws {
        let bookID = UUID()
        let records = [
            ReadingSessionAggregateRecord(
                id: UUID(),
                bookID: bookID,
                statusRawValue: ReadingStatus.reading.rawValue,
                startedAt: date(1),
                endedAt: date(1, hour: 13),
                durationSeconds: 3_600,
                pagesRead: 120,
                progressUnitRawValue: ReadingProgressUnit.pages.rawValue,
                originRawValue: ReadingSessionOrigin.timer.rawValue,
                createdAt: date(1)
            ),
            ReadingSessionAggregateRecord(
                id: UUID(),
                bookID: bookID,
                statusRawValue: ReadingStatus.reading.rawValue,
                startedAt: date(2),
                endedAt: date(2, hour: 13),
                durationSeconds: 3_600,
                pagesRead: nil,
                progressUnitRawValue: ReadingProgressUnit.percentage.rawValue,
                originRawValue: ReadingSessionOrigin.timer.rawValue,
                createdAt: date(2)
            )
        ]

        let snapshot = ReadingSessionAggregateBuilder.make(
            records: records,
            now: date(3),
            calendar: calendar
        )
        let aggregate = try #require(snapshot.booksByID[bookID])

        #expect(snapshot.totalSessionCount == 2)
        #expect(aggregate.totalSeconds == 7_200)
        #expect(aggregate.pageBasedSeconds == 3_600)
        #expect(aggregate.totalPages == 120)
        #expect(aggregate.averageSessionDurationSeconds == 3_600)
        #expect(aggregate.pagesPerHour == 120)
    }

    @Test func aggregateBuilderExcludesProviderImportsFromSessionsTimeAndReadingDays() {
        let importedDay = date(4)
        let snapshot = ReadingSessionAggregateBuilder.make(
            records: [
                ReadingSessionAggregateRecord(
                    id: UUID(),
                    statusRawValue: ReadingStatus.reading.rawValue,
                    startedAt: importedDay,
                    endedAt: importedDay.addingTimeInterval(1_800),
                    durationSeconds: 1_800,
                    pagesRead: 60,
                    progressUnitRawValue: ReadingProgressUnit.pages.rawValue,
                    originRawValue: ReadingSessionOrigin.providerImport.rawValue,
                    createdAt: importedDay
                )
            ],
            now: date(5),
            calendar: calendar
        )

        #expect(snapshot.totalSessionCount == 0)
        #expect(snapshot.roundedMinutesByDay(for: .all).isEmpty)
        #expect(snapshot.readingDays(for: .all).isEmpty)
        #expect(snapshot.pagesByDay(for: .all).isEmpty)
    }

    @Test func shortRealSessionStillCountsAsReadingDayWithoutInventingMinutes() {
        let sessionDay = date(6)
        let snapshot = ReadingSessionAggregateBuilder.make(
            records: [
                ReadingSessionAggregateRecord(
                    id: UUID(),
                    statusRawValue: ReadingStatus.reading.rawValue,
                    startedAt: sessionDay,
                    endedAt: sessionDay.addingTimeInterval(20),
                    durationSeconds: 20,
                    pagesRead: nil,
                    progressUnitRawValue: ReadingProgressUnit.percentage.rawValue,
                    originRawValue: ReadingSessionOrigin.quickLog.rawValue,
                    createdAt: sessionDay
                )
            ],
            now: date(7),
            calendar: calendar
        )
        let normalizedDay = calendar.startOfDay(for: sessionDay)

        #expect(snapshot.totalSessionCount == 1)
        #expect(snapshot.roundedMinutesByDay(for: .all).isEmpty)
        #expect(snapshot.readingDays(for: .all)[normalizedDay] == 1)
    }

    @Test func completedProgressCountsAsMeasuredWithoutInventingPages() {
        let contribution = ReadingProgressMetricMapper.contribution(
            from: ReadingProgressMetricInput(
                progressUnitRawValue: ReadingProgressUnit.none.rawValue,
                isCompleted: true
            ),
            source: .completion
        )

        #expect(contribution.hasMeasuredProgress)
        #expect(contribution.isCompletion)
        #expect(contribution.pagesRead == 0)
        #expect(contribution.normalizedProgress == nil)
    }
}

import Foundation
import Testing
@testable import Shelf_Notes

struct StatisticsComputePipelineTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 0,
        _ minute: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        ) ?? .distantPast
    }

    @Test func bookSnapshotCarriesReadingSessionsIntoValueSnapshot() {
        let book = Book(title: "Night Read", author: "Ada", status: .reading)
        let session = ReadingSession(
            book: book,
            startedAt: date(2026, 1, 1, 23, 30),
            endedAt: date(2026, 1, 2, 0, 30),
            pagesRead: 24
        )
        book.readingSessionsSafe = [session]

        let snapshot = StatisticsBookSnapshot(book: book)

        #expect(snapshot.readingSessions.count == 1)
        #expect(snapshot.readingSessions.first?.startedAt == date(2026, 1, 1, 23, 30))
        #expect(snapshot.readingSessions.first?.endedAt == date(2026, 1, 2, 0, 30))
        #expect(snapshot.readingSessions.first?.durationSeconds == 3_600)
        #expect(snapshot.readingSessions.first?.pagesRead == 24)
    }

    @Test func heatmapBuilderSplitsReadingMinutesAcrossDays() {
        let builder = StatisticsHeatmapBuilder(now: date(2026, 4, 15), calendar: calendar)
        let books = [
            StatisticsBookSnapshot(
                title: "Night Read",
                author: "Ada",
                statusRawValue: ReadingStatus.reading.rawValue,
                readingSessions: [
                    .init(
                        startedAt: date(2026, 1, 1, 23, 30),
                        endedAt: date(2026, 1, 2, 0, 30),
                        durationSeconds: 3_600,
                        pagesRead: 24
                    )
                ]
            )
        ]

        let cache = builder.makeHeatmapCache(
            for: .init(
                selectedYear: 2026,
                scope: .all,
                activityMetric: .readingMinutes,
                booksSignature: 11
            ),
            books: books
        )

        #expect(cache.counts[date(2026, 1, 1)] == 30)
        #expect(cache.counts[date(2026, 1, 2)] == 30)
        #expect(cache.stats.activeDays == 2)
        #expect(cache.stats.maxCount == 30)
    }

    @Test func detachedPipelineKeepsStatsAndHeatmapStableForSameSource() async {
        let books = [
            StatisticsBookSnapshot(
                title: "Alpha",
                author: "Author One",
                statusRawValue: ReadingStatus.finished.rawValue,
                tags: ["Crime", "Noir"],
                readFrom: date(2026, 1, 1),
                readTo: date(2026, 1, 5),
                publisher: "Pub A",
                pageCount: 300,
                language: "DE",
                categories: ["Fiction / Thriller / Noir"],
                mainCategory: "Fiction / Thriller / Noir",
                userRatingAverage1: 4.6,
                readingSessions: [
                    .init(
                        startedAt: date(2026, 1, 2, 20, 0),
                        endedAt: date(2026, 1, 2, 21, 0),
                        durationSeconds: 3_600,
                        pagesRead: 40
                    )
                ]
            ),
            StatisticsBookSnapshot(
                title: "Beta",
                author: "Author Two",
                statusRawValue: ReadingStatus.reading.rawValue,
                tags: ["History"],
                readFrom: date(2026, 2, 10),
                publisher: "Pub B",
                pageCount: 150,
                language: "EN",
                categories: ["Nonfiction / History"],
                mainCategory: "Nonfiction / History",
                readingSessions: [
                    .init(
                        startedAt: date(2026, 2, 12, 9, 0),
                        endedAt: date(2026, 2, 12, 9, 45),
                        durationSeconds: 2_700,
                        pagesRead: 18
                    )
                ]
            )
        ]

        let source = StatisticsSourceSnapshot(booksSignature: 77, books: books)
        let pipeline = StatisticsComputePipeline(source: source, now: date(2026, 4, 15), calendar: calendar)
        let statsKey = StatisticsView.StatsCacheKey(selectedYear: 2026, scope: .all, booksSignature: 77)
        let heatmapKey = StatisticsView.HeatmapCacheKey(
            selectedYear: 2026,
            scope: .all,
            activityMetric: .readingMinutes,
            booksSignature: 77
        )

        let firstStats = await pipeline.makeStatsCache(for: statsKey)
        let secondStats = await pipeline.makeStatsCache(for: statsKey)
        let firstHeatmap = await pipeline.makeHeatmapCache(for: heatmapKey)
        let secondHeatmap = await pipeline.makeHeatmapCache(for: heatmapKey)

        #expect(firstStats.summary.heroSubtitle == secondStats.summary.heroSubtitle)
        #expect(firstStats.monthlySeries == secondStats.monthlySeries)
        #expect(firstStats.topTags.map(\.label) == secondStats.topTags.map(\.label))
        #expect(firstStats.topTags.map(\.count) == secondStats.topTags.map(\.count))
        #expect(firstHeatmap.counts == secondHeatmap.counts)
        #expect(firstHeatmap.stats.activeDays == secondHeatmap.stats.activeDays)
        #expect(firstHeatmap.stats.bestDayLabel == secondHeatmap.stats.bestDayLabel)
    }
}

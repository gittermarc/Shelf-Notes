import Foundation
import Testing
@testable import Shelf_Notes

struct StatisticsSnapshotBuilderTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    @Test func buildsSummaryForScopedYearData() {
        let builder = StatisticsSnapshotBuilder(now: date(2026, 4, 15), calendar: calendar)
        let books = [
            StatisticsBookSnapshot(
                title: "Alpha",
                author: "Author One",
                statusRawValue: ReadingStatus.finished.rawValue,
                readFrom: date(2026, 1, 1),
                readTo: date(2026, 1, 5),
                publisher: "Pub A",
                publishedDate: "2021-02-01",
                pageCount: 300,
                language: "DE",
                categories: ["Fiction / Thriller / Noir"],
                mainCategory: "Fiction / Thriller / Noir",
                userRatingAverage1: 4.6
            ),
            StatisticsBookSnapshot(
                title: "Beta",
                author: "Author Two",
                statusRawValue: ReadingStatus.finished.rawValue,
                tags: ["History"],
                readFrom: date(2026, 2, 10),
                readTo: date(2026, 2, 12),
                publisher: "Pub B",
                publishedDate: "2020",
                pageCount: 150,
                language: "EN",
                categories: ["Nonfiction / History"],
                mainCategory: "Nonfiction / History",
                userRatingAverage1: 3.8
            ),
            StatisticsBookSnapshot(
                title: "Gamma",
                author: "Author Two",
                statusRawValue: ReadingStatus.reading.rawValue,
                tags: ["Currently Reading"],
                publisher: "Pub B",
                publishedDate: "2019",
                pageCount: 420,
                language: "EN"
            )
        ]

        let key = StatisticsStatsCacheKey(
            selectedYear: 2026,
            scope: .all,
            booksSignature: 123
        )
        let cache = builder.makeStatsCache(for: key, books: books)

        #expect(cache.summary.heroSubtitle == "3 Bücher • 2 gelesen • 870 Seiten (wo vorhanden)")
        #expect(cache.summary.overview.scopedBooksCount == 3)
        #expect(cache.summary.overview.finishedScopedBooksCount == 2)
        #expect(cache.summary.overview.uniqueAuthorsCount == 2)
        #expect(cache.summary.overview.uniquePublishersCount == 2)
        #expect(cache.summary.overview.pagesInSelectedYear == 450)
        #expect(cache.summary.overview.finishedInSelectedYearCount == 2)
        #expect(cache.summary.overview.avgPagesPerBookText == "225")
        #expect(cache.summary.overview.avgDaysPerBookText == "4")
        #expect(cache.summary.yearOptions == [2027, 2026, 2021, 2020, 2019])
        #expect(cache.summary.tinyTeaserLine == "Ø 55 Seiten/Tag • Ø 4 Tage/Abschluss")
    }

    @Test func buildsStableTopListsAndRatings() {
        let builder = StatisticsSnapshotBuilder(now: date(2026, 7, 1), calendar: calendar)
        let books = [
            StatisticsBookSnapshot(
                title: "Noir One",
                author: "Ada",
                statusRawValue: ReadingStatus.finished.rawValue,
                tags: ["#Mood", "Crime"],
                publisher: "Zed",
                pageCount: 220,
                language: "DE",
                categories: ["Fiction / Thriller / Noir"],
                mainCategory: "Fiction / Thriller / Noir",
                userRatingAverage1: 4.4
            ),
            StatisticsBookSnapshot(
                title: "Noir Two",
                author: "Ada",
                statusRawValue: ReadingStatus.finished.rawValue,
                tags: ["Mood"],
                publisher: "Alpha",
                pageCount: 180,
                language: "DE",
                categories: ["Fiction / Thriller / Noir"],
                mainCategory: "Fiction / Thriller / Noir",
                userRatingAverage1: 4.8
            ),
            StatisticsBookSnapshot(
                title: "History One",
                author: "Bea",
                statusRawValue: ReadingStatus.toRead.rawValue,
                tags: ["Crime"],
                publisher: "Alpha",
                pageCount: 300,
                language: "EN",
                categories: ["Nonfiction / History"],
                mainCategory: "Nonfiction / History"
            )
        ]

        let cache = builder.makeStatsCache(
            for: .init(selectedYear: 2026, scope: .all, booksSignature: 99),
            books: books
        )

        #expect(cache.topGenres.map { $0.label } == ["Thriller", "History"])
        #expect(cache.topGenres.map { $0.count } == [2, 1])
        #expect(cache.topSubgenres.map { $0.label } == ["Noir"])
        #expect(cache.topAuthors.map { $0.label } == ["Ada", "Bea"])
        #expect(cache.topPublishers.map { $0.label } == ["Alpha", "Zed"])
        #expect(cache.topPublishers.map { $0.count } == [2, 1])
        #expect(cache.topLanguages.map { $0.label } == ["DE", "EN"])
        #expect(cache.topTags.map { $0.label } == ["Crime", "Mood"])
        #expect(cache.topTags.map { $0.count } == [2, 2])
        #expect(cache.highestRated?.label == "Noir Two • 4.8 / 5")
    }

    @Test func buildsMonthlySeriesAndNerdStatsForFinishedBooks() {
        let builder = StatisticsSnapshotBuilder(now: date(2026, 4, 15), calendar: calendar)
        let books = [
            StatisticsBookSnapshot(
                title: "Sprint",
                statusRawValue: ReadingStatus.finished.rawValue,
                readFrom: date(2026, 1, 10),
                readTo: date(2026, 1, 10),
                pageCount: 100
            ),
            StatisticsBookSnapshot(
                title: "Marathon",
                statusRawValue: ReadingStatus.finished.rawValue,
                readFrom: date(2026, 2, 1),
                readTo: date(2026, 2, 10),
                pageCount: 500
            ),
            StatisticsBookSnapshot(
                title: "April Book",
                statusRawValue: ReadingStatus.finished.rawValue,
                readFrom: date(2026, 4, 2),
                readTo: date(2026, 4, 4),
                pageCount: 250
            )
        ]

        let cache = builder.makeStatsCache(
            for: .init(selectedYear: 2026, scope: .all, booksSignature: 7),
            books: books
        )

        #expect(cache.monthsCount == 4)
        #expect(cache.monthlySeries.map { $0.finishedCount } == [1, 1, 0, 1])
        #expect(cache.monthlySeries.map { $0.pages } == [100, 500, 0, 250])
        #expect(cache.fastest?.label == "Sprint • 1 Tage")
        #expect(cache.slowest?.label == "Marathon • 10 Tage")
        #expect(cache.biggest?.label == "Marathon • 500 Seiten")
    }

    @Test func returnsEmptyFriendlySnapshotForNoBooks() {
        let builder = StatisticsSnapshotBuilder(now: date(2026, 4, 15), calendar: calendar)
        let cache = builder.makeStatsCache(
            for: .init(selectedYear: 2026, scope: .all, booksSignature: 0),
            books: []
        )

        #expect(cache.summary.heroSubtitle == "0 Bücher • 0 gelesen • 0 Seiten (wo vorhanden)")
        #expect(cache.summary.overview.scopedBooksCount == 0)
        #expect(cache.summary.overview.pagesInSelectedYear == 0)
        #expect(cache.summary.overview.avgPagesPerBookText == "–")
        #expect(cache.summary.overview.avgDaysPerBookText == "–")
        #expect(cache.summary.yearOptions == [2027, 2026])
        #expect(cache.monthsCount == 4)
        #expect(cache.monthlySeries.allSatisfy { $0.finishedCount == 0 && $0.pages == 0 })
        #expect(cache.topGenres.isEmpty)
        #expect(cache.highestRated == nil)
    }

    @Test func scopeFilterUsesBuilderSemanticsInsteadOfViewSideAggregation() {
        let builder = StatisticsSnapshotBuilder(now: date(2026, 4, 15), calendar: calendar)
        let books = [
            StatisticsBookSnapshot(
                title: "Finished Thriller",
                author: "Ada",
                statusRawValue: ReadingStatus.finished.rawValue,
                tags: ["Crime"],
                readFrom: date(2026, 1, 3),
                readTo: date(2026, 1, 5),
                publisher: "Alpha",
                pageCount: 320,
                language: "DE",
                categories: ["Fiction / Thriller / Noir"],
                mainCategory: "Fiction / Thriller / Noir",
                userRatingAverage1: 4.5
            ),
            StatisticsBookSnapshot(
                title: "Reading History",
                author: "Bea",
                statusRawValue: ReadingStatus.reading.rawValue,
                tags: ["History"],
                readFrom: date(2026, 2, 1),
                publisher: "Beta",
                pageCount: 210,
                language: "EN",
                categories: ["Nonfiction / History"],
                mainCategory: "Nonfiction / History",
                userRatingAverage1: 3.7
            ),
            StatisticsBookSnapshot(
                title: "Queued Sci-Fi",
                author: "Cy",
                statusRawValue: ReadingStatus.toRead.rawValue,
                tags: ["Sci-Fi"],
                publisher: "Gamma",
                pageCount: 410,
                language: "EN",
                categories: ["Fiction / Science Fiction"],
                mainCategory: "Fiction / Science Fiction"
            )
        ]

        let cache = builder.makeStatsCache(
            for: .init(selectedYear: 2026, scope: .finished, booksSignature: 200),
            books: books
        )

        #expect(cache.summary.overview.scopedBooksCount == 1)
        #expect(cache.summary.overview.finishedScopedBooksCount == 1)
        #expect(cache.summary.overview.uniqueAuthorsCount == 1)
        #expect(cache.summary.overview.uniquePublishersCount == 1)
        #expect(cache.summary.heroSubtitle == "1 Bücher • 1 gelesen • 320 Seiten (wo vorhanden)")
        #expect(cache.topGenres.map { $0.label } == ["Thriller"])
        #expect(cache.topTags.map { $0.label } == ["Crime"])
        #expect(cache.highestRated?.label == "Finished Thriller • 4.5 / 5")
    }


    @Test func summaryCountsRereadCompletionsSeparatelyFromUniqueBooks() {
        let builder = StatisticsSnapshotBuilder(now: date(2026, 6, 15), calendar: calendar)
        let bookID = UUID(uuidString: "00000000-0000-0000-0000-000000003001") ?? UUID()
        let completions = [
            ReadingCompletionRecord(
                id: "attempt-one",
                bookID: bookID,
                attemptID: UUID(uuidString: "00000000-0000-0000-0000-000000003101"),
                sequenceNumber: 1,
                title: "Repeat",
                author: "Ada",
                startedAt: date(2026, 1, 1),
                finishedAt: date(2026, 1, 8),
                pageCount: 300,
                isReread: false
            ),
            ReadingCompletionRecord(
                id: "attempt-two",
                bookID: bookID,
                attemptID: UUID(uuidString: "00000000-0000-0000-0000-000000003102"),
                sequenceNumber: 2,
                title: "Repeat",
                author: "Ada",
                startedAt: date(2026, 3, 1),
                finishedAt: date(2026, 3, 7),
                pageCount: 300,
                isReread: true
            )
        ]
        let books = [
            StatisticsBookSnapshot(
                id: bookID,
                title: "Repeat",
                author: "Ada",
                statusRawValue: ReadingStatus.reading.rawValue,
                readFrom: date(2026, 6, 1),
                readTo: nil,
                pageCount: 300,
                readingCompletions: completions,
                activeAttemptStartedAt: date(2026, 6, 1)
            )
        ]

        let cache = builder.makeStatsCache(
            for: .init(selectedYear: 2026, scope: .finished, booksSignature: 301),
            books: books
        )

        #expect(cache.summary.overview.scopedBooksCount == 1)
        #expect(cache.summary.overview.finishedScopedBooksCount == 1)
        #expect(cache.summary.overview.readingCompletionCount == 2)
        #expect(cache.summary.overview.rereadCompletionCount == 1)
        #expect(cache.summary.overview.finishedInSelectedYearCount == 2)
        #expect(cache.summary.overview.uniqueBooksInSelectedYearCount == 1)
        #expect(cache.summary.overview.rereadCompletionsInSelectedYearCount == 1)
        #expect(cache.summary.overview.pagesInSelectedYear == 600)
        #expect(cache.monthlySeries.map { $0.finishedCount } == [1, 0, 1, 0, 0, 0])
        #expect(cache.monthlySeries.map { $0.pages } == [300, 0, 300, 0, 0, 0])
        #expect(cache.summary.heroSubtitle == "1 Bücher • 2 Abschlüsse • 1 Bücher gelesen • 300 Seiten (wo vorhanden)")
    }

    @Test func mixedLibraryKeepsCompletionCountsButLimitsPageStatistics() {
        let builder = StatisticsSnapshotBuilder(now: date(2026, 4, 15), calendar: calendar)
        let physicalID = UUID()
        let ebookID = UUID()
        let books = [
            StatisticsBookSnapshot(
                id: physicalID,
                title: "Paper",
                statusRawValue: ReadingStatus.finished.rawValue,
                pageCount: 300,
                readingCompletions: [
                    ReadingCompletionRecord(
                        id: "paper-completion",
                        bookID: physicalID,
                        sequenceNumber: 1,
                        title: "Paper",
                        author: "Ada",
                        startedAt: date(2026, 1, 1),
                        finishedAt: date(2026, 1, 10),
                        pageCount: 300,
                        progressUnitRawValue: ReadingProgressUnit.pages.rawValue,
                        isReread: false
                    )
                ],
                progressUnitRawValue: ReadingProgressUnit.pages.rawValue
            ),
            StatisticsBookSnapshot(
                id: ebookID,
                title: "Digital",
                statusRawValue: ReadingStatus.finished.rawValue,
                pageCount: 450,
                readingCompletions: [
                    ReadingCompletionRecord(
                        id: "ebook-completion",
                        bookID: ebookID,
                        sequenceNumber: 1,
                        title: "Digital",
                        author: "Bea",
                        startedAt: date(2026, 2, 1),
                        finishedAt: date(2026, 2, 8),
                        pageCount: 450,
                        mediumRawValue: ReadingMedium.ebook.rawValue,
                        providerRawValue: ReadingProvider.kindle.rawValue,
                        progressUnitRawValue: ReadingProgressUnit.percentage.rawValue,
                        isReread: false
                    )
                ],
                progressUnitRawValue: ReadingProgressUnit.percentage.rawValue
            )
        ]

        let cache = builder.makeStatsCache(
            for: .init(selectedYear: 2026, scope: .all, booksSignature: 450),
            books: books
        )

        #expect(cache.summary.overview.readingCompletionCount == 2)
        #expect(cache.summary.overview.finishedInSelectedYearCount == 2)
        #expect(cache.summary.overview.pagesInSelectedYear == 300)
        #expect(cache.summary.overview.avgPagesPerBookText == "300")
        #expect(cache.summary.overview.hasNonPageCompletionsInSelectedYear)
        #expect(cache.summary.heroSubtitle == "2 Bücher • 2 gelesen • 300 Seiten (nur seitenbasiert)")
        #expect(cache.monthlySeries.map(\.finishedCount) == [1, 1, 0, 0])
        #expect(cache.monthlySeries.map(\.pages) == [300, 0, 0, 0])
        #expect(cache.biggest?.label == "Paper • 300 Seiten")
    }

}

import Foundation

nonisolated enum ReadingAnalyticsIndexBuilder {
    static func make(
        books: [ReadingAnalyticsBookRecord],
        sessions: [ReadingAnalyticsSessionRecord],
        now: Date = Date(),
        calendar: Calendar = .current,
        sessionsAreSortedDescending: Bool = false
    ) -> ReadingAnalyticsIndex {
        let yearSummaries = makeYearSummaries(from: books, calendar: calendar)
        let finishedBookYears = yearSummaries.keys.sorted(by: >)
        let recentActivity = ReadingAnalyticsRecentActivityBuilder.make(
            sessions: sessions,
            sessionsAreSortedDescending: sessionsAreSortedDescending,
            now: now,
            calendar: calendar
        )

        return ReadingAnalyticsIndex(
            finishedBookYears: finishedBookYears,
            yearSummaries: yearSummaries,
            recentActivity: recentActivity
        )
    }

    private static func makeYearSummaries(
        from books: [ReadingAnalyticsBookRecord],
        calendar: Calendar
    ) -> [Int: ReadingAnalyticsYearSummary] {
        var accumulators: [Int: YearAccumulator] = [:]

        for book in books {
            for completion in book.readingCompletions {
                let keyDate = completion.finishedAt
                let year = calendar.component(.year, from: keyDate)
                let month = calendar.component(.month, from: keyDate)
                let pages = completion.normalizedPageCount

                var accumulator = accumulators[year] ?? YearAccumulator()
                accumulator.finishedBookCount += 1
                accumulator.uniqueBookIDs.insert(completion.bookID)
                if completion.isReread {
                    accumulator.rereadCompletionCount += 1
                }
                accumulator.pagesRead += pages
                let contribution = completion.metricContribution
                if contribution.progressUnit == .pages {
                    accumulator.pageBasedCompletionCount += 1
                } else {
                    accumulator.nonPageCompletionCount += 1
                }

                if pages > 0 {
                    accumulator.countedBooksWithPagesCount += 1
                }

                accumulator.pagesByMonth[month, default: 0] += pages
                accumulators[year] = accumulator
            }
        }

        return Dictionary(uniqueKeysWithValues: accumulators.map { year, accumulator in
            let averagePagesPerBook: Int?
            if accumulator.countedBooksWithPagesCount == 0 {
                averagePagesPerBook = nil
            } else {
                averagePagesPerBook = Int(
                    (
                        Double(accumulator.pagesRead) /
                        Double(accumulator.countedBooksWithPagesCount)
                    ).rounded()
                )
            }

            return (
                year,
                ReadingAnalyticsYearSummary(
                    year: year,
                    finishedBookCount: accumulator.finishedBookCount,
                    uniqueFinishedBookCount: accumulator.uniqueBookIDs.count,
                    rereadCompletionCount: accumulator.rereadCompletionCount,
                    pagesRead: accumulator.pagesRead,
                    pageBasedCompletionCount: accumulator.pageBasedCompletionCount,
                    nonPageCompletionCount: accumulator.nonPageCompletionCount,
                    countedBooksWithPagesCount: accumulator.countedBooksWithPagesCount,
                    averagePagesPerBook: averagePagesPerBook,
                    pagesByMonth: accumulator.pagesByMonth
                )
            )
        })
    }

}

private nonisolated struct YearAccumulator {
    var finishedBookCount: Int = 0
    var uniqueBookIDs: Set<UUID> = []
    var rereadCompletionCount: Int = 0
    var pagesRead: Int = 0
    var pageBasedCompletionCount: Int = 0
    var nonPageCompletionCount: Int = 0
    var countedBooksWithPagesCount: Int = 0
    var pagesByMonth: [Int: Int] = [:]
}

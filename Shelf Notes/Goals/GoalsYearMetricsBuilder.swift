//
//  GoalsYearMetricsBuilder.swift
//  Shelf Notes
//
//  Pure builder for derived yearly metrics used by GoalsView.
//

import Foundation

nonisolated struct GoalsYearCompletion: Identifiable {
    let id: String
    let book: Book
    let record: ReadingCompletionRecord
}

nonisolated struct GoalsYearMetrics {
    let selectedYear: Int
    let availableYears: [Int]
    let finishedCompletions: [GoalsYearCompletion]
    let pagesReadInSelectedYear: Int
    let countedBooksWithPagesCount: Int
    let averagePagesPerBook: Int?
    let monthsCount: Int
    let pagesPerMonth: Int
    let uniqueFinishedBooksCount: Int
    let rereadCompletionCount: Int

    var finishedBooks: [Book] {
        finishedCompletions.map(\.book)
    }

    var finishedCompletionCount: Int {
        finishedCompletions.count
    }
}

extension GoalsYearMetrics: Equatable {
    static func == (lhs: GoalsYearMetrics, rhs: GoalsYearMetrics) -> Bool {
        lhs.selectedYear == rhs.selectedYear &&
        lhs.availableYears == rhs.availableYears &&
        lhs.finishedCompletions.map(\.id) == rhs.finishedCompletions.map(\.id) &&
        lhs.pagesReadInSelectedYear == rhs.pagesReadInSelectedYear &&
        lhs.countedBooksWithPagesCount == rhs.countedBooksWithPagesCount &&
        lhs.averagePagesPerBook == rhs.averagePagesPerBook &&
        lhs.monthsCount == rhs.monthsCount &&
        lhs.pagesPerMonth == rhs.pagesPerMonth &&
        lhs.uniqueFinishedBooksCount == rhs.uniqueFinishedBooksCount &&
        lhs.rereadCompletionCount == rhs.rereadCompletionCount
    }

    static func placeholder(
        selectedYear: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> GoalsYearMetrics {
        GoalsYearMetricsBuilder.make(
            selectedYear: selectedYear,
            books: [],
            goals: [],
            now: now,
            calendar: calendar
        )
    }
}

nonisolated enum GoalsYearMetricsBuilder {
    static func make(
        selectedYear: Int,
        books: [Book],
        goals: [ReadingGoal],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> GoalsYearMetrics {
        let analyticsIndex = ReadingAnalyticsIndexBuilder.make(
            books: ReadingAnalyticsInputMapper.bookRecords(from: books),
            sessions: [],
            now: now,
            calendar: calendar
        )
        let yearSummary = analyticsIndex.summary(forYear: selectedYear)
        let availableYears = availableYears(
            from: analyticsIndex.finishedBookYears,
            goals: goals,
            selectedYear: selectedYear,
            now: now,
            calendar: calendar
        )
        let finishedCompletions = completions(in: selectedYear, books: books, calendar: calendar)
        let monthsCount = monthsCount(for: selectedYear, now: now, calendar: calendar)
        let pagesPerMonth = Int((Double(yearSummary.pagesRead) / Double(max(1, monthsCount))).rounded())

        return GoalsYearMetrics(
            selectedYear: selectedYear,
            availableYears: availableYears,
            finishedCompletions: finishedCompletions,
            pagesReadInSelectedYear: yearSummary.pagesRead,
            countedBooksWithPagesCount: yearSummary.countedBooksWithPagesCount,
            averagePagesPerBook: yearSummary.averagePagesPerBook,
            monthsCount: monthsCount,
            pagesPerMonth: pagesPerMonth,
            uniqueFinishedBooksCount: yearSummary.uniqueFinishedBookCount,
            rereadCompletionCount: yearSummary.rereadCompletionCount
        )
    }

    private static func availableYears(
        from finishedBookYears: [Int],
        goals: [ReadingGoal],
        selectedYear: Int,
        now: Date,
        calendar: Calendar
    ) -> [Int] {
        let currentYear = calendar.component(.year, from: now)
        let nextYear = currentYear + 1

        var years = Set<Int>()
        years.insert(currentYear)
        years.insert(nextYear)
        years.insert(selectedYear)

        for year in finishedBookYears {
            years.insert(year)
        }

        for goal in goals {
            years.insert(goal.year)
        }

        return years.sorted(by: >)
    }

    private static func completions(
        in selectedYear: Int,
        books: [Book],
        calendar: Calendar
    ) -> [GoalsYearCompletion] {
        let start = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) ?? .distantPast
        let end = calendar.date(from: DateComponents(year: selectedYear + 1, month: 1, day: 1)) ?? .distantFuture

        return books
            .flatMap { book in
                ReadingCompletionRecordBuilder.records(from: book).compactMap { record in
                    guard record.finishedAt >= start && record.finishedAt < end else { return nil }
                    return GoalsYearCompletion(id: record.id, book: book, record: record)
                }
            }
            .sorted(by: compareCompletions)
    }

    private static func compareCompletions(_ lhs: GoalsYearCompletion, _ rhs: GoalsYearCompletion) -> Bool {
        let left = lhs.record
        let right = rhs.record

        if left.finishedAt != right.finishedAt {
            return left.finishedAt < right.finishedAt
        }

        if lhs.book.createdAt != rhs.book.createdAt {
            return lhs.book.createdAt < rhs.book.createdAt
        }

        let titleComparison = lhs.book.title.localizedCaseInsensitiveCompare(rhs.book.title)
        if titleComparison != .orderedSame {
            return titleComparison == .orderedAscending
        }

        let authorComparison = lhs.book.author.localizedCaseInsensitiveCompare(rhs.book.author)
        if authorComparison != .orderedSame {
            return authorComparison == .orderedAscending
        }

        if left.sequenceNumber != right.sequenceNumber {
            return left.sequenceNumber < right.sequenceNumber
        }

        return left.id < right.id
    }

    private static func monthsCount(
        for selectedYear: Int,
        now: Date,
        calendar: Calendar
    ) -> Int {
        let currentYear = calendar.component(.year, from: now)

        if selectedYear < currentYear {
            return 12
        }

        if selectedYear > currentYear {
            return 12
        }

        return max(1, calendar.component(.month, from: now))
    }
}

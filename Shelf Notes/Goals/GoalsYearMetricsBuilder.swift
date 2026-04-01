//
//  GoalsYearMetricsBuilder.swift
//  Shelf Notes
//
//  Pure builder for derived yearly metrics used by GoalsView.
//

import Foundation

struct GoalsYearMetrics {
    let selectedYear: Int
    let availableYears: [Int]
    let finishedBooks: [Book]
    let pagesReadInSelectedYear: Int
    let countedBooksWithPagesCount: Int
    let averagePagesPerBook: Int?
    let monthsCount: Int
    let pagesPerMonth: Int
}

enum GoalsYearMetricsBuilder {
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
            now: now,
            calendar: calendar
        )
        let finishedBooks = finishedBooks(in: selectedYear, books: books, calendar: calendar)
        let monthsCount = monthsCount(for: selectedYear, now: now, calendar: calendar)
        let pagesPerMonth = Int((Double(yearSummary.pagesRead) / Double(max(1, monthsCount))).rounded())

        return GoalsYearMetrics(
            selectedYear: selectedYear,
            availableYears: availableYears,
            finishedBooks: finishedBooks,
            pagesReadInSelectedYear: yearSummary.pagesRead,
            countedBooksWithPagesCount: yearSummary.countedBooksWithPagesCount,
            averagePagesPerBook: yearSummary.averagePagesPerBook,
            monthsCount: monthsCount,
            pagesPerMonth: pagesPerMonth
        )
    }

    private static func availableYears(
        from finishedBookYears: [Int],
        goals: [ReadingGoal],
        now: Date,
        calendar: Calendar
    ) -> [Int] {
        let currentYear = calendar.component(.year, from: now)
        let nextYear = currentYear + 1

        var years = Set<Int>()
        years.insert(currentYear)
        years.insert(nextYear)

        for year in finishedBookYears {
            years.insert(year)
        }

        for goal in goals {
            years.insert(goal.year)
        }

        return years.sorted(by: >)
    }

    private static func finishedBooks(
        in selectedYear: Int,
        books: [Book],
        calendar: Calendar
    ) -> [Book] {
        let start = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) ?? .distantPast
        let end = calendar.date(from: DateComponents(year: selectedYear + 1, month: 1, day: 1)) ?? .distantFuture

        return books
            .filter { book in
                guard book.status == .finished else { return false }
                guard let keyDate = readKeyDate(book) else { return false }
                return keyDate >= start && keyDate < end
            }
            .sorted(by: compareFinishedBooks)
    }

    private static func compareFinishedBooks(_ lhs: Book, _ rhs: Book) -> Bool {
        let lhsKeyDate = readKeyDate(lhs) ?? lhs.createdAt
        let rhsKeyDate = readKeyDate(rhs) ?? rhs.createdAt

        if lhsKeyDate != rhsKeyDate {
            return lhsKeyDate < rhsKeyDate
        }

        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }

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

    private static func readKeyDate(_ book: Book) -> Date? {
        book.readTo ?? book.readFrom
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

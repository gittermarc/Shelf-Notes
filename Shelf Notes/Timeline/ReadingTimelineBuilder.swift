import Foundation

nonisolated enum ReadingTimelineBuilder {
    static func build(
        bookSnapshots: [ReadingTimelineBookSnapshot],
        calendar: Calendar = .current
    ) -> ReadingTimelineDisplayState {
        let entryItems = bookSnapshots
            .flatMap { book in
                book.completions.map { completion in
                    ReadingTimelineEntryDisplayItem(
                        completion: completion,
                        userRatingAverage: book.userRatingAverage
                    )
                }
            }
            .sorted { left, right in
                ReadingTimelineCompletionSnapshot.compare(left.completion, right.completion)
            }

        guard !entryItems.isEmpty else {
            return .empty
        }

        let yearStats = buildYearStats(entries: entryItems, calendar: calendar)
        let years = Array(Set(entryItems.map { calendar.component(.year, from: $0.date) })).sorted()
        let items = buildItems(
            entries: entryItems,
            yearStatsByYear: yearStats,
            calendar: calendar
        )

        return ReadingTimelineDisplayState(
            years: years,
            items: items,
            completionCount: entryItems.count,
            rereadCompletionCount: entryItems.filter { $0.completion.isReread }.count
        )
    }

    private static func buildYearStats(
        entries: [ReadingTimelineEntryDisplayItem],
        calendar: Calendar
    ) -> [Int: ReadingTimelineYearDisplayStats] {
        var entriesByYear: [Int: [ReadingTimelineEntryDisplayItem]] = [:]
        for entry in entries {
            let year = calendar.component(.year, from: entry.date)
            entriesByYear[year, default: []].append(entry)
        }

        var statsByYear: [Int: ReadingTimelineYearDisplayStats] = [:]
        for (year, entriesForYear) in entriesByYear {
            let sorted = entriesForYear.sorted { left, right in
                ReadingTimelineCompletionSnapshot.compare(left.completion, right.completion)
            }
            let ratedAverages = entriesForYear.compactMap(\.userRatingAverage)
            let averageRating = ratedAverages.isEmpty
                ? nil
                : ratedAverages.reduce(0, +) / Double(ratedAverages.count)

            statsByYear[year] = ReadingTimelineYearDisplayStats(
                year: year,
                count: entriesForYear.count,
                uniqueBookCount: Set(entriesForYear.map(\.bookID)).count,
                rereadCount: entriesForYear.filter { $0.completion.isReread }.count,
                ratedCount: ratedAverages.count,
                averageRating: averageRating,
                firstDate: sorted.first?.date,
                lastDate: sorted.last?.date,
                previewBookIDs: Array(sorted.prefix(4).map(\.bookID))
            )
        }
        return statsByYear
    }

    private static func buildItems(
        entries: [ReadingTimelineEntryDisplayItem],
        yearStatsByYear: [Int: ReadingTimelineYearDisplayStats],
        calendar: Calendar
    ) -> [ReadingTimelineDisplayItem] {
        var output: [ReadingTimelineDisplayItem] = []
        output.reserveCapacity(entries.count + yearStatsByYear.count)
        var lastYear: Int?

        for entry in entries {
            let year = calendar.component(.year, from: entry.date)
            if lastYear != year {
                let stats = yearStatsByYear[year] ?? .empty(year: year)
                output.append(ReadingTimelineDisplayItem(kind: .year(year, stats)))
                lastYear = year
            }
            output.append(ReadingTimelineDisplayItem(kind: .completion(entry)))
        }

        return output
    }
}

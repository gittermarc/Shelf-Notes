//
//  ReadingTimelineViewModel.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 25.01.26.
//

import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
final class ReadingTimelineViewModel: ObservableObject {

    // MARK: - UI state

    @Published var selectedYear: Int?

    /// Set to a year to trigger `ScrollViewReader` jump.
    /// The view should reset this to `nil` after it scrolls, so selecting the same year again still jumps.
    @Published var jumpToYear: Int?

    // Mini-map auto highlight support
    @Published var timelineViewportWidth: CGFloat = 0
    @Published var yearMarkerMidXByYear: [Int: CGFloat] = [:]

    // MARK: - Derived data

    @Published private(set) var years: [Int] = []
    @Published private(set) var items: [ReadingTimelineItem] = []
    @Published private(set) var hasBuiltTimeline = false

    // MARK: - Inputs

    private var cachedEntries: [ReadingTimelineEntry] = []

    /// Task-friendly signature for `.task(id:)`.
    ///
    /// ReadingAttempts are included because an active reread can make the book status `.reading`
    /// while previous completed attempts still belong on the timeline.
    static func taskSignature(books: [Book]) -> Int {
        func dayStamp(_ d: Date) -> Int {
            Int(d.timeIntervalSince1970 / 86_400)
        }

        func dayStamp(_ d: Date?) -> Int {
            guard let d else { return -1 }
            return Int(d.timeIntervalSince1970 / 86_400)
        }

        var xorAgg: Int = 0
        var sumAgg: Int = 0

        for b in books {
            var h = Hasher()
            h.combine(b.id)

            h.combine(dayStamp(b.createdAt))
            h.combine(dayStamp(b.readFrom))
            h.combine(dayStamp(b.readTo))
            h.combine(b.statusRawValue)

            for attempt in b.orderedReadingAttempts {
                h.combine(attempt.id)
                h.combine(attempt.sequenceNumber)
                h.combine(attempt.statusRawValue)
                h.combine(dayStamp(attempt.startedAt))
                h.combine(dayStamp(attempt.finishedAt))
                h.combine(attempt.pageCountSnapshot)
                h.combine(dayStamp(attempt.updatedAt))
            }

            // Year summary cards depend on these.
            h.combine(b.userRatingPlot)
            h.combine(b.userRatingCharacters)
            h.combine(b.userRatingWritingStyle)
            h.combine(b.userRatingAtmosphere)
            h.combine(b.userRatingGenreFit)
            h.combine(b.userRatingPresentation)

            let bookHash = h.finalize()
            xorAgg ^= bookHash
            sumAgg &+= bookHash
        }

        var finalHasher = Hasher()
        finalHasher.combine(books.count)
        finalHasher.combine(xorAgg)
        finalHasher.combine(sumAgg)
        return finalHasher.finalize()
    }

    func setBooks(_ books: [Book]) {
        cachedEntries = books
            .flatMap { book in
                ReadingCompletionRecordBuilder.records(from: book).map { completion in
                    ReadingTimelineEntry(book: book, completion: completion)
                }
            }
            .sorted { left, right in
                ReadingCompletionRecordBuilder.compare(left.completion, right.completion)
            }

        years = Array(Set(cachedEntries.map { Calendar.current.component(.year, from: $0.date) })).sorted()

        let yearStats = buildYearStats(entries: cachedEntries)
        items = buildItems(entries: cachedEntries, yearStatsByYear: yearStats)
        hasBuiltTimeline = true

        if selectedYear == nil {
            selectedYear = years.first
        } else if let selectedYear, !years.contains(selectedYear) {
            self.selectedYear = years.first
        }
    }

    // MARK: - Commands

    func requestJump(to year: Int) {
        selectedYear = year
        jumpToYear = year
    }

    func requestJumpToStart() {
        guard let first = years.first else { return }
        requestJump(to: first)
    }

    func requestJumpToEnd() {
        guard let last = years.last else { return }
        requestJump(to: last)
    }

    func scrollID(forYear year: Int) -> String {
        "year-\(year)"
    }

    // MARK: - Auto highlight

    func updateViewportWidth(_ width: CGFloat) {
        timelineViewportWidth = width
        updateAutoHighlightedYearIfNeeded()
    }

    func updateYearMarkerPositions(_ positions: [Int: CGFloat]) {
        yearMarkerMidXByYear = positions
        updateAutoHighlightedYearIfNeeded()
    }

    private func updateAutoHighlightedYearIfNeeded() {
        guard timelineViewportWidth > 0 else { return }
        let centerX = timelineViewportWidth / 2

        var bestYear: Int?
        var bestDistance: CGFloat = .greatestFiniteMagnitude

        for (year, midX) in yearMarkerMidXByYear {
            let dist = abs(midX - centerX)
            if dist < bestDistance {
                bestDistance = dist
                bestYear = year
            }
        }

        guard let bestYear else { return }

        if selectedYear != bestYear {
            selectedYear = bestYear
        }
    }

    // MARK: - Building blocks

    private func buildYearStats(entries: [ReadingTimelineEntry]) -> [Int: ReadingTimelineYearStats] {
        var dict: [Int: [ReadingTimelineEntry]] = [:]

        for entry in entries {
            let year = Calendar.current.component(.year, from: entry.date)
            dict[year, default: []].append(entry)
        }

        var out: [Int: ReadingTimelineYearStats] = [:]
        for (year, entriesForYear) in dict {
            let count = entriesForYear.count

            let ratedAverages: [Double] = entriesForYear.compactMap { $0.book.userRatingAverage }
            let ratedCount = ratedAverages.count
            let avgRating: Double? = ratedAverages.isEmpty
                ? nil
                : (ratedAverages.reduce(0, +) / Double(ratedAverages.count))

            let sorted = entriesForYear.sorted { $0.date < $1.date }
            let firstDate = sorted.first?.date
            let lastDate = sorted.last?.date
            let previewBooks = Array(sorted.prefix(4).map { $0.book })
            let uniqueBookCount = Set(sorted.map { $0.book.id }).count
            let rereadCount = sorted.filter { $0.completion.isReread }.count

            out[year] = ReadingTimelineYearStats(
                year: year,
                count: count,
                uniqueBookCount: uniqueBookCount,
                rereadCount: rereadCount,
                ratedCount: ratedCount,
                averageRating: avgRating,
                firstDate: firstDate,
                lastDate: lastDate,
                previewBooks: previewBooks
            )
        }

        return out
    }

    private func buildItems(
        entries: [ReadingTimelineEntry],
        yearStatsByYear: [Int: ReadingTimelineYearStats]
    ) -> [ReadingTimelineItem] {
        guard !entries.isEmpty else { return [] }

        var out: [ReadingTimelineItem] = []
        var lastYear: Int?

        for entry in entries {
            let year = Calendar.current.component(.year, from: entry.date)

            if lastYear != year {
                let stats = yearStatsByYear[year] ?? ReadingTimelineYearStats(
                    year: year,
                    count: 0,
                    uniqueBookCount: 0,
                    rereadCount: 0,
                    ratedCount: 0,
                    averageRating: nil,
                    firstDate: nil,
                    lastDate: nil,
                    previewBooks: []
                )
                out.append(ReadingTimelineItem(kind: .year(year, stats)))
                lastYear = year
            }

            out.append(ReadingTimelineItem(kind: .completion(entry)))
        }

        return out
    }
}

// MARK: - Models used by the timeline

struct ReadingTimelineItem: Identifiable {
    enum Kind {
        case year(Int, ReadingTimelineYearStats)
        case completion(ReadingTimelineEntry)
    }

    let kind: Kind

    var id: String {
        switch kind {
        case .year(let year, _):
            return "year-\(year)"
        case .completion(let entry):
            return "completion-\(entry.completion.id)"
        }
    }
}

struct ReadingTimelineEntry {
    let book: Book
    let completion: ReadingCompletionRecord

    var date: Date {
        completion.finishedAt
    }

    var attemptLabel: String? {
        completion.isReread ? completion.displayName : nil
    }
}

struct ReadingTimelineYearStats {
    let year: Int
    let count: Int
    let uniqueBookCount: Int
    let rereadCount: Int
    let ratedCount: Int
    let averageRating: Double?
    let firstDate: Date?
    let lastDate: Date?
    let previewBooks: [Book]

    var dateRangeText: String? {
        guard let firstDate, let lastDate else { return nil }
        let start = firstDate.formatted(.dateTime.day().month(.twoDigits))
        let end = lastDate.formatted(.dateTime.day().month(.twoDigits))
        return "\(start) – \(end)"
    }

    var averageRatingText: String? {
        guard let averageRating else { return nil }
        let rounded = (averageRating * 10).rounded() / 10
        return String(format: "%.1f", rounded)
    }
}

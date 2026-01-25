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

    // MARK: - Inputs

    private var cachedEntries: [ReadingTimelineEntry] = []

    func setBooks(_ finishedBooks: [Book]) {
        cachedEntries = finishedBooks
            .map { ReadingTimelineEntry(book: $0, date: completionDate(for: $0)) }
            .sorted { $0.date < $1.date }

        years = Array(Set(cachedEntries.map { Calendar.current.component(.year, from: $0.date) })).sorted()

        let yearStats = buildYearStats(entries: cachedEntries)
        items = buildItems(entries: cachedEntries, yearStatsByYear: yearStats)

        if selectedYear == nil {
            selectedYear = years.first
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

        // Find the year marker closest to the center of the visible area.
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

        // Only update if it actually changed, to avoid needless state churn.
        if selectedYear != bestYear {
            selectedYear = bestYear
        }
    }

    // MARK: - Building blocks

    private func completionDate(for book: Book) -> Date {
        book.readTo ?? book.readFrom ?? book.createdAt
    }

    private func buildYearStats(entries: [ReadingTimelineEntry]) -> [Int: ReadingTimelineYearStats] {
        var dict: [Int: [ReadingTimelineEntry]] = [:]

        for e in entries {
            let y = Calendar.current.component(.year, from: e.date)
            dict[y, default: []].append(e)
        }

        var out: [Int: ReadingTimelineYearStats] = [:]
        for (year, es) in dict {
            let count = es.count

            let ratedAverages: [Double] = es.compactMap { $0.book.userRatingAverage }
            let ratedCount = ratedAverages.count
            let avgRating: Double? = ratedAverages.isEmpty
                ? nil
                : (ratedAverages.reduce(0, +) / Double(ratedAverages.count))

            let sorted = es.sorted { $0.date < $1.date }
            let firstDate = sorted.first?.date
            let lastDate = sorted.last?.date
            let previewBooks = Array(sorted.prefix(4).map { $0.book })

            out[year] = ReadingTimelineYearStats(
                year: year,
                count: count,
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

        for e in entries {
            let y = Calendar.current.component(.year, from: e.date)

            if lastYear != y {
                let stats = yearStatsByYear[y] ?? ReadingTimelineYearStats(
                    year: y,
                    count: 0,
                    ratedCount: 0,
                    averageRating: nil,
                    firstDate: nil,
                    lastDate: nil,
                    previewBooks: []
                )
                out.append(ReadingTimelineItem(kind: .year(y, stats)))
                lastYear = y
            }

            out.append(ReadingTimelineItem(kind: .book(e.book, e.date)))
        }

        return out
    }
}

// MARK: - Models used by the timeline

struct ReadingTimelineItem: Identifiable {
    enum Kind {
        case year(Int, ReadingTimelineYearStats)
        case book(Book, Date)
    }

    let kind: Kind

    var id: String {
        switch kind {
        case .year(let y, _):
            return "year-\(y)"
        case .book(let book, let date):
            // Stable across renders and unique enough for UI diffing.
            return "book-\(book.id.uuidString)-\(Int(date.timeIntervalSince1970))"
        }
    }
}

struct ReadingTimelineEntry {
    let book: Book
    let date: Date
}

struct ReadingTimelineYearStats {
    let year: Int
    let count: Int
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

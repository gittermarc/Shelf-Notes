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

    // Mini-map auto highlight support. These values change frequently while scrolling,
    // so they deliberately stay private and non-published.
    private var timelineViewportWidth: CGFloat = 0
    private var yearMarkerMidXByYear: [Int: CGFloat] = [:]

    // MARK: - Derived data

    @Published private(set) var years: [Int] = []
    @Published private(set) var items: [ReadingTimelineItem] = []
    @Published private(set) var displayState: ReadingTimelineDisplayState = .empty
    @Published private(set) var hasBuiltTimeline = false

    // MARK: - Inputs

    private var lastAppliedSourceSignature: ReadingTimelineSourceSignature?
    private var buildGeneration = 0

    /// Task-friendly signature for `.task(id:)`.
    ///
    /// Uses the same MainActor snapshot input as the value-only builder, so status,
    /// legacy fallback completions, completed attempts and ratings stay in sync.
    static func taskSignature(books: [Book]) -> ReadingTimelineSourceSignature {
        ReadingTimelineSourceSignature(bookSnapshots: ReadingTimelineBookSnapshot.snapshots(from: books))
    }

    func setBooks(_ books: [Book]) async {
        let snapshots = ReadingTimelineBookSnapshot.snapshots(from: books)
        let sourceSignature = ReadingTimelineSourceSignature(bookSnapshots: snapshots)

        if hasBuiltTimeline, lastAppliedSourceSignature == sourceSignature {
            return
        }

        buildGeneration += 1
        let generation = buildGeneration
        let calendar = Calendar.current

        let nextDisplayState = await PerformanceSignposter.measureAsync("Timeline Build") {
            await Task.detached(priority: .userInitiated) {
                ReadingTimelineBuilder.build(bookSnapshots: snapshots, calendar: calendar)
            }.value
        }

        guard !Task.isCancelled else { return }
        guard generation == buildGeneration else { return }

        var bookByID: [UUID: Book] = [:]
        for book in books {
            bookByID[book.id] = book
        }
        displayState = nextDisplayState
        years = nextDisplayState.years
        items = ReadingTimelineViewModel.makeItems(
            from: nextDisplayState,
            bookByID: bookByID
        )
        lastAppliedSourceSignature = sourceSignature
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
        guard abs(timelineViewportWidth - width) > ReadingTimelineYearSelection.defaultPositionTolerance else { return }
        timelineViewportWidth = width
        updateAutoHighlightedYearIfNeeded()
    }

    func updateYearMarkerPositions(_ positions: [Int: CGFloat]) {
        guard !ReadingTimelineYearSelection.markerPositionsAreEquivalent(
            yearMarkerMidXByYear,
            positions
        ) else { return }
        yearMarkerMidXByYear = positions
        updateAutoHighlightedYearIfNeeded()
    }

    private func updateAutoHighlightedYearIfNeeded() {
        let bestYear = ReadingTimelineYearSelection.nearestYear(
            viewportWidth: timelineViewportWidth,
            markerMidXByYear: yearMarkerMidXByYear,
            selectedYear: selectedYear
        )
        guard let bestYear else { return }

        if selectedYear != bestYear {
            selectedYear = bestYear
        }
    }

    // MARK: - Display bridge

    private static func makeItems(
        from displayState: ReadingTimelineDisplayState,
        bookByID: [UUID: Book]
    ) -> [ReadingTimelineItem] {
        displayState.items.compactMap { item in
            switch item.kind {
            case .year(let year, let displayStats):
                let previewBooks = displayStats.previewBookIDs.compactMap { bookByID[$0] }
                let stats = ReadingTimelineYearStats(
                    displayStats: displayStats,
                    previewBooks: previewBooks
                )
                return ReadingTimelineItem(kind: .year(year, stats))

            case .completion(let displayItem):
                guard let book = bookByID[displayItem.bookID] else { return nil }
                let entry = ReadingTimelineEntry(
                    book: book,
                    completion: displayItem.completion.asCompletionRecord
                )
                return ReadingTimelineItem(kind: .completion(entry))
            }
        }
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

    init(
        year: Int,
        count: Int,
        uniqueBookCount: Int,
        rereadCount: Int,
        ratedCount: Int,
        averageRating: Double?,
        firstDate: Date?,
        lastDate: Date?,
        previewBooks: [Book]
    ) {
        self.year = year
        self.count = count
        self.uniqueBookCount = uniqueBookCount
        self.rereadCount = rereadCount
        self.ratedCount = ratedCount
        self.averageRating = averageRating
        self.firstDate = firstDate
        self.lastDate = lastDate
        self.previewBooks = previewBooks
    }

    init(
        displayStats: ReadingTimelineYearDisplayStats,
        previewBooks: [Book]
    ) {
        self.init(
            year: displayStats.year,
            count: displayStats.count,
            uniqueBookCount: displayStats.uniqueBookCount,
            rereadCount: displayStats.rereadCount,
            ratedCount: displayStats.ratedCount,
            averageRating: displayStats.averageRating,
            firstDate: displayStats.firstDate,
            lastDate: displayStats.lastDate,
            previewBooks: previewBooks
        )
    }

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

//
//  ReadingTimelineViewModel.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 25.01.26.
//

import Foundation
import SwiftUI
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

    // MARK: - Commands

    func ensureSelectedYear(in years: [Int]) {
        guard !years.isEmpty else {
            if selectedYear != nil {
                selectedYear = nil
            }
            return
        }

        if let selectedYear, years.contains(selectedYear) {
            return
        }

        selectedYear = years.first
    }

    func requestJump(to year: Int) {
        selectedYear = year
        jumpToYear = year
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
}

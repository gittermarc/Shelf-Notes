import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingTimelineYearSelectionTests {
    @Test func selectsYearNearestToViewportCenter() {
        let selectedYear = ReadingTimelineYearSelection.nearestYear(
            viewportWidth: 240,
            markerMidXByYear: [
                2020: 36,
                2021: 118,
                2022: 210
            ],
            selectedYear: nil,
            hysteresis: 0
        )

        #expect(selectedYear == 2021)
    }

    @Test func returnsNilWithoutViewportWidth() {
        let selectedYear = ReadingTimelineYearSelection.nearestYear(
            viewportWidth: 0,
            markerMidXByYear: [2024: 100],
            selectedYear: nil
        )

        #expect(selectedYear == nil)
    }

    @Test func returnsNilWithoutMarkers() {
        let selectedYear = ReadingTimelineYearSelection.nearestYear(
            viewportWidth: 240,
            markerMidXByYear: [:],
            selectedYear: nil
        )

        #expect(selectedYear == nil)
    }

    @Test func keepsCurrentSelectionForMinimalPositionChanges() {
        let selectedYear = ReadingTimelineYearSelection.nearestYear(
            viewportWidth: 200,
            markerMidXByYear: [
                2024: 96,
                2025: 106,
                2026: 180
            ],
            selectedYear: 2025,
            hysteresis: 8
        )

        #expect(selectedYear == 2025)
    }

    @Test func detectsEquivalentMarkerPositionsWithinTolerance() {
        let existing: [Int: CGFloat] = [
            2024: 96,
            2025: 106
        ]
        let updated: [Int: CGFloat] = [
            2024: 96.25,
            2025: 105.75
        ]

        #expect(ReadingTimelineYearSelection.markerPositionsAreEquivalent(existing, updated, tolerance: 0.5))
    }
}
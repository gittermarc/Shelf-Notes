//
//  ReadingTimelineYearSelection.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 01.07.26.
//

import Foundation

enum ReadingTimelineYearSelection {
    static let defaultPositionTolerance: CGFloat = 0.5
    static let defaultSelectionHysteresis: CGFloat = 8

    static func nearestYear(
        viewportWidth: CGFloat,
        markerMidXByYear: [Int: CGFloat],
        selectedYear: Int?,
        hysteresis: CGFloat = defaultSelectionHysteresis
    ) -> Int? {
        guard viewportWidth > 0, !markerMidXByYear.isEmpty else { return nil }

        let centerX = viewportWidth / 2
        let rankedYears = markerMidXByYear
            .map { year, midX in
                ReadingTimelineYearCandidate(
                    year: year,
                    distanceFromCenter: abs(midX - centerX)
                )
            }
            .sorted { left, right in
                if left.distanceFromCenter == right.distanceFromCenter {
                    return left.year < right.year
                }
                return left.distanceFromCenter < right.distanceFromCenter
            }

        guard let nearest = rankedYears.first else { return nil }

        if let selectedYear,
           let selectedMidX = markerMidXByYear[selectedYear] {
            let selectedDistance = abs(selectedMidX - centerX)
            let clampedHysteresis = max(0, hysteresis)
            if selectedDistance <= nearest.distanceFromCenter + clampedHysteresis {
                return selectedYear
            }
        }

        return nearest.year
    }

    static func markerPositionsAreEquivalent(
        _ lhs: [Int: CGFloat],
        _ rhs: [Int: CGFloat],
        tolerance: CGFloat = defaultPositionTolerance
    ) -> Bool {
        guard lhs.keys.count == rhs.keys.count else { return false }
        let clampedTolerance = max(0, tolerance)

        for (year, leftMidX) in lhs {
            guard let rightMidX = rhs[year] else { return false }
            if abs(leftMidX - rightMidX) > clampedTolerance {
                return false
            }
        }

        return true
    }
}

private struct ReadingTimelineYearCandidate {
    let year: Int
    let distanceFromCenter: CGFloat
}
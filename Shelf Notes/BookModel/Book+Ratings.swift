//
//  Book+Ratings.swift
//  Shelf Notes
//

import Foundation

extension Book {
    /// All rating fields in one place (0 = not rated)
    var userRatingValues: [Int] {
        [
            userRatingPlot,
            userRatingCharacters,
            userRatingWritingStyle,
            userRatingAtmosphere,
            userRatingGenreFit,
            userRatingPresentation
        ]
    }

    /// Average of all set criteria (ignores zeros). Returns nil if nothing was rated yet.
    var userRatingAverage: Double? {
        let values = userRatingValues.filter { $0 > 0 }
        guard !values.isEmpty else { return nil }
        let sum = values.reduce(0, +)
        return Double(sum) / Double(values.count)
    }

    /// Convenience: average rounded to 1 decimal (e.g. 4.2)
    var userRatingAverage1: Double? {
        guard let average = userRatingAverage else { return nil }
        return (average * 10).rounded() / 10
    }

    /// Resets all user rating fields back to 0 (= nicht bewertet).
    func clearUserRatings() {
        userRatingPlot = 0
        userRatingCharacters = 0
        userRatingWritingStyle = 0
        userRatingAtmosphere = 0
        userRatingGenreFit = 0
        userRatingPresentation = 0
    }
}

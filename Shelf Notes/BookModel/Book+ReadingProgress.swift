//
//  Book+ReadingProgress.swift
//  Shelf Notes
//

import Foundation

extension Book {
    /// Sum of all logged pages across sessions (ignores nil/<=0).
    var pagesReadTotalFromSessions: Int {
        readingSessionsSafe
            .compactMap { $0.pagesReadNormalized }
            .reduce(0, +)
    }

    /// Reading progress in the range 0…1.
    ///
    /// Rules:
    /// - If the book is marked as finished, progress is always 1.0.
    /// - If `pageCount` is missing/0 and the book is not finished, returns `nil`.
    /// - Otherwise: sum(pagesRead) / pageCount, clamped to 0…1.
    var readingProgressFraction: Double? {
        if status == .finished {
            return 1.0
        }

        guard let total = pageCount, total > 0 else { return nil }
        let read = max(0, pagesReadTotalFromSessions)
        return min(1.0, max(0.0, Double(read) / Double(total)))
    }
}

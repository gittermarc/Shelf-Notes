//
//  Book+ReadingAttempts.swift
//  Shelf Notes
//

import Foundation

extension Book {
    /// Komfort: nil wie leeres Array behandeln.
    var readingAttemptsSafe: [ReadingAttempt] {
        get { readingAttempts ?? [] }
        set { readingAttempts = newValue }
    }

    var orderedReadingAttempts: [ReadingAttempt] {
        readingAttemptsSafe.sorted { left, right in
            if left.sequenceNumber != right.sequenceNumber {
                return left.sequenceNumber < right.sequenceNumber
            }
            if left.createdAt != right.createdAt {
                return left.createdAt < right.createdAt
            }
            return left.id.uuidString < right.id.uuidString
        }
    }

    var activeReadingAttempts: [ReadingAttempt] {
        orderedReadingAttempts.filter { $0.status == .active }
    }

    var activeReadingAttempt: ReadingAttempt? {
        activeReadingAttempts.last
    }

    var completedReadingAttempts: [ReadingAttempt] {
        orderedReadingAttempts.filter { $0.status == .finished }
    }

    var completedReadingAttemptCount: Int {
        completedReadingAttempts.count
    }

    var isRereading: Bool {
        activeReadingAttempt != nil && completedReadingAttemptCount > 0
    }

    var nextReadingAttemptSequenceNumber: Int {
        let maxSequence = readingAttemptsSafe
            .map { max(0, $0.sequenceNumber) }
            .max() ?? 0
        return maxSequence + 1
    }

    var currentReadingAttemptDisplayName: String? {
        if let activeReadingAttempt {
            return activeReadingAttempt.displayName
        }
        return orderedReadingAttempts.last?.displayName
    }

    func displayName(for attempt: ReadingAttempt) -> String {
        attempt.displayName
    }
}

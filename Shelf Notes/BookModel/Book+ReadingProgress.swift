//
//  Book+ReadingProgress.swift
//  Shelf Notes
//

import Foundation

@MainActor
extension Book {
    /// Sum of all logged pages across sessions (ignores nil/<=0).
    var pagesReadTotalFromSessions: Int {
        readingSessionsSafe
            .compactMap { $0.pagesReadNormalized }
            .reduce(0, +)
    }

    /// Format-neutral progress of the current reading pass.
    ///
    /// Existing books without attempts keep their historic page-based behavior.
    /// Once attempts exist, an active reread is isolated from older passes.
    var currentReadingProgressSnapshot: ReadingProgressSnapshot {
        if status == .toRead {
            return legacyPageProgressSnapshot(status: .active)
        }

        if status == .finished, let latestAttempt = orderedReadingAttempts.last {
            let input = latestAttempt.progressInputSnapshot
            return ReadingProgressEngine.snapshot(
                for: ReadingProgressAttemptSnapshot(
                    attemptID: input.attemptID,
                    status: .finished,
                    unit: input.unit,
                    pageCountSnapshot: input.pageCountSnapshot,
                    totalValueSnapshot: input.totalValueSnapshot,
                    sessionPageValues: input.sessionPageValues,
                    updates: input.updates
                )
            )
        }

        if let activeAttempt = activeReadingAttempt {
            return activeAttempt.readingProgressSnapshot
        }

        if let latestAttempt = orderedReadingAttempts.last {
            return latestAttempt.readingProgressSnapshot
        }

        let fallbackStatus: ReadingAttemptStatus = status == .finished ? .finished : .active
        return legacyPageProgressSnapshot(status: fallbackStatus)
    }

    private func legacyPageProgressSnapshot(
        status: ReadingAttemptStatus
    ) -> ReadingProgressSnapshot {
        let sessions = readingSessionsSafe
        let input = ReadingProgressAttemptSnapshot(
            attemptID: id,
            status: status,
            unit: .pages,
            pageCountSnapshot: pageCount,
            sessionPageValues: sessions.compactMap(\.pagesRead)
        )
        return ReadingProgressEngine.snapshot(for: input)
    }

    /// Reading progress in the range 0…1.
    ///
    /// Rules:
    /// - If the book is marked as finished, progress is always 1.0.
    /// - If `pageCount` is missing/0 and the book is not finished, returns `nil`.
    /// - Otherwise: sum(pagesRead) / pageCount, clamped to 0…1.
    var readingProgressFraction: Double? {
        currentReadingProgressSnapshot.normalizedProgress
    }
}

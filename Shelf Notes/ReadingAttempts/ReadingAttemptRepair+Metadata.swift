//
//  ReadingAttemptRepair+Metadata.swift
//  Shelf Notes
//

import Foundation

extension ReadingAttemptRepair {

    static func repairAttemptBacklinks(book: Book, attempts: [ReadingAttempt], now: Date) -> Bool {
        var didChange = false

        for attempt in attempts {
            if attempt.book?.id != book.id {
                attempt.book = book
                attempt.updatedAt = now
                didChange = true
            }
        }

        return didChange
    }

    static func makeAttempt(
        book: Book,
        attempts: [ReadingAttempt],
        status: ReadingAttemptStatus,
        now: Date
    ) -> ReadingAttempt {
        let sequenceNumber = nextSequenceNumber(after: attempts)
        let range = legacyRange(for: book, status: status, now: now)

        return ReadingAttempt(
            book: book,
            sequenceNumber: sequenceNumber,
            status: status,
            startedAt: range.startedAt,
            finishedAt: range.finishedAt,
            pageCountSnapshot: normalizedPageCount(book.pageCount),
            createdAt: now,
            updatedAt: now
        )
    }

    static func markFinished(_ attempt: ReadingAttempt, from book: Book, now: Date) {
        let range = legacyRange(for: book, status: .finished, now: now)
        attempt.status = .finished
        if attempt.startedAt == nil {
            attempt.startedAt = range.startedAt
        }
        if attempt.finishedAt == nil {
            attempt.finishedAt = range.finishedAt
        }
        if attempt.pageCountSnapshot == nil {
            attempt.pageCountSnapshot = normalizedPageCount(book.pageCount)
        }
        attempt.updatedAt = now
    }

    static func fillMissingFinishedMetadata(book: Book, attempts: [ReadingAttempt], now: Date) -> Bool {
        var didChange = false
        let range = legacyRange(for: book, status: .finished, now: now)

        for attempt in attempts where attempt.status == .finished {
            var attemptDidChange = false
            if attempt.startedAt == nil, let startedAt = range.startedAt {
                attempt.startedAt = startedAt
                attemptDidChange = true
            }
            if attempt.finishedAt == nil, let finishedAt = range.finishedAt {
                attempt.finishedAt = finishedAt
                attemptDidChange = true
            }
            if attempt.pageCountSnapshot == nil, let pageCount = normalizedPageCount(book.pageCount) {
                attempt.pageCountSnapshot = pageCount
                attemptDidChange = true
            }
            if attemptDidChange {
                attempt.updatedAt = now
                didChange = true
            }
        }

        return didChange
    }

    static func fillMissingActiveMetadata(book: Book, attempts: [ReadingAttempt], now: Date) -> Bool {
        var didChange = false
        let range = legacyRange(for: book, status: .active, now: now)

        for attempt in attempts where attempt.status == .active {
            var attemptDidChange = false
            if attempt.startedAt == nil, let startedAt = range.startedAt {
                attempt.startedAt = startedAt
                attemptDidChange = true
            }
            if attempt.pageCountSnapshot == nil, let pageCount = normalizedPageCount(book.pageCount) {
                attempt.pageCountSnapshot = pageCount
                attemptDidChange = true
            }
            if attemptDidChange {
                attempt.updatedAt = now
                didChange = true
            }
        }

        return didChange
    }

    static func legacyRange(
        for book: Book,
        status: ReadingAttemptStatus,
        now: Date
    ) -> (startedAt: Date?, finishedAt: Date?) {
        let sessions = book.readingSessionsSafe
        let earliestSessionStart = sessions.map(\.startedAt).min()
        let latestSessionEnd = sessions.map(\.endedAt).max()

        switch status {
        case .active:
            if let previousFinishedAt = book.readTo {
                let activeSessionStart = sessions
                    .filter { $0.startedAt >= previousFinishedAt }
                    .map(\.startedAt)
                    .min()
                return (activeSessionStart ?? now, nil)
            }
            return (book.readFrom ?? earliestSessionStart ?? now, nil)
        case .finished:
            let finishedAt = book.readTo ?? latestSessionEnd
            let startedAt = book.readFrom ?? earliestSessionStart ?? finishedAt
            return (startedAt, finishedAt)
        case .abandoned:
            return (book.readFrom ?? earliestSessionStart, latestSessionEnd)
        }
    }

    static func normalizedPageCount(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }

    static func nextSequenceNumber(after attempts: [ReadingAttempt]) -> Int {
        let maxSequence = attempts
            .map { max(0, $0.sequenceNumber) }
            .max() ?? 0
        return maxSequence + 1
    }

    static func ordered(_ attempts: [ReadingAttempt]) -> [ReadingAttempt] {
        attempts.sorted { left, right in
            if left.sequenceNumber != right.sequenceNumber {
                return left.sequenceNumber < right.sequenceNumber
            }
            if left.createdAt != right.createdAt {
                return left.createdAt < right.createdAt
            }
            return left.id.uuidString < right.id.uuidString
        }
    }

    static func dedupAttempts(_ input: [ReadingAttempt]) -> [ReadingAttempt] {
        var seen = Set<UUID>()
        var output: [ReadingAttempt] = []
        output.reserveCapacity(input.count)

        for attempt in input {
            if seen.insert(attempt.id).inserted {
                output.append(attempt)
            }
        }

        return output
    }
}

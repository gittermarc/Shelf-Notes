//
//  ReadingSessionLogging.swift
//  Shelf Notes
//
//  Centralized rules for logging reading sessions:
//  - page validation (remaining pages)
//  - "session implies reading"
//  - auto-finish + readFrom/readTo policy
//  - session creation (start/end/duration)
//

import Foundation

struct ReadingSessionLogging {

    // MARK: - Book state snapshot

    struct BookState: Equatable {
        var status: ReadingStatus
        var pageCount: Int?
        var readFrom: Date?
        var readTo: Date?

        init(book: Book) {
            self.status = book.status
            self.pageCount = book.pageCount
            self.readFrom = book.readFrom
            self.readTo = book.readTo
        }

        func applying(to book: Book) {
            // Important: setting status can clear readFrom/readTo for non-finished statuses.
            // Therefore set `status` first, then write the read range.
            if book.status != status {
                book.status = status
            }
            book.readFrom = readFrom
            book.readTo = readTo
            book.pageCount = pageCount
        }
    }

    // MARK: - Timing

    struct Timing: Equatable {
        let startedAt: Date
        let endedAt: Date
        let durationSeconds: Int

        init(startedAt: Date, endedAt: Date) {
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.durationSeconds = max(0, Int(endedAt.timeIntervalSince(startedAt).rounded()))
        }

        init(endedAt: Date, durationSeconds: Int) {
            let dur = max(0, durationSeconds)
            self.endedAt = endedAt
            self.durationSeconds = dur
            self.startedAt = endedAt.addingTimeInterval(-TimeInterval(dur))
        }
    }

    // MARK: - Validation

    enum ValidationError: Error, Equatable {
        case noRemainingPages(total: Int)
        case pagesExceedRemaining(remaining: Int, total: Int)

        var message: String {
            switch self {
            case .noRemainingPages(let total):
                return "Dieses Buch hat bereits alle \(total) Seiten erreicht – du kannst keine weiteren Seiten loggen."
            case .pagesExceedRemaining(let remaining, let total):
                return "Zu viele Seiten: Es sind nur noch \(remaining) von \(total) Seiten übrig."
            }
        }
    }

    // MARK: - Plan

    struct Plan: Equatable {
        var updatedBookState: BookState
        var timing: Timing
        var normalizedPages: Int?
        var trimmedNote: String?
        var didImplyReading: Bool
        var didMarkFinished: Bool

        func makeSession(book: Book) -> ReadingSession {
            ReadingSession(
                book: book,
                startAt: timing.startedAt,
                durationSeconds: timing.durationSeconds,
                pagesRead: normalizedPages,
                note: trimmedNote
            )
        }

        func apply(to book: Book) {
            updatedBookState.applying(to: book)
        }
    }

    // MARK: - Utilities

    static func normalizedTotalPages(_ raw: Int?) -> Int? {
        guard let t = raw, t > 0 else { return nil }
        return t
    }

    static func normalizePages(_ pages: Int?) -> Int? {
        guard let p = pages, p > 0 else { return nil }
        return p
    }

    static func trimNote(_ note: String?) -> String? {
        guard let n = note?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty else { return nil }
        return n
    }

    static func pagesReadTotal(in sessions: [ReadingSession]) -> Int {
        sessions
            .compactMap { $0.pagesReadNormalized }
            .reduce(0, +)
    }

    static func remainingPages(totalPages: Int?, sessions: [ReadingSession]) -> Int? {
        guard let total = normalizedTotalPages(totalPages) else { return nil }
        let already = pagesReadTotal(in: sessions)
        return max(0, total - already)
    }

    static func progressFraction(status: ReadingStatus, totalPages: Int?, sessions: [ReadingSession]) -> Double? {
        if status == .finished { return 1.0 }
        guard let total = normalizedTotalPages(totalPages) else { return nil }
        let read = max(0, pagesReadTotal(in: sessions))
        return min(1.0, max(0.0, Double(read) / Double(total)))
    }

    // MARK: - Main entry

    static func plan(
        bookState: BookState,
        existingSessions: [ReadingSession],
        timing: Timing,
        pages: Int?,
        note: String?
    ) -> Result<Plan, ValidationError> {
        let normalizedPages = normalizePages(pages)
        let trimmedNote = trimNote(note)

        // Page validation: you can't log more pages than the book has remaining.
        if let total = normalizedTotalPages(bookState.pageCount), let p = normalizedPages {
            let already = pagesReadTotal(in: existingSessions)
            let remaining = max(0, total - already)

            if remaining <= 0 {
                return .failure(.noRemainingPages(total: total))
            }

            if p > remaining {
                return .failure(.pagesExceedRemaining(remaining: remaining, total: total))
            }
        }

        var updated = bookState
        var didImplyReading = false
        var didMarkFinished = false

        // A logged session implies "reading" if the user hasn't started yet.
        if updated.status == .toRead {
            updated.status = .reading
            didImplyReading = true
        }

        // Auto-finish: if this session reaches the last page, mark the book as finished.
        if let total = normalizedTotalPages(updated.pageCount) {
            let already = pagesReadTotal(in: existingSessions)
            let after = already + (normalizedPages ?? 0)
            if after >= total {
                updated.status = .finished
                didMarkFinished = true

                if updated.readFrom == nil {
                    let earliestExisting = existingSessions.map(\ReadingSession.startedAt).min()
                    let earliest = min(earliestExisting ?? timing.startedAt, timing.startedAt)
                    updated.readFrom = earliest
                }

                updated.readTo = timing.endedAt

                if let from = updated.readFrom, let to = updated.readTo, to < from {
                    updated.readFrom = to
                }
            }
        }

        return .success(
            Plan(
                updatedBookState: updated,
                timing: timing,
                normalizedPages: normalizedPages,
                trimmedNote: trimmedNote,
                didImplyReading: didImplyReading,
                didMarkFinished: didMarkFinished
            )
        )
    }
}

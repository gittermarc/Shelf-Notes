//
//  ReadingSessionLogging.swift
//  Shelf Notes
//
//  Centralized rules for logging format-neutral reading sessions.
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
            let duration = max(0, durationSeconds)
            self.endedAt = endedAt
            self.durationSeconds = duration
            self.startedAt = endedAt.addingTimeInterval(-TimeInterval(duration))
        }
    }

    typealias ValidationError = ReadingProgressMutationValidationError

    // MARK: - Plan

    struct Plan: Equatable {
        var updatedBookState: BookState
        var timing: Timing
        var progress: ReadingProgressMutationPlan
        var trimmedNote: String?
        var didImplyReading: Bool
        var didMarkFinished: Bool
        var isLegacySupplement: Bool

        var normalizedPages: Int? {
            progress.pagesDelta
        }

        func makeSession(
            book: Book,
            context: ReadingSessionContext,
            existingSession: ReadingSession? = nil
        ) -> ReadingSession {
            let session = existingSession ?? ReadingSession(
                book: book,
                startAt: timing.startedAt,
                durationSeconds: timing.durationSeconds
            )

            session.book = book
            session.startedAt = timing.startedAt
            session.endedAt = timing.endedAt
            session.durationSeconds = timing.durationSeconds
            session.pagesRead = progress.pagesDelta
            session.note = trimmedNote
            session.mediumRawValue = context.medium.rawValue
            session.providerRawValue = context.provider.rawValue
            session.originRawValue = context.origin.rawValue
            session.progressUnitRawValue = context.progressUnit.rawValue
            session.startValue = progress.startValue
            session.endValue = progress.endValue
            session.startNormalizedProgress = progress.startNormalizedProgress
            session.endNormalizedProgress = progress.endNormalizedProgress
            session.startLocator = progress.startLocator
            session.endLocator = progress.endLocator
            return session
        }

        func apply(to book: Book) {
            updatedBookState.applying(to: book)
        }
    }

    // MARK: - Utilities

    static func normalizedTotalPages(_ raw: Int?) -> Int? {
        guard let total = raw, total > 0 else { return nil }
        return total
    }

    static func normalizePages(_ pages: Int?) -> Int? {
        guard let pages, pages > 0 else { return nil }
        return pages
    }

    static func trimNote(_ note: String?) -> String? {
        guard let note = note?.trimmingCharacters(in: .whitespacesAndNewlines),
              note.isEmpty == false else {
            return nil
        }
        return note
    }

    static func pagesReadTotal(in sessions: [ReadingSession]) -> Int {
        sessions
            .compactMap(\.pagesReadNormalized)
            .reduce(0, +)
    }

    static func remainingPages(totalPages: Int?, sessions: [ReadingSession]) -> Int? {
        ReadingProgressEngine.snapshot(
            for: pageProgressInput(
                status: .reading,
                totalPages: totalPages,
                sessions: sessions
            )
        ).remainingPages
    }

    static func progressFraction(status: ReadingStatus, totalPages: Int?, sessions: [ReadingSession]) -> Double? {
        ReadingProgressEngine.snapshot(
            for: pageProgressInput(
                status: status,
                totalPages: totalPages,
                sessions: sessions
            )
        ).normalizedProgress
    }

    static func progressSnapshot(
        status: ReadingStatus,
        unit: ReadingProgressUnit,
        totalPages: Int?,
        totalValue: Double?,
        sessions: [ReadingSession],
        updates: [ReadingProgressUpdate] = []
    ) -> ReadingProgressSnapshot {
        ReadingProgressEngine.snapshot(
            for: ReadingProgressAttemptSnapshot(
                attemptID: UUID(),
                status: status == .finished ? .finished : .active,
                unit: unit,
                pageCountSnapshot: totalPages,
                totalValueSnapshot: totalValue,
                sessionPageValues: sessions.compactMap(\.pagesRead),
                updates: updates
            )
        )
    }

    private static func pageProgressInput(
        status: ReadingStatus,
        totalPages: Int?,
        sessions: [ReadingSession]
    ) -> ReadingProgressAttemptSnapshot {
        ReadingProgressAttemptSnapshot(
            attemptID: UUID(),
            status: status == .finished ? .finished : .active,
            unit: .pages,
            pageCountSnapshot: totalPages,
            sessionPageValues: sessions.compactMap(\.pagesRead)
        )
    }

    // MARK: - Main entry

    static func plan(
        bookState: BookState,
        existingSessions: [ReadingSession],
        currentProgress: ReadingProgressSnapshot,
        timing: Timing,
        progressUpdate: ReadingProgressUpdate?,
        note: String?,
        mutationMode: ReadingProgressMutationMode = .standard,
        allowsFinishedBookSupplement: Bool = false,
        allowsAbsolutePageValue: Bool = false
    ) -> Result<Plan, ValidationError> {
        let progressResult = ReadingProgressMutationPlanner.makePlan(
            current: currentProgress,
            update: progressUpdate,
            mode: mutationMode,
            allowsPageOverflow: allowsFinishedBookSupplement,
            allowsAbsolutePageValue: allowsAbsolutePageValue
        )

        let progress: ReadingProgressMutationPlan
        switch progressResult {
        case .success(let value):
            progress = value
        case .failure(let error):
            return .failure(error)
        }

        let trimmedNote = trimNote(note)

        if allowsFinishedBookSupplement, bookState.status == .finished {
            return .success(
                Plan(
                    updatedBookState: bookState,
                    timing: timing,
                    progress: progress,
                    trimmedNote: trimmedNote,
                    didImplyReading: false,
                    didMarkFinished: false,
                    isLegacySupplement: true
                )
            )
        }

        var updated = bookState
        var didImplyReading = false

        if updated.status == .toRead {
            updated.status = .reading
            didImplyReading = true
        }

        let didMarkFinished = progress.didReachCompletion
        if didMarkFinished {
            updated.status = .finished

            if updated.readFrom == nil {
                let earliestExisting = existingSessions.map(\.startedAt).min()
                updated.readFrom = min(earliestExisting ?? timing.startedAt, timing.startedAt)
            }

            updated.readTo = timing.endedAt

            if let from = updated.readFrom, let to = updated.readTo, to < from {
                updated.readFrom = to
            }
        }

        return .success(
            Plan(
                updatedBookState: updated,
                timing: timing,
                progress: progress,
                trimmedNote: trimmedNote,
                didImplyReading: didImplyReading,
                didMarkFinished: didMarkFinished,
                isLegacySupplement: false
            )
        )
    }

    static func plan(
        bookState: BookState,
        existingSessions: [ReadingSession],
        timing: Timing,
        pages: Int?,
        note: String?,
        allowsFinishedBookSupplement: Bool = false
    ) -> Result<Plan, ValidationError> {
        let currentProgress = progressSnapshot(
            status: bookState.status,
            unit: .pages,
            totalPages: bookState.pageCount,
            totalValue: bookState.pageCount.map(Double.init),
            sessions: existingSessions
        )
        let update = normalizePages(pages).map {
            ReadingProgressUpdate.pageDelta(
                $0,
                occurredAt: timing.endedAt
            )
        }

        return plan(
            bookState: bookState,
            existingSessions: existingSessions,
            currentProgress: currentProgress,
            timing: timing,
            progressUpdate: update,
            note: note,
            allowsFinishedBookSupplement: allowsFinishedBookSupplement
        )
    }
}

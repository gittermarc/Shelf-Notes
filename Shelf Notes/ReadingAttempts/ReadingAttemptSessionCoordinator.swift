//
//  ReadingAttemptSessionCoordinator.swift
//  Shelf Notes
//

import Foundation

/// Small coordination helpers for assigning newly logged sessions to the current
/// reading attempt without forcing UI code to know persistence details.
enum ReadingAttemptSessionCoordinator {

    static func progressSessions(for book: Book, allSessions: [ReadingSession]) -> [ReadingSession] {
        guard let activeAttempt = book.activeReadingAttempt else {
            return allSessions
        }

        return sessions(for: activeAttempt, allSessions: allSessions)
    }

    static func sessions(for attempt: ReadingAttempt, allSessions: [ReadingSession]) -> [ReadingSession] {
        let attemptID = attempt.id
        let relatedSessionIDs = Set(attempt.sessionsSafe.map(\.id))

        return allSessions.filter { session in
            if session.readingAttempt?.id == attemptID {
                return true
            }
            return relatedSessionIDs.contains(session.id)
        }
    }

    static func currentRemainingPages(for book: Book, allSessions: [ReadingSession]) -> Int? {
        if book.status == .finished, book.activeReadingAttempt == nil {
            return nil
        }

        if let activeAttempt = book.activeReadingAttempt,
           activeAttempt.progressUnit != .pages {
            return nil
        }

        return ReadingSessionLogging.remainingPages(
            totalPages: book.pageCount,
            sessions: progressSessions(for: book, allSessions: allSessions)
        )
    }

    @discardableResult
    @MainActor
    static func startNewRereadAttempt(
        for book: Book,
        startedAt: Date,
        now: Date = Date(),
        source: ReadingSessionSource = ReadingSessionSource(origin: .legacy),
        insertAttempt: (ReadingAttempt) -> Void
    ) -> ReadingAttempt {
        _ = ReadingAttemptRepair.repair(book: book, now: now, insertAttempt: insertAttempt)

        if let activeAttempt = book.activeReadingAttempt {
            updateActiveAttemptMetadata(
                activeAttempt,
                book: book,
                startedAt: startedAt,
                now: now
            )
            updateSourceTotalIfNeeded(activeAttempt, source: source, now: now)
            if book.status != .reading {
                book.status = .reading
            }
            return activeAttempt
        }

        let attempt = ReadingAttempt(
            book: book,
            sequenceNumber: book.nextReadingAttemptSequenceNumber,
            status: .active,
            startedAt: startedAt,
            finishedAt: nil,
            pageCountSnapshot: ReadingAttemptRepair.normalizedPageCount(book.pageCount),
            readingMedium: source.medium,
            defaultProvider: source.provider,
            progressUnit: source.progressUnit,
            totalValueSnapshot: source.totalValue,
            createdAt: now,
            updatedAt: now
        )

        insertAttempt(attempt)
        var attempts = book.readingAttemptsSafe
        attempts.append(attempt)
        book.readingAttemptsSafe = attempts
        book.status = .reading
        return attempt
    }

    @discardableResult
    @MainActor
    static func ensureActiveAttemptForSessionIfNeeded(
        book: Book,
        startedAt: Date,
        now: Date = Date(),
        source: ReadingSessionSource = ReadingSessionSource(origin: .legacy),
        insertAttempt: (ReadingAttempt) -> Void
    ) -> ReadingAttempt? {
        if let activeAttempt = book.activeReadingAttempt {
            updateActiveAttemptMetadata(
                activeAttempt,
                book: book,
                startedAt: startedAt,
                now: now
            )
            updateSourceTotalIfNeeded(activeAttempt, source: source, now: now)
            if book.status != .reading {
                book.status = .reading
            }
            return activeAttempt
        }

        if book.status == .finished {
            return nil
        }

        let attempt = ReadingAttempt(
            book: book,
            sequenceNumber: book.nextReadingAttemptSequenceNumber,
            status: .active,
            startedAt: startedAt,
            finishedAt: nil,
            pageCountSnapshot: ReadingAttemptRepair.normalizedPageCount(book.pageCount),
            readingMedium: source.medium,
            defaultProvider: source.provider,
            progressUnit: source.progressUnit,
            totalValueSnapshot: source.totalValue,
            createdAt: now,
            updatedAt: now
        )

        insertAttempt(attempt)
        var attempts = book.readingAttemptsSafe
        attempts.append(attempt)
        book.readingAttemptsSafe = attempts

        if book.status == .toRead {
            book.status = .reading
        }

        return attempt
    }

    @MainActor
    static func attach(
        session: ReadingSession,
        to attempt: ReadingAttempt?,
        plan: ReadingSessionLogging.Plan,
        book: Book,
        now: Date = Date()
    ) {
        guard let attempt else { return }

        session.readingAttempt = attempt
        attempt.addSessionIfNeeded(session)
        updateActiveAttemptMetadata(
            attempt,
            book: book,
            startedAt: plan.timing.startedAt,
            now: now
        )

        if plan.didMarkFinished {
            finish(attempt, book: book, finishedAt: plan.timing.endedAt, now: now)
        }
    }

    @MainActor
    static func applyProgressMutation(
        to attempt: ReadingAttempt?,
        plan: ReadingSessionLogging.Plan,
        book: Book,
        now: Date = Date()
    ) {
        guard let attempt else { return }

        updateActiveAttemptMetadata(
            attempt,
            book: book,
            startedAt: plan.timing.startedAt,
            now: now
        )

        if plan.didMarkFinished {
            finish(attempt, book: book, finishedAt: plan.timing.endedAt, now: now)
        }
    }

    @MainActor
    static func detachBeforeDeleting(_ session: ReadingSession, now: Date = Date()) {
        guard let attempt = session.readingAttempt else { return }
        attempt.sessionsSafe = attempt.sessionsSafe.filter { $0.id != session.id }
        attempt.updatedAt = now
        session.readingAttempt = nil
    }

    @MainActor
    private static func updateActiveAttemptMetadata(
        _ attempt: ReadingAttempt,
        book: Book,
        startedAt: Date,
        now: Date
    ) {
        var didChange = false

        if attempt.startedAt == nil || startedAt < (attempt.startedAt ?? startedAt) {
            attempt.startedAt = startedAt
            didChange = true
        }

        if attempt.pageCountSnapshot == nil,
           let pageCount = ReadingAttemptRepair.normalizedPageCount(book.pageCount) {
            attempt.pageCountSnapshot = pageCount
            didChange = true
        }

        if didChange {
            attempt.updatedAt = now
        }
    }

    @MainActor
    private static func finish(
        _ attempt: ReadingAttempt,
        book: Book,
        finishedAt: Date,
        now: Date
    ) {
        attempt.status = .finished
        attempt.finishedAt = finishedAt

        if attempt.startedAt == nil {
            attempt.startedAt = book.readFrom ?? attempt.sessionsSafe.map(\.startedAt).min() ?? finishedAt
        }

        if attempt.pageCountSnapshot == nil {
            attempt.pageCountSnapshot = ReadingAttemptRepair.normalizedPageCount(book.pageCount)
        }

        attempt.updatedAt = now
    }

    @MainActor
    private static func updateSourceTotalIfNeeded(
        _ attempt: ReadingAttempt,
        source: ReadingSessionSource,
        now: Date
    ) {
        guard attempt.totalValueSnapshot == nil,
              let total = source.totalValue,
              total.isFinite,
              total > 0 else {
            return
        }
        attempt.totalValueSnapshot = total
        attempt.updatedAt = now
    }
}

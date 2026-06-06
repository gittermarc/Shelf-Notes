//
//  ReadingAttemptRepair+Sessions.swift
//  Shelf Notes
//

import Foundation

extension ReadingAttemptRepair {

    static func attachSessionAttemptsToBook(book: Book, attempts: inout [ReadingAttempt]) -> Bool {
        var didChange = false
        var seen = Set(attempts.map(\.id))

        for session in book.readingSessionsSafe {
            guard let attempt = session.readingAttempt else { continue }
            guard attempt.book?.id == book.id else { continue }
            guard seen.insert(attempt.id).inserted else { continue }
            attempts.append(attempt)
            didChange = true
        }

        if didChange {
            book.readingAttemptsSafe = attempts
        }

        return didChange
    }

    static func repairSessionAssignments(
        book: Book,
        attempts: [ReadingAttempt],
        now: Date
    ) -> Bool {
        guard attempts.isEmpty == false else { return false }

        var didChange = false

        for attempt in attempts {
            let dedupedSessions = dedupSessions(attempt.sessionsSafe)
            if dedupedSessions.map(\.id) != attempt.sessionsSafe.map(\.id) {
                attempt.sessionsSafe = dedupedSessions
                attempt.updatedAt = now
                didChange = true
            }
        }

        for session in book.readingSessionsSafe {
            if session.book?.id != book.id {
                session.book = book
                didChange = true
            }

            if let existingAttempt = session.readingAttempt,
               attempts.contains(where: { $0.id == existingAttempt.id }) {
                if existingAttempt.contains(session) == false {
                    existingAttempt.addSessionIfNeeded(session)
                    didChange = true
                }
                continue
            }

            guard let target = targetAttempt(for: session, bookStatus: book.status, attempts: attempts) else {
                continue
            }

            session.readingAttempt = target
            target.addSessionIfNeeded(session)
            didChange = true
        }

        return didChange
    }

    static func targetAttempt(
        for session: ReadingSession,
        bookStatus: ReadingStatus,
        attempts: [ReadingAttempt]
    ) -> ReadingAttempt? {
        let orderedAttempts = ordered(attempts)

        if orderedAttempts.count == 1 {
            return orderedAttempts[0]
        }

        let rangeMatches = orderedAttempts.filter { attempt in
            dateRange(of: attempt, contains: session)
        }

        if rangeMatches.count == 1 {
            return rangeMatches[0]
        }

        if bookStatus == .reading,
           let activeAttempt = orderedAttempts.last(where: { $0.status == .active }) {
            let hasCompletedHistory = orderedAttempts.contains { $0.status == .finished }
            if hasCompletedHistory == false || dateRange(of: activeAttempt, contains: session) {
                return activeAttempt
            }
        }

        return nil
    }

    static func dateRange(of attempt: ReadingAttempt, contains session: ReadingSession) -> Bool {
        guard attempt.startedAt != nil || attempt.finishedAt != nil else {
            return false
        }

        if let startedAt = attempt.startedAt, session.endedAt < startedAt {
            return false
        }

        if let finishedAt = attempt.finishedAt, session.startedAt > finishedAt {
            return false
        }

        return true
    }

    static func dedupSessions(_ input: [ReadingSession]) -> [ReadingSession] {
        var seen = Set<UUID>()
        var output: [ReadingSession] = []
        output.reserveCapacity(input.count)

        for session in input {
            if seen.insert(session.id).inserted {
                output.append(session)
            }
        }

        return output
    }
}

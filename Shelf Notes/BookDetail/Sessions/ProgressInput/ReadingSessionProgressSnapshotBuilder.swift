//
//  ReadingSessionProgressSnapshotBuilder.swift
//  Shelf Notes
//

import Foundation

@MainActor
enum ReadingSessionProgressSnapshotBuilder {
    static func make(
        book: Book,
        attempt: ReadingAttempt?,
        context: ReadingSessionContext,
        sessions: [ReadingSession],
        excludingSessionID: UUID? = nil
    ) -> ReadingProgressSnapshot {
        guard let attempt else {
            return ReadingSessionLogging.progressSnapshot(
                status: book.status,
                unit: context.progressUnit,
                totalPages: context.progressUnit == .pages ? book.pageCount : nil,
                totalValue: context.totalValue,
                sessions: sessions
            )
        }

        let attemptID = attempt.id
        let relatedSessionIDs = Set(attempt.sessionsSafe.map(\.id))
        let relatedSessions = sessions.filter { session in
            if let excludingSessionID, session.id == excludingSessionID {
                return false
            }
            if session.readingAttempt?.id == attemptID {
                return true
            }
            return relatedSessionIDs.contains(session.id)
        }
        let relatedEvents = attempt.progressEventsSafe.filter { event in
            if let excludingSessionID, event.sourceSessionID == excludingSessionID {
                return false
            }
            guard let relatedAttemptID = event.readingAttempt?.id else {
                return true
            }
            return relatedAttemptID == attemptID
        }
        let fallbackPageCount = attempt.progressUnit == .pages
            ? ReadingAttemptRepair.normalizedPageCount(book.pageCount)
            : nil
        let totalValueSnapshot = attempt.totalValueSnapshot
            ?? context.totalValue
            ?? fallbackPageCount.map(Double.init)
        var updates: [ReadingProgressUpdate] = []
        updates.reserveCapacity((relatedSessions.count * 2) + relatedEvents.count)

        for session in relatedSessions {
            updates.append(contentsOf: ReadingProgressUpdate.updates(session: session))
        }
        for event in relatedEvents {
            updates.append(ReadingProgressUpdate(event: event))
        }

        return ReadingProgressEngine.snapshot(
            for: ReadingProgressAttemptSnapshot(
                attemptID: attemptID,
                status: attempt.status,
                unit: attempt.progressUnit,
                pageCountSnapshot: attempt.pageCountSnapshot ?? fallbackPageCount,
                totalValueSnapshot: totalValueSnapshot,
                sessionPageValues: relatedSessions.compactMap(\.pagesRead),
                updates: updates
            )
        )
    }
}
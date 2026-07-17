//
//  ReadingSessionDeletionService.swift
//  Shelf Notes
//

import Foundation
import SwiftData

struct DeletedReadingSessionsResult {
    let snapshots: [SavedReadingSessionSnapshot]
}

enum ReadingSessionDeletionError: Error {
    case fetchFailed(Error)
    case saveFailed(Error)

    var message: String {
        switch self {
        case .fetchFailed(let error):
            return "Konnte verknüpfte Fortschrittsdaten nicht laden: " + error.localizedDescription
        case .saveFailed(let error):
            return "Konnte Session nicht löschen: " + error.localizedDescription
        }
    }
}

@MainActor
enum ReadingSessionDeletionService {
    static func delete(
        session: ReadingSession,
        modelContext: ModelContext,
        now: Date = Date()
    ) -> Result<DeletedReadingSessionsResult, ReadingSessionDeletionError> {
        delete(sessions: [session], modelContext: modelContext, now: now)
    }

    static func delete(
        sessions: [ReadingSession],
        modelContext: ModelContext,
        now: Date = Date()
    ) -> Result<DeletedReadingSessionsResult, ReadingSessionDeletionError> {
        let uniqueSessions = deduplicated(sessions)
        let persistedEvents: [ReadingProgressEvent]
        do {
            persistedEvents = try modelContext.fetch(FetchDescriptor<ReadingProgressEvent>())
        } catch {
            return .failure(.fetchFailed(error))
        }
        var snapshots: [SavedReadingSessionSnapshot] = []
        snapshots.reserveCapacity(uniqueSessions.count)

        for session in uniqueSessions {
            let matchesSession: (ReadingProgressEvent) -> Bool = { event in
                event.sourceSessionID == session.id
                    || event.deduplicationKey == ReadingProgressEventFingerprint.sessionProgressKey(sessionID: session.id)
            }
            let persistedLinkedEvents = persistedEvents.filter { event in
                matchesSession(event)
            }
            let attemptLinkedEvents = (session.readingAttempt?.progressEventsSafe ?? []).filter(matchesSession)
            let linkedEvents: [ReadingProgressEvent]

            if let book = session.book {
                linkedEvents = deduplicatedEvents(
                    ReadingProgressEventMutationService.sessionEvents(
                        sessionID: session.id,
                        book: book,
                        attempt: session.readingAttempt
                    ) + attemptLinkedEvents + persistedLinkedEvents
                )
                snapshots.append(
                    SavedReadingSessionSnapshot(
                        bookID: book.id,
                        session: session,
                        progressEventID: linkedEvents.first?.id
                    )
                )
                book.readingSessionsSafe.removeAll { $0.id == session.id }
            } else {
                linkedEvents = deduplicatedEvents(attemptLinkedEvents + persistedLinkedEvents)
            }

            ReadingProgressEventMutationService.remove(
                events: linkedEvents,
                knownBook: session.book,
                knownAttempt: session.readingAttempt,
                modelContext: modelContext
            )
            ReadingAttemptSessionCoordinator.detachBeforeDeleting(session, now: now)
            session.book = nil
            modelContext.delete(session)
        }

        if let error = modelContext.saveWithDiagnostics() {
            return .failure(.saveFailed(error))
        }

        return .success(DeletedReadingSessionsResult(snapshots: snapshots))
    }

    private static func deduplicated(_ sessions: [ReadingSession]) -> [ReadingSession] {
        var seen = Set<UUID>()
        var result: [ReadingSession] = []
        result.reserveCapacity(sessions.count)

        for session in sessions where seen.insert(session.id).inserted {
            result.append(session)
        }
        return result
    }

    private static func deduplicatedEvents(_ events: [ReadingProgressEvent]) -> [ReadingProgressEvent] {
        var seen = Set<UUID>()
        var result: [ReadingProgressEvent] = []
        result.reserveCapacity(events.count)

        for event in events where seen.insert(event.id).inserted {
            result.append(event)
        }
        return result
    }
}

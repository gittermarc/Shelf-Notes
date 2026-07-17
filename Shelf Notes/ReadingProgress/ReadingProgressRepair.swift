//
//  ReadingProgressRepair.swift
//  Shelf Notes
//

import Foundation
import SwiftData

/// Idempotent backfill for format-neutral progress data.
///
/// No one-time migration flag is used because older CloudKit records can arrive
/// after an earlier repair pass.
@MainActor
enum ReadingProgressRepair {
    static func repairIfNeeded(modelContext: ModelContext) async {
        do {
            let books = try modelContext.fetch(
                FetchDescriptor<Book>(
                    sortBy: [SortDescriptor(\Book.createdAt, order: .forward)]
                )
            )
            let events = try modelContext.fetch(
                FetchDescriptor<ReadingProgressEvent>(
                    sortBy: [
                        SortDescriptor(\ReadingProgressEvent.occurredAt, order: .forward),
                        SortDescriptor(\ReadingProgressEvent.createdAt, order: .forward)
                    ]
                )
            )

            let didChange = repair(
                books: books,
                knownEvents: events,
                now: Date(),
                insertEvent: { modelContext.insert($0) },
                deleteEvent: { modelContext.delete($0) }
            )

            if didChange {
                _ = modelContext.saveWithDiagnostics()
            }
        } catch {
            #if DEBUG
            print("ReadingProgressRepair failed: \(error)")
            #endif
        }
    }

    @discardableResult
    static func repair(
        books: [Book],
        knownEvents: [ReadingProgressEvent] = [],
        now: Date = Date(),
        insertEvent: (ReadingProgressEvent) -> Void = { _ in },
        deleteEvent: (ReadingProgressEvent) -> Void = { _ in }
    ) -> Bool {
        var didChange = false
        let allKnownEvents = deduplicatedEvents(
            knownEvents
                + books.flatMap(\.readingProgressEventsSafe)
                + books.flatMap { $0.readingAttemptsSafe.flatMap(\.progressEventsSafe) }
        )

        for book in books {
            if repair(
                book: book,
                knownEvents: allKnownEvents,
                now: now,
                insertEvent: insertEvent,
                deleteEvent: deleteEvent
            ) {
                didChange = true
            }
        }

        return didChange
    }

    @discardableResult
    private static func repair(
        book: Book,
        knownEvents: [ReadingProgressEvent],
        now: Date,
        insertEvent: (ReadingProgressEvent) -> Void,
        deleteEvent: (ReadingProgressEvent) -> Void
    ) -> Bool {
        var didChange = false
        let attempts = deduplicatedAttempts(book.readingAttemptsSafe)

        if sameIDs(attempts, book.readingAttemptsSafe, id: \.id) == false {
            book.readingAttemptsSafe = attempts
            didChange = true
        }

        if repairAttemptSourcesAndBacklinks(book: book, attempts: attempts, now: now) {
            didChange = true
        }

        let sessionsResult = repairSessions(book: book, attempts: attempts)
        var sessions = sessionsResult.sessions
        if sessionsResult.didChange {
            didChange = true
        }

        let eventResult = repairEventRelationships(
            book: book,
            attempts: attempts,
            sessions: sessions,
            knownEvents: knownEvents,
            now: now
        )
        var events = eventResult.events
        if eventResult.didChange {
            didChange = true
        }

        let deduplicationResult = removeExactDuplicates(
            events: events,
            book: book,
            attempts: attempts,
            deleteEvent: deleteEvent
        )
        events = deduplicationResult.events
        if deduplicationResult.didChange {
            didChange = true
        }

        for attempt in attempts {
            let baselineResult = repairLegacyBaseline(
                book: book,
                attempt: attempt,
                sessions: sessions,
                events: events,
                now: now,
                insertEvent: insertEvent,
                deleteEvent: deleteEvent
            )
            events = baselineResult.events
            if baselineResult.didChange {
                didChange = true
            }
        }

        let normalizedBookEvents = deduplicatedEvents(events)
        if sameIDs(normalizedBookEvents, book.readingProgressEventsSafe, id: \.id) == false {
            book.readingProgressEventsSafe = normalizedBookEvents
            didChange = true
        }

        for attempt in attempts {
            let attemptID = attempt.id
            let relatedEvents = normalizedBookEvents.filter {
                $0.readingAttempt?.id == attemptID
            }
            if sameIDs(relatedEvents, attempt.progressEventsSafe, id: \.id) == false {
                attempt.progressEventsSafe = relatedEvents
                didChange = true
            }
        }

        sessions = deduplicatedSessions(sessions)
        if sameIDs(sessions, book.readingSessionsSafe, id: \.id) == false {
            book.readingSessionsSafe = sessions
            didChange = true
        }

        return didChange
    }
}
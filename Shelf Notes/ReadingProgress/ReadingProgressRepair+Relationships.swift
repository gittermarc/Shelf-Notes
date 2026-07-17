//
//  ReadingProgressRepair+Relationships.swift
//  Shelf Notes
//

import Foundation

extension ReadingProgressRepair {
    struct SessionRepairResult {
        let sessions: [ReadingSession]
        let didChange: Bool
    }

    struct EventRepairResult {
        let events: [ReadingProgressEvent]
        let didChange: Bool
    }

    static func repairAttemptSourcesAndBacklinks(
        book: Book,
        attempts: [ReadingAttempt],
        now: Date
    ) -> Bool {
        var didChange = false

        for attempt in attempts {
            var attemptDidChange = false

            if attempt.book?.id != book.id {
                attempt.book = book
                attemptDidChange = true
            }
            if normalizedRawValue(attempt.readingMediumRawValue) == nil {
                attempt.readingMediumRawValue = ReadingMedium.physical.rawValue
                attemptDidChange = true
            }
            if normalizedRawValue(attempt.defaultProviderRawValue) == nil {
                attempt.defaultProviderRawValue = ReadingProvider.none.rawValue
                attemptDidChange = true
            }
            if normalizedRawValue(attempt.progressUnitRawValue) == nil {
                attempt.progressUnitRawValue = ReadingProgressUnit.pages.rawValue
                attemptDidChange = true
            }

            if attemptDidChange {
                attempt.updatedAt = now
                didChange = true
            }
        }

        return didChange
    }

    static func repairSessions(
        book: Book,
        attempts: [ReadingAttempt]
    ) -> SessionRepairResult {
        var didChange = false
        var sessions = deduplicatedSessions(
            book.readingSessionsSafe + attempts.flatMap(\.sessionsSafe)
        )

        for session in sessions {
            if session.book?.id != book.id {
                session.book = book
                didChange = true
            }
            if normalizedRawValue(session.mediumRawValue) == nil {
                session.mediumRawValue = ReadingMedium.physical.rawValue
                didChange = true
            }
            if normalizedRawValue(session.providerRawValue) == nil {
                session.providerRawValue = ReadingProvider.none.rawValue
                didChange = true
            }
            if normalizedRawValue(session.progressUnitRawValue) == nil {
                session.progressUnitRawValue = ReadingProgressUnit.pages.rawValue
                didChange = true
            }
            if normalizedRawValue(session.originRawValue) == nil {
                session.originRawValue = ReadingSessionOrigin.legacy.rawValue
                didChange = true
            }

            if let currentAttempt = session.readingAttempt,
               attempts.contains(where: { $0.id == currentAttempt.id }) {
                if currentAttempt.contains(session) == false {
                    currentAttempt.addSessionIfNeeded(session)
                    didChange = true
                }
                continue
            }

            if let target = ReadingAttemptRepair.targetAttempt(
                for: session,
                bookStatus: book.status,
                attempts: attempts
            ) {
                session.readingAttempt = target
                target.addSessionIfNeeded(session)
                didChange = true
            }
        }

        sessions = deduplicatedSessions(sessions)
        if sameIDs(sessions, book.readingSessionsSafe, id: \.id) == false {
            book.readingSessionsSafe = sessions
            didChange = true
        }

        for attempt in attempts {
            let attemptID = attempt.id
            let related = sessions.filter { $0.readingAttempt?.id == attemptID }
            if sameIDs(related, attempt.sessionsSafe, id: \.id) == false {
                attempt.sessionsSafe = related
                didChange = true
            }
        }

        return SessionRepairResult(sessions: sessions, didChange: didChange)
    }

    static func repairEventRelationships(
        book: Book,
        attempts: [ReadingAttempt],
        sessions: [ReadingSession],
        knownEvents: [ReadingProgressEvent],
        now: Date
    ) -> EventRepairResult {
        var didChange = false
        let bookEventIDs = Set(book.readingProgressEventsSafe.map(\.id))
        let attemptEventIDs = Set(attempts.flatMap(\.progressEventsSafe).map(\.id))
        let sourceSessionIDs = Set(sessions.map(\.id))
        let attemptIDs = Set(attempts.map(\.id))
        var events = deduplicatedEvents(
            book.readingProgressEventsSafe
                + attempts.flatMap(\.progressEventsSafe)
                + knownEvents.filter { event in
                    bookEventIDs.contains(event.id)
                        || attemptEventIDs.contains(event.id)
                        || event.book?.id == book.id
                        || event.readingAttempt?.book?.id == book.id
                        || event.sourceSessionID.map(sourceSessionIDs.contains) == true
                        || ReadingProgressEventFingerprint.attemptID(
                            fromLegacyBaselineKey: event.deduplicationKey
                        ).map(attemptIDs.contains) == true
                }
        )

        for event in events {
            if event.book?.id != book.id {
                event.book = book
                event.updatedAt = now
                didChange = true
            }
            if normalizedRawValue(event.mediumRawValue) == nil {
                event.mediumRawValue = ReadingMedium.physical.rawValue
                event.updatedAt = now
                didChange = true
            }
            if normalizedRawValue(event.providerRawValue) == nil {
                event.providerRawValue = ReadingProvider.none.rawValue
                event.updatedAt = now
                didChange = true
            }
            if normalizedRawValue(event.progressUnitRawValue) == nil {
                event.progressUnitRawValue = ReadingProgressUnit.none.rawValue
                event.updatedAt = now
                didChange = true
            }
            if normalizedRawValue(event.originRawValue) == nil {
                event.originRawValue = ReadingSessionOrigin.legacy.rawValue
                event.updatedAt = now
                didChange = true
            }

            if let currentAttempt = event.readingAttempt,
               attempts.contains(where: { $0.id == currentAttempt.id }) {
                if currentAttempt.progressEventsSafe.contains(where: { $0.id == event.id }) == false {
                    currentAttempt.progressEventsSafe.append(event)
                    didChange = true
                }
                continue
            }

            if let target = targetAttempt(
                for: event,
                attempts: attempts,
                sessions: sessions
            ) {
                event.readingAttempt = target
                if target.progressEventsSafe.contains(where: { $0.id == event.id }) == false {
                    target.progressEventsSafe.append(event)
                }
                event.updatedAt = now
                didChange = true
            }
        }

        events = deduplicatedEvents(events)
        if sameIDs(events, book.readingProgressEventsSafe, id: \.id) == false {
            book.readingProgressEventsSafe = events
            didChange = true
        }

        for attempt in attempts {
            let attemptID = attempt.id
            let related = events.filter { $0.readingAttempt?.id == attemptID }
            if sameIDs(related, attempt.progressEventsSafe, id: \.id) == false {
                attempt.progressEventsSafe = related
                didChange = true
            }
        }

        return EventRepairResult(events: events, didChange: didChange)
    }

    static func targetAttempt(
        for event: ReadingProgressEvent,
        attempts: [ReadingAttempt],
        sessions: [ReadingSession]
    ) -> ReadingAttempt? {
        if let baselineAttemptID = ReadingProgressEventFingerprint.attemptID(
            fromLegacyBaselineKey: event.deduplicationKey
        ) {
            return attempts.first { $0.id == baselineAttemptID }
        }

        if let sourceSessionID = event.sourceSessionID,
           let sourceAttemptID = sessions.first(where: { $0.id == sourceSessionID })?.readingAttempt?.id {
            return attempts.first { $0.id == sourceAttemptID }
        }

        if attempts.count == 1 {
            return attempts[0]
        }

        return nil
    }

    static func normalizedRawValue(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func deduplicatedAttempts(_ input: [ReadingAttempt]) -> [ReadingAttempt] {
        var seen = Set<UUID>()
        return input.filter { seen.insert($0.id).inserted }
    }

    static func deduplicatedSessions(_ input: [ReadingSession]) -> [ReadingSession] {
        var seen = Set<UUID>()
        return input.filter { seen.insert($0.id).inserted }
    }

    static func deduplicatedEvents(_ input: [ReadingProgressEvent]) -> [ReadingProgressEvent] {
        var seen = Set<UUID>()
        return input.filter { seen.insert($0.id).inserted }
    }

    static func sameIDs<Value, ID: Hashable>(
        _ left: [Value],
        _ right: [Value],
        id: (Value) -> ID
    ) -> Bool {
        guard left.count == right.count else { return false }
        return Set(left.map(id)) == Set(right.map(id))
    }
}
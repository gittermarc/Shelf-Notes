//
//  ReadingProgressEventMutationService.swift
//  Shelf Notes
//

import Foundation
import SwiftData

@MainActor
enum ReadingProgressEventMutationService {
    static func upsertSessionEvent(
        book: Book,
        attempt: ReadingAttempt?,
        session: ReadingSession,
        context: ReadingSessionContext,
        progress: ReadingProgressMutationPlan,
        modelContext: ModelContext,
        now: Date
    ) -> ReadingProgressEvent? {
        let fetchedEvents = (try? modelContext.fetch(FetchDescriptor<ReadingProgressEvent>())) ?? []
        let linkedEvents = deduplicated(
            sessionEvents(
                sessionID: session.id,
                book: book,
                attempt: attempt
            ) + fetchedEvents.filter { event in
                event.sourceSessionID == session.id
                    || event.deduplicationKey == ReadingProgressEventFingerprint.sessionProgressKey(sessionID: session.id)
            }
        )

        guard progress.shouldPersistEvent,
              let nativeValue = progress.eventNativeValue else {
            remove(
                events: linkedEvents,
                knownBook: book,
                knownAttempt: attempt,
                modelContext: modelContext
            )
            return nil
        }

        let key = ReadingProgressEventFingerprint.sessionProgressKey(sessionID: session.id)
        let canonical = canonicalEvent(from: linkedEvents)
            ?? ReadingProgressEvent(
                book: book,
                readingAttempt: attempt,
                occurredAt: session.endedAt,
                medium: context.medium,
                provider: context.provider,
                progressUnit: progress.unit,
                nativeValue: nativeValue,
                totalValue: progress.eventTotalValue,
                normalizedProgress: progress.eventNormalizedProgress,
                locator: progress.eventLocator,
                origin: context.origin,
                externalIdentifier: session.externalEventIdentifier,
                deduplicationKey: key,
                sourceSessionID: session.id,
                createdAt: now,
                updatedAt: now
            )

        if linkedEvents.isEmpty {
            modelContext.insert(canonical)
        }

        detachFromPreviousAttemptIfNeeded(canonical, newAttempt: attempt)
        canonical.book = book
        canonical.readingAttempt = attempt
        canonical.occurredAt = session.endedAt
        canonical.mediumRawValue = context.medium.rawValue
        canonical.providerRawValue = context.provider.rawValue
        canonical.progressUnitRawValue = progress.unit.rawValue
        canonical.nativeValue = nativeValue
        canonical.totalValue = progress.eventTotalValue
        canonical.normalizedProgress = progress.eventNormalizedProgress
        canonical.locator = progress.eventLocator
        canonical.originRawValue = context.origin.rawValue
        canonical.externalIdentifier = session.externalEventIdentifier
        canonical.deduplicationKey = key
        canonical.sourceSessionID = session.id
        canonical.importedAt = nil
        canonical.updatedAt = now

        attach(canonical, to: book, attempt: attempt)

        for duplicate in linkedEvents where duplicate.id != canonical.id {
            remove(
                event: duplicate,
                knownBook: book,
                knownAttempt: duplicate.readingAttempt ?? attempt,
                modelContext: modelContext
            )
        }

        return canonical
    }

    static func upsertImportedEvent(
        book: Book,
        attempt: ReadingAttempt?,
        request: ReadingProgressImportRequest,
        progress: ReadingProgressMutationPlan,
        modelContext: ModelContext,
        now: Date
    ) -> ReadingProgressEvent {
        let fetchedEvents = (try? modelContext.fetch(FetchDescriptor<ReadingProgressEvent>())) ?? []
        let matchingEvents = deduplicated(
            importedEvents(
                deduplicationKey: request.deduplicationKey,
                book: book,
                attempt: attempt
            ) + fetchedEvents.filter { event in
                guard event.deduplicationKey == request.deduplicationKey else {
                    return false
                }

                if event.book?.id == book.id {
                    return true
                }

                return event.book == nil && event.readingAttempt?.book?.id == book.id
            }
        )
        let canonical = canonicalEvent(from: matchingEvents)
            ?? ReadingProgressEvent(
                book: book,
                readingAttempt: attempt,
                occurredAt: request.update.occurredAt,
                medium: request.source.medium,
                provider: request.source.provider,
                progressUnit: progress.unit,
                nativeValue: progress.eventNativeValue ?? 0,
                totalValue: progress.eventTotalValue,
                normalizedProgress: progress.eventNormalizedProgress,
                locator: progress.eventLocator,
                origin: request.source.origin,
                externalIdentifier: request.externalIdentifier,
                deduplicationKey: request.deduplicationKey,
                sourceSessionID: nil,
                importedAt: request.importedAt,
                createdAt: now,
                updatedAt: now
            )

        if matchingEvents.isEmpty {
            modelContext.insert(canonical)
        }

        detachFromPreviousAttemptIfNeeded(canonical, newAttempt: attempt)
        canonical.book = book
        canonical.readingAttempt = attempt
        canonical.occurredAt = request.update.occurredAt
        canonical.mediumRawValue = request.source.medium.rawValue
        canonical.providerRawValue = request.source.provider.rawValue
        canonical.progressUnitRawValue = progress.unit.rawValue
        canonical.nativeValue = progress.eventNativeValue ?? 0
        canonical.totalValue = progress.eventTotalValue
        canonical.normalizedProgress = progress.eventNormalizedProgress
        canonical.locator = progress.eventLocator
        canonical.originRawValue = request.source.origin.rawValue
        canonical.externalIdentifier = request.externalIdentifier
        canonical.deduplicationKey = request.deduplicationKey
        canonical.sourceSessionID = nil
        canonical.importedAt = request.importedAt
        canonical.updatedAt = now

        attach(canonical, to: book, attempt: attempt)

        for duplicate in matchingEvents where duplicate.id != canonical.id {
            remove(
                event: duplicate,
                knownBook: book,
                knownAttempt: duplicate.readingAttempt ?? attempt,
                modelContext: modelContext
            )
        }

        return canonical
    }

    static func sessionEvents(
        sessionID: UUID,
        book: Book,
        attempt: ReadingAttempt?
    ) -> [ReadingProgressEvent] {
        deduplicated(
            book.readingProgressEventsSafe
                + (attempt?.progressEventsSafe ?? [])
        )
        .filter { event in
            event.sourceSessionID == sessionID
                || event.deduplicationKey == ReadingProgressEventFingerprint.sessionProgressKey(sessionID: sessionID)
        }
    }

    static func remove(
        events: [ReadingProgressEvent],
        knownBook: Book? = nil,
        knownAttempt: ReadingAttempt? = nil,
        modelContext: ModelContext
    ) {
        for event in deduplicated(events) {
            remove(
                event: event,
                knownBook: knownBook,
                knownAttempt: event.readingAttempt ?? knownAttempt,
                modelContext: modelContext
            )
        }
    }

    private static func importedEvents(
        deduplicationKey: String,
        book: Book,
        attempt: ReadingAttempt?
    ) -> [ReadingProgressEvent] {
        deduplicated(
            book.readingProgressEventsSafe
                + (attempt?.progressEventsSafe ?? [])
        )
        .filter { $0.deduplicationKey == deduplicationKey }
    }

    private static func canonicalEvent(from events: [ReadingProgressEvent]) -> ReadingProgressEvent? {
        events.min { left, right in
            if left.createdAt != right.createdAt {
                return left.createdAt < right.createdAt
            }
            return left.id.uuidString < right.id.uuidString
        }
    }

    private static func attach(
        _ event: ReadingProgressEvent,
        to book: Book,
        attempt: ReadingAttempt?
    ) {
        if book.readingProgressEventsSafe.contains(where: { $0.id == event.id }) == false {
            book.readingProgressEventsSafe.append(event)
        }

        if let attempt,
           attempt.progressEventsSafe.contains(where: { $0.id == event.id }) == false {
            attempt.progressEventsSafe.append(event)
        }
    }

    private static func detachFromPreviousAttemptIfNeeded(
        _ event: ReadingProgressEvent,
        newAttempt: ReadingAttempt?
    ) {
        guard let previousAttempt = event.readingAttempt,
              previousAttempt.id != newAttempt?.id else {
            return
        }
        previousAttempt.progressEventsSafe.removeAll { $0.id == event.id }
    }

    private static func remove(
        event: ReadingProgressEvent,
        knownBook: Book?,
        knownAttempt: ReadingAttempt?,
        modelContext: ModelContext
    ) {
        knownBook?.readingProgressEventsSafe.removeAll { $0.id == event.id }
        event.book?.readingProgressEventsSafe.removeAll { $0.id == event.id }
        knownAttempt?.progressEventsSafe.removeAll { $0.id == event.id }
        event.readingAttempt?.progressEventsSafe.removeAll { $0.id == event.id }
        event.readingAttempt = nil
        event.book = nil
        modelContext.delete(event)
    }

    private static func deduplicated(_ events: [ReadingProgressEvent]) -> [ReadingProgressEvent] {
        var seen = Set<UUID>()
        var result: [ReadingProgressEvent] = []
        result.reserveCapacity(events.count)

        for event in events where seen.insert(event.id).inserted {
            result.append(event)
        }
        return result
    }
}

//
//  ReadingProgressRepair+Dedupe.swift
//  Shelf Notes
//

import Foundation

extension ReadingProgressRepair {
    static func removeExactDuplicates(
        events: [ReadingProgressEvent],
        book: Book,
        attempts: [ReadingAttempt],
        deleteEvent: (ReadingProgressEvent) -> Void
    ) -> EventsMutationResult {
        var canonicalByFingerprint: [ReadingProgressEventFingerprint: ReadingProgressEvent] = [:]
        var output: [ReadingProgressEvent] = []
        var didChange = false

        for event in events.sorted(by: eventCreationOrder) {
            if ReadingProgressEventFingerprint.attemptID(
                fromLegacyBaselineKey: event.deduplicationKey
            ) != nil {
                output.append(event)
                continue
            }

            let hasStableIdentity = normalizedRawValue(event.deduplicationKey) != nil
                || normalizedRawValue(event.externalIdentifier ?? "") != nil
                || event.sourceSessionID != nil
            guard hasStableIdentity else {
                output.append(event)
                continue
            }

            let fingerprint = exactFingerprint(for: event)
            if canonicalByFingerprint[fingerprint] == nil {
                canonicalByFingerprint[fingerprint] = event
                output.append(event)
                continue
            }

            removeEventReferences(event, book: book, attempts: attempts)
            deleteEvent(event)
            didChange = true
        }

        return EventsMutationResult(events: output, didChange: didChange)
    }

    static func exactFingerprint(
        for event: ReadingProgressEvent
    ) -> ReadingProgressEventFingerprint {
        ReadingProgressEventFingerprint(
            deduplicationKey: event.deduplicationKey,
            bookID: event.book?.id,
            attemptID: event.readingAttempt?.id,
            occurredAtBits: event.occurredAt.timeIntervalSinceReferenceDate.bitPattern,
            mediumRawValue: event.mediumRawValue,
            providerRawValue: event.providerRawValue,
            progressUnitRawValue: event.progressUnitRawValue,
            nativeValueBits: event.nativeValue.bitPattern,
            totalValueBits: event.totalValue?.bitPattern,
            normalizedProgressBits: event.normalizedProgress?.bitPattern,
            locator: event.locator,
            originRawValue: event.originRawValue,
            externalIdentifier: event.externalIdentifier,
            sourceSessionID: event.sourceSessionID,
            importedAtBits: ReadingProgressEventFingerprint.dateBits(event.importedAt)
        )
    }

    static func removeEventReferences(
        _ event: ReadingProgressEvent,
        book: Book,
        attempts: [ReadingAttempt]
    ) {
        book.readingProgressEventsSafe.removeAll { $0.id == event.id }
        for attempt in attempts {
            attempt.progressEventsSafe.removeAll { $0.id == event.id }
        }
        event.book = nil
        event.readingAttempt = nil
    }

    static func eventCreationOrder(
        _ left: ReadingProgressEvent,
        _ right: ReadingProgressEvent
    ) -> Bool {
        if left.createdAt != right.createdAt {
            return left.createdAt < right.createdAt
        }
        return left.id.uuidString < right.id.uuidString
    }
}

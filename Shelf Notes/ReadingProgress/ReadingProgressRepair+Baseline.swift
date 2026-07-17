//
//  ReadingProgressRepair+Baseline.swift
//  Shelf Notes
//

import Foundation

extension ReadingProgressRepair {
    struct EventsMutationResult {
        let events: [ReadingProgressEvent]
        let didChange: Bool
    }

    static func repairLegacyBaseline(
        book: Book,
        attempt: ReadingAttempt,
        sessions: [ReadingSession],
        events: [ReadingProgressEvent],
        now: Date,
        insertEvent: (ReadingProgressEvent) -> Void,
        deleteEvent: (ReadingProgressEvent) -> Void
    ) -> EventsMutationResult {
        let key = ReadingProgressEventFingerprint.legacyBaselineKey(attemptID: attempt.id)
        var updatedEvents = events
        let baselineEvents = updatedEvents
            .filter { $0.deduplicationKey == key }
            .sorted(by: eventCreationOrder)
        let attemptID = attempt.id
        let legacySessions = sessions.filter { session in
            session.readingAttempt?.id == attemptID
                && session.origin == .legacy
                && session.progressUnit == .pages
                && session.pagesReadNormalized != nil
        }
        let pageTotal = positivePageSum(legacySessions.compactMap(\.pagesReadNormalized))

        guard attempt.progressUnit == .pages, pageTotal > 0 else {
            guard baselineEvents.isEmpty == false else {
                return EventsMutationResult(events: updatedEvents, didChange: false)
            }

            for event in baselineEvents {
                removeEventReferences(event, book: book, attempts: [attempt])
                deleteEvent(event)
            }
            updatedEvents.removeAll { $0.deduplicationKey == key }
            return EventsMutationResult(events: updatedEvents, didChange: true)
        }

        let occurredAt = legacySessions.map(\.endedAt).max()
            ?? attempt.finishedAt
            ?? attempt.updatedAt
        let totalValue = reliablePageTotal(for: attempt).map(Double.init)
        let normalizedProgress = attempt.status == .finished
            ? 1
            : totalValue.map { min(1, max(0, Double(pageTotal) / $0)) }

        let canonical: ReadingProgressEvent
        var didChange = false
        if let existing = baselineEvents.first {
            canonical = existing
        } else {
            canonical = ReadingProgressEvent(
                book: book,
                readingAttempt: attempt,
                occurredAt: occurredAt,
                medium: attempt.readingMedium,
                provider: attempt.defaultProvider,
                progressUnit: .pages,
                nativeValue: Double(pageTotal),
                totalValue: totalValue,
                normalizedProgress: normalizedProgress,
                locator: nil,
                origin: .legacy,
                externalIdentifier: nil,
                deduplicationKey: key,
                sourceSessionID: nil,
                importedAt: nil,
                createdAt: now,
                updatedAt: now
            )
            insertEvent(canonical)
            updatedEvents.append(canonical)
            book.readingProgressEventsSafe.append(canonical)
            attempt.progressEventsSafe.append(canonical)
            didChange = true
        }

        if updateBaseline(
            canonical,
            book: book,
            attempt: attempt,
            occurredAt: occurredAt,
            pageTotal: pageTotal,
            totalValue: totalValue,
            normalizedProgress: normalizedProgress,
            key: key,
            now: now
        ) {
            didChange = true
        }

        for duplicate in baselineEvents.dropFirst() {
            removeEventReferences(duplicate, book: book, attempts: [attempt])
            deleteEvent(duplicate)
            updatedEvents.removeAll { $0.id == duplicate.id }
            didChange = true
        }

        if book.readingProgressEventsSafe.contains(where: { $0.id == canonical.id }) == false {
            book.readingProgressEventsSafe.append(canonical)
            didChange = true
        }
        if attempt.progressEventsSafe.contains(where: { $0.id == canonical.id }) == false {
            attempt.progressEventsSafe.append(canonical)
            didChange = true
        }

        return EventsMutationResult(
            events: deduplicatedEvents(updatedEvents),
            didChange: didChange
        )
    }

    static func updateBaseline(
        _ event: ReadingProgressEvent,
        book: Book,
        attempt: ReadingAttempt,
        occurredAt: Date,
        pageTotal: Int,
        totalValue: Double?,
        normalizedProgress: Double?,
        key: String,
        now: Date
    ) -> Bool {
        var didChange = false

        didChange = assignIfDifferent(&event.book, book, ids: { $0?.id }) || didChange
        didChange = assignIfDifferent(&event.readingAttempt, attempt, ids: { $0?.id }) || didChange
        didChange = assignIfDifferent(&event.occurredAt, occurredAt) || didChange
        didChange = assignIfDifferent(&event.mediumRawValue, attempt.readingMedium.rawValue) || didChange
        didChange = assignIfDifferent(&event.providerRawValue, attempt.defaultProvider.rawValue) || didChange
        didChange = assignIfDifferent(&event.progressUnitRawValue, ReadingProgressUnit.pages.rawValue) || didChange
        didChange = assignDoubleIfDifferent(&event.nativeValue, Double(pageTotal)) || didChange
        didChange = assignOptionalDoubleIfDifferent(&event.totalValue, totalValue) || didChange
        didChange = assignOptionalDoubleIfDifferent(&event.normalizedProgress, normalizedProgress) || didChange
        didChange = assignIfDifferent(&event.locator, nil as String?) || didChange
        didChange = assignIfDifferent(&event.originRawValue, ReadingSessionOrigin.legacy.rawValue) || didChange
        didChange = assignIfDifferent(&event.externalIdentifier, nil as String?) || didChange
        didChange = assignIfDifferent(&event.deduplicationKey, key) || didChange
        didChange = assignIfDifferent(&event.sourceSessionID, nil as UUID?) || didChange
        didChange = assignIfDifferent(&event.importedAt, nil as Date?) || didChange

        if didChange {
            event.updatedAt = now
        }

        return didChange
    }

    static func reliablePageTotal(for attempt: ReadingAttempt) -> Int? {
        if let pageCount = attempt.pageCountSnapshot, pageCount > 0 {
            return pageCount
        }
        guard let total = attempt.totalValueSnapshot,
              total.isFinite,
              total > 0,
              total.rounded(.towardZero) == total,
              total <= Double(Int.max) else {
            return nil
        }
        return Int(total)
    }

    static func positivePageSum(_ values: [Int]) -> Int {
        var result = 0
        for value in values where value > 0 {
            let addition = result.addingReportingOverflow(value)
            result = addition.overflow ? Int.max : addition.partialValue
            if result == Int.max {
                break
            }
        }
        return result
    }

    static func assignIfDifferent<Value: Equatable>(
        _ target: inout Value,
        _ value: Value
    ) -> Bool {
        guard target != value else { return false }
        target = value
        return true
    }

    static func assignIfDifferent<Model, ID: Equatable>(
        _ target: inout Model?,
        _ value: Model?,
        ids: (Model?) -> ID?
    ) -> Bool {
        guard ids(target) != ids(value) else { return false }
        target = value
        return true
    }

    static func assignDoubleIfDifferent(
        _ target: inout Double,
        _ value: Double
    ) -> Bool {
        guard target.bitPattern != value.bitPattern else { return false }
        target = value
        return true
    }

    static func assignOptionalDoubleIfDifferent(
        _ target: inout Double?,
        _ value: Double?
    ) -> Bool {
        guard target?.bitPattern != value?.bitPattern else { return false }
        target = value
        return true
    }
}
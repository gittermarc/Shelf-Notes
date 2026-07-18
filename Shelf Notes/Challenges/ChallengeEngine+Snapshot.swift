//
//  ChallengeEngine+Snapshot.swift
//  Shelf Notes
//
//  Value-only snapshots for ChallengeEngine.
//  Goal: keep heavy crunching off-main, while limiting SwiftData access to fetch points.
//

import Foundation
import SwiftData

nonisolated extension ChallengeEngine {

    struct SessionSnapshot: Sendable {
        let bookID: UUID?
        let startedAt: Date
        let endedAt: Date
        let durationSeconds: Int
        let pagesRead: Int
        let hasNote: Bool
        let progressUnitRawValue: String
        let originRawValue: String
        let startValue: Double?
        let endValue: Double?
        let startNormalizedProgress: Double?
        let endNormalizedProgress: Double?
        let startLocator: String?
        let endLocator: String?

        init(
            bookID: UUID? = nil,
            startedAt: Date,
            endedAt: Date,
            durationSeconds: Int,
            pagesRead: Int,
            hasNote: Bool = false,
            progressUnitRawValue: String = ReadingProgressUnit.pages.rawValue,
            originRawValue: String = ReadingSessionOrigin.legacy.rawValue,
            startValue: Double? = nil,
            endValue: Double? = nil,
            startNormalizedProgress: Double? = nil,
            endNormalizedProgress: Double? = nil,
            startLocator: String? = nil,
            endLocator: String? = nil
        ) {
            self.bookID = bookID
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.durationSeconds = max(0, durationSeconds)
            self.pagesRead = max(0, pagesRead)
            self.hasNote = hasNote
            self.progressUnitRawValue = progressUnitRawValue
            self.originRawValue = originRawValue
            self.startValue = startValue
            self.endValue = endValue
            self.startNormalizedProgress = startNormalizedProgress
            self.endNormalizedProgress = endNormalizedProgress
            self.startLocator = startLocator
            self.endLocator = endLocator
        }

        var progressUnit: ReadingProgressUnit {
            ReadingProgressUnit.fromPersisted(progressUnitRawValue)
        }

        var origin: ReadingSessionOrigin {
            ReadingSessionOrigin.fromPersisted(originRawValue)
        }

        var metricContribution: ReadingMetricContribution {
            ReadingSessionMetricMapper.contribution(
                from: ReadingSessionMetricInput(
                    startedAt: startedAt,
                    durationSeconds: durationSeconds,
                    pagesRead: pagesRead,
                    nativeValue: endValue,
                    normalizedProgress: endNormalizedProgress,
                    locator: endLocator,
                    progressUnitRawValue: progressUnitRawValue,
                    originRawValue: originRawValue
                )
            )
        }

        var hasMeasuredProgressIncrease: Bool {
            guard metricContribution.hasMeasuredProgress else { return false }
            return ReadingProgressIncreaseDetector.sessionHasIncrease(
                unit: progressUnit,
                pagesRead: pagesRead,
                startValue: startValue,
                endValue: endValue,
                startNormalizedProgress: startNormalizedProgress,
                endNormalizedProgress: endNormalizedProgress,
                startLocator: startLocator,
                endLocator: endLocator
            )
        }
    }

    struct ProgressEventSnapshot: Sendable {
        let id: UUID
        let bookID: UUID?
        let attemptID: UUID?
        let occurredAt: Date
        let progressUnitRawValue: String
        let originRawValue: String
        let nativeValue: Double?
        let totalValue: Double?
        let normalizedProgress: Double?
        let locator: String?
        let deduplicationKey: String

        init(
            id: UUID = UUID(),
            bookID: UUID? = nil,
            attemptID: UUID? = nil,
            occurredAt: Date,
            progressUnitRawValue: String,
            originRawValue: String = ReadingSessionOrigin.providerImport.rawValue,
            nativeValue: Double? = nil,
            totalValue: Double? = nil,
            normalizedProgress: Double? = nil,
            locator: String? = nil,
            deduplicationKey: String = ""
        ) {
            self.id = id
            self.bookID = bookID
            self.attemptID = attemptID
            self.occurredAt = occurredAt
            self.progressUnitRawValue = progressUnitRawValue
            self.originRawValue = originRawValue
            self.nativeValue = nativeValue
            self.totalValue = totalValue
            self.normalizedProgress = normalizedProgress
            self.locator = locator
            self.deduplicationKey = deduplicationKey
        }

        var progressUnit: ReadingProgressUnit {
            ReadingProgressUnit.fromPersisted(progressUnitRawValue)
        }

        var origin: ReadingSessionOrigin {
            ReadingSessionOrigin.fromPersisted(originRawValue)
        }

        var observation: ReadingProgressComparableObservation {
            ReadingProgressComparableObservation(
                unit: progressUnit,
                nativeValue: nativeValue,
                totalValue: totalValue,
                normalizedProgress: normalizedProgress,
                locator: locator
            )
        }

        var stableDeduplicationKey: String {
            let normalized = deduplicationKey.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? "event:\(id.uuidString.lowercased())" : normalized
        }
    }

    struct FinishedBookSnapshot: Sendable {
        let bookID: UUID?
        let attemptID: UUID?
        let sequenceNumber: Int
        let readTo: Date
        let hasUserNote: Bool
        let hasUserRating: Bool
        let isReread: Bool

        init(
            bookID: UUID? = nil,
            attemptID: UUID? = nil,
            sequenceNumber: Int = 1,
            readTo: Date,
            hasUserNote: Bool = false,
            hasUserRating: Bool = false,
            isReread: Bool = false
        ) {
            self.bookID = bookID
            self.attemptID = attemptID
            self.sequenceNumber = max(1, sequenceNumber)
            self.readTo = readTo
            self.hasUserNote = hasUserNote
            self.hasUserRating = hasUserRating
            self.isReread = isReread
        }

        init(
            completion: ReadingCompletionRecord,
            hasUserNote: Bool = false,
            hasUserRating: Bool = false
        ) {
            self.init(
                bookID: completion.bookID,
                attemptID: completion.attemptID,
                sequenceNumber: completion.sequenceNumber,
                readTo: completion.finishedAt,
                hasUserNote: hasUserNote,
                hasUserRating: hasUserRating,
                isReread: completion.isReread
            )
        }
    }

    struct Snapshot: Sendable {
        let sessions: [SessionSnapshot]
        let finishedBooks: [FinishedBookSnapshot]
        let progressEvents: [ProgressEventSnapshot]

        var finishedBookReadTo: [Date] {
            finishedBooks.map(\.readTo)
        }

        init(sessions: [SessionSnapshot], finishedBookReadTo: [Date]) {
            self.sessions = sessions
            self.finishedBooks = finishedBookReadTo.map { FinishedBookSnapshot(readTo: $0) }
            self.progressEvents = []
        }

        init(
            sessions: [SessionSnapshot],
            finishedBooks: [FinishedBookSnapshot],
            progressEvents: [ProgressEventSnapshot] = []
        ) {
            self.sessions = sessions
            self.finishedBooks = finishedBooks
            self.progressEvents = progressEvents
        }
    }

    struct ChallengeRecordSnapshot: Sendable {
        let id: UUID
        let kind: ChallengeKind
        let metric: ChallengeMetric
        let periodStart: Date
        let periodEnd: Date
        let targetValue: Int
        let completedAt: Date?
        let title: String
        let detail: String

        init(
            id: UUID,
            kind: ChallengeKind,
            metric: ChallengeMetric,
            periodStart: Date,
            periodEnd: Date,
            targetValue: Int,
            completedAt: Date?,
            title: String = "",
            detail: String = ""
        ) {
            self.id = id
            self.kind = kind
            self.metric = metric
            self.periodStart = periodStart
            self.periodEnd = periodEnd
            self.targetValue = targetValue
            self.completedAt = completedAt
            self.title = title
            self.detail = detail
        }

        @MainActor
        init(from record: ChallengeRecord) {
            self.init(
                id: record.id,
                kind: record.kind,
                metric: record.metric,
                periodStart: record.periodStart,
                periodEnd: record.periodEnd,
                targetValue: record.targetValue,
                completedAt: record.completedAt,
                title: record.title,
                detail: record.detail
            )
        }

        init(from plan: EnsurePlan) {
            self.init(
                id: plan.id,
                kind: plan.kind,
                metric: plan.metric,
                periodStart: plan.periodStart,
                periodEnd: plan.periodEnd,
                targetValue: plan.targetValue,
                completedAt: nil,
                title: plan.title,
                detail: plan.detail
            )
        }
    }

    @MainActor
    static func buildSnapshot(range: Range<Date>, modelContext: ModelContext) -> Snapshot {
        let sessions = fetchSessionSnapshots(in: range, modelContext: modelContext)
        let finished = fetchFinishedBookSnapshots(in: range, modelContext: modelContext)
        let progressEvents = fetchProgressEventSnapshots(before: range.upperBound, modelContext: modelContext)
        return Snapshot(
            sessions: sessions,
            finishedBooks: finished,
            progressEvents: progressEvents
        )
    }

    @MainActor
    static func fetchChallengeSnapshot(
        kind: ChallengeKind,
        periodStart: Date,
        periodEnd: Date,
        modelContext: ModelContext
    ) -> ChallengeRecordSnapshot? {
        let kindRaw = kind.rawValue
        let start = periodStart
        let end = periodEnd

        let descriptor = FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate<ChallengeRecord> {
                $0.kindRawValue == kindRaw &&
                $0.periodStart == start &&
                $0.periodEnd == end
            },
            sortBy: [SortDescriptor(\ChallengeRecord.createdAt, order: .forward)]
        )

        guard let record = (try? modelContext.fetch(descriptor))?.first else { return nil }
        return ChallengeRecordSnapshot(from: record)
    }

    @MainActor
    static func fetchRecentChallengeSnapshots(kind: ChallengeKind, before periodStart: Date, limit: Int, modelContext: ModelContext) -> [ChallengeRecordSnapshot] {
        let kindRaw = kind.rawValue
        let before = periodStart
        var descriptor = FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate<ChallengeRecord> { $0.kindRawValue == kindRaw && $0.periodStart < before },
            sortBy: [SortDescriptor(\ChallengeRecord.periodStart, order: .reverse)]
        )
        descriptor.fetchLimit = max(0, limit)
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.map { ChallengeRecordSnapshot(from: $0) }
    }
}

// MARK: - SwiftData fetches

private extension ChallengeEngine {

    @MainActor
    static func fetchSessionSnapshots(in range: Range<Date>, modelContext: ModelContext) -> [SessionSnapshot] {
        let start = range.lowerBound
        let end = range.upperBound

        let descriptor = FetchDescriptor<ReadingSession>(
            predicate: #Predicate<ReadingSession> { $0.endedAt > start && $0.startedAt < end }
        )

        let results = (try? modelContext.fetch(descriptor)) ?? []
        if results.isEmpty { return [] }

        return results.map { session in
            SessionSnapshot(
                bookID: session.book?.id,
                startedAt: session.startedAt,
                endedAt: session.endedAt,
                durationSeconds: session.durationSeconds,
                pagesRead: session.pagesReadNormalized ?? 0,
                hasNote: !(session.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                progressUnitRawValue: session.progressUnitRawValue,
                originRawValue: session.originRawValue,
                startValue: session.startValue,
                endValue: session.endValue,
                startNormalizedProgress: session.startNormalizedProgress,
                endNormalizedProgress: session.endNormalizedProgress,
                startLocator: session.startLocator,
                endLocator: session.endLocator
            )
        }
    }

    @MainActor
    static func fetchProgressEventSnapshots(
        before end: Date,
        modelContext: ModelContext
    ) -> [ProgressEventSnapshot] {
        let endValue = end
        let descriptor = FetchDescriptor<ReadingProgressEvent>(
            predicate: #Predicate<ReadingProgressEvent> {
                $0.occurredAt < endValue && $0.sourceSessionID == nil
            },
            sortBy: [
                SortDescriptor(\ReadingProgressEvent.occurredAt, order: .forward),
                SortDescriptor(\ReadingProgressEvent.createdAt, order: .forward)
            ]
        )

        return ((try? modelContext.fetch(descriptor)) ?? []).compactMap { event in
            guard event.origin == .providerImport else { return nil }
            return ProgressEventSnapshot(
                id: event.id,
                bookID: event.book?.id ?? event.readingAttempt?.book?.id,
                attemptID: event.readingAttempt?.id,
                occurredAt: event.occurredAt,
                progressUnitRawValue: event.progressUnitRawValue,
                originRawValue: event.originRawValue,
                nativeValue: event.nativeValue,
                totalValue: event.totalValue,
                normalizedProgress: event.normalizedProgress,
                locator: event.locator,
                deduplicationKey: event.deduplicationKey
            )
        }
    }

    @MainActor
    static func fetchFinishedBookSnapshots(in range: Range<Date>, modelContext: ModelContext) -> [FinishedBookSnapshot] {
        let start = range.lowerBound
        let end = range.upperBound

        let descriptor = FetchDescriptor<Book>(
            sortBy: [SortDescriptor(\Book.createdAt, order: .forward)]
        )

        let results = (try? modelContext.fetch(descriptor)) ?? []
        if results.isEmpty { return [] }

        return results.flatMap { book in
            let hasNote = !book.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let hasRating = book.userRatingValues.contains { $0 > 0 }
            return ReadingCompletionRecordBuilder.records(from: book)
                .filter { $0.finishedAt >= start && $0.finishedAt < end }
                .map { completion in
                    FinishedBookSnapshot(
                        completion: completion,
                        hasUserNote: hasNote,
                        hasUserRating: hasRating
                    )
                }
        }
    }
}

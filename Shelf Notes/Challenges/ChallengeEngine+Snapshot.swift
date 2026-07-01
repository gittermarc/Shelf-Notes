//
//  ChallengeEngine+Snapshot.swift
//  Shelf Notes
//
//  Value-only snapshots for ChallengeEngine.
//  Goal: keep heavy crunching off-main, while limiting SwiftData access to fetch points.
//

import Foundation
import SwiftData

extension ChallengeEngine {

    struct SessionSnapshot: Sendable {
        let bookID: UUID?
        let startedAt: Date
        let endedAt: Date
        let durationSeconds: Int
        let pagesRead: Int
        let hasNote: Bool

        init(
            bookID: UUID? = nil,
            startedAt: Date,
            endedAt: Date,
            durationSeconds: Int,
            pagesRead: Int,
            hasNote: Bool = false
        ) {
            self.bookID = bookID
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.durationSeconds = max(0, durationSeconds)
            self.pagesRead = max(0, pagesRead)
            self.hasNote = hasNote
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

        var finishedBookReadTo: [Date] {
            finishedBooks.map(\.readTo)
        }

        init(sessions: [SessionSnapshot], finishedBookReadTo: [Date]) {
            self.sessions = sessions
            self.finishedBooks = finishedBookReadTo.map { FinishedBookSnapshot(readTo: $0) }
        }

        init(sessions: [SessionSnapshot], finishedBooks: [FinishedBookSnapshot]) {
            self.sessions = sessions
            self.finishedBooks = finishedBooks
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
        return Snapshot(sessions: sessions, finishedBooks: finished)
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
                hasNote: !(session.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

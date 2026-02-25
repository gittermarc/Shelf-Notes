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
        let startedAt: Date
        let endedAt: Date
        let durationSeconds: Int
        let pagesRead: Int

        init(startedAt: Date, endedAt: Date, durationSeconds: Int, pagesRead: Int) {
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.durationSeconds = max(0, durationSeconds)
            self.pagesRead = max(0, pagesRead)
        }
    }

    struct Snapshot: Sendable {
        let sessions: [SessionSnapshot]
        let finishedBookReadTo: [Date]

        init(sessions: [SessionSnapshot], finishedBookReadTo: [Date]) {
            self.sessions = sessions
            self.finishedBookReadTo = finishedBookReadTo
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

        init(
            id: UUID,
            kind: ChallengeKind,
            metric: ChallengeMetric,
            periodStart: Date,
            periodEnd: Date,
            targetValue: Int,
            completedAt: Date?
        ) {
            self.id = id
            self.kind = kind
            self.metric = metric
            self.periodStart = periodStart
            self.periodEnd = periodEnd
            self.targetValue = targetValue
            self.completedAt = completedAt
        }

        init(from record: ChallengeRecord) {
            self.init(
                id: record.id,
                kind: record.kind,
                metric: record.metric,
                periodStart: record.periodStart,
                periodEnd: record.periodEnd,
                targetValue: record.targetValue,
                completedAt: record.completedAt
            )
        }
    }

    @MainActor
    static func buildSnapshot(range: Range<Date>, modelContext: ModelContext) -> Snapshot {
        let sessions = fetchSessionSnapshots(in: range, modelContext: modelContext)
        let finished = fetchFinishedBookReadToDates(in: range, modelContext: modelContext)
        return Snapshot(sessions: sessions, finishedBookReadTo: finished)
    }

    @MainActor
    static func fetchChallengeSnapshot(kind: ChallengeKind, periodStart: Date, modelContext: ModelContext) -> ChallengeRecordSnapshot? {
        let kindRaw = kind.rawValue
        let start = periodStart

        let descriptor = FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate<ChallengeRecord> { $0.kindRawValue == kindRaw && $0.periodStart == start }
        )

        guard let record = (try? modelContext.fetch(descriptor))?.first else { return nil }
        return ChallengeRecordSnapshot(from: record)
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

        return results.map {
            SessionSnapshot(
                startedAt: $0.startedAt,
                endedAt: $0.endedAt,
                durationSeconds: $0.durationSeconds,
                pagesRead: $0.pagesReadNormalized ?? 0
            )
        }
    }

    @MainActor
    static func fetchFinishedBookReadToDates(in range: Range<Date>, modelContext: ModelContext) -> [Date] {
        let start = range.lowerBound
        let end = range.upperBound

        let statusFinished = ReadingStatus.finished.rawValue
        let legacyFinished = "Gelesen"

        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate<Book> {
                ($0.statusRawValue == statusFinished || $0.statusRawValue == legacyFinished) &&
                $0.readTo != nil &&
                $0.readTo! >= start &&
                $0.readTo! < end
            }
        )

        let results = (try? modelContext.fetch(descriptor)) ?? []
        if results.isEmpty { return [] }

        return results.compactMap { $0.readTo }
    }
}

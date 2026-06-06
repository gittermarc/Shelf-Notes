//
//  ChallengeDuplicateResolver.swift
//  Shelf Notes
//
//  Keeps one ChallengeRecord per kind/period window and identifies duplicates safely.
//

import Foundation
import SwiftData

enum ChallengeDuplicateResolver {
    struct PeriodKey: Hashable, Sendable {
        let kindRawValue: String
        let periodStart: Date
        let periodEnd: Date
    }

    struct RecordSnapshot: Equatable, Sendable {
        let id: UUID
        let key: PeriodKey
        let createdAt: Date
        let completedAt: Date?
        let acknowledgedAt: Date?
        let rerollsUsed: Int
        let rerolledAt: Date?

        init(
            id: UUID,
            kindRawValue: String,
            periodStart: Date,
            periodEnd: Date,
            createdAt: Date,
            completedAt: Date? = nil,
            acknowledgedAt: Date? = nil,
            rerollsUsed: Int = 0,
            rerolledAt: Date? = nil
        ) {
            self.id = id
            self.key = PeriodKey(kindRawValue: kindRawValue, periodStart: periodStart, periodEnd: periodEnd)
            self.createdAt = createdAt
            self.completedAt = completedAt
            self.acknowledgedAt = acknowledgedAt
            self.rerollsUsed = max(0, rerollsUsed)
            self.rerolledAt = rerolledAt
        }

        @MainActor
        init(record: ChallengeRecord) {
            self.init(
                id: record.id,
                kindRawValue: record.kindRawValue,
                periodStart: record.periodStart,
                periodEnd: record.periodEnd,
                createdAt: record.createdAt,
                completedAt: record.completedAt,
                acknowledgedAt: record.acknowledgedAt,
                rerollsUsed: record.rerollsUsed,
                rerolledAt: record.rerolledAt
            )
        }
    }

    struct Resolution: Equatable, Sendable {
        let key: PeriodKey
        let retainedID: UUID
        let removedIDs: [UUID]
    }

    static func resolutions(for snapshots: [RecordSnapshot]) -> [Resolution] {
        let grouped = Dictionary(grouping: snapshots, by: \RecordSnapshot.key)

        return grouped.compactMap { key, candidates in
            guard candidates.count > 1, let retained = preferredRecord(from: candidates) else { return nil }
            let removedIDs = candidates
                .filter { $0.id != retained.id }
                .map(\.id)
                .sorted { $0.uuidString < $1.uuidString }

            guard !removedIDs.isEmpty else { return nil }
            return Resolution(key: key, retainedID: retained.id, removedIDs: removedIDs)
        }
        .sorted { lhs, rhs in
            resolutionSortKey(lhs) < resolutionSortKey(rhs)
        }
    }

    static func idsToDelete(from snapshots: [RecordSnapshot]) -> Set<UUID> {
        Set(resolutions(for: snapshots).flatMap(\.removedIDs))
    }

    @MainActor
    @discardableResult
    static func deleteDuplicates(in records: [ChallengeRecord], modelContext: ModelContext) -> Int {
        let ids = idsToDelete(from: records.map { RecordSnapshot(record: $0) })
        guard !ids.isEmpty else { return 0 }

        var deletedCount = 0
        for record in records where ids.contains(record.id) {
            modelContext.delete(record)
            deletedCount += 1
        }
        return deletedCount
    }

    private static func preferredRecord(from candidates: [RecordSnapshot]) -> RecordSnapshot? {
        candidates.sorted { lhs, rhs in
            shouldPrefer(lhs, over: rhs)
        }.first
    }

    private static func shouldPrefer(_ lhs: RecordSnapshot, over rhs: RecordSnapshot) -> Bool {
        let lhsRank = statusRank(lhs)
        let rhsRank = statusRank(rhs)
        if lhsRank != rhsRank { return lhsRank > rhsRank }

        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func statusRank(_ snapshot: RecordSnapshot) -> Int {
        if snapshot.acknowledgedAt != nil { return 3 }
        if snapshot.completedAt != nil { return 2 }
        if snapshot.rerolledAt != nil || snapshot.rerollsUsed > 0 { return 1 }
        return 0
    }

    private static func resolutionSortKey(_ resolution: Resolution) -> String {
        [
            resolution.key.kindRawValue,
            String(resolution.key.periodStart.timeIntervalSinceReferenceDate),
            String(resolution.key.periodEnd.timeIntervalSinceReferenceDate),
            resolution.retainedID.uuidString
        ].joined(separator: "\u{1F}")
    }
}

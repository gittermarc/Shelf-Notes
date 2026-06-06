//
//  ChallengeSourceStore.swift
//  Shelf Notes
//
//  Fetches bounded ChallengeRecord slices for challenge UI entry points.
//

import Foundation
import SwiftData

@MainActor
enum ChallengeSourceStore {
    static func makeSnapshot(
        modelContext: ModelContext,
        enabledKinds: [ChallengeKind],
        now: Date = Date(),
        includeHistory: Bool = true,
        dashboardHistoryLimit: Int = 12
    ) -> ChallengeSourceSnapshot {
        let active = fetchActiveRecords(modelContext: modelContext, now: now)
        let unclaimed = fetchUnclaimedRewardRecords(modelContext: modelContext)
        let history = includeHistory ? fetchRecentHistoryRecords(modelContext: modelContext, now: now) : []

        return ChallengeSourceSnapshot(
            activeRecords: active,
            unclaimedRecords: unclaimed,
            historyRecords: history,
            enabledKinds: enabledKinds,
            now: now,
            dashboardHistoryLimit: dashboardHistoryLimit
        )
    }

    static func fetchVisibleActiveRecords(
        modelContext: ModelContext,
        enabledKinds: [ChallengeKind],
        now: Date = Date()
    ) -> [ChallengeRecord] {
        makeSnapshot(
            modelContext: modelContext,
            enabledKinds: enabledKinds,
            now: now,
            includeHistory: false
        ).activeRecords
    }

    static func fetchRecord(id: UUID, modelContext: ModelContext) -> ChallengeRecord? {
        let value = id
        let descriptor = FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate<ChallengeRecord> { $0.id == value }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }
}

private extension ChallengeSourceStore {
    static func fetchActiveRecords(modelContext: ModelContext, now: Date) -> [ChallengeRecord] {
        let nowValue = now
        let descriptor = FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate<ChallengeRecord> {
                $0.periodStart <= nowValue && $0.periodEnd > nowValue
            },
            sortBy: [
                SortDescriptor(\ChallengeRecord.kindRawValue, order: .forward),
                SortDescriptor(\ChallengeRecord.periodStart, order: .reverse),
                SortDescriptor(\ChallengeRecord.createdAt, order: .forward)
            ]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    static func fetchUnclaimedRewardRecords(modelContext: ModelContext) -> [ChallengeRecord] {
        let descriptor = FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate<ChallengeRecord> {
                $0.completedAt != nil && $0.acknowledgedAt == nil
            },
            sortBy: [
                SortDescriptor(\ChallengeRecord.periodEnd, order: .reverse),
                SortDescriptor(\ChallengeRecord.kindRawValue, order: .forward),
                SortDescriptor(\ChallengeRecord.createdAt, order: .forward)
            ]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    static func fetchRecentHistoryRecords(modelContext: ModelContext, now: Date) -> [ChallengeRecord] {
        ChallengeCadence.supportedKinds.flatMap { kind -> [ChallengeRecord] in
            fetchRecentHistoryRecords(
                kind: kind,
                limit: ChallengeCadence.definition(for: kind).historyLimit,
                modelContext: modelContext,
                now: now
            )
        }
    }

    static func fetchRecentHistoryRecords(
        kind: ChallengeKind,
        limit: Int,
        modelContext: ModelContext,
        now: Date
    ) -> [ChallengeRecord] {
        guard limit > 0 else { return [] }

        let kindRaw = kind.rawValue
        let nowValue = now
        var descriptor = FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate<ChallengeRecord> {
                $0.kindRawValue == kindRaw && $0.periodEnd <= nowValue
            },
            sortBy: [
                SortDescriptor(\ChallengeRecord.periodEnd, order: .reverse),
                SortDescriptor(\ChallengeRecord.periodStart, order: .reverse),
                SortDescriptor(\ChallengeRecord.createdAt, order: .forward)
            ]
        )
        descriptor.fetchLimit = max(1, limit * 4)
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return Array(ChallengeDuplicateResolver.deduplicatedRecords(records).prefix(limit))
    }
}

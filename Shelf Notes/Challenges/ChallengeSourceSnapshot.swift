//
//  ChallengeSourceSnapshot.swift
//  Shelf Notes
//
//  Bounded challenge source state for UI builders.
//

import Foundation

struct ChallengeSourceSnapshot {
    static let empty = ChallengeSourceSnapshot(
        activeRecords: [],
        unclaimedRecords: [],
        historyRecords: [],
        dashboardRecords: [],
        progressRecords: []
    )

    let activeRecords: [ChallengeRecord]
    let unclaimedRecords: [ChallengeRecord]
    let historyRecords: [ChallengeRecord]
    let dashboardRecords: [ChallengeRecord]
    let progressRecords: [ChallengeRecord]

    var isEmpty: Bool {
        dashboardRecords.isEmpty
    }

    @MainActor var signature: ChallengeSummarySignature {
        ChallengeSummarySignature(challenges: dashboardRecords)
    }

    private init(
        activeRecords: [ChallengeRecord],
        unclaimedRecords: [ChallengeRecord],
        historyRecords: [ChallengeRecord],
        dashboardRecords: [ChallengeRecord],
        progressRecords: [ChallengeRecord]
    ) {
        self.activeRecords = activeRecords
        self.unclaimedRecords = unclaimedRecords
        self.historyRecords = historyRecords
        self.dashboardRecords = dashboardRecords
        self.progressRecords = progressRecords
    }

    @MainActor
    init(
        activeRecords: [ChallengeRecord],
        unclaimedRecords: [ChallengeRecord],
        historyRecords: [ChallengeRecord],
        enabledKinds: [ChallengeKind],
        now: Date = Date(),
        dashboardHistoryLimit: Int = 12
    ) {
        let normalizedKinds = ChallengePreferences.normalizedKinds(enabledKinds)
        let enabledKindSet = Set(normalizedKinds)

        let dedupedActive = Self.visibleActiveRecords(
            activeRecords,
            enabledKindSet: enabledKindSet,
            now: now
        )
        let dedupedUnclaimed = Self.unclaimedRewardRecords(unclaimedRecords)
        let dedupedHistory = Self.recentHistoryRecords(
            historyRecords,
            now: now
        )
        let progressHistory = Array(Self.globallySortedHistory(dedupedHistory).prefix(max(0, dashboardHistoryLimit)))

        self.activeRecords = dedupedActive
        self.unclaimedRecords = dedupedUnclaimed
        self.historyRecords = dedupedHistory
        self.dashboardRecords = Self.uniqueRecords(dedupedActive + dedupedUnclaimed + dedupedHistory)
        self.progressRecords = Self.uniqueRecords(dedupedActive + dedupedUnclaimed + progressHistory)
    }

    @MainActor func record(withID id: UUID) -> ChallengeRecord? {
        dashboardRecords.first { $0.id == id }
    }

    @MainActor
    static func make(
        records: [ChallengeRecord],
        enabledKinds: [ChallengeKind],
        now: Date = Date(),
        dashboardHistoryLimit: Int = 12,
        historyLimits: [ChallengeKind: Int]? = nil
    ) -> ChallengeSourceSnapshot {
        let deduped = ChallengeDuplicateResolver.deduplicatedRecords(records)
        let active = deduped.filter { $0.periodStart <= now && $0.periodEnd > now }
        let unclaimed = deduped.filter { $0.isCompleted && !$0.isClaimed }
        let history = boundedHistoryRecords(
            from: deduped,
            now: now,
            historyLimits: historyLimits ?? defaultHistoryLimits
        )

        return ChallengeSourceSnapshot(
            activeRecords: active,
            unclaimedRecords: unclaimed,
            historyRecords: history,
            enabledKinds: enabledKinds,
            now: now,
            dashboardHistoryLimit: dashboardHistoryLimit
        )
    }
}

@MainActor
extension ChallengeSourceSnapshot {
    static let defaultHistoryLimits: [ChallengeKind: Int] = Dictionary(
        uniqueKeysWithValues: ChallengeCadence.supportedKinds.map { kind in
            (kind, ChallengeCadence.definition(for: kind).historyLimit)
        }
    )

    private static func visibleActiveRecords(
        _ records: [ChallengeRecord],
        enabledKindSet: Set<ChallengeKind>,
        now: Date
    ) -> [ChallengeRecord] {
        let visible = records.filter { record in
            record.periodStart <= now && record.periodEnd > now &&
            (enabledKindSet.contains(record.kind) || (record.isCompleted && !record.isClaimed))
        }
        return uniqueRecords(sortedActiveRecords(ChallengeDuplicateResolver.deduplicatedRecords(visible)))
    }

    private static func unclaimedRewardRecords(_ records: [ChallengeRecord]) -> [ChallengeRecord] {
        let rewards = records.filter { $0.isCompleted && !$0.isClaimed }
        return uniqueRecords(sortedRewardRecords(ChallengeDuplicateResolver.deduplicatedRecords(rewards)))
    }

    private static func recentHistoryRecords(
        _ records: [ChallengeRecord],
        now: Date
    ) -> [ChallengeRecord] {
        let history = records.filter { $0.periodEnd <= now }
        return uniqueRecords(ChallengeDuplicateResolver.deduplicatedRecords(history))
    }

    private static func boundedHistoryRecords(
        from records: [ChallengeRecord],
        now: Date,
        historyLimits: [ChallengeKind: Int]
    ) -> [ChallengeRecord] {
        ChallengeCadence.supportedKinds.flatMap { kind -> [ChallengeRecord] in
            let limit = max(0, historyLimits[kind] ?? ChallengeCadence.definition(for: kind).historyLimit)
            guard limit > 0 else { return [] }

            let recordsForKind = records
                .filter { $0.kind == kind && $0.periodEnd <= now }
                .sorted(by: historySort)
                .prefix(limit)
            return Array(recordsForKind)
        }
    }

    private static func globallySortedHistory(_ records: [ChallengeRecord]) -> [ChallengeRecord] {
        records.sorted(by: historySort)
    }

    private static func sortedActiveRecords(_ records: [ChallengeRecord]) -> [ChallengeRecord] {
        records.sorted { lhs, rhs in
            if lhs.kind != rhs.kind { return lhs.kind.sortOrder < rhs.kind.sortOrder }
            if lhs.periodEnd != rhs.periodEnd { return lhs.periodEnd < rhs.periodEnd }
            return lhs.periodStart < rhs.periodStart
        }
    }

    private static func sortedRewardRecords(_ records: [ChallengeRecord]) -> [ChallengeRecord] {
        records.sorted { lhs, rhs in
            if lhs.periodEnd != rhs.periodEnd { return lhs.periodEnd > rhs.periodEnd }
            if lhs.kind != rhs.kind { return lhs.kind.sortOrder < rhs.kind.sortOrder }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private static func historySort(_ lhs: ChallengeRecord, _ rhs: ChallengeRecord) -> Bool {
        if lhs.periodEnd != rhs.periodEnd { return lhs.periodEnd > rhs.periodEnd }
        if lhs.kind != rhs.kind { return lhs.kind.sortOrder < rhs.kind.sortOrder }
        if lhs.periodStart != rhs.periodStart { return lhs.periodStart > rhs.periodStart }
        return lhs.createdAt < rhs.createdAt
    }

    private static func uniqueRecords(_ records: [ChallengeRecord]) -> [ChallengeRecord] {
        var seen: Set<UUID> = []
        var result: [ChallengeRecord] = []
        result.reserveCapacity(records.count)

        for record in records where !seen.contains(record.id) {
            seen.insert(record.id)
            result.append(record)
        }

        return result
    }
}

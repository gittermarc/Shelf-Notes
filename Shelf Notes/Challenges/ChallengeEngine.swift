//
//  ChallengeEngine.swift
//  Shelf Notes
//
//  Generates current challenges and computes progress from existing data.
//

import Foundation
import SwiftData

nonisolated enum ChallengeEngine {

    // MARK: - Public API

    /// Ensures that active default challenge cadences exist for the current period.
    @MainActor
    static func ensureCurrentChallenges(modelContext: ModelContext) {
        repairDuplicateChallenges(modelContext: modelContext)

        let now = Date()
        let cadences = ensureCadenceInputs(
            kinds: ChallengeCadence.defaultGenerationKinds,
            now: now,
            modelContext: modelContext
        )
        guard let range = snapshotRange(for: cadences, now: now) else { return }

        let snapshot = buildSnapshot(range: range, modelContext: modelContext)
        let plans = ChallengeEngine.planEnsures(cadences: cadences, snapshot: snapshot)

        applyEnsurePlans(plans, modelContext: modelContext)
    }

    /// Refreshes completion timestamps for currently active challenges (if the user has reached the target).
    @MainActor
    static func refreshCompletionForActiveChallenges(modelContext: ModelContext) {
        repairDuplicateChallenges(modelContext: modelContext)

        let now = Date()
        let active = fetchActiveChallenges(now: now, modelContext: modelContext)
        guard !active.isEmpty else { return }

        let minStart = active.map(\.periodStart).min() ?? now
        let maxEnd = active.map(\.periodEnd).max() ?? now
        let snapshot = buildSnapshot(range: minStart..<maxEnd, modelContext: modelContext)

        let activeSnapshots = active.map { ChallengeRecordSnapshot(from: $0) }
        let completionPlans = planCompletions(now: now, active: activeSnapshots, snapshot: snapshot)
        applyCompletionPlans(completionPlans, modelContext: modelContext)
    }

    /// Preferred entry point for UI tasks.
    ///
    /// Fetching is done on the current actor (usually MainActor via `modelContext`).
    /// Heavy crunching is done off-main via value-only snapshots.
    @MainActor
    static func ensureCurrentChallengesAndRefreshCompletion(modelContext: ModelContext) async {
        repairDuplicateChallenges(modelContext: modelContext)

        let now = Date()
        let cadences = ensureCadenceInputs(
            kinds: ChallengeCadence.defaultGenerationKinds,
            now: now,
            modelContext: modelContext
        )
        let activeSnapshots = fetchActiveChallenges(now: now, modelContext: modelContext).map { ChallengeRecordSnapshot(from: $0) }

        let range = snapshotRange(for: cadences, active: activeSnapshots, now: now) ?? (now..<now)
        let snapshot = buildSnapshot(range: range, modelContext: modelContext)

        let plans = await Task.detached(priority: .utility) {
            let ensures = planEnsures(cadences: cadences, snapshot: snapshot)
            let completions = planCompletions(now: now, active: activeSnapshots, snapshot: snapshot)
            return (ensures, completions)
        }.value

        applyEnsurePlans(plans.0, modelContext: modelContext)
        applyCompletionPlans(plans.1, modelContext: modelContext)
    }

    /// Computes progress for multiple challenges efficiently.
    ///
    /// This fetches a single snapshot spanning all provided periods and crunches the results off-main.
    @MainActor
    static func computeProgressMap(for challenges: [ChallengeRecord], modelContext: ModelContext) async -> [UUID: ChallengeProgress] {
        guard !challenges.isEmpty else { return [:] }

        let minStart = challenges.map(\.periodStart).min() ?? Date()
        let maxEnd = challenges.map(\.periodEnd).max() ?? Date()

        let snapshot = buildSnapshot(range: minStart..<maxEnd, modelContext: modelContext)
        let challengeSnapshots = challenges.map { ChallengeRecordSnapshot(from: $0) }

        return await Task.detached(priority: .utility) {
            var map: [UUID: ChallengeProgress] = [:]
            map.reserveCapacity(challengeSnapshots.count)

            for ch in challengeSnapshots {
                map[ch.id] = computeProgress(metric: ch.metric, window: ch.periodStart..<ch.periodEnd, snapshot: snapshot)
            }

            return map
        }.value
    }

    /// Reroll a challenge (max 1 per period). Keeps the period, swaps the metric + recalculates the target.
    @MainActor
    static func reroll(_ challenge: ChallengeRecord, modelContext: ModelContext) {
        guard challenge.canReroll else { return }

        let kind = challenge.kind
        let periodStart = challenge.periodStart
        let periodEnd = challenge.periodEnd

        let baselineStart = ChallengeCadence.baselineStart(
            for: kind,
            baselineEnd: periodStart,
            calendar: calendar()
        )
        let snapshot = buildSnapshot(range: baselineStart..<periodEnd, modelContext: modelContext)
        let recentMetrics = fetchRecentChallengeSnapshots(
            kind: kind,
            before: periodStart,
            limit: 3,
            modelContext: modelContext
        ).map(\.metric)
        let generated = rerollReplacement(
            kind: kind,
            current: challenge.metric,
            periodStart: periodStart,
            periodEnd: periodEnd,
            snapshot: snapshot,
            challengeID: challenge.id,
            rerollsUsed: challenge.rerollsUsed,
            recentMetrics: recentMetrics
        )

        challenge.metric = generated.metric
        challenge.title = generated.title
        challenge.detail = generated.detail
        challenge.targetValue = generated.targetValue
        challenge.completedAt = nil
        challenge.acknowledgedAt = nil

        challenge.rerollsUsed += 1
        challenge.rerolledAt = Date()

        _ = modelContext.saveWithDiagnostics()
    }

    /// Marks a completed challenge as acknowledged ("claimed").
    @MainActor
    static func claim(_ challenge: ChallengeRecord, modelContext: ModelContext) {
        guard challenge.isCompleted, !challenge.isClaimed else { return }
        challenge.acknowledgedAt = Date()
        _ = modelContext.saveWithDiagnostics()
    }

    /// Computes progress for a challenge.
    ///
    /// Returns a value in the unit of the challenge metric (minutes, days, sessions, pages, books).
    @MainActor
    static func computeProgress(for challenge: ChallengeRecord, modelContext: ModelContext) -> ChallengeProgress {
        let windowStart = challenge.periodStart
        let windowEnd = challenge.periodEnd

        let snapshot = buildSnapshot(range: windowStart..<windowEnd, modelContext: modelContext)
        return computeProgress(metric: challenge.metric, window: windowStart..<windowEnd, snapshot: snapshot)
    }

    // MARK: - Types

    struct ChallengeProgress: Equatable, Sendable {
        let value: Int
        let unitSuffix: String

        func fraction(target: Int) -> Double {
            guard target > 0 else { return 0 }
            return min(1.0, max(0.0, Double(value) / Double(target)))
        }

        func valueText(target: Int) -> String {
            if target > 0 {
                return "\(value)/\(target) \(unitSuffix)"
            }
            return "\(value) \(unitSuffix)"
        }

        func remainingText(target: Int) -> String? {
            guard target > 0 else { return nil }
            let remaining = max(0, target - value)
            guard remaining > 0 else { return nil }
            return "Noch \(remaining) \(unitSuffix)"
        }
    }

    // MARK: - Internal: apply plans

    @MainActor
    private static func applyEnsurePlans(_ plans: [EnsurePlan], modelContext: ModelContext) {
        guard !plans.isEmpty else { return }

        var changed = false

        for p in plans {
            let existing = fetchChallenges(
                kind: p.kind,
                periodStart: p.periodStart,
                periodEnd: p.periodEnd,
                modelContext: modelContext
            )

            if !existing.isEmpty {
                let deletedCount = ChallengeDuplicateResolver.deleteDuplicates(in: existing, modelContext: modelContext)
                changed = changed || deletedCount > 0
                continue
            }

            let record = ChallengeRecord(
                kind: p.kind,
                metric: p.metric,
                periodStart: p.periodStart,
                periodEnd: p.periodEnd,
                title: p.title,
                detail: p.detail,
                targetValue: p.targetValue
            )

            modelContext.insert(record)
            changed = true
        }

        if changed {
            _ = modelContext.saveWithDiagnostics()
        }
    }

    @MainActor
    private static func applyCompletionPlans(_ plans: [CompletionPlan], modelContext: ModelContext) {
        guard !plans.isEmpty else { return }

        var changed = false

        for p in plans {
            guard let record = fetchChallengeByID(p.challengeID, modelContext: modelContext) else { continue }
            if record.completedAt == nil {
                record.completedAt = p.completedAt
                changed = true
            }
        }

        if changed {
            _ = modelContext.saveWithDiagnostics()
        }
    }

    // MARK: - Internal: fetching

    @MainActor
    @discardableResult
    private static func repairDuplicateChallenges(modelContext: ModelContext) -> Bool {
        let records = fetchAllChallenges(modelContext: modelContext)
        let deletedCount = ChallengeDuplicateResolver.deleteDuplicates(in: records, modelContext: modelContext)
        guard deletedCount > 0 else { return false }

        _ = modelContext.saveWithDiagnostics()
        return true
    }

    @MainActor
    private static func fetchChallenges(
        kind: ChallengeKind,
        periodStart: Date,
        periodEnd: Date,
        modelContext: ModelContext
    ) -> [ChallengeRecord] {
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

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    @MainActor
    private static func fetchAllChallenges(modelContext: ModelContext) -> [ChallengeRecord] {
        let descriptor = FetchDescriptor<ChallengeRecord>(
            sortBy: [
                SortDescriptor(\ChallengeRecord.periodStart, order: .forward),
                SortDescriptor(\ChallengeRecord.periodEnd, order: .forward),
                SortDescriptor(\ChallengeRecord.kindRawValue, order: .forward),
                SortDescriptor(\ChallengeRecord.createdAt, order: .forward)
            ]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    @MainActor
    private static func fetchChallengeByID(_ id: UUID, modelContext: ModelContext) -> ChallengeRecord? {
        let value = id
        let descriptor = FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate<ChallengeRecord> { $0.id == value }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    @MainActor
    private static func fetchActiveChallenges(now: Date, modelContext: ModelContext) -> [ChallengeRecord] {
        let nowVal = now
        let descriptor = FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate<ChallengeRecord> { $0.periodStart <= nowVal && $0.periodEnd > nowVal },
            sortBy: [SortDescriptor(\ChallengeRecord.periodStart, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Period helpers

    private static func calendar() -> Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }

    static func periodBounds(kind: ChallengeKind, now: Date) -> PeriodBounds {
        ChallengeCadence.periodBounds(for: kind, now: now, calendar: calendar())
    }

    @MainActor
    private static func ensureCadenceInputs(
        kinds: [ChallengeKind],
        now: Date,
        modelContext: ModelContext
    ) -> [EnsureCadenceInput] {
        kinds.filter(\.isKnownCadence).map { kind in
            let period = periodBounds(kind: kind, now: now)
            return EnsureCadenceInput(
                kind: kind,
                period: period,
                existing: fetchChallengeSnapshot(
                    kind: kind,
                    periodStart: period.start,
                    periodEnd: period.end,
                    modelContext: modelContext
                ),
                recent: fetchRecentChallengeSnapshots(
                    kind: kind,
                    before: period.start,
                    limit: 3,
                    modelContext: modelContext
                )
            )
        }
    }

    private static func snapshotRange(
        for cadences: [EnsureCadenceInput],
        now: Date
    ) -> Range<Date>? {
        snapshotRange(for: cadences, active: [], now: now)
    }

    private static func snapshotRange(
        for cadences: [EnsureCadenceInput],
        active: [ChallengeRecordSnapshot],
        now: Date
    ) -> Range<Date>? {
        guard !cadences.isEmpty || !active.isEmpty else { return nil }

        let cal = calendar()
        let cadenceStarts = cadences.map { input in
            ChallengeCadence.baselineStart(
                for: input.kind,
                baselineEnd: input.period.start,
                calendar: cal
            )
        }
        let activeStarts = active.map(\.periodStart)
        let ends = cadences.map { $0.period.end } + active.map(\.periodEnd)

        let earliest = (cadenceStarts + activeStarts).min() ?? now
        let latest = ends.max() ?? now
        return earliest..<latest
    }

    // MARK: - Notes
    // Heavy aggregation and generation logic was moved into value-only snapshots.
    // See: ChallengeEngine+Snapshot.swift and ChallengeEngine+Compute.swift.
}

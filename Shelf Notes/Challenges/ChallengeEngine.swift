//
//  ChallengeEngine.swift
//  Shelf Notes
//
//  Generates Weekly/Monthly challenges and computes progress from existing data.
//

import Foundation
import SwiftData

nonisolated enum ChallengeEngine {

    // MARK: - Public API

    /// Ensures that there is an active weekly + monthly challenge for the current period.
    @MainActor
    static func ensureCurrentChallenges(modelContext: ModelContext) {
        let now = Date()
        let weekly = periodBounds(kind: .weekly, now: now)
        let monthly = periodBounds(kind: .monthly, now: now)

        let earliest = min(
            weekly.start.addingTimeInterval(TimeInterval(-28 * 24 * 60 * 60)),
            monthly.start.addingTimeInterval(TimeInterval(-90 * 24 * 60 * 60))
        )
        let latest = max(weekly.end, monthly.end)

        let snapshot = buildSnapshot(range: earliest..<latest, modelContext: modelContext)

        let plans = ChallengeEngine.planEnsures(
            weekly: weekly,
            monthly: monthly,
            existingWeekly: fetchChallengeSnapshot(kind: .weekly, periodStart: weekly.start, modelContext: modelContext),
            existingMonthly: fetchChallengeSnapshot(kind: .monthly, periodStart: monthly.start, modelContext: modelContext),
            snapshot: snapshot
        )

        applyEnsurePlans(plans, modelContext: modelContext)
    }

    /// Refreshes completion timestamps for currently active challenges (if the user has reached the target).
    @MainActor
    static func refreshCompletionForActiveChallenges(modelContext: ModelContext) {
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
        let now = Date()
        let weekly = periodBounds(kind: .weekly, now: now)
        let monthly = periodBounds(kind: .monthly, now: now)

        let earliest = min(
            weekly.start.addingTimeInterval(TimeInterval(-28 * 24 * 60 * 60)),
            monthly.start.addingTimeInterval(TimeInterval(-90 * 24 * 60 * 60))
        )
        let latest = max(weekly.end, monthly.end)

        let snapshot = buildSnapshot(range: earliest..<latest, modelContext: modelContext)
        let existingWeekly = fetchChallengeSnapshot(kind: .weekly, periodStart: weekly.start, modelContext: modelContext)
        let existingMonthly = fetchChallengeSnapshot(kind: .monthly, periodStart: monthly.start, modelContext: modelContext)
        let activeSnapshots = fetchActiveChallenges(now: now, modelContext: modelContext).map { ChallengeRecordSnapshot(from: $0) }

        let plans = await Task.detached(priority: .utility) {
            let ensures = planEnsures(
                weekly: weekly,
                monthly: monthly,
                existingWeekly: existingWeekly,
                existingMonthly: existingMonthly,
                snapshot: snapshot
            )
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

        let daysBack = (kind == .weekly) ? 28 : 90
        let baselineStart = calendar().date(byAdding: .day, value: -daysBack, to: periodStart)
            ?? periodStart.addingTimeInterval(TimeInterval(-daysBack * 24 * 60 * 60))
        let snapshot = buildSnapshot(range: baselineStart..<periodEnd, modelContext: modelContext)
        let generated = rerollReplacement(
            kind: kind,
            current: challenge.metric,
            periodStart: periodStart,
            periodEnd: periodEnd,
            snapshot: snapshot,
            challengeID: challenge.id,
            rerollsUsed: challenge.rerollsUsed
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

        for p in plans {
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
        }

        _ = modelContext.saveWithDiagnostics()
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
    private static func fetchChallenge(kind: ChallengeKind, periodStart: Date, modelContext: ModelContext) -> ChallengeRecord? {
        let kindRaw = kind.rawValue
        let start = periodStart

        let descriptor = FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate<ChallengeRecord> { $0.kindRawValue == kindRaw && $0.periodStart == start }
        )

        return (try? modelContext.fetch(descriptor))?.first
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

    private static func periodBounds(kind: ChallengeKind, now: Date) -> PeriodBounds {
        let cal = calendar()

        switch kind {
        case .weekly:
            let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? cal.startOfDay(for: now)
            let start = cal.startOfDay(for: weekStart)
            let end = cal.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 24 * 60 * 60)
            return PeriodBounds(start: start, end: end)

        case .monthly:
            let comps = cal.dateComponents([.year, .month], from: now)
            let monthStart = cal.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)) ?? cal.startOfDay(for: now)
            let start = cal.startOfDay(for: monthStart)
            let end = cal.date(byAdding: .month, value: 1, to: start) ?? start.addingTimeInterval(30 * 24 * 60 * 60)
            return PeriodBounds(start: start, end: end)
        }
    }

    // MARK: - Notes
    // Heavy aggregation and generation logic was moved into value-only snapshots.
    // See: ChallengeEngine+Snapshot.swift and ChallengeEngine+Compute.swift.
}

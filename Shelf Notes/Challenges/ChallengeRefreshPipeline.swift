//
//  ChallengeRefreshPipeline.swift
//  Shelf Notes
//
//  Value-only refresh planning for challenge updates after reading-session mutations.
//

import Foundation
import SwiftData

nonisolated enum ChallengeRefreshPipeline {
    struct Input: Sendable {
        let now: Date
        let cadenceInputs: [ChallengeEngine.EnsureCadenceInput]
        let completionSnapshots: [ChallengeEngine.ChallengeRecordSnapshot]
        let visibleProgressSnapshots: [ChallengeEngine.ChallengeRecordSnapshot]
        let snapshot: ChallengeEngine.Snapshot
        let savedSessionPayloads: [ChallengeSessionMutationPayload]

        init(
            now: Date,
            cadenceInputs: [ChallengeEngine.EnsureCadenceInput],
            completionSnapshots: [ChallengeEngine.ChallengeRecordSnapshot],
            visibleProgressSnapshots: [ChallengeEngine.ChallengeRecordSnapshot],
            snapshot: ChallengeEngine.Snapshot,
            savedSessionPayloads: [ChallengeSessionMutationPayload]
        ) {
            self.now = now
            self.cadenceInputs = cadenceInputs
            self.completionSnapshots = completionSnapshots
            self.visibleProgressSnapshots = visibleProgressSnapshots
            self.snapshot = snapshot
            self.savedSessionPayloads = savedSessionPayloads
        }
    }

    struct Output: Sendable {
        let ensurePlans: [ChallengeEngine.EnsurePlan]
        let completionPlans: [ChallengeEngine.CompletionPlan]
        let progressByID: [UUID: ChallengeEngine.ChallengeProgress]
        let progressSnapshots: [ChallengeEngine.ChallengeRecordSnapshot]
        let savedSessionImpacts: [ChallengeSessionImpact]

        static let empty = Output(
            ensurePlans: [],
            completionPlans: [],
            progressByID: [:],
            progressSnapshots: [],
            savedSessionImpacts: []
        )
    }

    @MainActor
    static func makeInput(
        modelContext: ModelContext,
        enabledKinds: [ChallengeKind],
        now: Date,
        savedSessionPayloads: [ChallengeSessionMutationPayload]
    ) -> Input {
        let cadenceInputs = makeCadenceInputs(
            enabledKinds: enabledKinds,
            now: now,
            modelContext: modelContext
        )
        let completionSnapshots = ChallengeEngine.fetchDeduplicatedActiveChallengeSnapshots(
            now: now,
            modelContext: modelContext
        )
        let visibleProgressSnapshots = ChallengeSourceStore.fetchVisibleActiveRecords(
            modelContext: modelContext,
            enabledKinds: enabledKinds,
            now: now
        ).map { ChallengeEngine.ChallengeRecordSnapshot(from: $0) }
        let range = snapshotRange(
            cadenceInputs: cadenceInputs,
            activeSnapshots: uniqueSnapshots(completionSnapshots + visibleProgressSnapshots),
            now: now
        ) ?? (now..<now)
        let snapshot = ChallengeEngine.buildSnapshot(
            range: range,
            modelContext: modelContext
        )

        return Input(
            now: now,
            cadenceInputs: cadenceInputs,
            completionSnapshots: completionSnapshots,
            visibleProgressSnapshots: visibleProgressSnapshots,
            snapshot: snapshot,
            savedSessionPayloads: savedSessionPayloads
        )
    }

    static func makeOutput(input: Input) -> Output {
        let ensurePlans = ChallengeEngine.planEnsures(
            cadences: input.cadenceInputs,
            snapshot: input.snapshot
        )
        let completionPlans = ChallengeEngine.planCompletions(
            now: input.now,
            active: input.completionSnapshots,
            snapshot: input.snapshot
        )
        let progressSnapshots = makeProgressSnapshots(
            visibleActiveSnapshots: input.visibleProgressSnapshots,
            ensurePlans: ensurePlans,
            now: input.now
        )
        let progressByID = computeProgressMap(
            for: progressSnapshots,
            snapshot: input.snapshot
        )
        let impacts = makeSavedSessionImpacts(
            payloads: input.savedSessionPayloads,
            progressSnapshots: progressSnapshots,
            progressByID: progressByID,
            now: input.now
        )

        return Output(
            ensurePlans: ensurePlans,
            completionPlans: completionPlans,
            progressByID: progressByID,
            progressSnapshots: progressSnapshots,
            savedSessionImpacts: impacts
        )
    }

    static func snapshotRange(
        cadenceInputs: [ChallengeEngine.EnsureCadenceInput],
        activeSnapshots: [ChallengeEngine.ChallengeRecordSnapshot],
        now: Date,
        calendar: Calendar = ChallengeCadence.calendar()
    ) -> Range<Date>? {
        guard !cadenceInputs.isEmpty || !activeSnapshots.isEmpty else { return nil }

        let cadenceStarts = cadenceInputs.map { input in
            ChallengeCadence.baselineStart(
                for: input.kind,
                baselineEnd: input.period.start,
                calendar: calendar
            )
        }
        let activeStarts = activeSnapshots.map(\.periodStart)
        let periodEnds = cadenceInputs.map { $0.period.end } + activeSnapshots.map(\.periodEnd)

        let earliest = (cadenceStarts + activeStarts).min() ?? now
        let latest = periodEnds.max() ?? now
        guard latest > earliest else { return now..<now }
        return earliest..<latest
    }

    static func computeProgressMap(
        for challenges: [ChallengeEngine.ChallengeRecordSnapshot],
        snapshot: ChallengeEngine.Snapshot
    ) -> [UUID: ChallengeEngine.ChallengeProgress] {
        guard !challenges.isEmpty else { return [:] }

        var map: [UUID: ChallengeEngine.ChallengeProgress] = [:]
        map.reserveCapacity(challenges.count)

        for challenge in challenges {
            map[challenge.id] = ChallengeEngine.computeProgress(
                metric: challenge.metric,
                window: challenge.periodStart..<challenge.periodEnd,
                snapshot: snapshot
            )
        }

        return map
    }
}

private nonisolated extension ChallengeRefreshPipeline {
    @MainActor
    static func makeCadenceInputs(
        enabledKinds: [ChallengeKind],
        now: Date,
        modelContext: ModelContext
    ) -> [ChallengeEngine.EnsureCadenceInput] {
        ChallengePreferences.normalizedKinds(enabledKinds).filter(\.isKnownCadence).map { kind in
            let period = ChallengeEngine.periodBounds(kind: kind, now: now)
            return ChallengeEngine.EnsureCadenceInput(
                kind: kind,
                period: period,
                existing: ChallengeEngine.fetchChallengeSnapshot(
                    kind: kind,
                    periodStart: period.start,
                    periodEnd: period.end,
                    modelContext: modelContext
                ),
                recent: ChallengeEngine.fetchRecentChallengeSnapshots(
                    kind: kind,
                    before: period.start,
                    limit: 3,
                    modelContext: modelContext
                )
            )
        }
    }

    static func makeProgressSnapshots(
        visibleActiveSnapshots: [ChallengeEngine.ChallengeRecordSnapshot],
        ensurePlans: [ChallengeEngine.EnsurePlan],
        now: Date
    ) -> [ChallengeEngine.ChallengeRecordSnapshot] {
        let ensuredActiveSnapshots = ensurePlans.compactMap { plan -> ChallengeEngine.ChallengeRecordSnapshot? in
            guard plan.periodStart <= now && plan.periodEnd > now else { return nil }
            return ChallengeEngine.ChallengeRecordSnapshot(from: plan)
        }
        return uniqueSnapshots(visibleActiveSnapshots + ensuredActiveSnapshots)
    }

    static func makeSavedSessionImpacts(
        payloads: [ChallengeSessionMutationPayload],
        progressSnapshots: [ChallengeEngine.ChallengeRecordSnapshot],
        progressByID: [UUID: ChallengeEngine.ChallengeProgress],
        now: Date
    ) -> [ChallengeSessionImpact] {
        payloads.compactMap { payload in
            guard let sessionSnapshot = payload.sessionSnapshot else { return nil }
            let contribution = ChallengeSessionContribution(
                bookID: sessionSnapshot.bookID,
                startedAt: sessionSnapshot.startedAt,
                endedAt: sessionSnapshot.endedAt,
                durationSeconds: sessionSnapshot.durationSeconds,
                pagesRead: sessionSnapshot.pagesRead,
                didMarkBookFinished: payload.didMarkBookFinished,
                hasNote: sessionSnapshot.hasNote
            )
            return ChallengeSessionImpactBuilder.makeSavedSessionImpact(
                challengeSnapshots: progressSnapshots,
                progressAfterByID: progressByID,
                contribution: contribution,
                now: now
            )
        }
    }

    static func uniqueSnapshots(
        _ snapshots: [ChallengeEngine.ChallengeRecordSnapshot]
    ) -> [ChallengeEngine.ChallengeRecordSnapshot] {
        var seen: Set<UUID> = []
        var result: [ChallengeEngine.ChallengeRecordSnapshot] = []
        result.reserveCapacity(snapshots.count)

        for snapshot in snapshots where !seen.contains(snapshot.id) {
            seen.insert(snapshot.id)
            result.append(snapshot)
        }

        return result.sorted { lhs, rhs in
            if lhs.kind != rhs.kind { return lhs.kind.sortOrder < rhs.kind.sortOrder }
            if lhs.periodEnd != rhs.periodEnd { return lhs.periodEnd < rhs.periodEnd }
            if lhs.periodStart != rhs.periodStart { return lhs.periodStart < rhs.periodStart }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}

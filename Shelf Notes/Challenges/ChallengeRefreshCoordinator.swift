//
//  ChallengeRefreshCoordinator.swift
//  Shelf Notes
//
//  Central entry points for challenge refreshes triggered by reading actions.
//

import Foundation
import SwiftData

extension Notification.Name {
    static let challengeSessionImpactDidChange = Notification.Name("ShelfNotesChallengeSessionImpactDidChange")
}

enum ChallengeSessionImpactNotifier {
    static func post(_ impact: ChallengeSessionImpact) {
        NotificationCenter.default.post(name: .challengeSessionImpactDidChange, object: impact)
    }
}

@MainActor
enum ChallengeRefreshCoordinator {
    private static let coalescedRefreshDebounceNanoseconds: UInt64 = 220_000_000
    private static var pendingBatch = ChallengeRefreshBatch()
    private static var pendingModelContext: ModelContext?
    private static var scheduledCoalescedRefreshTask: Task<Void, Never>?

    static func prepareCurrentChallenges(
        modelContext: ModelContext,
        enabledKinds: [ChallengeKind] = ChallengePreferencesStore.load().enabledKinds
    ) async {
        await PerformanceSignposter.measureAsync("Challenge Refresh") {
            await ChallengeEngine.ensureCurrentChallengesAndRefreshCompletion(
                modelContext: modelContext,
                kinds: enabledKinds
            )
        }
    }

    static func computeProgressMap(
        for challenges: [ChallengeRecord],
        modelContext: ModelContext
    ) async -> [UUID: ChallengeEngine.ChallengeProgress] {
        await PerformanceSignposter.measureAsync("Challenge Progress Map") {
            await ChallengeEngine.computeProgressMap(for: challenges, modelContext: modelContext)
        }
    }

    static func refreshActiveProgress(modelContext: ModelContext) async -> [UUID: ChallengeEngine.ChallengeProgress] {
        let active = ChallengeSourceStore.fetchVisibleActiveRecords(
            modelContext: modelContext,
            enabledKinds: ChallengePreferencesStore.load().enabledKinds
        )
        return await computeProgressMap(for: active, modelContext: modelContext)
    }

    static func requestRefreshAfterReadingSessionSave(
        modelContext: ModelContext,
        mutation: SavedReadingSessionMutationResult
    ) {
        requestRefreshAfterReadingSessionSave(
            modelContext: modelContext,
            sessionSnapshot: mutation.sessionSnapshot,
            didMarkBookFinished: mutation.didMarkBookFinished
        )
    }

    static func requestRefreshAfterReadingSessionSave(
        modelContext: ModelContext,
        sessionSnapshot: SavedReadingSessionSnapshot,
        didMarkBookFinished: Bool
    ) {
        requestCoalescedRefresh(
            modelContext: modelContext,
            request: .readingSessionSaved(
                sessionSnapshot: sessionSnapshot,
                didMarkBookFinished: didMarkBookFinished
            )
        )
    }

    static func requestRefreshAfterReadingSessionMutation(modelContext: ModelContext) {
        requestCoalescedRefresh(
            modelContext: modelContext,
            request: .readingSessionChanged()
        )
    }

    static func requestRefreshAfterReadingSessionDelete(
        modelContext: ModelContext,
        sessionSnapshot: SavedReadingSessionSnapshot
    ) {
        requestCoalescedRefresh(
            modelContext: modelContext,
            request: .readingSessionDeleted(sessionSnapshot: sessionSnapshot)
        )
    }

    static func requestCoalescedRefresh(
        modelContext: ModelContext,
        request: ChallengeRefreshRequest
    ) {
        pendingModelContext = modelContext
        pendingBatch.append(request)
        schedulePendingCoalescedRefresh()
    }

    @discardableResult
    static func refreshAfterReadingSessionSave(
        modelContext: ModelContext,
        mutation: SavedReadingSessionMutationResult
    ) async -> ChallengeSessionImpact? {
        await refreshAfterReadingSessionSave(
            modelContext: modelContext,
            sessionSnapshot: mutation.sessionSnapshot,
            didMarkBookFinished: mutation.didMarkBookFinished
        )
    }

    @discardableResult
    static func refreshAfterReadingSessionSave(
        modelContext: ModelContext,
        bookID: UUID,
        session: ReadingSession,
        didMarkBookFinished: Bool
    ) async -> ChallengeSessionImpact? {
        await refreshAfterReadingSessionSave(
            modelContext: modelContext,
            sessionSnapshot: SavedReadingSessionSnapshot(bookID: bookID, session: session),
            didMarkBookFinished: didMarkBookFinished
        )
    }

    @discardableResult
    static func refreshAfterReadingSessionSave(
        modelContext: ModelContext,
        sessionSnapshot: SavedReadingSessionSnapshot,
        didMarkBookFinished: Bool
    ) async -> ChallengeSessionImpact? {
        await PerformanceSignposter.measureAsync("Challenge Session Save Refresh") {
            let batch = ChallengeRefreshBatch(
                requests: [
                    .readingSessionSaved(
                        sessionSnapshot: sessionSnapshot,
                        didMarkBookFinished: didMarkBookFinished
                    )
                ]
            )
            let impacts = await refreshAfterReadingSessionBatch(
                modelContext: modelContext,
                batch: batch
            )
            return impacts.first
        }
    }

    static func refreshAfterReadingSessionMutation(modelContext: ModelContext) async {
        await PerformanceSignposter.measureAsync("Challenge Session Mutation Refresh") {
            let batch = ChallengeRefreshBatch(requests: [.readingSessionChanged()])
            _ = await refreshAfterReadingSessionBatch(
                modelContext: modelContext,
                batch: batch
            )
        }
    }

    @discardableResult
    static func refreshAfterReadingSessionBatch(
        modelContext: ModelContext,
        batch: ChallengeRefreshBatch
    ) async -> [ChallengeSessionImpact] {
        await PerformanceSignposter.measureAsync("Challenge Session Batch Refresh") {
            guard !batch.isEmpty else { return [] }

            let enabledKinds = ChallengePreferencesStore.load().enabledKinds
            let now = Date()
            let input = ChallengeRefreshPipeline.makeInput(
                modelContext: modelContext,
                enabledKinds: enabledKinds,
                now: now,
                savedSessionPayloads: batch.savedSessionPayloads
            )
            let output = await Task.detached(priority: .utility) {
                ChallengeRefreshPipeline.makeOutput(input: input)
            }.value

            ChallengeEngine.applyRefreshPlans(
                ensurePlans: batch.requiresChallengePreparation ? output.ensurePlans : [],
                completionPlans: batch.requiresChallengePreparation ? output.completionPlans : [],
                modelContext: modelContext
            )

            let impacts = output.savedSessionImpacts

            if batch.postsReadingSessionChange {
                ReadingSessionChangeNotifier.post()
            }
            for impact in impacts {
                ChallengeSessionImpactNotifier.post(impact)
            }

            return impacts
        }
    }

    private static func schedulePendingCoalescedRefresh() {
        scheduledCoalescedRefreshTask?.cancel()
        scheduledCoalescedRefreshTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: coalescedRefreshDebounceNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await flushPendingCoalescedRefresh()
        }
    }

    private static func flushPendingCoalescedRefresh() async {
        guard let modelContext = pendingModelContext, !pendingBatch.isEmpty else {
            scheduledCoalescedRefreshTask = nil
            return
        }

        let batch = pendingBatch
        pendingBatch = ChallengeRefreshBatch()
        pendingModelContext = nil
        scheduledCoalescedRefreshTask = nil

        _ = await refreshAfterReadingSessionBatch(
            modelContext: modelContext,
            batch: batch
        )
    }
}

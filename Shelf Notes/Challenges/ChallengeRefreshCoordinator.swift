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
            let enabledKinds = ChallengePreferencesStore.load().enabledKinds
            await prepareCurrentChallenges(modelContext: modelContext, enabledKinds: enabledKinds)

            let active = ChallengeSourceStore.fetchVisibleActiveRecords(
                modelContext: modelContext,
                enabledKinds: enabledKinds
            )
            let progress = await computeProgressMap(for: active, modelContext: modelContext)
            let contribution = ChallengeSessionContribution(
                bookID: sessionSnapshot.bookID,
                startedAt: sessionSnapshot.startedAt,
                endedAt: sessionSnapshot.endedAt,
                durationSeconds: sessionSnapshot.durationSeconds,
                pagesRead: sessionSnapshot.pagesRead,
                didMarkBookFinished: didMarkBookFinished,
                hasNote: sessionSnapshot.hasNote
            )
            let impact = ChallengeSessionImpactBuilder.makeSavedSessionImpact(
                challenges: active,
                progressAfterByID: progress,
                contribution: contribution
            )

            ReadingSessionChangeNotifier.post()
            if let impact {
                ChallengeSessionImpactNotifier.post(impact)
            }

            return impact
        }
    }

    static func refreshAfterReadingSessionMutation(modelContext: ModelContext) async {
        await PerformanceSignposter.measureAsync("Challenge Session Mutation Refresh") {
            await prepareCurrentChallenges(modelContext: modelContext)
            ReadingSessionChangeNotifier.post()
        }
    }
}

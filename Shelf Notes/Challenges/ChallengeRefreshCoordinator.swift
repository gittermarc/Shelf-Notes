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
    static func prepareCurrentChallenges(modelContext: ModelContext) async {
        await ChallengeEngine.ensureCurrentChallengesAndRefreshCompletion(modelContext: modelContext)
    }

    static func computeProgressMap(
        for challenges: [ChallengeRecord],
        modelContext: ModelContext
    ) async -> [UUID: ChallengeEngine.ChallengeProgress] {
        await ChallengeEngine.computeProgressMap(for: challenges, modelContext: modelContext)
    }

    static func refreshActiveProgress(modelContext: ModelContext) async -> [UUID: ChallengeEngine.ChallengeProgress] {
        let active = fetchActiveChallenges(modelContext: modelContext)
        return await computeProgressMap(for: active, modelContext: modelContext)
    }

    @discardableResult
    static func refreshAfterReadingSessionSave(
        modelContext: ModelContext,
        bookID: UUID,
        session: ReadingSession,
        didMarkBookFinished: Bool
    ) async -> ChallengeSessionImpact? {
        await prepareCurrentChallenges(modelContext: modelContext)

        let active = fetchActiveChallenges(modelContext: modelContext)
        let progress = await computeProgressMap(for: active, modelContext: modelContext)
        let contribution = ChallengeSessionContribution(
            bookID: bookID,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            durationSeconds: session.durationSeconds,
            pagesRead: session.pagesRead,
            didMarkBookFinished: didMarkBookFinished,
            hasNote: !(session.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    static func refreshAfterReadingSessionMutation(modelContext: ModelContext) async {
        await prepareCurrentChallenges(modelContext: modelContext)
        ReadingSessionChangeNotifier.post()
    }

    private static func fetchActiveChallenges(
        modelContext: ModelContext,
        now: Date = Date()
    ) -> [ChallengeRecord] {
        let nowValue = now
        let descriptor = FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate<ChallengeRecord> { $0.periodStart <= nowValue && $0.periodEnd > nowValue },
            sortBy: [
                SortDescriptor(\ChallengeRecord.periodStart, order: .reverse),
                SortDescriptor(\ChallengeRecord.kindRawValue, order: .forward)
            ]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}

//
//  ChallengeSessionImpactBuilder.swift
//  Shelf Notes
//
//  Builds lightweight impact summaries for saved and pending reading sessions.
//

import Foundation

@MainActor
enum ChallengeSessionImpactBuilder {
    static func makeSavedSessionImpact(
        challenges: [ChallengeRecord],
        progressAfterByID: [UUID: ChallengeEngine.ChallengeProgress],
        contribution: ChallengeSessionContribution,
        now: Date = Date()
    ) -> ChallengeSessionImpact? {
        makeImpact(
            challenges: challenges,
            progressByID: progressAfterByID,
            contribution: contribution,
            basis: .progressIncludesContribution,
            now: now
        )
    }

    static func makePendingSessionImpact(
        challenges: [ChallengeRecord],
        progressBeforeByID: [UUID: ChallengeEngine.ChallengeProgress],
        contribution: ChallengeSessionContribution,
        now: Date = Date()
    ) -> ChallengeSessionImpact? {
        makeImpact(
            challenges: challenges,
            progressByID: progressBeforeByID,
            contribution: contribution,
            basis: .progressExcludesContribution,
            now: now
        )
    }

    private enum ProgressBasis {
        case progressIncludesContribution
        case progressExcludesContribution
    }

    private static func makeImpact(
        challenges: [ChallengeRecord],
        progressByID: [UUID: ChallengeEngine.ChallengeProgress],
        contribution: ChallengeSessionContribution,
        basis: ProgressBasis,
        now: Date
    ) -> ChallengeSessionImpact? {
        let active = challenges
            .filter { $0.periodStart <= now && $0.periodEnd > now }
            .sorted { lhs, rhs in
                if lhs.kind != rhs.kind { return lhs.kind == .weekly }
                return lhs.periodEnd < rhs.periodEnd
            }

        guard !active.isEmpty else { return nil }

        let entries = active.compactMap { record in
            makeEntry(
                record: record,
                progress: progressByID[record.id],
                contribution: contribution,
                basis: basis
            )
        }

        guard !entries.isEmpty else { return nil }

        let didComplete = entries.contains(where: \.didComplete)
        let first = entries[0]
        let title = didComplete ? "Challenge geknackt" : "Session zählt für Challenges"
        let subtitle = didComplete
            ? "\(first.title): \(first.progressText)"
            : "\(first.contributionText) · \(first.title)"

        return ChallengeSessionImpact(
            id: UUID(),
            bookID: contribution.bookID,
            createdAt: now,
            title: title,
            subtitle: subtitle,
            entries: entries
        )
    }

    private static func makeEntry(
        record: ChallengeRecord,
        progress: ChallengeEngine.ChallengeProgress?,
        contribution: ChallengeSessionContribution,
        basis: ProgressBasis
    ) -> ChallengeSessionImpactEntry? {
        guard let progress else { return nil }

        let delta = contributionValue(record: record, contribution: contribution)
        guard delta > 0 else { return nil }

        let beforeValue: Int
        let afterValue: Int

        switch basis {
        case .progressIncludesContribution:
            afterValue = progress.value
            beforeValue = max(0, progress.value - delta)
        case .progressExcludesContribution:
            beforeValue = progress.value
            afterValue = progress.value + delta
        }

        let didComplete = beforeValue < record.targetValue && afterValue >= record.targetValue
        let projected = ChallengeEngine.ChallengeProgress(value: afterValue, unitSuffix: record.metric.unitSuffix)

        return ChallengeSessionImpactEntry(
            id: record.id,
            kind: record.kind,
            metric: record.metric,
            title: record.title,
            contributionText: "+\(delta) \(record.metric.unitSuffix)",
            progressText: projected.valueText(target: record.targetValue),
            didComplete: didComplete,
            progressFraction: projected.fraction(target: record.targetValue),
            systemImage: record.metric.systemImage
        )
    }

    private static func contributionValue(
        record: ChallengeRecord,
        contribution: ChallengeSessionContribution
    ) -> Int {
        let session = ChallengeEngine.SessionSnapshot(
            startedAt: contribution.startedAt,
            endedAt: contribution.endedAt,
            durationSeconds: contribution.durationSeconds,
            pagesRead: contribution.pagesRead
        )
        let finishedBookReadTo = contribution.didMarkBookFinished ? [contribution.endedAt] : []
        let snapshot = ChallengeEngine.Snapshot(
            sessions: [session],
            finishedBookReadTo: finishedBookReadTo
        )

        return ChallengeEngine.computeProgress(
            metric: record.metric,
            window: record.periodStart..<record.periodEnd,
            snapshot: snapshot
        ).value
    }
}

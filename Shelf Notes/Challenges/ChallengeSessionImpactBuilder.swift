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
                if lhs.kind != rhs.kind { return lhs.kind.sortOrder < rhs.kind.sortOrder }
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
        .sorted(by: sortEntries)

        guard !entries.isEmpty else { return nil }

        let didComplete = entries.contains(where: \.didComplete)
        let first = entries[0]
        let title = makeTitle(didComplete: didComplete, first: first)
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
            bookID: contribution.bookID,
            startedAt: contribution.startedAt,
            endedAt: contribution.endedAt,
            durationSeconds: contribution.durationSeconds,
            pagesRead: contribution.pagesRead,
            hasNote: contribution.hasNote
        )
        let finishedBooks: [ChallengeEngine.FinishedBookSnapshot] = contribution.didMarkBookFinished
            ? [ChallengeEngine.FinishedBookSnapshot(readTo: contribution.endedAt)]
            : []
        let snapshot = ChallengeEngine.Snapshot(
            sessions: [session],
            finishedBooks: finishedBooks
        )

        return ChallengeEngine.computeProgress(
            metric: record.metric,
            window: record.periodStart..<record.periodEnd,
            snapshot: snapshot
        ).value
    }

    private static func sortEntries(_ lhs: ChallengeSessionImpactEntry, _ rhs: ChallengeSessionImpactEntry) -> Bool {
        let lhsPriority = priority(for: lhs)
        let rhsPriority = priority(for: rhs)
        if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
        if lhs.kind != rhs.kind { return lhs.kind.sortOrder < rhs.kind.sortOrder }
        if lhs.progressFraction != rhs.progressFraction { return lhs.progressFraction > rhs.progressFraction }
        return lhs.title < rhs.title
    }

    private static func priority(for entry: ChallengeSessionImpactEntry) -> Int {
        if entry.didComplete { return 0 }
        if entry.kind == .daily && entry.progressFraction >= 0.60 { return 1 }
        if entry.kind == .weekly && entry.progressFraction >= 0.75 { return 2 }
        switch entry.kind {
        case .daily:
            return 3
        case .weekly:
            return 4
        case .monthly:
            return 5
        case .yearly:
            return 6
        case .unknown:
            return 7
        }
    }

    private static func makeTitle(didComplete: Bool, first: ChallengeSessionImpactEntry) -> String {
        if didComplete {
            if first.kind == .daily { return "Tagesmission geknackt" }
            if first.kind == .yearly { return "Jahresquest geknackt" }
            return "Challenge geknackt"
        }

        switch first.kind {
        case .daily:
            return "Zählt auf deine Tagesmission"
        case .yearly:
            return "Zahlt auf deine Jahresquest ein"
        case .weekly, .monthly, .unknown:
            return "Session zählt für Challenges"
        }
    }
}

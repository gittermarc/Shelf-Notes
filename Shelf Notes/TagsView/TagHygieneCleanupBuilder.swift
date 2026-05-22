import Foundation

enum TagHygieneCleanupBuilder {

    static func plan(
        for insight: TagHygieneInsight,
        snapshots: [TagsDashboardBookSnapshot]
    ) -> TagHygieneCleanupPlan? {
        switch insight.kind {
        case .formattingConflict:
            return formattingPlan(for: insight, snapshots: snapshots)
        case .duplicateCandidate:
            return duplicatePlan(for: insight, snapshots: snapshots)
        case .singleUseTags:
            return singleUseDeletePlan(for: insight, snapshots: snapshots)
        case .untaggedBooks:
            return nil
        }
    }

    private static func formattingPlan(
        for insight: TagHygieneInsight,
        snapshots: [TagsDashboardBookSnapshot]
    ) -> TagHygieneCleanupPlan? {
        guard let targetTag = normalizedPrimaryTag(from: insight) else { return nil }
        let sourceTags = sourceTags(from: insight, fallback: targetTag)
        let result = TagLibraryMutation.merge(
            sourceTags: sourceTags,
            into: targetTag,
            in: makeMutationSnapshots(from: snapshots)
        )

        guard result.hasChanges else { return nil }

        return TagHygieneCleanupPlan(
            kind: .normalizeFormatting,
            title: "Schreibweise bereinigen",
            detail: "Alle Varianten werden auf #\(targetTag) vereinheitlicht. Innere Sonderzeichen wie bei C# bleiben erhalten.",
            sourceTags: sourceTags,
            targetTag: targetTag,
            affectedBookIDs: result.changedBookIDs.sorted(by: uuidSort),
            result: result
        )
    }

    private static func duplicatePlan(
        for insight: TagHygieneInsight,
        snapshots: [TagsDashboardBookSnapshot]
    ) -> TagHygieneCleanupPlan? {
        guard let targetTag = normalizedPrimaryTag(from: insight) else { return nil }
        let sourceTags = sourceTags(from: insight, fallback: targetTag)
        guard sourceTags.count > 1 else { return nil }

        let result = TagLibraryMutation.merge(
            sourceTags: sourceTags,
            into: targetTag,
            in: makeMutationSnapshots(from: snapshots)
        )

        guard result.hasChanges else { return nil }

        return TagHygieneCleanupPlan(
            kind: .mergeDuplicates,
            title: "Tags zusammenführen",
            detail: "Die Varianten werden in #\(targetTag) überführt. Wenn ein Buch mehrere Varianten hat, bleibt nur das Ziel-Tag erhalten.",
            sourceTags: sourceTags,
            targetTag: targetTag,
            affectedBookIDs: result.changedBookIDs.sorted(by: uuidSort),
            result: result
        )
    }

    private static func singleUseDeletePlan(
        for insight: TagHygieneInsight,
        snapshots: [TagsDashboardBookSnapshot]
    ) -> TagHygieneCleanupPlan? {
        guard let tag = normalizedPrimaryTag(from: insight) else { return nil }

        let result = TagLibraryMutation.delete(
            tag: tag,
            in: makeMutationSnapshots(from: snapshots)
        )

        guard result.hasChanges else { return nil }

        return TagHygieneCleanupPlan(
            kind: .removeSingleUseTag,
            title: "Einmal-Tag entfernen",
            detail: "#\(tag) wird von den betroffenen Büchern entfernt. Die Bücher selbst bleiben unverändert erhalten.",
            sourceTags: [tag],
            targetTag: nil,
            affectedBookIDs: result.changedBookIDs.sorted(by: uuidSort),
            result: result
        )
    }

    private static func normalizedPrimaryTag(from insight: TagHygieneInsight) -> String? {
        guard let primaryTag = insight.primaryTag else { return nil }
        let normalized = normalizeTagString(primaryTag)
        guard !normalized.isEmpty else { return nil }
        return normalized
    }

    private static func sourceTags(from insight: TagHygieneInsight, fallback: String) -> [String] {
        let tags = insight.affectedTags.isEmpty ? [fallback] : insight.affectedTags
        return TagLibraryMutation.uniqueNormalizedTags(tags)
    }

    private static func makeMutationSnapshots(
        from snapshots: [TagsDashboardBookSnapshot]
    ) -> [TagLibraryMutationBookSnapshot] {
        snapshots.map { snapshot in
            TagLibraryMutationBookSnapshot(id: snapshot.id, tags: snapshot.tags)
        }
    }

    private static func uuidSort(_ lhs: UUID, _ rhs: UUID) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}

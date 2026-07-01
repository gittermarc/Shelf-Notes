import Foundation
import Testing
@testable import Shelf_Notes

struct TagHygieneCleanupBuilderTests {

    @Test func formattingInsightCreatesNormalizationPlan() {
        let snapshots = [
            makeSnapshot(1, tags: [" #Crime ", "Noir"]),
            makeSnapshot(2, tags: ["Crime"])
        ]
        let report = TagHygieneBuilder.build(snapshots: snapshots, maxInsights: 10)
        let insight = report.insights.first { $0.kind == .formattingConflict }

        let plan = insight.flatMap { TagHygieneCleanupBuilder.plan(for: $0, snapshots: snapshots) }

        #expect(plan?.kind == .normalizeFormatting)
        #expect(plan?.targetTag == "Crime")
        #expect(plan?.affectedBookIDs == [fixedID(1)])
        #expect(plan?.result.changes.first?.newTags == ["Crime", "Noir"])
    }

    @Test func duplicateInsightCreatesMergePlanUsingTagLibraryMutation() {
        let snapshots = [
            makeSnapshot(1, tags: ["SciFi", "Space"]),
            makeSnapshot(2, tags: ["Sci-Fi"]),
            makeSnapshot(3, tags: ["History"])
        ]
        let report = TagHygieneBuilder.build(snapshots: snapshots, maxInsights: 10)
        let insight = report.insights.first { $0.kind == .duplicateCandidate }

        let plan = insight.flatMap { TagHygieneCleanupBuilder.plan(for: $0, snapshots: snapshots) }

        #expect(plan?.kind == .mergeDuplicates)
        #expect(plan?.targetTag == "Sci-Fi")
        #expect(plan?.sourceTags == ["Sci-Fi", "SciFi"])
        #expect(plan?.affectedBookIDs == [fixedID(1)])
        #expect(plan?.result.changes.first?.newTags == ["Sci-Fi", "Space"])
    }

    @Test func singleUseInsightCreatesDeletePlanForFirstSingleUseTag() {
        let snapshots = [
            makeSnapshot(1, tags: ["Crime"]),
            makeSnapshot(2, tags: ["Crime"]),
            makeSnapshot(3, tags: ["Memoir"]),
            makeSnapshot(4, tags: ["Noir"])
        ]
        let report = TagHygieneBuilder.build(snapshots: snapshots, maxInsights: 10)
        let insight = report.insights.first { $0.kind == .singleUseTags }

        let plan = insight.flatMap { TagHygieneCleanupBuilder.plan(for: $0, snapshots: snapshots) }

        #expect(plan?.kind == .removeSingleUseTag)
        #expect(plan?.sourceTags == ["Memoir"])
        #expect(plan?.targetTag == nil)
        #expect(plan?.affectedBookIDs == [fixedID(3)])
        #expect(plan?.result.changes.first?.newTags == [])
    }

    @Test func untaggedInsightDoesNotCreateCleanupPlan() {
        let snapshots = [
            makeSnapshot(1, tags: []),
            makeSnapshot(2, tags: ["Crime"])
        ]
        let report = TagHygieneBuilder.build(snapshots: snapshots, maxInsights: 10)
        let insight = report.insights.first { $0.kind == .untaggedBooks }

        let plan = insight.flatMap { TagHygieneCleanupBuilder.plan(for: $0, snapshots: snapshots) }

        #expect(plan == nil)
    }

    @Test func cSharpFormattingPlanKeepsInnerHash() {
        let snapshots = [
            makeSnapshot(1, tags: ["#C#", "Programming"]),
            makeSnapshot(2, tags: ["C#"]),
            makeSnapshot(3, tags: ["C"])
        ]
        let report = TagHygieneBuilder.build(snapshots: snapshots, maxInsights: 10)
        let insight = report.insights.first { $0.kind == .formattingConflict && $0.primaryTag == "C#" }

        let plan = insight.flatMap { TagHygieneCleanupBuilder.plan(for: $0, snapshots: snapshots) }

        #expect(plan?.targetTag == "C#")
        #expect(plan?.sourceTags == ["C#"])
        #expect(plan?.affectedBookIDs == [fixedID(1)])
        #expect(plan?.result.changes.first?.newTags == ["C#", "Programming"])
    }

    @Test func cleanupPlanDoesNotCreateEmptyTags() {
        let snapshots = [
            makeSnapshot(1, tags: [" #Crime ", "#", "  "])
        ]
        let report = TagHygieneBuilder.build(snapshots: snapshots, maxInsights: 10)
        let insight = report.insights.first { $0.kind == .formattingConflict }

        let plan = insight.flatMap { TagHygieneCleanupBuilder.plan(for: $0, snapshots: snapshots) }

        #expect(plan?.result.changes.first?.newTags == ["Crime"])
    }

    @Test func cleanupPlanCanUseSharedDomainIndex() {
        let snapshots = [
            makeSnapshot(1, tags: [" #Crime ", "Noir"]),
            makeSnapshot(2, tags: ["Crime"])
        ]
        let index = TagsDomainIndex(snapshots: snapshots)
        let report = TagHygieneBuilder.build(index: index, maxInsights: 10)
        let insight = report.insights.first { $0.kind == .formattingConflict }

        let plan = insight.flatMap { TagHygieneCleanupBuilder.plan(for: $0, index: index) }

        #expect(plan?.kind == .normalizeFormatting)
        #expect(plan?.targetTag == "Crime")
        #expect(plan?.affectedBookIDs == [fixedID(1)])
        #expect(plan?.result.changes.first?.newTags == ["Crime", "Noir"])
    }

    private func makeSnapshot(
        _ value: Int,
        title: String = "Test Book",
        author: String = "Test Author",
        status: ReadingStatus = .toRead,
        tags: [String]
    ) -> TagsDashboardBookSnapshot {
        TagsDashboardBookSnapshot(
            id: fixedID(value),
            title: title,
            author: author,
            statusRawValue: status.rawValue,
            tags: tags
        )
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}

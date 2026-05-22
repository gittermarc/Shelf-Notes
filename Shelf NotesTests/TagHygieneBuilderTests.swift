import Foundation
import Testing
@testable import Shelf_Notes

struct TagHygieneBuilderTests {

    @Test func detectsCaseConflicts() {
        let snapshots = [
            makeSnapshot(1, tags: ["Crime"]),
            makeSnapshot(2, tags: ["crime"]),
            makeSnapshot(3, tags: ["Noir"])
        ]

        let report = TagHygieneBuilder.build(snapshots: snapshots, maxInsights: 10)
        let insight = report.insights.first { $0.kind == .formattingConflict }

        #expect(insight?.primaryTag == "Crime")
        #expect(insight?.affectedTags.contains("Crime") == true)
        #expect(insight?.affectedTags.contains("crime") == true)
        #expect(insight?.affectedBooksCount == 2)
    }

    @Test func detectsWhitespaceAndLeadingHashConflicts() {
        let snapshots = [
            makeSnapshot(1, tags: [" #History "]),
            makeSnapshot(2, tags: ["History"])
        ]

        let report = TagHygieneBuilder.build(snapshots: snapshots, maxInsights: 10)
        let insight = report.insights.first { $0.kind == .formattingConflict }

        #expect(insight?.primaryTag == "History")
        #expect(insight?.affectedTags.contains("#History") == true)
        #expect(insight?.affectedTags.contains("History") == true)
        #expect(insight?.affectedBooksCount == 2)
    }

    @Test func detectsConservativeDuplicateCandidates() {
        let snapshots = [
            makeSnapshot(1, tags: ["Sci-Fi"]),
            makeSnapshot(2, tags: ["SciFi"]),
            makeSnapshot(3, tags: ["New York"]),
            makeSnapshot(4, tags: ["NYC"])
        ]

        let report = TagHygieneBuilder.build(snapshots: snapshots, maxInsights: 10)
        let duplicates = report.insights.filter { $0.kind == .duplicateCandidate }

        #expect(duplicates.contains { Set($0.affectedTags) == Set(["Sci-Fi", "SciFi"]) })
        #expect(duplicates.contains { Set($0.affectedTags) == Set(["New York", "NYC"]) })
    }

    @Test func detectsSingleUseTags() {
        let snapshots = [
            makeSnapshot(1, tags: ["Crime"]),
            makeSnapshot(2, tags: ["Crime"]),
            makeSnapshot(3, tags: ["Memoir"]),
            makeSnapshot(4, tags: ["Noir"])
        ]

        let report = TagHygieneBuilder.build(snapshots: snapshots, maxInsights: 10)
        let insight = report.insights.first { $0.kind == .singleUseTags }

        #expect(insight?.affectedTags == ["Memoir", "Noir"])
        #expect(insight?.affectedBooksCount == 2)
    }

    @Test func countsUntaggedBooks() {
        let snapshots = [
            makeSnapshot(1, tags: ["Crime"]),
            makeSnapshot(2, tags: []),
            makeSnapshot(3, tags: [" ", "#"])
        ]

        let report = TagHygieneBuilder.build(snapshots: snapshots, maxInsights: 10)
        let insight = report.insights.first { $0.kind == .untaggedBooks }

        #expect(report.untaggedBookIDs == [fixedID(2), fixedID(3)])
        #expect(insight?.affectedBookIDs == [fixedID(2), fixedID(3)])
        #expect(insight?.title == "2 Bücher ohne Tags")
    }

    @Test func keepsInnerHashAndAvoidsFalseDuplicateForCSharp() {
        let snapshots = [
            makeSnapshot(1, tags: ["C#"]),
            makeSnapshot(2, tags: ["C"]),
            makeSnapshot(3, tags: ["#C#"])
        ]

        let report = TagHygieneBuilder.build(snapshots: snapshots, maxInsights: 10)
        let duplicates = report.insights.filter { $0.kind == .duplicateCandidate }
        let formatting = report.insights.first { $0.kind == .formattingConflict && $0.primaryTag == "C#" }

        #expect(duplicates.isEmpty)
        #expect(formatting?.affectedTags.contains("C#") == true)
        #expect(formatting?.affectedTags.contains("#C#") == true)
        #expect(formatting?.affectedTags.contains("C") != true)
    }

    @Test func avoidsShortTagShapeFalsePositives() {
        let snapshots = [
            makeSnapshot(1, tags: ["AI"]),
            makeSnapshot(2, tags: ["A-I"])
        ]

        let report = TagHygieneBuilder.build(snapshots: snapshots, maxInsights: 10)
        let duplicates = report.insights.filter { $0.kind == .duplicateCandidate }

        #expect(duplicates.isEmpty)
    }

    @Test func sortsInsightsStablyByPriority() {
        let snapshots = [
            makeSnapshot(1, tags: ["crime"]),
            makeSnapshot(2, tags: ["Crime"]),
            makeSnapshot(3, tags: ["Sci-Fi"]),
            makeSnapshot(4, tags: ["SciFi"]),
            makeSnapshot(5, tags: []),
            makeSnapshot(6, tags: ["Memoir"])
        ]

        let report = TagHygieneBuilder.build(snapshots: snapshots, maxInsights: 10)

        #expect(report.insights.map(\.kind).prefix(4) == [
            .formattingConflict,
            .duplicateCandidate,
            .singleUseTags,
            .untaggedBooks
        ])
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

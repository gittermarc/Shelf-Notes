import Foundation
import Testing
@testable import Shelf_Notes

struct TagsDomainIndexTests {

    @Test func buildsUsageCountsBookIDsAndOriginalSpellingsInOneIndex() {
        let snapshots = [
            makeSnapshot(1, status: .finished, tags: [" #Crime ", "Noir", "crime"]),
            makeSnapshot(2, status: .reading, tags: ["crime", "History"]),
            makeSnapshot(3, status: .toRead, tags: [" ", "#"]),
            makeSnapshot(4, status: .finished, tags: ["Noir"])
        ]

        let index = TagsDomainIndex(snapshots: snapshots)
        let crime = index.usageIndex.entriesByKey["crime"]
        let noir = index.usageIndex.entriesByKey["noir"]

        #expect(index.totalBooks == 4)
        #expect(index.usageIndex.taggedBookIDsCount == 3)
        #expect(index.usageIndex.untaggedBookIDs == [fixedID(3)])
        #expect(index.usageIndex.totalTagUsages == 5)
        #expect(index.usageIndex.normalizedTags == ["Crime", "Noir", "History"])
        #expect(index.normalizedTagsByBookID[fixedID(1)] == ["Crime", "Noir"])
        #expect(index.occurrences.count == 6)

        #expect(crime?.count == 2)
        #expect(crime?.bookIDs == [fixedID(1), fixedID(2)])
        #expect(crime?.statusCounts.finished == 1)
        #expect(crime?.statusCounts.reading == 1)
        #expect(crime?.originalSpellings == ["#Crime", "crime"])

        #expect(noir?.count == 2)
        #expect(noir?.bookIDs == [fixedID(1), fixedID(4)])
        #expect(noir?.statusCounts.finished == 2)
    }

    @Test func inputSignatureChangesForRelevantTagAndStatusChanges() {
        let base = [
            makeSnapshot(1, status: .finished, tags: ["Crime"]),
            makeSnapshot(2, status: .reading, tags: ["Noir"])
        ]
        let changedStatus = [
            makeSnapshot(1, status: .reading, tags: ["Crime"]),
            makeSnapshot(2, status: .reading, tags: ["Noir"])
        ]
        let changedTags = [
            makeSnapshot(1, status: .finished, tags: ["Crime", "History"]),
            makeSnapshot(2, status: .reading, tags: ["Noir"])
        ]
        let changedFormatting = [
            makeSnapshot(1, status: .finished, tags: [" #Crime "]),
            makeSnapshot(2, status: .reading, tags: ["Noir"])
        ]

        let baseSignature = TagsDomainIndex(snapshots: base).inputSignature

        #expect(baseSignature != TagsDomainIndex(snapshots: changedStatus).inputSignature)
        #expect(baseSignature != TagsDomainIndex(snapshots: changedTags).inputSignature)
        #expect(baseSignature != TagsDomainIndex(snapshots: changedFormatting).inputSignature)
    }

    @Test func dashboardAndHygieneCanBeDerivedFromSharedIndex() {
        let snapshots = [
            makeSnapshot(1, status: .finished, tags: ["Crime", "Noir"]),
            makeSnapshot(2, status: .reading, tags: ["crime", "History"]),
            makeSnapshot(3, status: .toRead, tags: []),
            makeSnapshot(4, status: .finished, tags: ["Sci-Fi"])
        ]
        let index = TagsDomainIndex(snapshots: snapshots)
        let dashboard = TagsDashboardBuilder.build(index: index)
        let hygiene = TagHygieneBuilder.build(index: index, maxInsights: 10)

        #expect(dashboard.summary.totalBooks == 4)
        #expect(dashboard.summary.totalTags == 4)
        #expect(dashboard.summary.taggedBooksCount == 3)
        #expect(dashboard.summary.untaggedBooksCount == 1)
        #expect(dashboard.entries.map(\.tag) == ["Crime", "History", "Noir", "Sci-Fi"])
        #expect(dashboard.entries.map(\.bookCount) == [2, 1, 1, 1])
        #expect(hygiene.untaggedBookIDs == dashboard.untaggedBookIDs)
        #expect(hygiene.insights.map(\.kind).contains(.formattingConflict))
        #expect(hygiene.insights.map(\.kind).contains(.singleUseTags))
        #expect(hygiene.insights.map(\.kind).contains(.untaggedBooks))
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

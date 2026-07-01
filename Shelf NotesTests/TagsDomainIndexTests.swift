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

    @Test func suggestionSnapshotsBuildReusableSuggestionMetadata() {
        let snapshots = [
            makeSuggestionSnapshot(
                1,
                author: "Megan Example",
                tags: [" #Crime ", "Noir", "crime"],
                categories: ["Fiction / Mystery & Detective"],
                mainCategory: "Science Fiction"
            ),
            makeSuggestionSnapshot(
                2,
                author: "Megan Example",
                tags: ["Crime", "NYC"],
                categories: ["Fiction / Mystery & Detective"]
            ),
            makeSuggestionSnapshot(
                3,
                tags: ["History"],
                categories: ["Biography und Autobiografie"]
            )
        ]

        let index = TagsDomainIndex(suggestionSnapshots: snapshots)

        #expect(index.suggestionSnapshots.map(\.id) == [fixedID(1), fixedID(2), fixedID(3)])
        #expect(index.normalizedTags(for: fixedID(1)) == ["Crime", "Noir"])
        #expect(index.categoryCandidates(for: fixedID(1)) == ["Sci-Fi", "Mystery", "Detective"])
        #expect(index.categoryCandidateKeys(for: fixedID(1)) == Set(["sci-fi", "mystery", "detective"]))
        #expect(index.comparableMainCategoryKey(for: fixedID(1)) == "sci-fi")
        #expect(index.tagCounts.map(\.tag) == ["Crime", "History", "Noir", "NYC"])
        #expect(index.tagCounts.map(\.count) == [2, 1, 1, 1])
    }

    @Test func autocompleteSuggestionsCanUseDomainIndexCounts() {
        let snapshots = [
            makeSuggestionSnapshot(1, tags: [" #Sci-Fi ", "Space Opera"]),
            makeSuggestionSnapshot(2, tags: ["Science"]),
            makeSuggestionSnapshot(3, tags: ["Crime"])
        ]
        let index = TagsDomainIndex(suggestionSnapshots: snapshots)

        let suggestions = index.autocompleteSuggestions(
            query: "sci",
            selectedTags: ["Science"]
        )

        #expect(suggestions == ["Sci-Fi"])
    }

    @Test func sourceSignatureTracksTagRelevantFieldsAndIgnoresOrder() {
        let base = [
            makeSourceSnapshot(1, title: "Noir One", author: "A", tags: ["Crime"], categories: ["Mystery"], mainCategory: "Fiction"),
            makeSourceSnapshot(2, title: "Noir Two", author: "B", tags: ["Noir"], categories: ["Thriller"], mainCategory: "Fiction")
        ]
        let sameValuesDifferentOrder = [base[1], base[0]]
        let changedTitle = [
            makeSourceSnapshot(1, title: "Noir Changed", author: "A", tags: ["Crime"], categories: ["Mystery"], mainCategory: "Fiction"),
            base[1]
        ]
        let changedCategory = [
            makeSourceSnapshot(1, title: "Noir One", author: "A", tags: ["Crime"], categories: ["Detective"], mainCategory: "Fiction"),
            base[1]
        ]

        let baseSignature = TagsSourceSignature(sourceSnapshots: base)

        #expect(baseSignature == TagsSourceSignature(sourceSnapshots: sameValuesDifferentOrder))
        #expect(baseSignature != TagsSourceSignature(sourceSnapshots: changedTitle))
        #expect(baseSignature != TagsSourceSignature(sourceSnapshots: changedCategory))
    }

    @Test func sourceIndexExposesReusableDashboardSuggestionAndMutationSnapshots() {
        let sourceSnapshots = [
            makeSourceSnapshot(
                1,
                title: "Noir One",
                author: "A. Author",
                tags: ["Crime"],
                categories: ["Fiction / Mystery & Detective"],
                status: .finished
            ),
            makeSourceSnapshot(
                2,
                title: "Noir Two",
                author: "A. Author",
                tags: ["Noir", "Crime"],
                categories: ["Fiction / Mystery & Detective"],
                status: .reading
            )
        ]
        let index = TagsDomainIndex(sourceSnapshots: sourceSnapshots)

        #expect(index.dashboardSnapshots.map(\.id) == sourceSnapshots.map(\.id))
        #expect(index.suggestionSnapshots.map(\.id) == sourceSnapshots.map(\.id))
        #expect(index.mutationSnapshots.map(\.id) == sourceSnapshots.map(\.id))
        #expect(index.dashboardSnapshots.first?.statusRawValue == ReadingStatus.finished.rawValue)
        #expect(index.suggestionSnapshots.first?.categories == ["Fiction / Mystery & Detective"])
        #expect(index.mutationSnapshots.first?.tags == ["Crime"])
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

    private func makeSuggestionSnapshot(
        _ value: Int,
        title: String = "Test Book",
        author: String = "Test Author",
        tags: [String] = [],
        categories: [String] = [],
        mainCategory: String? = nil,
        status: ReadingStatus = .toRead
    ) -> TagSuggestionBookSnapshot {
        TagSuggestionBookSnapshot(
            id: fixedID(value),
            title: title,
            author: author,
            tags: tags,
            categories: categories,
            mainCategory: mainCategory,
            statusRawValue: status.rawValue
        )
    }

    private func makeSourceSnapshot(
        _ value: Int,
        title: String = "Test Book",
        author: String = "Test Author",
        tags: [String],
        categories: [String] = [],
        mainCategory: String? = nil,
        status: ReadingStatus = .toRead
    ) -> TagsSourceSnapshot {
        TagsSourceSnapshot(
            id: fixedID(value),
            title: title,
            author: author,
            categories: categories,
            mainCategory: mainCategory,
            tags: tags,
            statusRawValue: status.rawValue
        )
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}

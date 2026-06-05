import Foundation
import Testing
@testable import Shelf_Notes

struct TagsIndexBuilderTests {

    @Test func normalizesAndDeduplicatesTagsCaseInsensitively() {
        let tags = TagsIndexBuilder.uniqueNormalizedTags([
            "  #Noir  ",
            "noir",
            " Crime ",
            "#crime",
            "",
            "   "
        ])

        #expect(tags == ["Noir", "Crime"])
    }

    @Test func parsesCommaSeparatedDraftsAndFallsBackToSingleTag() {
        let commaSeparated = TagsIndexBuilder.parsedTags(from: "  #Noir, Crime, noir,  ")
        let single = TagsIndexBuilder.parsedTags(from: "   #History  ")

        #expect(commaSeparated == ["Noir", "Crime"])
        #expect(single == ["History"])
    }

    @Test func computesStableCountsAcrossMultipleBooks() {
        let snapshot = [
            TagsIndexBuilder.BookTagsSnapshot(id: UUID(), tags: ["#Noir", "Crime"]),
            TagsIndexBuilder.BookTagsSnapshot(id: UUID(), tags: ["noir", "History"]),
            TagsIndexBuilder.BookTagsSnapshot(id: UUID(), tags: ["Crime"])
        ]

        let counts = TagsIndexBuilder.computeTagCounts(snapshot: snapshot)

        #expect(counts.map(\.tag) == ["Crime", "Noir", "History"])
        #expect(counts.map(\.count) == [2, 2, 1])
    }

    @Test func tagIndexSignatureUsesOnlyBookIDsAndTags() {
        let bookID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let unchanged = [
            TagsIndexBuilder.BookTagsSnapshot(id: bookID, tags: ["#Noir", "Crime"])
        ]
        let sameTagSnapshotAfterIrrelevantBookEdits = [
            TagsIndexBuilder.BookTagsSnapshot(id: bookID, tags: ["#Noir", "Crime"])
        ]
        let changedTags = [
            TagsIndexBuilder.BookTagsSnapshot(id: bookID, tags: ["#Noir", "Crime", "History"])
        ]

        let unchangedSignature = TagsIndexBuilder.computeSignature(snapshot: unchanged)

        #expect(unchangedSignature == TagsIndexBuilder.computeSignature(snapshot: sameTagSnapshotAfterIrrelevantBookEdits))
        #expect(unchangedSignature != TagsIndexBuilder.computeSignature(snapshot: changedTags))
    }

    @Test func suggestionsPreferPrefixMatchesAndExcludeSelectedTags() {
        let tagCounts = [
            TagsIndexBuilder.TagCount(tag: "Crime", count: 5),
            TagsIndexBuilder.TagCount(tag: "Space Opera", count: 4),
            TagsIndexBuilder.TagCount(tag: "Cosy Crime", count: 3),
            TagsIndexBuilder.TagCount(tag: "Microhistory", count: 2)
        ]

        let suggestions = TagsIndexBuilder.autocompleteSuggestions(
            query: "cri",
            selectedTags: ["crime"],
            tagCounts: tagCounts
        )

        #expect(suggestions == ["Cosy Crime", "Microhistory"])
    }

    @Test func suggestionsReturnEmptyForBlankQueryOrEmptyCounts() {
        let blankQuery = TagsIndexBuilder.autocompleteSuggestions(
            query: "   ",
            selectedTags: [],
            tagCounts: [TagsIndexBuilder.TagCount(tag: "Noir", count: 1)]
        )
        let emptyCounts = TagsIndexBuilder.autocompleteSuggestions(
            query: "no",
            selectedTags: [],
            tagCounts: []
        )

        #expect(blankQuery.isEmpty)
        #expect(emptyCounts.isEmpty)
    }
}
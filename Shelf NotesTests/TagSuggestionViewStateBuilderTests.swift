import Foundation
import Testing
@testable import Shelf_Notes

struct TagSuggestionViewStateBuilderTests {

    @Test func buildsSmartAndFrequentItemsFromSingleSuggestionResult() {
        let target = makeSnapshot(
            1,
            tags: ["Crime"],
            categories: ["Fiction / Mystery & Detective"]
        )
        let library = [
            target,
            makeSnapshot(2, tags: ["Crime", "Noir"], categories: ["Fiction / Mystery & Detective"]),
            makeSnapshot(3, tags: ["History"]),
            makeSnapshot(4, tags: ["Sci-Fi"])
        ]
        let tagCounts = [
            TagsIndexBuilder.TagCount(tag: "Crime", count: 2),
            TagsIndexBuilder.TagCount(tag: "Noir", count: 1),
            TagsIndexBuilder.TagCount(tag: "History", count: 1),
            TagsIndexBuilder.TagCount(tag: "Sci-Fi", count: 1)
        ]

        let suggestions = TagSuggestionEngine.suggestions(
            for: target,
            in: library,
            limit: 8
        )
        let expectedSmartItems = TagSuggestionPresentationBuilder.suggestedItems(
            from: suggestions,
            selectedTags: target.tags,
            limit: 6
        )
        let expectedFrequentItems = TagSuggestionPresentationBuilder.frequentItems(
            from: tagCounts,
            selectedTags: target.tags,
            excludingTags: expectedSmartItems.map(\.tag),
            limit: 18
        )

        let state = TagSuggestionViewStateBuilder.make(
            target: target,
            library: library,
            tagCounts: tagCounts,
            selectedTags: target.tags,
            suggestionLimit: 8,
            smartLimit: 6,
            frequentLimit: 18
        )

        #expect(state.smartItems.map(\.tag) == expectedSmartItems.map(\.tag))
        #expect(state.smartItems.map(\.reasonLabel) == expectedSmartItems.map(\.reasonLabel))
        #expect(state.frequentItems.map(\.tag) == expectedFrequentItems.map(\.tag))
        #expect(state.frequentItems.map(\.isSelected) == expectedFrequentItems.map(\.isSelected))
    }

    @Test func frequentItemsReuseSmartTagsAsExclusions() {
        let target = makeSnapshot(
            1,
            categories: ["Science Fiction"]
        )
        let library = [
            target,
            makeSnapshot(2, tags: ["Sci-Fi"]),
            makeSnapshot(3, tags: ["Crime"])
        ]
        let tagCounts = [
            TagsIndexBuilder.TagCount(tag: "Sci-Fi", count: 4),
            TagsIndexBuilder.TagCount(tag: "Crime", count: 3),
            TagsIndexBuilder.TagCount(tag: "History", count: 2)
        ]

        let state = TagSuggestionViewStateBuilder.make(
            target: target,
            library: library,
            tagCounts: tagCounts,
            selectedTags: [],
            suggestionLimit: 8,
            smartLimit: 1,
            frequentLimit: 18
        )

        let smartTags = state.smartItems.map(\.tag)
        let frequentTags = state.frequentItems.map(\.tag)

        #expect(smartTags.contains("Sci-Fi"))
        #expect(!frequentTags.contains("Sci-Fi"))
        #expect(frequentTags.contains("Crime") || frequentTags.contains("History"))
    }

    private func makeSnapshot(
        _ value: Int,
        title: String = "Test Book",
        author: String = "",
        tags: [String] = [],
        categories: [String] = [],
        mainCategory: String? = nil,
        statusRawValue: String = "toRead"
    ) -> TagSuggestionBookSnapshot {
        TagSuggestionBookSnapshot(
            id: fixedID(value),
            title: title,
            author: author,
            tags: tags,
            categories: categories,
            mainCategory: mainCategory,
            statusRawValue: statusRawValue
        )
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
}

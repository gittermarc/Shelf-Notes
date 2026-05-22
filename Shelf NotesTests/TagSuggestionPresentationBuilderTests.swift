import Foundation
import Testing
@testable import Shelf_Notes

struct TagSuggestionPresentationBuilderTests {

    @Test func suggestedItemsExcludeSelectedTagsAndKeepReasonDetails() {
        let suggestions = [
            TagSuggestion(
                tag: " Crime ",
                score: 120,
                reasons: [.category],
                relatedBookCount: 0,
                existingTagCount: 0
            ),
            TagSuggestion(
                tag: "Noir",
                score: 100,
                reasons: [.similarBook, .coTag],
                relatedBookCount: 2,
                existingTagCount: 3
            )
        ]

        let items = TagSuggestionPresentationBuilder.suggestedItems(
            from: suggestions,
            selectedTags: ["crime"],
            limit: 10
        )

        #expect(items.map(\.tag) == ["Noir"])
        #expect(items.first?.reasonLabel == "Ähnliche Bücher · Oft gemeinsam")
        #expect(items.first?.detail == "3x genutzt · 2 ähnliche Bücher")
    }

    @Test func suggestedItemsDeduplicateAndRespectLimit() {
        let suggestions = [
            TagSuggestion(tag: "Sci-Fi", score: 90, reasons: [.category], relatedBookCount: 0, existingTagCount: 0),
            TagSuggestion(tag: "sci-fi", score: 80, reasons: [.frequent], relatedBookCount: 0, existingTagCount: 4),
            TagSuggestion(tag: "Noir", score: 70, reasons: [.frequent], relatedBookCount: 0, existingTagCount: 2)
        ]

        let items = TagSuggestionPresentationBuilder.suggestedItems(
            from: suggestions,
            selectedTags: [],
            limit: 1
        )

        #expect(items.map(\.tag) == ["Sci-Fi"])
    }

    @Test func frequentItemsMarkSelectedAndAvoidSuggestedDuplicates() {
        let counts = [
            TagsIndexBuilder.TagCount(tag: "Crime", count: 5),
            TagsIndexBuilder.TagCount(tag: "Noir", count: 3),
            TagsIndexBuilder.TagCount(tag: "NYC", count: 2)
        ]

        let items = TagSuggestionPresentationBuilder.frequentItems(
            from: counts,
            selectedTags: ["crime"],
            excludingTags: ["Noir"],
            limit: 10
        )

        #expect(items.map(\.tag) == ["Crime", "NYC"])
        #expect(items.first?.isSelected == true)
        #expect(items.last?.isSelected == false)
    }

    @Test func acceptingSuggestionUsesCentralTagMergingAndKeepsInnerHash() {
        let tags = TagSuggestionPresentationBuilder.tagsAfterAcceptingSuggestion(
            "#C#",
            existingTags: ["Crime", "crime", " "]
        )

        #expect(tags == ["Crime", "C#"])
    }
}

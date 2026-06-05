import Foundation

struct TagSuggestionViewState {
    let smartItems: [TagSuggestionDisplayItem]
    let frequentItems: [FrequentTagDisplayItem]
}

enum TagSuggestionViewStateBuilder {
    static func make(
        target: TagSuggestionBookSnapshot,
        library: [TagSuggestionBookSnapshot],
        tagCounts: [TagsIndexBuilder.TagCount],
        selectedTags: [String],
        suggestionLimit: Int = 8,
        smartLimit: Int = 6,
        frequentLimit: Int = 18
    ) -> TagSuggestionViewState {
        let suggestions = TagSuggestionEngine.suggestions(
            for: target,
            in: library,
            limit: suggestionLimit
        )

        let smartItems = TagSuggestionPresentationBuilder.suggestedItems(
            from: suggestions,
            selectedTags: selectedTags,
            limit: smartLimit
        )

        let frequentItems = TagSuggestionPresentationBuilder.frequentItems(
            from: tagCounts,
            selectedTags: selectedTags,
            excludingTags: smartItems.map(\.tag),
            limit: frequentLimit
        )

        return TagSuggestionViewState(
            smartItems: smartItems,
            frequentItems: frequentItems
        )
    }

    static func make(
        target: TagSuggestionBookSnapshot,
        domainIndex: TagsDomainIndex,
        selectedTags: [String],
        suggestionLimit: Int = 8,
        smartLimit: Int = 6,
        frequentLimit: Int = 18
    ) -> TagSuggestionViewState {
        let suggestions = TagSuggestionEngine.suggestions(
            for: target,
            in: domainIndex,
            limit: suggestionLimit
        )

        let smartItems = TagSuggestionPresentationBuilder.suggestedItems(
            from: suggestions,
            selectedTags: selectedTags,
            limit: smartLimit
        )

        let frequentItems = TagSuggestionPresentationBuilder.frequentItems(
            from: domainIndex.tagCounts,
            selectedTags: selectedTags,
            excludingTags: smartItems.map(\.tag),
            limit: frequentLimit
        )

        return TagSuggestionViewState(
            smartItems: smartItems,
            frequentItems: frequentItems
        )
    }
}

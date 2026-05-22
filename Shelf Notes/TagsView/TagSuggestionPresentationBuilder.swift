import Foundation

enum TagSuggestionPresentationBuilder {
    static func suggestedItems(
        from suggestions: [TagSuggestion],
        selectedTags: [String],
        limit: Int = 8
    ) -> [TagSuggestionDisplayItem] {
        guard limit > 0 else { return [] }

        let selectedKeys = Set(TagsIndexBuilder.uniqueNormalizedTags(selectedTags).map { suggestionKey($0) })
        var seenKeys: Set<String> = []
        var items: [TagSuggestionDisplayItem] = []
        items.reserveCapacity(min(limit, suggestions.count))

        for suggestion in suggestions {
            let normalizedTag = normalizeTagString(suggestion.tag)
            guard !normalizedTag.isEmpty else { continue }

            let key = suggestionKey(normalizedTag)
            guard !selectedKeys.contains(key), !seenKeys.contains(key) else { continue }

            seenKeys.insert(key)
            items.append(
                TagSuggestionDisplayItem(
                    tag: normalizedTag,
                    reasonLabel: suggestion.reasonLabel,
                    detail: detailText(for: suggestion),
                    score: suggestion.score,
                    existingTagCount: suggestion.existingTagCount,
                    relatedBookCount: suggestion.relatedBookCount
                )
            )

            if items.count >= limit {
                break
            }
        }

        return items
    }

    static func frequentItems(
        from tagCounts: [TagsIndexBuilder.TagCount],
        selectedTags: [String],
        excludingTags: [String] = [],
        limit: Int = 18
    ) -> [FrequentTagDisplayItem] {
        guard limit > 0 else { return [] }

        let selectedKeys = Set(TagsIndexBuilder.uniqueNormalizedTags(selectedTags).map { suggestionKey($0) })
        let excludedKeys = Set(TagsIndexBuilder.uniqueNormalizedTags(excludingTags).map { suggestionKey($0) })
        var seenKeys: Set<String> = []
        var items: [FrequentTagDisplayItem] = []
        items.reserveCapacity(min(limit, tagCounts.count))

        for count in tagCounts {
            let normalizedTag = normalizeTagString(count.tag)
            guard !normalizedTag.isEmpty else { continue }

            let key = suggestionKey(normalizedTag)
            guard !seenKeys.contains(key) else { continue }
            guard !excludedKeys.contains(key) || selectedKeys.contains(key) else { continue }

            seenKeys.insert(key)
            items.append(
                FrequentTagDisplayItem(
                    tag: normalizedTag,
                    count: count.count,
                    isSelected: selectedKeys.contains(key)
                )
            )

            if items.count >= limit {
                break
            }
        }

        return items
    }

    static func tagsAfterAcceptingSuggestion(_ tag: String, existingTags: [String]) -> [String] {
        TagsIndexBuilder.mergedTags(existingTags: existingTags, addedTags: [tag])
    }

    private static func detailText(for suggestion: TagSuggestion) -> String {
        var parts: [String] = []

        if suggestion.existingTagCount > 0 {
            parts.append("\(suggestion.existingTagCount)x genutzt")
        }

        if suggestion.relatedBookCount == 1 {
            parts.append("1 ähnliches Buch")
        } else if suggestion.relatedBookCount > 1 {
            parts.append("\(suggestion.relatedBookCount) ähnliche Bücher")
        }

        if parts.isEmpty {
            return suggestion.reasonLabel
        }

        return parts.joined(separator: " · ")
    }

    private static func suggestionKey(_ tag: String) -> String {
        normalizeTagString(tag)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}

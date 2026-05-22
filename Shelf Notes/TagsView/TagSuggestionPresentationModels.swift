import Foundation

struct TagSuggestionDisplayItem: Identifiable, Hashable {
    let tag: String
    let reasonLabel: String
    let detail: String
    let score: Int
    let existingTagCount: Int
    let relatedBookCount: Int

    var id: String {
        normalizeTagString(tag).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
    }
}

struct FrequentTagDisplayItem: Identifiable, Hashable {
    let tag: String
    let count: Int
    let isSelected: Bool

    var id: String {
        normalizeTagString(tag).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()
    }
}

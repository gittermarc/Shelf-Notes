import Foundation

nonisolated enum TagSuggestionReason: String, CaseIterable, Identifiable, Hashable {
    case category
    case frequent
    case similarBook
    case coTag

    var id: String { rawValue }

    var label: String {
        switch self {
        case .category:
            return "Aus Kategorie"
        case .frequent:
            return "Häufig genutzt"
        case .similarBook:
            return "Ähnliche Bücher"
        case .coTag:
            return "Oft gemeinsam"
        }
    }
}

nonisolated struct TagSuggestion: Identifiable, Hashable {
    let tag: String
    let score: Int
    let reasons: [TagSuggestionReason]
    let relatedBookCount: Int
    let existingTagCount: Int

    var id: String {
        tag.lowercased()
    }

    var reasonLabel: String {
        reasons.map(\.label).joined(separator: " · ")
    }
}

nonisolated struct TagSuggestionBookSnapshot: Identifiable, Hashable {
    let id: UUID
    let title: String
    let author: String
    let tags: [String]
    let categories: [String]
    let mainCategory: String?
    let statusRawValue: String
}

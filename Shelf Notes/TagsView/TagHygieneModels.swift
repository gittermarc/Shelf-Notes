import Foundation

enum TagHygieneInsightKind: String, Hashable {
    case formattingConflict
    case duplicateCandidate
    case singleUseTags
    case untaggedBooks

    var systemImage: String {
        switch self {
        case .formattingConflict:
            return "textformat"
        case .duplicateCandidate:
            return "square.stack.3d.up"
        case .singleUseTags:
            return "tag"
        case .untaggedBooks:
            return "tag.slash"
        }
    }
}

struct TagHygieneInsight: Identifiable, Hashable {
    let kind: TagHygieneInsightKind
    let title: String
    let detail: String
    let affectedTags: [String]
    let affectedBookIDs: [UUID]
    let primaryTag: String?
    let actionTitle: String

    var id: String {
        let tagPart = affectedTags
            .map { $0.lowercased() }
            .joined(separator: "|")
        let bookPart = affectedBookIDs
            .map(\.uuidString)
            .sorted()
            .joined(separator: "|")
        return "\(kind.rawValue):\(tagPart):\(bookPart)"
    }

    var affectedBooksCount: Int {
        affectedBookIDs.count
    }

    var affectedTagsCount: Int {
        affectedTags.count
    }
}

struct TagHygieneReport: Hashable {
    let insights: [TagHygieneInsight]
    let untaggedBookIDs: [UUID]

    var hasInsights: Bool {
        !insights.isEmpty
    }
}

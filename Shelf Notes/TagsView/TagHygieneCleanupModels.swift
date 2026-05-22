import Foundation

enum TagHygieneCleanupKind: String, Hashable {
    case normalizeFormatting
    case mergeDuplicates
    case removeSingleUseTag

    var systemImage: String {
        switch self {
        case .normalizeFormatting:
            return "textformat"
        case .mergeDuplicates:
            return "arrow.triangle.merge"
        case .removeSingleUseTag:
            return "trash"
        }
    }

    var actionTitle: String {
        switch self {
        case .normalizeFormatting:
            return "Schreibweise bereinigen"
        case .mergeDuplicates:
            return "Zusammenführen"
        case .removeSingleUseTag:
            return "Entfernen"
        }
    }

    var isDestructive: Bool {
        switch self {
        case .normalizeFormatting, .mergeDuplicates:
            return false
        case .removeSingleUseTag:
            return true
        }
    }
}

struct TagHygieneCleanupPlan: Identifiable, Hashable {
    let kind: TagHygieneCleanupKind
    let title: String
    let detail: String
    let sourceTags: [String]
    let targetTag: String?
    let affectedBookIDs: [UUID]
    let result: TagLibraryMutationResult

    var id: String {
        let tagPart = sourceTags
            .map { $0.lowercased() }
            .joined(separator: "|")
        let targetPart = targetTag?.lowercased() ?? "none"
        let bookPart = affectedBookIDs
            .map(\.uuidString)
            .sorted()
            .joined(separator: "|")
        return "\(kind.rawValue):\(tagPart):\(targetPart):\(bookPart)"
    }

    var affectedBooksCount: Int {
        affectedBookIDs.count
    }

    var actionTitle: String {
        kind.actionTitle
    }

    var isDestructive: Bool {
        kind.isDestructive
    }
}

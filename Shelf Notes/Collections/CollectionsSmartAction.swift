import Foundation

enum CollectionsSmartActionKind: String, Hashable {
    case unassignedBooks
    case emptyCollections
    case activeCollection
    case unratedFinishedBooks
    case tagCluster
    case authorCluster
    case largeCollection
}

struct CollectionsSmartAction: Hashable, Identifiable {
    let id: String
    let kind: CollectionsSmartActionKind
    let title: String
    let message: String
    let detail: String
    let systemImage: String
    let priority: Int
    let collectionID: UUID?
    let relatedBookIDs: [UUID]
    let ctaTitle: String?
}

enum CollectionNextActionKind: String, Hashable {
    case addBooks
    case continueReading
    case rateFinishedBook
    case startPlannedBook
    case completed
}

struct CollectionNextAction: Hashable, Identifiable {
    let id: String
    let kind: CollectionNextActionKind
    let title: String
    let message: String
    let detail: String
    let systemImage: String
    let bookID: UUID?
    let ctaTitle: String?
}

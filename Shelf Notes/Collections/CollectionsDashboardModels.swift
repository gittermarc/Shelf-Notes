import Foundation

struct CollectionsDashboardBookSnapshot: Hashable, Identifiable {
    let id: UUID
    let title: String
    let author: String
    let statusRawValue: String
    let tags: [String]
    let userRatingAverage: Double?

    init(
        id: UUID,
        title: String,
        author: String,
        statusRawValue: String,
        tags: [String] = [],
        userRatingAverage: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.statusRawValue = statusRawValue
        self.tags = tags
        self.userRatingAverage = userRatingAverage
    }
}

struct CollectionsDashboardCollectionSnapshot: Hashable, Identifiable {
    let id: UUID
    let name: String
    let createdAt: Date
    let updatedAt: Date
    let books: [CollectionsDashboardBookSnapshot]
}

struct CollectionsDashboardStatusCounts: Hashable {
    var toRead: Int = 0
    var reading: Int = 0
    var finished: Int = 0
    var unknown: Int = 0

    var total: Int {
        toRead + reading + finished + unknown
    }

    var hasBooks: Bool {
        total > 0
    }

    var progressFraction: Double {
        guard total > 0 else { return 0 }
        return Double(finished) / Double(total)
    }

    mutating func increment(statusRawValue: String) {
        switch ReadingStatus.fromPersisted(statusRawValue) {
        case .toRead:
            toRead += 1
        case .reading:
            reading += 1
        case .finished:
            finished += 1
        case .none:
            unknown += 1
        }
    }
}

struct CollectionsDashboardHighlight: Hashable {
    let id: UUID
    let name: String
    let bookCount: Int
}

struct CollectionsDashboardSummary: Hashable {
    let totalBooks: Int
    let totalCollections: Int
    let booksInCollectionsCount: Int
    let unassignedBooksCount: Int
    let activeCollectionsCount: Int
    let largestCollection: CollectionsDashboardHighlight?
}

struct CollectionsDashboardEntry: Hashable, Identifiable {
    let id: UUID
    let name: String
    let createdAt: Date
    let updatedAt: Date
    let bookCount: Int
    let statusCounts: CollectionsDashboardStatusCounts
    let representativeBookIDs: [UUID]

    var displayName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Ohne Namen" : trimmedName
    }

    var hasActiveBooks: Bool {
        statusCounts.reading > 0
    }
}

struct CollectionsDashboard: Hashable {
    let summary: CollectionsDashboardSummary
    let entries: [CollectionsDashboardEntry]
    let unassignedBookIDs: [UUID]
}

enum CollectionsDashboardSortMode: String, CaseIterable, Identifiable {
    case recentActivity
    case mostBooks
    case progress
    case name

    var id: String { rawValue }

    var label: String {
        switch self {
        case .recentActivity:
            return "Aktuell"
        case .mostBooks:
            return "Größe"
        case .progress:
            return "Fortschritt"
        case .name:
            return "Name"
        }
    }
}

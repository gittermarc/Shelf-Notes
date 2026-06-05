import Foundation

struct CollectionDetailBookSnapshot: Hashable, Identifiable {
    let id: UUID
    let title: String
    let author: String
    let statusRawValue: String
    let createdAt: Date
    let readFrom: Date?
    let readTo: Date?
    let userRatingAverage: Double?
}

struct CollectionDetailState: Hashable {
    let collectionName: String
    let bookCount: Int
    let statusCounts: CollectionsDashboardStatusCounts
    let representativeBookIDs: [UUID]

    var displayName: String {
        let trimmedName = collectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "Ohne Namen" : trimmedName
    }

    var isEmpty: Bool {
        bookCount == 0
    }
}

enum CollectionDetailStatusFilter: String, CaseIterable, Identifiable {
    case all
    case toRead
    case reading
    case finished

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:
            return "Alle"
        case .toRead:
            return "Geplant"
        case .reading:
            return "Aktiv"
        case .finished:
            return "Gelesen"
        }
    }

    func includes(statusRawValue: String) -> Bool {
        guard self != .all else { return true }
        guard let status = ReadingStatus.fromPersisted(statusRawValue) else { return false }

        switch self {
        case .all:
            return true
        case .toRead:
            return status == .toRead
        case .reading:
            return status == .reading
        case .finished:
            return status == .finished
        }
    }
}

enum CollectionDetailSortMode: String, CaseIterable, Identifiable {
    case title
    case author
    case status
    case rating
    case readDate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .title:
            return "Titel"
        case .author:
            return "Autor"
        case .status:
            return "Status"
        case .rating:
            return "Bewertung"
        case .readDate:
            return "Lesedatum"
        }
    }
}

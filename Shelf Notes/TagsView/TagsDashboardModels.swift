import Foundation

nonisolated enum TagsDashboardSortMode: String, CaseIterable, Identifiable {
    case mostUsed
    case alphabetic
    case leastUsed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mostUsed:
            return "Häufig"
        case .alphabetic:
            return "A-Z"
        case .leastUsed:
            return "Selten"
        }
    }
}

nonisolated struct TagsDashboardBookSnapshot: Identifiable, Hashable {
    let id: UUID
    let title: String
    let author: String
    let statusRawValue: String
    let tags: [String]
}

nonisolated struct TagsDashboardStatusCounts: Hashable {
    var toRead: Int = 0
    var reading: Int = 0
    var finished: Int = 0

    var total: Int {
        toRead + reading + finished
    }

    var compactLabel: String {
        let parts = statusParts
        guard !parts.isEmpty else { return "Keine Statusdaten" }
        return parts.joined(separator: " · ")
    }

    var statusParts: [String] {
        var parts: [String] = []

        if finished > 0 {
            parts.append("\(finished) gelesen")
        }

        if reading > 0 {
            parts.append("\(reading) lese ich")
        }

        if toRead > 0 {
            parts.append("\(toRead) geplant")
        }

        return parts
    }

    mutating func increment(statusRawValue: String) {
        switch ReadingStatus.fromPersisted(statusRawValue) ?? .toRead {
        case .toRead:
            toRead += 1
        case .reading:
            reading += 1
        case .finished:
            finished += 1
        }
    }
}

nonisolated struct TagsDashboardEntry: Identifiable, Hashable {
    let tag: String
    let bookCount: Int
    let statusCounts: TagsDashboardStatusCounts

    var id: String {
        tag.lowercased()
    }
}

nonisolated struct TagsDashboardTopTag: Hashable {
    let tag: String
    let count: Int
}

nonisolated struct TagsDashboardSummary: Hashable {
    let totalBooks: Int
    let totalTags: Int
    let taggedBooksCount: Int
    let untaggedBooksCount: Int
    let topTag: TagsDashboardTopTag?
}

nonisolated struct TagsDashboardRelatedTag: Identifiable, Hashable {
    let tag: String
    let sharedBookCount: Int

    var id: String {
        tag.lowercased()
    }
}

nonisolated struct TagsDashboard: Hashable {
    let summary: TagsDashboardSummary
    let entries: [TagsDashboardEntry]
    let untaggedBookIDs: [UUID]
}

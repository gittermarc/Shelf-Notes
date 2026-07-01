import Foundation

nonisolated struct ReadingTimelineEntryDisplayItem: Hashable, Sendable, Identifiable {
    let completion: ReadingTimelineCompletionSnapshot
    let userRatingAverage: Double?

    var id: String {
        "completion-\(completion.id)"
    }

    var bookID: UUID {
        completion.bookID
    }

    var date: Date {
        completion.finishedAt
    }

    var title: String {
        completion.title
    }

    var author: String {
        completion.author
    }

    var attemptLabel: String? {
        completion.isReread ? completion.displayName : nil
    }
}

nonisolated struct ReadingTimelineYearDisplayStats: Hashable, Sendable {
    let year: Int
    let count: Int
    let uniqueBookCount: Int
    let rereadCount: Int
    let ratedCount: Int
    let averageRating: Double?
    let firstDate: Date?
    let lastDate: Date?
    let previewBookIDs: [UUID]

    static func empty(year: Int) -> ReadingTimelineYearDisplayStats {
        ReadingTimelineYearDisplayStats(
            year: year,
            count: 0,
            uniqueBookCount: 0,
            rereadCount: 0,
            ratedCount: 0,
            averageRating: nil,
            firstDate: nil,
            lastDate: nil,
            previewBookIDs: []
        )
    }

    var dateRangeText: String? {
        guard let firstDate, let lastDate else { return nil }
        let start = firstDate.formatted(.dateTime.day().month(.twoDigits))
        let end = lastDate.formatted(.dateTime.day().month(.twoDigits))
        return "\(start) – \(end)"
    }

    var averageRatingText: String? {
        guard let averageRating else { return nil }
        let rounded = (averageRating * 10).rounded() / 10
        return String(format: "%.1f", rounded)
    }
}

nonisolated struct ReadingTimelineDisplayItem: Hashable, Sendable, Identifiable {
    enum Kind: Hashable, Sendable {
        case year(Int, ReadingTimelineYearDisplayStats)
        case completion(ReadingTimelineEntryDisplayItem)
    }

    let kind: Kind

    var id: String {
        switch kind {
        case .year(let year, _):
            return "year-\(year)"
        case .completion(let item):
            return item.id
        }
    }
}

nonisolated struct ReadingTimelineDisplayState: Hashable, Sendable {
    let years: [Int]
    let items: [ReadingTimelineDisplayItem]
    let completionCount: Int
    let rereadCompletionCount: Int

    static let empty = ReadingTimelineDisplayState(
        years: [],
        items: [],
        completionCount: 0,
        rereadCompletionCount: 0
    )
}

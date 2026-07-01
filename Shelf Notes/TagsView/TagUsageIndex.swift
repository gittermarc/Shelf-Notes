import Foundation

nonisolated struct TagUsageIndex {
    nonisolated struct Entry: Identifiable, Hashable {
        let key: String
        let tag: String
        let bookIDs: [UUID]
        let statusCounts: TagsDashboardStatusCounts
        let originalSpellings: [String]

        var id: String { key }

        var count: Int {
            bookIDs.count
        }
    }

    let entries: [Entry]
    let entriesByKey: [String: Entry]
    let untaggedBookIDs: [UUID]
    let taggedBookIDsCount: Int
    let totalTagUsages: Int

    var normalizedTags: [String] {
        entries.map(\.tag)
    }

    var tagCounts: [TagsIndexBuilder.TagCount] {
        entries.map { TagsIndexBuilder.TagCount(tag: $0.tag, count: $0.count) }
    }

    var originalSpellingsByKey: [String: [String]] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.originalSpellings) })
    }

    func bookIDs(matching normalizedTag: String) -> [UUID] {
        let key = normalizedTag.lowercased()
        return entriesByKey[key]?.bookIDs ?? []
    }
}

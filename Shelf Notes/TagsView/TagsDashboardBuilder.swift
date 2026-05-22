import Foundation

enum TagsDashboardBuilder {

    private struct TagAggregate {
        var tag: String
        var bookCount: Int
        var statusCounts: TagsDashboardStatusCounts
    }

    static func makeSnapshots(books: [Book]) -> [TagsDashboardBookSnapshot] {
        books.map { book in
            TagsDashboardBookSnapshot(
                id: book.id,
                title: book.title,
                author: book.author,
                statusRawValue: book.statusRawValue,
                tags: book.tags
            )
        }
    }

    static func build(snapshots: [TagsDashboardBookSnapshot]) -> TagsDashboard {
        var aggregates: [String: TagAggregate] = [:]
        var taggedBookIDs: Set<UUID> = []
        var untaggedBookIDs: [UUID] = []

        for book in snapshots {
            let tags = normalizedTags(for: book)

            if tags.isEmpty {
                untaggedBookIDs.append(book.id)
                continue
            }

            taggedBookIDs.insert(book.id)

            for tag in tags {
                let key = tag.lowercased()
                var aggregate = aggregates[key] ?? TagAggregate(
                    tag: tag,
                    bookCount: 0,
                    statusCounts: TagsDashboardStatusCounts()
                )

                aggregate.bookCount += 1
                aggregate.statusCounts.increment(statusRawValue: book.statusRawValue)
                aggregates[key] = aggregate
            }
        }

        let entries = aggregates.values
            .map { aggregate in
                TagsDashboardEntry(
                    tag: aggregate.tag,
                    bookCount: aggregate.bookCount,
                    statusCounts: aggregate.statusCounts
                )
            }
            .sorted { lhs, rhs in
                sortMostUsed(lhs, rhs)
            }

        let topTag = entries.first.map { entry in
            TagsDashboardTopTag(tag: entry.tag, count: entry.bookCount)
        }

        let summary = TagsDashboardSummary(
            totalBooks: snapshots.count,
            totalTags: entries.count,
            taggedBooksCount: taggedBookIDs.count,
            untaggedBooksCount: untaggedBookIDs.count,
            topTag: topTag
        )

        return TagsDashboard(
            summary: summary,
            entries: entries,
            untaggedBookIDs: untaggedBookIDs
        )
    }

    static func filteredEntries(
        _ entries: [TagsDashboardEntry],
        searchText: String,
        sortMode: TagsDashboardSortMode
    ) -> [TagsDashboardEntry] {
        let query = normalizeTagString(searchText).lowercased()
        let filtered: [TagsDashboardEntry]

        if query.isEmpty {
            filtered = entries
        } else {
            filtered = entries.filter { entry in
                entry.tag.lowercased().localizedStandardContains(query)
            }
        }

        return filtered.sorted { lhs, rhs in
            switch sortMode {
            case .mostUsed:
                return sortMostUsed(lhs, rhs)
            case .alphabetic:
                return lhs.tag.localizedCaseInsensitiveCompare(rhs.tag) == .orderedAscending
            case .leastUsed:
                if lhs.bookCount != rhs.bookCount {
                    return lhs.bookCount < rhs.bookCount
                }

                return lhs.tag.localizedCaseInsensitiveCompare(rhs.tag) == .orderedAscending
            }
        }
    }

    static func bookIDs(matching tag: String, snapshots: [TagsDashboardBookSnapshot]) -> [UUID] {
        let normalizedTag = normalizeTagString(tag)
        guard !normalizedTag.isEmpty else { return [] }

        return snapshots.compactMap { book in
            let tags = normalizedTags(for: book)
            guard tags.contains(where: { $0.caseInsensitiveCompare(normalizedTag) == .orderedSame }) else {
                return nil
            }

            return book.id
        }
    }

    static func relatedTags(
        for tag: String,
        snapshots: [TagsDashboardBookSnapshot],
        limit: Int = 8
    ) -> [TagsDashboardRelatedTag] {
        let normalizedTag = normalizeTagString(tag)
        guard !normalizedTag.isEmpty else { return [] }

        struct Aggregate {
            var tag: String
            var sharedBookCount: Int
        }

        var aggregates: [String: Aggregate] = [:]

        for book in snapshots {
            let tags = normalizedTags(for: book)
            guard tags.contains(where: { $0.caseInsensitiveCompare(normalizedTag) == .orderedSame }) else {
                continue
            }

            for otherTag in tags where otherTag.caseInsensitiveCompare(normalizedTag) != .orderedSame {
                let key = otherTag.lowercased()
                var aggregate = aggregates[key] ?? Aggregate(tag: otherTag, sharedBookCount: 0)
                aggregate.sharedBookCount += 1
                aggregates[key] = aggregate
            }
        }

        return aggregates.values
            .map { TagsDashboardRelatedTag(tag: $0.tag, sharedBookCount: $0.sharedBookCount) }
            .sorted { lhs, rhs in
                if lhs.sharedBookCount != rhs.sharedBookCount {
                    return lhs.sharedBookCount > rhs.sharedBookCount
                }

                return lhs.tag.localizedCaseInsensitiveCompare(rhs.tag) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }

    static func normalizedTags(for book: TagsDashboardBookSnapshot) -> [String] {
        TagsIndexBuilder.uniqueNormalizedTags(book.tags)
    }

    static func isUntagged(_ book: TagsDashboardBookSnapshot) -> Bool {
        normalizedTags(for: book).isEmpty
    }

    private static func sortMostUsed(_ lhs: TagsDashboardEntry, _ rhs: TagsDashboardEntry) -> Bool {
        if lhs.bookCount != rhs.bookCount {
            return lhs.bookCount > rhs.bookCount
        }

        return lhs.tag.localizedCaseInsensitiveCompare(rhs.tag) == .orderedAscending
    }
}

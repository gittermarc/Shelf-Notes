import Foundation

enum TagsDashboardBuilder {

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
        build(index: TagsDomainIndex(snapshots: snapshots))
    }

    static func build(index: TagsDomainIndex) -> TagsDashboard {
        let entries = index.usageIndex.entries.map { usage in
            TagsDashboardEntry(
                tag: usage.tag,
                bookCount: usage.count,
                statusCounts: usage.statusCounts
            )
        }

        let topTag = entries.first.map { entry in
            TagsDashboardTopTag(tag: entry.tag, count: entry.bookCount)
        }

        let summary = TagsDashboardSummary(
            totalBooks: index.totalBooks,
            totalTags: entries.count,
            taggedBooksCount: index.usageIndex.taggedBookIDsCount,
            untaggedBooksCount: index.usageIndex.untaggedBookIDs.count,
            topTag: topTag
        )

        return TagsDashboard(
            summary: summary,
            entries: entries,
            untaggedBookIDs: index.usageIndex.untaggedBookIDs
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
        bookIDs(matching: tag, index: TagsDomainIndex(snapshots: snapshots))
    }

    static func bookIDs(matching tag: String, index: TagsDomainIndex) -> [UUID] {
        let normalizedTag = normalizeTagString(tag)
        guard !normalizedTag.isEmpty else { return [] }

        return index.usageIndex.bookIDs(matching: normalizedTag)
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

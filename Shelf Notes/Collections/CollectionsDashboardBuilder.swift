import Foundation

enum CollectionsDashboardBuilder {

    static func makeBookSnapshots(books: [Book]) -> [CollectionsDashboardBookSnapshot] {
        books.map { book in
            CollectionsDashboardBookSnapshot(
                id: book.id,
                title: book.title,
                author: book.author,
                statusRawValue: book.statusRawValue,
                tags: book.tags,
                userRatingAverage: book.userRatingAverage
            )
        }
    }

    static func makeCollectionSnapshots(collections: [BookCollection]) -> [CollectionsDashboardCollectionSnapshot] {
        collections.map { collection in
            CollectionsDashboardCollectionSnapshot(
                id: collection.id,
                name: collection.name,
                createdAt: collection.createdAt,
                updatedAt: collection.updatedAt,
                books: makeBookSnapshots(books: collection.booksSafe)
            )
        }
    }

    static func build(
        collections: [CollectionsDashboardCollectionSnapshot],
        allBooks: [CollectionsDashboardBookSnapshot]
    ) -> CollectionsDashboard {
        var assignedBookIDs = Set<UUID>()

        let entries = collections.map { collection in
            var statusCounts = CollectionsDashboardStatusCounts()
            var representativeBookIDs: [UUID] = []

            for book in collection.books {
                assignedBookIDs.insert(book.id)
                statusCounts.increment(statusRawValue: book.statusRawValue)

                if representativeBookIDs.count < 4 {
                    representativeBookIDs.append(book.id)
                }
            }

            return CollectionsDashboardEntry(
                id: collection.id,
                name: collection.name,
                createdAt: collection.createdAt,
                updatedAt: collection.updatedAt,
                bookCount: collection.books.count,
                statusCounts: statusCounts,
                representativeBookIDs: representativeBookIDs
            )
        }
        .sorted { lhs, rhs in
            sortRecentActivity(lhs, rhs)
        }

        let allBookIDs = allBooks.map(\.id)
        let unassignedBookIDs = allBookIDs.filter { !assignedBookIDs.contains($0) }
        let largestCollection = entries.max { lhs, rhs in
            if lhs.bookCount != rhs.bookCount {
                return lhs.bookCount < rhs.bookCount
            }

            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedDescending
        }
        .map { entry in
            CollectionsDashboardHighlight(
                id: entry.id,
                name: entry.displayName,
                bookCount: entry.bookCount
            )
        }

        let summary = CollectionsDashboardSummary(
            totalBooks: allBooks.count,
            totalCollections: collections.count,
            booksInCollectionsCount: assignedBookIDs.count,
            unassignedBooksCount: unassignedBookIDs.count,
            activeCollectionsCount: entries.filter(\.hasActiveBooks).count,
            largestCollection: largestCollection
        )

        return CollectionsDashboard(
            summary: summary,
            entries: entries,
            unassignedBookIDs: unassignedBookIDs
        )
    }

    static func filteredEntries(
        _ entries: [CollectionsDashboardEntry],
        searchText: String,
        sortMode: CollectionsDashboardSortMode
    ) -> [CollectionsDashboardEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered: [CollectionsDashboardEntry]

        if query.isEmpty {
            filtered = entries
        } else {
            filtered = entries.filter { entry in
                entry.displayName.lowercased().localizedStandardContains(query)
            }
        }

        return filtered.sorted { lhs, rhs in
            switch sortMode {
            case .recentActivity:
                return sortRecentActivity(lhs, rhs)
            case .mostBooks:
                if lhs.bookCount != rhs.bookCount {
                    return lhs.bookCount > rhs.bookCount
                }

                return sortByName(lhs, rhs)
            case .progress:
                let lhsProgress = lhs.statusCounts.progressFraction
                let rhsProgress = rhs.statusCounts.progressFraction

                if lhsProgress != rhsProgress {
                    return lhsProgress > rhsProgress
                }

                if lhs.bookCount != rhs.bookCount {
                    return lhs.bookCount > rhs.bookCount
                }

                return sortByName(lhs, rhs)
            case .name:
                return sortByName(lhs, rhs)
            }
        }
    }

    private static func sortRecentActivity(_ lhs: CollectionsDashboardEntry, _ rhs: CollectionsDashboardEntry) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }

        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }

        return sortByName(lhs, rhs)
    }

    private static func sortByName(_ lhs: CollectionsDashboardEntry, _ rhs: CollectionsDashboardEntry) -> Bool {
        lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }
}

import Foundation

enum CollectionDetailBuilder {

    static func makeBookSnapshots(books: [Book]) -> [CollectionDetailBookSnapshot] {
        var seenBookIDs = Set<UUID>()
        var snapshots: [CollectionDetailBookSnapshot] = []
        snapshots.reserveCapacity(books.count)

        for book in books where seenBookIDs.insert(book.id).inserted {
            snapshots.append(
                CollectionDetailBookSnapshot(
                    id: book.id,
                    title: book.title,
                    author: book.author,
                    statusRawValue: book.statusRawValue,
                    createdAt: book.createdAt,
                    readFrom: book.readFrom,
                    readTo: book.readTo,
                    userRatingAverage: book.userRatingAverage1
                )
            )
        }

        return snapshots
    }

    static func build(
        collectionName: String,
        books: [CollectionDetailBookSnapshot]
    ) -> CollectionDetailState {
        var statusCounts = CollectionsDashboardStatusCounts()
        var representativeBookIDs: [UUID] = []

        for book in books {
            statusCounts.increment(statusRawValue: book.statusRawValue)

            if representativeBookIDs.count < 4 {
                representativeBookIDs.append(book.id)
            }
        }

        return CollectionDetailState(
            collectionName: collectionName,
            bookCount: books.count,
            statusCounts: statusCounts,
            representativeBookIDs: representativeBookIDs
        )
    }

    static func filteredBooks(
        _ books: [CollectionDetailBookSnapshot],
        searchText: String,
        statusFilter: CollectionDetailStatusFilter,
        sortMode: CollectionDetailSortMode
    ) -> [CollectionDetailBookSnapshot] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered = books.filter { book in
            guard statusFilter.includes(statusRawValue: book.statusRawValue) else { return false }
            guard !query.isEmpty else { return true }

            return book.title.lowercased().localizedStandardContains(query)
                || book.author.lowercased().localizedStandardContains(query)
        }

        return filtered.sorted { lhs, rhs in
            switch sortMode {
            case .title:
                return sortByTitle(lhs, rhs)
            case .author:
                return sortByAuthor(lhs, rhs)
            case .status:
                return sortByStatus(lhs, rhs)
            case .rating:
                return sortByRating(lhs, rhs)
            case .readDate:
                return sortByReadDate(lhs, rhs)
            }
        }
    }

    private static func sortByTitle(
        _ lhs: CollectionDetailBookSnapshot,
        _ rhs: CollectionDetailBookSnapshot
    ) -> Bool {
        let titleResult = displayTitle(lhs).localizedCaseInsensitiveCompare(displayTitle(rhs))
        if titleResult != .orderedSame {
            return titleResult == .orderedAscending
        }

        return displayAuthor(lhs).localizedCaseInsensitiveCompare(displayAuthor(rhs)) == .orderedAscending
    }

    private static func sortByAuthor(
        _ lhs: CollectionDetailBookSnapshot,
        _ rhs: CollectionDetailBookSnapshot
    ) -> Bool {
        let authorResult = displayAuthor(lhs).localizedCaseInsensitiveCompare(displayAuthor(rhs))
        if authorResult != .orderedSame {
            return authorResult == .orderedAscending
        }

        return sortByTitle(lhs, rhs)
    }

    private static func sortByStatus(
        _ lhs: CollectionDetailBookSnapshot,
        _ rhs: CollectionDetailBookSnapshot
    ) -> Bool {
        let lhsRank = statusRank(lhs.statusRawValue)
        let rhsRank = statusRank(rhs.statusRawValue)

        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }

        return sortByTitle(lhs, rhs)
    }

    private static func sortByRating(
        _ lhs: CollectionDetailBookSnapshot,
        _ rhs: CollectionDetailBookSnapshot
    ) -> Bool {
        switch (lhs.userRatingAverage, rhs.userRatingAverage) {
        case let (left?, right?) where left != right:
            return left > right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return sortByTitle(lhs, rhs)
        }
    }

    private static func sortByReadDate(
        _ lhs: CollectionDetailBookSnapshot,
        _ rhs: CollectionDetailBookSnapshot
    ) -> Bool {
        switch (readDate(lhs), readDate(rhs)) {
        case let (left?, right?) where left != right:
            return left > right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return sortByTitle(lhs, rhs)
        }
    }

    private static func displayTitle(_ book: CollectionDetailBookSnapshot) -> String {
        let trimmed = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Ohne Titel" : trimmed
    }

    private static func displayAuthor(_ book: CollectionDetailBookSnapshot) -> String {
        let trimmed = book.author.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unbekannter Autor" : trimmed
    }

    private static func readDate(_ book: CollectionDetailBookSnapshot) -> Date? {
        book.readTo ?? book.readFrom
    }

    private static func statusRank(_ statusRawValue: String) -> Int {
        switch ReadingStatus.fromPersisted(statusRawValue) {
        case .reading:
            return 0
        case .toRead:
            return 1
        case .finished:
            return 2
        case .none:
            return 3
        }
    }
}

import Foundation

enum CollectionsSmartActionBuilder {

    static func makeHubActions(
        dashboard: CollectionsDashboard,
        collections: [CollectionsDashboardCollectionSnapshot],
        allBooks: [CollectionsDashboardBookSnapshot],
        limit: Int = 3
    ) -> [CollectionsSmartAction] {
        var actions: [CollectionsSmartAction] = []

        if let action = makeUnassignedBooksAction(dashboard: dashboard) {
            actions.append(action)
        }

        if let action = makeEmptyCollectionsAction(entries: dashboard.entries) {
            actions.append(action)
        }

        if let action = makeActiveCollectionAction(entries: dashboard.entries) {
            actions.append(action)
        }

        if let action = makeUnratedFinishedBooksAction(
            dashboard: dashboard,
            collections: collections,
            allBooks: allBooks
        ) {
            actions.append(action)
        }

        if let action = makeTagClusterAction(allBooks: allBooks) {
            actions.append(action)
        } else if let action = makeAuthorClusterAction(allBooks: allBooks) {
            actions.append(action)
        }

        if let action = makeLargeCollectionAction(entries: dashboard.entries) {
            actions.append(action)
        }

        return actions
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority {
                    return lhs.priority < rhs.priority
                }

                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .prefix(max(0, limit))
            .map { $0 }
    }

    static func makeNextAction(
        collectionName: String,
        books: [CollectionDetailBookSnapshot]
    ) -> CollectionNextAction? {
        if books.isEmpty {
            return CollectionNextAction(
                id: "add-books",
                kind: .addBooks,
                title: "Bücher hinzufügen",
                message: "Diese Liste ist bereit für ihr erstes kuratiertes Regal.",
                detail: "Starte mit ein paar passenden Titeln aus deiner Bibliothek.",
                systemImage: "rectangle.stack.badge.plus",
                bookID: nil,
                ctaTitle: "Bücher auswählen"
            )
        }

        if let activeBook = preferredActiveBook(from: books) {
            return CollectionNextAction(
                id: "continue-\(activeBook.id.uuidString)",
                kind: .continueReading,
                title: "Weiterlesen",
                message: "„\(displayTitle(activeBook))“ ist in dieser Liste gerade aktiv.",
                detail: "Öffne das Buch und halte deinen Lesefluss zusammen mit dieser Liste aktuell.",
                systemImage: "book.pages",
                bookID: activeBook.id,
                ctaTitle: "Buch öffnen"
            )
        }

        if let unratedBook = preferredUnratedFinishedBook(from: books) {
            return CollectionNextAction(
                id: "rate-\(unratedBook.id.uuidString)",
                kind: .rateFinishedBook,
                title: "Noch bewerten",
                message: "„\(displayTitle(unratedBook))“ ist gelesen, aber noch ohne deine Bewertung.",
                detail: "Eine Bewertung macht die Liste später deutlich aussagekräftiger.",
                systemImage: "star.leadinghalf.filled",
                bookID: unratedBook.id,
                ctaTitle: "Bewerten"
            )
        }

        if let plannedBook = preferredPlannedBook(from: books) {
            return CollectionNextAction(
                id: "start-\(plannedBook.id.uuidString)",
                kind: .startPlannedBook,
                title: "Als Nächstes starten",
                message: "„\(displayTitle(plannedBook))“ wartet als nächster guter Kandidat.",
                detail: "Perfekt, wenn du diese Liste wieder in Bewegung bringen willst.",
                systemImage: "bookmark",
                bookID: plannedBook.id,
                ctaTitle: "Buch öffnen"
            )
        }

        if books.allSatisfy({ ReadingStatus.fromPersisted($0.statusRawValue) == .finished }) {
            return CollectionNextAction(
                id: "completed-\(safeCollectionName(collectionName).lowercased())",
                kind: .completed,
                title: "Liste abgeschlossen",
                message: "Alle Bücher in „\(safeCollectionName(collectionName))“ sind gelesen.",
                detail: "Das ist ein schöner Abschluss. Diese Liste darf ruhig als fertiges Regal glänzen.",
                systemImage: "checkmark.seal",
                bookID: nil,
                ctaTitle: nil
            )
        }

        return nil
    }

    private static func makeUnassignedBooksAction(
        dashboard: CollectionsDashboard
    ) -> CollectionsSmartAction? {
        let count = dashboard.summary.unassignedBooksCount
        guard count > 0 else { return nil }

        let title = count == 1 ? "1 Buch ohne Liste" : "\(count) Bücher ohne Liste"
        let detail = dashboard.summary.totalCollections == 0
            ? "Erstelle deine erste Liste und bündle passende Titel."
            : "Gib diesen Büchern einen Kontext, bevor sie in der Bibliothek untergehen."

        return CollectionsSmartAction(
            id: "unassigned-books",
            kind: .unassignedBooks,
            title: title,
            message: "Ein Teil deiner Bibliothek ist noch nicht kuratiert.",
            detail: detail,
            systemImage: "tray",
            priority: 0,
            collectionID: nil,
            relatedBookIDs: dashboard.unassignedBookIDs,
            ctaTitle: nil
        )
    }

    private static func makeEmptyCollectionsAction(
        entries: [CollectionsDashboardEntry]
    ) -> CollectionsSmartAction? {
        let emptyEntries = entries
            .filter { $0.bookCount == 0 }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }

        guard let first = emptyEntries.first else { return nil }

        let title = emptyEntries.count == 1
            ? "Leere Liste befüllen"
            : "\(emptyEntries.count) leere Listen befüllen"

        return CollectionsSmartAction(
            id: "empty-collections",
            kind: .emptyCollections,
            title: title,
            message: "„\(first.displayName)“ wartet noch auf Bücher.",
            detail: "Öffne die Liste und füge direkt passende Titel hinzu.",
            systemImage: "rectangle.stack.badge.plus",
            priority: 1,
            collectionID: first.id,
            relatedBookIDs: [],
            ctaTitle: "Liste öffnen"
        )
    }

    private static func makeActiveCollectionAction(
        entries: [CollectionsDashboardEntry]
    ) -> CollectionsSmartAction? {
        let activeEntries = entries
            .filter { $0.statusCounts.reading > 0 }
            .sorted { lhs, rhs in
                if lhs.statusCounts.reading != rhs.statusCounts.reading {
                    return lhs.statusCounts.reading > rhs.statusCounts.reading
                }

                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }

                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }

        guard let first = activeEntries.first else { return nil }

        let activeText = first.statusCounts.reading == 1
            ? "1 laufendes Buch"
            : "\(first.statusCounts.reading) laufende Bücher"

        return CollectionsSmartAction(
            id: "active-\(first.id.uuidString)",
            kind: .activeCollection,
            title: "Aktive Liste im Blick",
            message: "„\(first.displayName)“ hat gerade \(activeText).",
            detail: "Guter Ort, um direkt in deinen aktuellen Lesekontext zurückzuspringen.",
            systemImage: "book.pages",
            priority: 2,
            collectionID: first.id,
            relatedBookIDs: [],
            ctaTitle: "Weiter zur Liste"
        )
    }

    private static func makeUnratedFinishedBooksAction(
        dashboard: CollectionsDashboard,
        collections: [CollectionsDashboardCollectionSnapshot],
        allBooks: [CollectionsDashboardBookSnapshot]
    ) -> CollectionsSmartAction? {
        let unassignedBookIDs = Set(dashboard.unassignedBookIDs)
        let assignedFinishedBooks = allBooks.filter { book in
            !unassignedBookIDs.contains(book.id)
                && ReadingStatus.fromPersisted(book.statusRawValue) == .finished
                && book.userRatingAverage == nil
        }

        guard !assignedFinishedBooks.isEmpty else { return nil }

        let firstCollection = collections
            .filter { collection in
                collection.books.contains { book in
                    assignedFinishedBooks.contains(where: { $0.id == book.id })
                }
            }
            .sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }

                return displayName(lhs.name).localizedCaseInsensitiveCompare(displayName(rhs.name)) == .orderedAscending
            }
            .first

        let title = assignedFinishedBooks.count == 1
            ? "1 gelesenes Buch bewerten"
            : "\(assignedFinishedBooks.count) gelesene Bücher bewerten"

        return CollectionsSmartAction(
            id: "unrated-finished",
            kind: .unratedFinishedBooks,
            title: title,
            message: "Einige fertige Bücher in deinen Listen haben noch keine Bewertung.",
            detail: "Bewertungen machen deine kuratierten Regale später deutlich hilfreicher.",
            systemImage: "star.leadinghalf.filled",
            priority: 3,
            collectionID: firstCollection?.id,
            relatedBookIDs: assignedFinishedBooks.map { $0.id },
            ctaTitle: firstCollection == nil ? nil : "Liste öffnen"
        )
    }

    private static func makeTagClusterAction(
        allBooks: [CollectionsDashboardBookSnapshot]
    ) -> CollectionsSmartAction? {
        let clusters = groupedBooksByTag(allBooks)
            .filter { $0.value.bookIDs.count >= 3 }
            .sorted { lhs, rhs in
                if lhs.value.bookIDs.count != rhs.value.bookIDs.count {
                    return lhs.value.bookIDs.count > rhs.value.bookIDs.count
                }

                return lhs.value.displayName.localizedCaseInsensitiveCompare(rhs.value.displayName) == .orderedAscending
            }

        guard let cluster = clusters.first else { return nil }
        let count = cluster.value.bookIDs.count

        return CollectionsSmartAction(
            id: "tag-cluster-\(cluster.key)",
            kind: .tagCluster,
            title: "Thema bündeln",
            message: "Du hast \(count) Bücher mit dem Tag „\(cluster.value.displayName)“.",
            detail: "Das könnte eine starke eigene Leseliste werden.",
            systemImage: "tag",
            priority: 4,
            collectionID: nil,
            relatedBookIDs: cluster.value.bookIDs,
            ctaTitle: nil
        )
    }

    private static func makeAuthorClusterAction(
        allBooks: [CollectionsDashboardBookSnapshot]
    ) -> CollectionsSmartAction? {
        let clusters = groupedBooksByAuthor(allBooks)
            .filter { $0.value.bookIDs.count >= 3 }
            .sorted { lhs, rhs in
                if lhs.value.bookIDs.count != rhs.value.bookIDs.count {
                    return lhs.value.bookIDs.count > rhs.value.bookIDs.count
                }

                return lhs.value.displayName.localizedCaseInsensitiveCompare(rhs.value.displayName) == .orderedAscending
            }

        guard let cluster = clusters.first else { return nil }
        let count = cluster.value.bookIDs.count

        return CollectionsSmartAction(
            id: "author-cluster-\(cluster.key)",
            kind: .authorCluster,
            title: "Autor bündeln",
            message: "\(count) Bücher von „\(cluster.value.displayName)“ passen gut in eine eigene Liste.",
            detail: "Gerade Reihen oder Lieblingsautoren gehen so nicht im Regal unter.",
            systemImage: "person.text.rectangle",
            priority: 5,
            collectionID: nil,
            relatedBookIDs: cluster.value.bookIDs,
            ctaTitle: nil
        )
    }

    private static func makeLargeCollectionAction(
        entries: [CollectionsDashboardEntry]
    ) -> CollectionsSmartAction? {
        let largeEntries = entries
            .filter { $0.bookCount >= 18 }
            .sorted { lhs, rhs in
                if lhs.bookCount != rhs.bookCount {
                    return lhs.bookCount > rhs.bookCount
                }

                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }

        guard let first = largeEntries.first else { return nil }

        return CollectionsSmartAction(
            id: "large-\(first.id.uuidString)",
            kind: .largeCollection,
            title: "Große Liste im Blick behalten",
            message: "„\(first.displayName)“ enthält schon \(first.bookCount) Bücher.",
            detail: "Filter und Sortierung helfen, damit daraus kein zweites Bücherchaos wird.",
            systemImage: "square.stack.3d.up",
            priority: 6,
            collectionID: first.id,
            relatedBookIDs: [],
            ctaTitle: "Liste öffnen"
        )
    }

    private static func preferredActiveBook(
        from books: [CollectionDetailBookSnapshot]
    ) -> CollectionDetailBookSnapshot? {
        books
            .filter { ReadingStatus.fromPersisted($0.statusRawValue) == .reading }
            .sorted { lhs, rhs in
                if lhs.readFrom != rhs.readFrom {
                    return (lhs.readFrom ?? .distantPast) > (rhs.readFrom ?? .distantPast)
                }

                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }

                return displayTitle(lhs).localizedCaseInsensitiveCompare(displayTitle(rhs)) == .orderedAscending
            }
            .first
    }

    private static func preferredUnratedFinishedBook(
        from books: [CollectionDetailBookSnapshot]
    ) -> CollectionDetailBookSnapshot? {
        books
            .filter { book in
                ReadingStatus.fromPersisted(book.statusRawValue) == .finished
                    && book.userRatingAverage == nil
            }
            .sorted { lhs, rhs in
                if lhs.readTo != rhs.readTo {
                    return (lhs.readTo ?? .distantPast) > (rhs.readTo ?? .distantPast)
                }

                return displayTitle(lhs).localizedCaseInsensitiveCompare(displayTitle(rhs)) == .orderedAscending
            }
            .first
    }

    private static func preferredPlannedBook(
        from books: [CollectionDetailBookSnapshot]
    ) -> CollectionDetailBookSnapshot? {
        books
            .filter { ReadingStatus.fromPersisted($0.statusRawValue) == .toRead }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }

                return displayTitle(lhs).localizedCaseInsensitiveCompare(displayTitle(rhs)) == .orderedAscending
            }
            .first
    }

    private static func groupedBooksByTag(
        _ books: [CollectionsDashboardBookSnapshot]
    ) -> [String: Cluster] {
        var clusters: [String: Cluster] = [:]

        for book in books {
            var seenTagsForBook = Set<String>()

            for tag in book.tags {
                let normalized = normalizeKey(tag)
                guard !normalized.isEmpty else { continue }
                guard seenTagsForBook.insert(normalized).inserted else { continue }

                var cluster = clusters[normalized] ?? Cluster(displayName: displayName(tag), bookIDs: [])
                cluster.bookIDs.append(book.id)
                clusters[normalized] = cluster
            }
        }

        return clusters
    }

    private static func groupedBooksByAuthor(
        _ books: [CollectionsDashboardBookSnapshot]
    ) -> [String: Cluster] {
        var clusters: [String: Cluster] = [:]

        for book in books {
            let normalized = normalizeKey(book.author)
            guard !normalized.isEmpty else { continue }

            var cluster = clusters[normalized] ?? Cluster(displayName: displayName(book.author), bookIDs: [])
            cluster.bookIDs.append(book.id)
            clusters[normalized] = cluster
        }

        return clusters
    }

    private static func normalizeKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private static func displayName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Ohne Namen" : trimmed
    }

    private static func safeCollectionName(_ value: String) -> String {
        displayName(value)
    }

    private static func displayTitle(_ book: CollectionDetailBookSnapshot) -> String {
        let trimmed = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Ohne Titel" : trimmed
    }

    private struct Cluster {
        let displayName: String
        var bookIDs: [UUID]
    }
}

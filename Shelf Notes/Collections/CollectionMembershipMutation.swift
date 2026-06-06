import Foundation

enum CollectionMembershipMutation {

    @discardableResult
    static func setMembership(
        _ isMember: Bool,
        book: Book,
        collection: BookCollection,
        now: Date = Date()
    ) -> Bool {
        if isMember {
            return add(book, to: collection, now: now)
        }

        return remove(book, from: collection, now: now)
    }

    @discardableResult
    static func add(
        _ book: Book,
        to collection: BookCollection,
        now: Date = Date()
    ) -> Bool {
        let currentCollections = book.collectionsSafe
        let isLinkedFromBook = containsCollection(collection.id, in: currentCollections)

        let currentBooks = collection.booksSafe
        let isLinkedFromCollection = containsBook(book.id, in: currentBooks)

        guard !isLinkedFromBook || !isLinkedFromCollection else { return false }

        if !isLinkedFromBook {
            var updatedCollections = currentCollections
            updatedCollections.append(collection)
            book.collectionsSafe = updatedCollections
        }

        if !isLinkedFromCollection {
            var updatedBooks = currentBooks
            updatedBooks.append(book)
            collection.booksSafe = updatedBooks
        }

        collection.updatedAt = now
        return true
    }

    @discardableResult
    static func add(
        _ books: [Book],
        to collection: BookCollection,
        now: Date = Date()
    ) -> Int {
        let uniqueBooks = uniqueBooksPreservingOrder(books)
        guard !uniqueBooks.isEmpty else { return 0 }

        var collectionBooks = collection.booksSafe
        var collectionBookIDs = Set(collectionBooks.map(\.id))
        var changedBookIDs = Set<UUID>()
        var didChangeCollectionBooks = false

        for book in uniqueBooks {
            let currentCollections = book.collectionsSafe
            if !containsCollection(collection.id, in: currentCollections) {
                var updatedCollections = currentCollections
                updatedCollections.append(collection)
                book.collectionsSafe = updatedCollections
                changedBookIDs.insert(book.id)
            }

            if collectionBookIDs.insert(book.id).inserted {
                collectionBooks.append(book)
                changedBookIDs.insert(book.id)
                didChangeCollectionBooks = true
            }
        }

        guard !changedBookIDs.isEmpty else { return 0 }

        if didChangeCollectionBooks {
            collection.booksSafe = collectionBooks
        }
        collection.updatedAt = now
        return changedBookIDs.count
    }

    @discardableResult
    static func remove(
        _ book: Book,
        from collection: BookCollection,
        now: Date = Date()
    ) -> Bool {
        let currentCollections = book.collectionsSafe
        let updatedCollections = currentCollections.filter { $0.id != collection.id }
        let didChangeBookCollections = updatedCollections.count != currentCollections.count

        let currentBooks = collection.booksSafe
        let updatedBooks = currentBooks.filter { $0.id != book.id }
        let didChangeCollectionBooks = updatedBooks.count != currentBooks.count

        guard didChangeBookCollections || didChangeCollectionBooks else { return false }

        if didChangeBookCollections {
            book.collectionsSafe = updatedCollections
        }

        if didChangeCollectionBooks {
            collection.booksSafe = updatedBooks
        }

        collection.updatedAt = now
        return true
    }

    @discardableResult
    static func remove(
        _ books: [Book],
        from collection: BookCollection,
        now: Date = Date()
    ) -> Int {
        let uniqueBooks = uniqueBooksPreservingOrder(books)
        guard !uniqueBooks.isEmpty else { return 0 }

        let bookIDsToRemove = Set(uniqueBooks.map(\.id))
        var changedBookIDs = Set<UUID>()

        for book in uniqueBooks {
            let currentCollections = book.collectionsSafe
            let updatedCollections = currentCollections.filter { $0.id != collection.id }
            guard updatedCollections.count != currentCollections.count else { continue }

            book.collectionsSafe = updatedCollections
            changedBookIDs.insert(book.id)
        }

        let currentBooks = collection.booksSafe
        var removedCollectionBookIDs = Set<UUID>()
        let updatedBooks = currentBooks.filter { book in
            let shouldRemove = bookIDsToRemove.contains(book.id)
            if shouldRemove {
                removedCollectionBookIDs.insert(book.id)
            }
            return !shouldRemove
        }

        if updatedBooks.count != currentBooks.count {
            collection.booksSafe = updatedBooks
            changedBookIDs.formUnion(removedCollectionBookIDs)
        }

        guard !changedBookIDs.isEmpty else { return 0 }
        collection.updatedAt = now
        return changedBookIDs.count
    }

    @discardableResult
    static func removeCollectionReferences(
        _ collection: BookCollection,
        from books: [Book],
        now: Date = Date()
    ) -> Int {
        remove(books, from: collection, now: now)
    }

    private static func containsBook(_ bookID: UUID, in books: [Book]) -> Bool {
        books.contains { $0.id == bookID }
    }

    private static func containsCollection(_ collectionID: UUID, in collections: [BookCollection]) -> Bool {
        collections.contains { $0.id == collectionID }
    }

    private static func uniqueBooksPreservingOrder(_ books: [Book]) -> [Book] {
        var seenIDs = Set<UUID>()
        var result: [Book] = []
        result.reserveCapacity(books.count)

        for book in books where seenIDs.insert(book.id).inserted {
            result.append(book)
        }

        return result
    }
}

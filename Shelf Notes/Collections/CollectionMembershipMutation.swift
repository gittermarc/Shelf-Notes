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
        var didChange = false

        let originalCollections = book.collectionsSafe
        var normalizedCollections = dedupCollections(originalCollections)
        if normalizedCollections.count != originalCollections.count {
            didChange = true
        }

        if !normalizedCollections.contains(where: { $0.id == collection.id }) {
            normalizedCollections.append(collection)
            didChange = true
        }

        let originalBooks = collection.booksSafe
        var normalizedBooks = dedupBooks(originalBooks)
        if normalizedBooks.count != originalBooks.count {
            didChange = true
        }

        if !normalizedBooks.contains(where: { $0.id == book.id }) {
            normalizedBooks.append(book)
            didChange = true
        }

        guard didChange else { return false }
        book.collectionsSafe = normalizedCollections
        collection.booksSafe = normalizedBooks
        collection.updatedAt = now
        return true
    }

    @discardableResult
    static func add(
        _ books: [Book],
        to collection: BookCollection,
        now: Date = Date()
    ) -> Int {
        var changedCount = 0

        for book in books {
            if add(book, to: collection, now: now) {
                changedCount += 1
            }
        }

        return changedCount
    }

    @discardableResult
    static func remove(
        _ book: Book,
        from collection: BookCollection,
        now: Date = Date()
    ) -> Bool {
        var didChange = false

        let originalCollections = book.collectionsSafe
        var normalizedCollections = dedupCollections(originalCollections)
        if normalizedCollections.count != originalCollections.count {
            didChange = true
        }

        let collectionCountBeforeRemoval = normalizedCollections.count
        normalizedCollections.removeAll { $0.id == collection.id }
        if normalizedCollections.count != collectionCountBeforeRemoval {
            didChange = true
        }

        let originalBooks = collection.booksSafe
        var normalizedBooks = dedupBooks(originalBooks)
        if normalizedBooks.count != originalBooks.count {
            didChange = true
        }

        let bookCountBeforeRemoval = normalizedBooks.count
        normalizedBooks.removeAll { $0.id == book.id }
        if normalizedBooks.count != bookCountBeforeRemoval {
            didChange = true
        }

        guard didChange else { return false }
        book.collectionsSafe = normalizedCollections
        collection.booksSafe = normalizedBooks
        collection.updatedAt = now
        return true
    }

    @discardableResult
    static func remove(
        _ books: [Book],
        from collection: BookCollection,
        now: Date = Date()
    ) -> Int {
        var changedCount = 0

        for book in books {
            if remove(book, from: collection, now: now) {
                changedCount += 1
            }
        }

        return changedCount
    }

    @discardableResult
    static func removeCollectionReferences(
        _ collection: BookCollection,
        from books: [Book],
        now: Date = Date()
    ) -> Int {
        remove(books, from: collection, now: now)
    }

    private static func dedupBooks(_ input: [Book]) -> [Book] {
        var seen = Set<UUID>()
        var output: [Book] = []
        output.reserveCapacity(input.count)

        for book in input {
            if seen.insert(book.id).inserted {
                output.append(book)
            }
        }

        return output
    }

    private static func dedupCollections(_ input: [BookCollection]) -> [BookCollection] {
        var seen = Set<UUID>()
        var output: [BookCollection] = []
        output.reserveCapacity(input.count)

        for collection in input {
            if seen.insert(collection.id).inserted {
                output.append(collection)
            }
        }

        return output
    }
}

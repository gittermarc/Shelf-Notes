//
//  Book+Collections.swift
//  Shelf Notes
//

import Foundation

extension Book {
    /// Komfort: nil wie leeres Array behandeln
    var collectionsSafe: [BookCollection] {
        get { collections ?? [] }
        set { collections = newValue }
    }

    /// Komfort: nil wie leeres Array behandeln
    var readingSessionsSafe: [ReadingSession] {
        get { readingSessions ?? [] }
        set { readingSessions = newValue }
    }

    func isInCollection(_ collection: BookCollection) -> Bool {
        collectionsSafe.contains(where: { $0.id == collection.id })
    }

    func addToCollection(_ collection: BookCollection) {
        if isInCollection(collection) { return }
        var items = collectionsSafe
        items.append(collection)
        collectionsSafe = items
    }

    func removeFromCollection(_ collection: BookCollection) {
        var items = collectionsSafe
        items.removeAll { $0.id == collection.id }
        collectionsSafe = items
    }
}

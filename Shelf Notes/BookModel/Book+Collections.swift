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
        CollectionMembershipMutation.add(self, to: collection)
    }

    func removeFromCollection(_ collection: BookCollection) {
        CollectionMembershipMutation.remove(self, from: collection)
    }
}

//
//  LibraryHomeSnapshot.swift
//  Shelf Notes
//
//  Value-only model for the Smart Shelf home area in the library.
//

import Foundation

extension LibraryView {
    nonisolated struct LibraryHomeSnapshot: Equatable {
        let continueReadingBookID: UUID?
        let quickStats: [LibraryHomeStat]
        let lanes: [LibraryHomeLane]

        static let empty = LibraryHomeSnapshot(
            continueReadingBookID: nil,
            quickStats: [],
            lanes: []
        )
    }

    nonisolated struct LibraryHomeStat: Equatable, Identifiable {
        let id: String
        let title: String
        let value: Int
        let systemImage: String
    }

    nonisolated struct LibraryHomeLane: Equatable, Identifiable {
        enum Kind: String, CaseIterable {
            case currentlyReading
            case recentlyAdded
            case recentlyFinished
            case topRated
        }

        let kind: Kind
        let title: String
        let systemImage: String
        let bookIDs: [UUID]

        var id: String { kind.rawValue }
    }
}

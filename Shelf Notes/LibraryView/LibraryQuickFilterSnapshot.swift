//
//  LibraryQuickFilterSnapshot.swift
//  Shelf Notes
//
//  Value-only discovery shortcuts for the Smart Shelf dashboard.
//

import Foundation

extension LibraryView {
    nonisolated struct LibraryQuickFilterSnapshot: Equatable {
        let tagItems: [LibraryQuickFilterItem]
        let collectionItems: [LibraryQuickFilterItem]

        static let empty = LibraryQuickFilterSnapshot(tagItems: [], collectionItems: [])

        var isEmpty: Bool {
            tagItems.isEmpty && collectionItems.isEmpty
        }
    }

    nonisolated struct LibraryQuickFilterItem: Equatable, Identifiable {
        enum Kind: String, Equatable {
            case tag
            case collection
        }

        let kind: Kind
        let title: String
        let normalizedValue: String
        let count: Int
        let systemImage: String

        var id: String {
            "\(kind.rawValue)-\(normalizedValue)"
        }
    }
}

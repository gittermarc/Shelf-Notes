//
//  LibraryShelfMaintenanceSummary.swift
//  Shelf Notes
//
//  Value-only summary for Smart Shelf maintenance hints.
//

import Foundation

extension LibraryView {
    nonisolated struct LibraryShelfMaintenanceSummary: Equatable {
        let items: [LibraryShelfMaintenanceItem]

        static let empty = LibraryShelfMaintenanceSummary(items: [])

        var isEmpty: Bool {
            items.isEmpty
        }

        var totalCount: Int {
            items.reduce(0) { partialResult, item in
                partialResult + item.count
            }
        }

        func count(for smartFilter: LibrarySmartFilter) -> Int {
            items.first { $0.smartFilter == smartFilter }?.count ?? 0
        }
    }

    nonisolated struct LibraryShelfMaintenanceItem: Equatable, Identifiable {
        let smartFilter: LibrarySmartFilter
        let title: String
        let count: Int
        let systemImage: String

        var id: String {
            smartFilter.rawValue
        }
    }
}

//
//  LibraryShelfMaintenanceBuilder.swift
//  Shelf Notes
//
//  Pure builder for Smart Shelf maintenance counts.
//

import Foundation

extension LibraryView {
    nonisolated enum LibraryShelfMaintenanceBuilder {
        static func makeSummary(
            source: LibrarySourceSnapshot,
            longInactiveCutoff: Date?
        ) -> LibraryShelfMaintenanceSummary {
            makeSummary(books: source.books, longInactiveCutoff: longInactiveCutoff)
        }

        static func makeSummary(
            books: [LibrarySourceSnapshot.BookSnapshot],
            longInactiveCutoff: Date?
        ) -> LibraryShelfMaintenanceSummary {
            guard books.isEmpty == false else { return .empty }

            let items: [LibraryShelfMaintenanceItem] = LibrarySmartFilter.maintenanceFilters.compactMap { smartFilter in
                let count = countMatches(
                    books: books,
                    smartFilter: smartFilter,
                    longInactiveCutoff: longInactiveCutoff
                )

                guard count > 0 else { return nil }

                return LibraryShelfMaintenanceItem(
                    smartFilter: smartFilter,
                    title: smartFilter.maintenanceTitle,
                    count: count,
                    systemImage: smartFilter.systemImage
                )
            }

            return LibraryShelfMaintenanceSummary(items: items)
        }

        static func countMatches(
            books: [LibrarySourceSnapshot.BookSnapshot],
            smartFilter: LibrarySmartFilter,
            longInactiveCutoff: Date?
        ) -> Int {
            books.reduce(0) { partialResult, book in
                smartFilter.matches(book, longInactiveCutoff: longInactiveCutoff)
                    ? partialResult + 1
                    : partialResult
            }
        }
    }
}

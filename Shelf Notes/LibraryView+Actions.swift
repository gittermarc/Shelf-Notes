//
//  LibraryView+Actions.swift
//  Shelf Notes
//
//  Extracted from LibraryView.swift to reduce file size and improve maintainability.
//

import Foundation
import SwiftData

extension LibraryView {

    // MARK: - Data integrity

    func enforceRatingRuleIfNeeded() {
        // Ratings are only allowed for finished books.
        // If older app versions left ratings on non-finished books, clean them up.
        let invalid = books.filter { b in
            b.status != .finished && b.userRatingValues.contains(where: { $0 > 0 })
        }

        guard !invalid.isEmpty else { return }

        for b in invalid {
            b.clearUserRatings()
        }

        modelContext.saveWithDiagnostics()
    }

    // MARK: - Delete

    func deleteBook(_ book: Book) {
        modelContext.delete(book)
        modelContext.saveWithDiagnostics()
    }

    func deleteBooks(at offsets: IndexSet, in displayedBooks: [Book]) {
        for index in offsets {
            guard displayedBooks.indices.contains(index) else { continue }
            modelContext.delete(displayedBooks[index])
        }
        modelContext.saveWithDiagnostics()
    }

    func deleteBooksInSection(_ sectionBooks: [Book], offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sectionBooks[index])
        }
        modelContext.saveWithDiagnostics()
    }
}

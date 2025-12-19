//
//  BookCollection.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 19.12.25.
//

import Foundation
import SwiftData

@Model
final class BookCollection {
    // CloudKit/SwiftData: kein @Attribute(.unique)
    var id: UUID = UUID()

    var name: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // ✅ Many-to-many
    // CloudKit: Beziehungen müssen optional sein
    // -> kein @Relationship-Macro nötig (und bei dir zuletzt problematisch)
    var books: [Book]?

    // Komfort: nil wie leeres Array behandeln
    var booksSafe: [Book] {
        get { books ?? [] }
        set { books = newValue }
    }

    init(name: String) {
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.books = nil
    }
}

// MARK: - Books helpers

extension BookCollection {
    func contains(_ book: Book) -> Bool {
        booksSafe.contains(where: { $0.id == book.id })
    }

    func addBook(_ book: Book) {
        if contains(book) { return }
        var arr = booksSafe
        arr.append(book)
        booksSafe = arr
        updatedAt = Date()
    }

    func removeBook(_ book: Book) {
        var arr = booksSafe
        arr.removeAll { $0.id == book.id }
        booksSafe = arr
        updatedAt = Date()
    }
}

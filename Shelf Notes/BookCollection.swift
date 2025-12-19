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
    // -> KEIN @Relationship Macro (macht bei dir gerade Ärger)
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

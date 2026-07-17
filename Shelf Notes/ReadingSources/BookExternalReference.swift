//
//  BookExternalReference.swift
//  Shelf Notes
//

import Foundation
import SwiftData

/// A provider-specific reference for one library item.
@Model
final class BookExternalReference {
    // CloudKit/SwiftData: avoid @Attribute(.unique).
    var id: UUID = UUID()

    var book: Book?
    var providerRawValue: String = ReadingProvider.none.rawValue
    var providerItemIdentifier: String = ""
    var canonicalURL: String?
    var isbn13: String?
    var editionNote: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        book: Book? = nil,
        provider: ReadingProvider,
        providerItemIdentifier: String,
        canonicalURL: String? = nil,
        isbn13: String? = nil,
        editionNote: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = UUID()
        self.book = book
        self.providerRawValue = provider.rawValue
        self.providerItemIdentifier = providerItemIdentifier
        self.canonicalURL = canonicalURL
        self.isbn13 = isbn13
        self.editionNote = editionNote
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension BookExternalReference {
    var provider: ReadingProvider {
        get { ReadingProvider.fromPersisted(providerRawValue) }
        set {
            providerRawValue = newValue.rawValue
            updatedAt = Date()
        }
    }
}

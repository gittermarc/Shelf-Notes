//
//  ReadingAnnotation.swift
//  Shelf Notes
//

import Foundation
import SwiftData

/// A provider-independent highlight, note or bookmark.
@Model
final class ReadingAnnotation {
    // CloudKit/SwiftData: avoid @Attribute(.unique).
    var id: UUID = UUID()

    var book: Book?
    var readingAttempt: ReadingAttempt?
    var kindRawValue: String = ReadingAnnotationKind.note.rawValue
    var providerRawValue: String = ReadingProvider.none.rawValue
    var originRawValue: String = ReadingSessionOrigin.legacy.rawValue
    var selectedText: String?
    var note: String?
    var locator: String?
    var normalizedProgress: Double?
    var externalIdentifier: String?

    /// Stable application-level deduplication key. It is intentionally not unique.
    var deduplicationKey: String = ""

    var importedAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        book: Book? = nil,
        readingAttempt: ReadingAttempt? = nil,
        kind: ReadingAnnotationKind,
        provider: ReadingProvider = .none,
        origin: ReadingSessionOrigin = .legacy,
        selectedText: String? = nil,
        note: String? = nil,
        locator: String? = nil,
        normalizedProgress: Double? = nil,
        externalIdentifier: String? = nil,
        deduplicationKey: String,
        importedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = UUID()
        self.book = book
        self.readingAttempt = readingAttempt
        self.kindRawValue = kind.rawValue
        self.providerRawValue = provider.rawValue
        self.originRawValue = origin.rawValue
        self.selectedText = selectedText
        self.note = note
        self.locator = locator
        self.normalizedProgress = normalizedProgress
        self.externalIdentifier = externalIdentifier
        self.deduplicationKey = deduplicationKey
        self.importedAt = importedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension ReadingAnnotation {
    var kind: ReadingAnnotationKind {
        get { ReadingAnnotationKind.fromPersisted(kindRawValue) }
        set {
            kindRawValue = newValue.rawValue
            updatedAt = Date()
        }
    }

    var provider: ReadingProvider {
        get { ReadingProvider.fromPersisted(providerRawValue) }
        set {
            providerRawValue = newValue.rawValue
            updatedAt = Date()
        }
    }

    var origin: ReadingSessionOrigin {
        get { ReadingSessionOrigin.fromPersisted(originRawValue) }
        set {
            originRawValue = newValue.rawValue
            updatedAt = Date()
        }
    }
}

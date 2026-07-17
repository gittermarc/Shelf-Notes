//
//  ReadingProgressEvent.swift
//  Shelf Notes
//

import Foundation
import SwiftData

/// A format-neutral progress observation from a manual or external source.
@Model
final class ReadingProgressEvent {
    // CloudKit/SwiftData: avoid @Attribute(.unique).
    var id: UUID = UUID()

    /// The library item this progress belongs to.
    var book: Book?

    /// Optional reading pass this progress belongs to.
    var readingAttempt: ReadingAttempt?

    var occurredAt: Date = Date()
    var mediumRawValue: String = ReadingMedium.physical.rawValue
    var providerRawValue: String = ReadingProvider.none.rawValue
    var progressUnitRawValue: String = ReadingProgressUnit.none.rawValue
    var nativeValue: Double = 0
    var totalValue: Double?
    var normalizedProgress: Double?
    var locator: String?
    var originRawValue: String = ReadingSessionOrigin.legacy.rawValue
    var externalIdentifier: String?

    /// Stable application-level deduplication key. It is intentionally not unique.
    var deduplicationKey: String = ""

    /// Optional source session without a second SwiftData relationship.
    var sourceSessionID: UUID?

    var importedAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        book: Book? = nil,
        readingAttempt: ReadingAttempt? = nil,
        occurredAt: Date = Date(),
        medium: ReadingMedium = .physical,
        provider: ReadingProvider = .none,
        progressUnit: ReadingProgressUnit = .none,
        nativeValue: Double,
        totalValue: Double? = nil,
        normalizedProgress: Double? = nil,
        locator: String? = nil,
        origin: ReadingSessionOrigin = .legacy,
        externalIdentifier: String? = nil,
        deduplicationKey: String,
        sourceSessionID: UUID? = nil,
        importedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = UUID()
        self.book = book
        self.readingAttempt = readingAttempt
        self.occurredAt = occurredAt
        self.mediumRawValue = medium.rawValue
        self.providerRawValue = provider.rawValue
        self.progressUnitRawValue = progressUnit.rawValue
        self.nativeValue = nativeValue
        self.totalValue = totalValue
        self.normalizedProgress = normalizedProgress
        self.locator = locator
        self.originRawValue = origin.rawValue
        self.externalIdentifier = externalIdentifier
        self.deduplicationKey = deduplicationKey
        self.sourceSessionID = sourceSessionID
        self.importedAt = importedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension ReadingProgressEvent {
    var medium: ReadingMedium {
        get { ReadingMedium.fromPersisted(mediumRawValue) }
        set {
            mediumRawValue = newValue.rawValue
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

    var progressUnit: ReadingProgressUnit {
        get { ReadingProgressUnit.fromPersisted(progressUnitRawValue) }
        set {
            progressUnitRawValue = newValue.rawValue
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

//
//  ReadingAttempt.swift
//  Shelf Notes
//

import Foundation
import SwiftData

/// A concrete reading pass for a book.
///
/// `Book` remains the library item. `ReadingAttempt` captures one actual pass
/// through that book, so rereads can keep their own dates, progress and sessions.
@Model
final class ReadingAttempt {
    // CloudKit/SwiftData: avoid @Attribute(.unique).
    var id: UUID = UUID()

    /// Human-readable order within a book: 1st pass, 2nd pass, etc.
    var sequenceNumber: Int = 1

    /// Stable persisted status code.
    var statusRawValue: String = ReadingAttemptStatus.active.rawValue

    /// Start date of this pass. Optional for older/partially repaired data.
    var startedAt: Date?

    /// Finish date of this pass. Optional while active or for incomplete legacy data.
    var finishedAt: Date?

    /// Snapshot of the book's page count when this pass was created/finished.
    /// This keeps old attempts stable if metadata is corrected later.
    var pageCountSnapshot: Int?

    /// Format-neutral source metadata for this concrete reading pass.
    var readingMediumRawValue: String = ReadingMedium.physical.rawValue
    var defaultProviderRawValue: String = ReadingProvider.none.rawValue
    var progressUnitRawValue: String = ReadingProgressUnit.pages.rawValue

    /// Optional total in the native progress unit used by this pass.
    var totalValueSnapshot: Double?

    /// Provider-side item identifier. Never stores credentials or file paths.
    var providerItemIdentifier: String?

    var lastExternalSyncAt: Date?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// The book this pass belongs to.
    /// The inverse is `Book.readingAttempts`.
    var book: Book?

    /// Sessions assigned to this pass.
    ///
    /// The delete rule is intentionally nullify. Deleting an attempt should not
    /// delete session history; deleting a book still cascades sessions via
    /// `Book.readingSessions`.
    @Relationship(deleteRule: .nullify, inverse: \ReadingSession.readingAttempt)
    var sessions: [ReadingSession]?

    /// Progress history survives deletion of an individual reading attempt.
    @Relationship(deleteRule: .nullify, inverse: \ReadingProgressEvent.readingAttempt)
    var progressEvents: [ReadingProgressEvent]?

    /// Imported or manually created annotations survive attempt deletion.
    @Relationship(deleteRule: .nullify, inverse: \ReadingAnnotation.readingAttempt)
    var annotations: [ReadingAnnotation]?

    init(
        book: Book? = nil,
        sequenceNumber: Int = 1,
        status: ReadingAttemptStatus = .active,
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        pageCountSnapshot: Int? = nil,
        readingMedium: ReadingMedium = .physical,
        defaultProvider: ReadingProvider = .none,
        progressUnit: ReadingProgressUnit = .pages,
        totalValueSnapshot: Double? = nil,
        providerItemIdentifier: String? = nil,
        lastExternalSyncAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = UUID()
        self.book = book
        self.sequenceNumber = max(1, sequenceNumber)
        self.statusRawValue = status.rawValue
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.pageCountSnapshot = pageCountSnapshot
        self.readingMediumRawValue = readingMedium.rawValue
        self.defaultProviderRawValue = defaultProvider.rawValue
        self.progressUnitRawValue = progressUnit.rawValue
        self.totalValueSnapshot = totalValueSnapshot
        self.providerItemIdentifier = providerItemIdentifier
        self.lastExternalSyncAt = lastExternalSyncAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sessions = nil
        self.progressEvents = nil
        self.annotations = nil
    }
}

extension ReadingAttempt {
    var status: ReadingAttemptStatus {
        get { ReadingAttemptStatus.fromPersisted(statusRawValue) ?? .active }
        set {
            statusRawValue = newValue.rawValue
            updatedAt = Date()
        }
    }

    var sessionsSafe: [ReadingSession] {
        get { sessions ?? [] }
        set { sessions = newValue }
    }

    var displayName: String {
        "\(max(1, sequenceNumber)). Durchgang"
    }

    var isActive: Bool {
        status == .active
    }

    var isFinished: Bool {
        status == .finished
    }

    func contains(_ session: ReadingSession) -> Bool {
        sessionsSafe.contains { $0.id == session.id }
    }

    func addSessionIfNeeded(_ session: ReadingSession) {
        guard !contains(session) else { return }
        var updatedSessions = sessionsSafe
        updatedSessions.append(session)
        sessionsSafe = updatedSessions
        updatedAt = Date()
    }
}

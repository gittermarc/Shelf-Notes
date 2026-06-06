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

    init(
        book: Book? = nil,
        sequenceNumber: Int = 1,
        status: ReadingAttemptStatus = .active,
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        pageCountSnapshot: Int? = nil,
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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sessions = nil
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

//
//  ReadingSession.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 06.01.26.
//

import Foundation
import SwiftData

/// A single reading session for one book.
///
/// CloudKit integration requires that all relationships have an inverse.
/// The inverse relationship is declared on `Book.readingSessions`.
///
/// Important:
/// We do **not** attach `@Relationship(inverse: ...)` here because (depending on
/// your toolchain/Xcode) that can trigger a "Circular reference resolving attached macro 'Relationship'".
/// SwiftData can infer this side of the relationship automatically.
@Model
final class ReadingSession {
    // CloudKit/SwiftData: avoid @Attribute(.unique)
    var id: UUID = UUID()

    /// The book this session belongs to.
    /// The inverse is `Book.readingSessions`.
    var book: Book?

    /// When the session started.
    var startedAt: Date = Date()

    /// When the session ended.
    var endedAt: Date = Date()

    /// Cached duration in seconds (kept in sync via initializers / helper).
    /// This avoids having to recompute on every aggregation query.
    var durationSeconds: Int = 0

    /// Optional pages read during this session.
    var pagesRead: Int?

    /// Optional short note (e.g. "Kapitel 12 war wild").
    var note: String?

    /// Creation timestamp (useful for sorting even if startedAt is edited).
    var createdAt: Date = Date()

    /// Convenience: duration as TimeInterval.
    var duration: TimeInterval {
        TimeInterval(max(0, durationSeconds))
    }

    /// Convenience: returns a normalized, non-negative pages value (nil if <= 0).
    var pagesReadNormalized: Int? {
        guard let p = pagesRead, p > 0 else { return nil }
        return p
    }

    init(
        book: Book? = nil,
        startedAt: Date,
        endedAt: Date,
        pagesRead: Int? = nil,
        note: String? = nil
    ) {
        self.book = book
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = max(0, Int(endedAt.timeIntervalSince(startedAt).rounded()))
        self.pagesRead = pagesRead
        self.note = note
        self.createdAt = Date()
    }

    /// Alternative initializer when you only know the duration.
    init(
        book: Book? = nil,
        startAt: Date = Date(),
        durationSeconds: Int,
        pagesRead: Int? = nil,
        note: String? = nil
    ) {
        self.book = book
        self.startedAt = startAt
        self.endedAt = startAt.addingTimeInterval(TimeInterval(max(0, durationSeconds)))
        self.durationSeconds = max(0, durationSeconds)
        self.pagesRead = pagesRead
        self.note = note
        self.createdAt = Date()
    }

    /// Keeps `durationSeconds` consistent after edits.
    func recomputeDuration() {
        durationSeconds = max(0, Int(endedAt.timeIntervalSince(startedAt).rounded()))
    }
}

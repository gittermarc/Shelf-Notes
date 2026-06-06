//
//  ReadingAttemptRepair.swift
//  Shelf Notes
//

import Foundation
import SwiftData

/// Idempotent repair/backfill for the new Book -> ReadingAttempt -> ReadingSession model.
///
/// This intentionally does not use a one-time UserDefaults flag. CloudKit can sync
/// older books later, so the repair must be cheap and safe to run repeatedly.
@MainActor
enum ReadingAttemptRepair {

    @MainActor
    static func repairIfNeeded(modelContext: ModelContext) async {
        do {
            let descriptor = FetchDescriptor<Book>(
                sortBy: [SortDescriptor(\Book.createdAt, order: .forward)]
            )
            let books = try modelContext.fetch(descriptor)

            let didChange = repair(books: books, now: Date()) { attempt in
                modelContext.insert(attempt)
            }

            if didChange {
                _ = modelContext.saveWithDiagnostics()
            }
        } catch {
            #if DEBUG
            print("ReadingAttemptRepair failed: \(error)")
            #endif
        }
    }

    @discardableResult
    static func repair(
        books: [Book],
        now: Date = Date(),
        insertAttempt: (ReadingAttempt) -> Void = { _ in }
    ) -> Bool {
        var didChange = false

        for book in books {
            if repair(book: book, now: now, insertAttempt: insertAttempt) {
                didChange = true
            }
        }

        return didChange
    }

    @discardableResult
    static func repair(
        book: Book,
        now: Date,
        insertAttempt: (ReadingAttempt) -> Void
    ) -> Bool {
        var didChange = false
        var attempts = book.readingAttemptsSafe

        if attachSessionAttemptsToBook(book: book, attempts: &attempts) {
            didChange = true
        }

        let dedupedAttempts = dedupAttempts(attempts)
        if dedupedAttempts.map(\.id) != attempts.map(\.id) {
            attempts = dedupedAttempts
            book.readingAttemptsSafe = attempts
            didChange = true
        }

        if repairAttemptBacklinks(book: book, attempts: attempts, now: now) {
            didChange = true
        }

        switch book.status {
        case .finished:
            if ensureFinishedAttempt(book: book, attempts: &attempts, now: now, insertAttempt: insertAttempt) {
                didChange = true
            }

            if fillMissingFinishedMetadata(book: book, attempts: attempts, now: now) {
                didChange = true
            }

        case .reading:
            if ensureCompletedLegacyAttemptBeforeReread(book: book, attempts: &attempts, now: now, insertAttempt: insertAttempt) {
                didChange = true
            }

            if ensureActiveAttempt(book: book, attempts: &attempts, now: now, insertAttempt: insertAttempt) {
                didChange = true
            }

            if fillMissingActiveMetadata(book: book, attempts: attempts, now: now) {
                didChange = true
            }

        case .toRead:
            break
        }

        if repairSessionAssignments(book: book, attempts: ordered(book.readingAttemptsSafe), now: now) {
            didChange = true
        }

        return didChange
    }

    static func ensureFinishedAttempt(
        book: Book,
        attempts: inout [ReadingAttempt],
        now: Date,
        insertAttempt: (ReadingAttempt) -> Void
    ) -> Bool {
        guard attempts.contains(where: { $0.status == .finished }) == false else { return false }

        if let activeAttempt = ordered(attempts).last(where: { $0.status == .active }) {
            markFinished(activeAttempt, from: book, now: now)
        } else {
            appendAttempt(
                makeAttempt(book: book, attempts: attempts, status: .finished, now: now),
                to: book,
                attempts: &attempts,
                insertAttempt: insertAttempt
            )
        }

        return true
    }

    static func ensureCompletedLegacyAttemptBeforeReread(
        book: Book,
        attempts: inout [ReadingAttempt],
        now: Date,
        insertAttempt: (ReadingAttempt) -> Void
    ) -> Bool {
        guard attempts.contains(where: { $0.status == .finished }) == false else { return false }
        guard book.readTo != nil else { return false }

        if let activeAttempt = ordered(attempts).last(where: { $0.status == .active }) {
            markFinished(activeAttempt, from: book, now: now)
        } else {
            appendAttempt(
                makeAttempt(book: book, attempts: attempts, status: .finished, now: now),
                to: book,
                attempts: &attempts,
                insertAttempt: insertAttempt
            )
        }

        return true
    }

    static func ensureActiveAttempt(
        book: Book,
        attempts: inout [ReadingAttempt],
        now: Date,
        insertAttempt: (ReadingAttempt) -> Void
    ) -> Bool {
        guard attempts.contains(where: { $0.status == .active }) == false else { return false }

        appendAttempt(
            makeAttempt(book: book, attempts: attempts, status: .active, now: now),
            to: book,
            attempts: &attempts,
            insertAttempt: insertAttempt
        )

        return true
    }

    static func appendAttempt(
        _ attempt: ReadingAttempt,
        to book: Book,
        attempts: inout [ReadingAttempt],
        insertAttempt: (ReadingAttempt) -> Void
    ) {
        insertAttempt(attempt)
        attempts.append(attempt)
        book.readingAttemptsSafe = attempts
    }
}

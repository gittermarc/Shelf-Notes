//
//  ReadingShareInboxProcessor.swift
//  Shelf Notes
//

import Foundation
import SwiftData

enum ReadingShareInboxProcessingError: Error, Equatable {
    case bookNotFound
    case duplicateAnnotation
}

enum ReadingShareInboxProcessor {
    static func pendingItems(store: ReadingShareInboxStore? = nil) -> [ReadingShareInboxItem] {
        let resolvedStore: ReadingShareInboxStore
        if let store {
            resolvedStore = store
        } else if let appGroupStore = try? ReadingShareInboxStore() {
            resolvedStore = appGroupStore
        } else {
            return []
        }
        return resolvedStore.readItemsSafely().sorted { left, right in
            left.createdAt < right.createdAt
        }
    }

    static func resolve(
        item: ReadingShareInboxItem,
        modelContext: ModelContext
    ) -> ReadingShareResolution {
        let books = fetchBooks(modelContext: modelContext)
        return ReadingShareMatchResolver.resolve(item: item, books: books)
    }

    @discardableResult
    static func saveAnnotation(
        for item: ReadingShareInboxItem,
        bookID: UUID,
        modelContext: ModelContext,
        store: ReadingShareInboxStore? = nil,
        attachCanonicalReference: Bool,
        now: Date = Date()
    ) throws -> ReadingAnnotation {
        let books = fetchBooks(modelContext: modelContext)
        guard let book = books.first(where: { $0.id == bookID }) else {
            throw ReadingShareInboxProcessingError.bookNotFound
        }

        let deduplicationKey = ReadingShareAnnotationFactory.deduplicationKey(for: item)
        if annotationExists(deduplicationKey: deduplicationKey, modelContext: modelContext) {
            try resolvedStore(store)?.removeItems(withIDs: [item.id])
            throw ReadingShareInboxProcessingError.duplicateAnnotation
        }

        if attachCanonicalReference {
            attachExternalReferenceIfNeeded(
                item: item,
                book: book,
                modelContext: modelContext,
                now: now
            )
        }

        let annotation = ReadingShareAnnotationFactory.makeAnnotation(item: item, book: book, now: now)
        modelContext.insert(annotation)

        var annotations = book.readingAnnotationsSafe
        if !annotations.contains(where: { $0.deduplicationKey == annotation.deduplicationKey }) {
            annotations.append(annotation)
            book.readingAnnotationsSafe = annotations
        }

        if let attempt = book.activeReadingAttempt {
            var attemptAnnotations = attempt.annotationsSafe
            if !attemptAnnotations.contains(where: { $0.deduplicationKey == annotation.deduplicationKey }) {
                attemptAnnotations.append(annotation)
                attempt.annotationsSafe = attemptAnnotations
            }
        }

        modelContext.saveWithDiagnostics()
        try resolvedStore(store)?.removeItems(withIDs: [item.id])
        return annotation
    }

    static func discard(
        _ item: ReadingShareInboxItem,
        store: ReadingShareInboxStore? = nil
    ) throws {
        try resolvedStore(store)?.discard(item)
    }

    private static func fetchBooks(modelContext: ModelContext) -> [Book] {
        let descriptor = FetchDescriptor<Book>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private static func annotationExists(
        deduplicationKey: String,
        modelContext: ModelContext
    ) -> Bool {
        let descriptor = FetchDescriptor<ReadingAnnotation>(
            predicate: #Predicate<ReadingAnnotation> { annotation in
                annotation.deduplicationKey == deduplicationKey
            }
        )
        return ((try? modelContext.fetchCount(descriptor)) ?? 0) > 0
    }

    private static func attachExternalReferenceIfNeeded(
        item: ReadingShareInboxItem,
        book: Book,
        modelContext: ModelContext,
        now: Date
    ) {
        let payload = item.payload
        guard let canonicalURL = payload.canonicalURL, !canonicalURL.isEmpty else { return }
        guard ReadingShareURLClassifier.classify(rawString: canonicalURL) != nil else { return }

        let provider = payload.provider
        let providerIdentifier = payload.providerItemIdentifier ?? canonicalURL
        let existing = book.externalReferencesSafe.contains { reference in
            reference.provider == provider
                && (
                    reference.canonicalURL == canonicalURL
                    || reference.providerItemIdentifier == providerIdentifier
                )
        }
        guard !existing else { return }

        let reference = BookExternalReference(
            book: book,
            provider: provider,
            providerItemIdentifier: providerIdentifier,
            canonicalURL: canonicalURL,
            isbn13: payload.isbn13Candidates.first,
            createdAt: now,
            updatedAt: now
        )
        var references = book.externalReferencesSafe
        references.append(reference)
        book.externalReferencesSafe = references
        modelContext.insert(reference)
    }

    private static func resolvedStore(_ store: ReadingShareInboxStore?) -> ReadingShareInboxStore? {
        if let store { return store }
        return try? ReadingShareInboxStore()
    }
}

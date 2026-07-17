import Foundation
import SwiftData
import Testing
@testable import Shelf_Notes

struct ReadingSourcePersistenceTests {

    @Test @MainActor func legacyDefaultsPreserveAttemptAndSessionBehavior() {
        let book = Book(title: "Legacy", status: .reading)
        let attempt = ReadingAttempt(
            book: book,
            sequenceNumber: 0,
            status: .active,
            pageCountSnapshot: 320
        )
        let session = ReadingSession(
            book: book,
            startAt: Date(timeIntervalSince1970: 1_000),
            durationSeconds: 600,
            pagesRead: 24,
            note: "Kapitel 3"
        )

        #expect(attempt.sequenceNumber == 1)
        #expect(attempt.status == .active)
        #expect(attempt.pageCountSnapshot == 320)
        #expect(attempt.readingMedium == .physical)
        #expect(attempt.defaultProvider == .none)
        #expect(attempt.progressUnit == .pages)
        #expect(attempt.totalValueSnapshot == nil)
        #expect(attempt.providerItemIdentifier == nil)
        #expect(attempt.lastExternalSyncAt == nil)

        #expect(session.medium == .physical)
        #expect(session.provider == .none)
        #expect(session.origin == .legacy)
        #expect(session.progressUnit == .pages)
        #expect(session.durationSeconds == 600)
        #expect(session.pagesReadNormalized == 24)
        #expect(session.startValue == nil)
        #expect(session.endValue == nil)
        #expect(session.startNormalizedProgress == nil)
        #expect(session.endNormalizedProgress == nil)
        #expect(session.startLocator == nil)
        #expect(session.endLocator == nil)
        #expect(session.externalEventIdentifier == nil)

        attempt.readingMediumRawValue = "futureMedium"
        attempt.defaultProviderRawValue = "futureProvider"
        attempt.progressUnitRawValue = "chapters"
        session.mediumRawValue = "futureMedium"
        session.providerRawValue = "futureProvider"
        session.originRawValue = "automaticSync"
        session.progressUnitRawValue = "chapters"

        #expect(attempt.readingMedium == .physical)
        #expect(attempt.defaultProvider == .none)
        #expect(attempt.progressUnit == .none)
        #expect(session.medium == .physical)
        #expect(session.provider == .none)
        #expect(session.origin == .legacy)
        #expect(session.progressUnit == .none)

        attempt.addSessionIfNeeded(session)
        attempt.addSessionIfNeeded(session)
        #expect(attempt.sessionsSafe.map(\.id) == [session.id])

        attempt.readingMedium = .ebook
        #expect(book.isEbook == false)
    }

    @Test @MainActor func extendedInMemorySchemaPersistsReadingSourceRelationships() throws {
        let container = try ModelContainerFactory.makeContainer(mode: .inMemory)
        let context = ModelContext(container)
        let timestamp = Date(timeIntervalSince1970: 2_000)
        let sourceSessionID = UUID()

        let book = Book(title: "Digital Foundation", status: .reading)
        let attempt = ReadingAttempt(
            sequenceNumber: 1,
            status: .active,
            startedAt: timestamp,
            readingMedium: .ebook,
            defaultProvider: .kindle,
            progressUnit: .percentage,
            totalValueSnapshot: 100,
            providerItemIdentifier: "kindle-book-1",
            lastExternalSyncAt: timestamp
        )
        let session = ReadingSession(
            startedAt: timestamp,
            endedAt: timestamp.addingTimeInterval(900),
            pagesRead: nil,
            note: nil,
            medium: .ebook,
            provider: .kindle,
            origin: .providerImport,
            progressUnit: .percentage,
            startValue: 12,
            endValue: 18,
            startNormalizedProgress: 0.12,
            endNormalizedProgress: 0.18,
            startLocator: "kindle://location/120",
            endLocator: "kindle://location/180",
            externalEventIdentifier: "kindle-event-1"
        )
        let progressEvent = ReadingProgressEvent(
            occurredAt: timestamp,
            medium: .ebook,
            provider: .kindle,
            progressUnit: .percentage,
            nativeValue: 18,
            totalValue: 100,
            normalizedProgress: 0.18,
            locator: "kindle://location/180",
            origin: .providerImport,
            externalIdentifier: "kindle-progress-1",
            deduplicationKey: "kindle:kindle-progress-1",
            sourceSessionID: sourceSessionID,
            importedAt: timestamp,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let externalReference = BookExternalReference(
            provider: .kindle,
            providerItemIdentifier: "kindle-book-1",
            canonicalURL: "https://example.com/books/kindle-book-1",
            isbn13: "9781234567890",
            editionNote: "2026 digital edition",
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let annotation = ReadingAnnotation(
            kind: .highlight,
            provider: .kindle,
            origin: .providerImport,
            selectedText: "Fear is the mind-killer.",
            note: "Key passage",
            locator: "kindle://location/180",
            normalizedProgress: 0.18,
            externalIdentifier: "kindle-annotation-1",
            deduplicationKey: "kindle:kindle-annotation-1",
            importedAt: timestamp,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        context.insert(book)
        context.insert(attempt)
        context.insert(session)
        context.insert(progressEvent)
        context.insert(externalReference)
        context.insert(annotation)

        attempt.book = book
        session.book = book
        session.readingAttempt = attempt
        progressEvent.book = book
        progressEvent.readingAttempt = attempt
        externalReference.book = book
        annotation.book = book
        annotation.readingAttempt = attempt

        book.readingAttemptsSafe = [attempt]
        book.readingSessionsSafe = [session]
        book.readingProgressEventsSafe = [progressEvent]
        book.externalReferencesSafe = [externalReference]
        book.readingAnnotationsSafe = [annotation]
        attempt.sessionsSafe = [session]
        attempt.progressEventsSafe = [progressEvent]
        attempt.annotationsSafe = [annotation]

        try context.save()

        let books = try context.fetch(FetchDescriptor<Book>())
        let attempts = try context.fetch(FetchDescriptor<ReadingAttempt>())
        let sessions = try context.fetch(FetchDescriptor<ReadingSession>())
        let progressEvents = try context.fetch(FetchDescriptor<ReadingProgressEvent>())
        let externalReferences = try context.fetch(FetchDescriptor<BookExternalReference>())
        let annotations = try context.fetch(FetchDescriptor<ReadingAnnotation>())

        let persistedBook = try #require(books.first)
        let persistedAttempt = try #require(attempts.first)
        let persistedSession = try #require(sessions.first)
        let persistedProgressEvent = try #require(progressEvents.first)
        let persistedExternalReference = try #require(externalReferences.first)
        let persistedAnnotation = try #require(annotations.first)

        #expect(books.count == 1)
        #expect(attempts.count == 1)
        #expect(sessions.count == 1)
        #expect(progressEvents.count == 1)
        #expect(externalReferences.count == 1)
        #expect(annotations.count == 1)
        #expect(persistedBook.readingProgressEventsSafe.map(\.id) == [persistedProgressEvent.id])
        #expect(persistedBook.externalReferencesSafe.map(\.id) == [persistedExternalReference.id])
        #expect(persistedBook.readingAnnotationsSafe.map(\.id) == [persistedAnnotation.id])
        #expect(persistedAttempt.progressEventsSafe.map(\.id) == [persistedProgressEvent.id])
        #expect(persistedAttempt.annotationsSafe.map(\.id) == [persistedAnnotation.id])
        #expect(persistedSession.readingAttempt?.id == persistedAttempt.id)
        #expect(persistedProgressEvent.book?.id == persistedBook.id)
        #expect(persistedProgressEvent.readingAttempt?.id == persistedAttempt.id)
        #expect(persistedProgressEvent.sourceSessionID == sourceSessionID)
        #expect(persistedExternalReference.provider == .kindle)
        #expect(persistedExternalReference.book?.id == persistedBook.id)
        #expect(persistedAnnotation.kind == .highlight)
        #expect(persistedAnnotation.book?.id == persistedBook.id)
        #expect(persistedAnnotation.readingAttempt?.id == persistedAttempt.id)
    }

    @Test @MainActor func deletingAttemptPreservesSessionProgressAndAnnotations() throws {
        let container = try ModelContainerFactory.makeContainer(mode: .inMemory)
        let context = ModelContext(container)
        let timestamp = Date(timeIntervalSince1970: 3_000)

        let book = Book(title: "History", status: .reading)
        let attempt = ReadingAttempt(sequenceNumber: 1, status: .active)
        let session = ReadingSession(
            startedAt: timestamp,
            endedAt: timestamp.addingTimeInterval(300),
            pagesRead: 10
        )
        let progressEvent = ReadingProgressEvent(
            occurredAt: timestamp,
            progressUnit: .pages,
            nativeValue: 10,
            deduplicationKey: "session:progress"
        )
        let annotation = ReadingAnnotation(
            kind: .bookmark,
            locator: "page:10",
            deduplicationKey: "session:bookmark"
        )

        context.insert(book)
        context.insert(attempt)
        context.insert(session)
        context.insert(progressEvent)
        context.insert(annotation)

        attempt.book = book
        session.book = book
        session.readingAttempt = attempt
        progressEvent.book = book
        progressEvent.readingAttempt = attempt
        annotation.book = book
        annotation.readingAttempt = attempt

        book.readingAttemptsSafe = [attempt]
        book.readingSessionsSafe = [session]
        book.readingProgressEventsSafe = [progressEvent]
        book.readingAnnotationsSafe = [annotation]
        attempt.sessionsSafe = [session]
        attempt.progressEventsSafe = [progressEvent]
        attempt.annotationsSafe = [annotation]

        try context.save()
        context.delete(attempt)
        try context.save()

        let persistedSessions = try context.fetch(FetchDescriptor<ReadingSession>())
        let persistedProgressEvents = try context.fetch(FetchDescriptor<ReadingProgressEvent>())
        let persistedAnnotations = try context.fetch(FetchDescriptor<ReadingAnnotation>())
        let persistedAttempts = try context.fetch(FetchDescriptor<ReadingAttempt>())

        #expect(persistedAttempts.isEmpty)
        #expect(persistedSessions.count == 1)
        #expect(persistedProgressEvents.count == 1)
        #expect(persistedAnnotations.count == 1)
        #expect(persistedSessions.first?.readingAttempt == nil)
        #expect(persistedProgressEvents.first?.readingAttempt == nil)
        #expect(persistedAnnotations.first?.readingAttempt == nil)
        #expect(persistedSessions.first?.book?.id == book.id)
        #expect(persistedProgressEvents.first?.book?.id == book.id)
        #expect(persistedAnnotations.first?.book?.id == book.id)
    }
}

import Foundation
import SwiftData
import Testing
@testable import Shelf_Notes

struct ReadingProgressImportMutationServiceTests {

    @Test @MainActor func providerProgressImportCreatesNoSessionOrReadingTime() throws {
        let container = try ModelContainerFactory.makeContainer(mode: .inMemory)
        let context = ModelContext(container)
        let book = Book(title: "Provider", status: .toRead)
        context.insert(book)
        let timestamp = Date(timeIntervalSince1970: 2_200)
        let request = makeRequest(
            normalizedProgress: 0.35,
            externalIdentifier: "item-123",
            timestamp: timestamp
        )

        let first = try ReadingProgressImportMutationService.saveProgress(
            book: book,
            modelContext: context,
            request: request,
            allSessions: [],
            now: timestamp
        ).get()
        let second = try ReadingProgressImportMutationService.saveProgress(
            book: book,
            modelContext: context,
            request: request,
            allSessions: [],
            now: timestamp.addingTimeInterval(1)
        ).get()
        let sessions = try context.fetch(FetchDescriptor<ReadingSession>())
        let events = try context.fetch(FetchDescriptor<ReadingProgressEvent>())

        #expect(sessions.isEmpty)
        #expect(events.count == 1)
        #expect(first.event.id == second.event.id)
        #expect(first.snapshot.sourceSessionID == nil)
        #expect(book.status == .reading)
        #expect(book.readFrom == nil)
        #expect(book.readTo == nil)
    }

    @Test @MainActor func completedProviderImportFinishesWithoutCreatingReadingDay() throws {
        let container = try ModelContainerFactory.makeContainer(mode: .inMemory)
        let context = ModelContext(container)
        let book = Book(title: "Provider Completion", status: .toRead)
        context.insert(book)
        let timestamp = Date(timeIntervalSince1970: 2_250)

        let mutation = try ReadingProgressImportMutationService.saveProgress(
            book: book,
            modelContext: context,
            request: makeRequest(
                normalizedProgress: 1,
                externalIdentifier: "item-complete",
                timestamp: timestamp
            ),
            allSessions: [],
            now: timestamp
        ).get()
        let sessions = try context.fetch(FetchDescriptor<ReadingSession>())

        #expect(mutation.didMarkBookFinished)
        #expect(book.status == .finished)
        #expect(book.activeReadingAttempt == nil)
        #expect(book.completedReadingAttempts.count == 1)
        #expect(book.readFrom == nil)
        #expect(book.readTo == nil)
        #expect(sessions.isEmpty)
        #expect(mutation.snapshot.sourceSessionID == nil)
        #expect(mutation.snapshot.normalizedProgress == 1)
    }

    @Test @MainActor func matchingImportKeysOnDifferentBooksRemainSeparate() throws {
        let container = try ModelContainerFactory.makeContainer(mode: .inMemory)
        let context = ModelContext(container)
        let firstBook = Book(title: "First", status: .toRead)
        let secondBook = Book(title: "Second", status: .toRead)
        context.insert(firstBook)
        context.insert(secondBook)
        let timestamp = Date(timeIntervalSince1970: 2_275)
        let request = makeRequest(
            normalizedProgress: 0.5,
            externalIdentifier: "shared-provider-key",
            timestamp: timestamp
        )

        let first = try ReadingProgressImportMutationService.saveProgress(
            book: firstBook,
            modelContext: context,
            request: request,
            allSessions: [],
            now: timestamp
        ).get()
        let second = try ReadingProgressImportMutationService.saveProgress(
            book: secondBook,
            modelContext: context,
            request: request,
            allSessions: [],
            now: timestamp.addingTimeInterval(1)
        ).get()
        let events = try context.fetch(FetchDescriptor<ReadingProgressEvent>())

        #expect(events.count == 2)
        #expect(first.event.id != second.event.id)
        #expect(first.event.book?.id == firstBook.id)
        #expect(second.event.book?.id == secondBook.id)
    }

    private func makeRequest(
        normalizedProgress: Double,
        externalIdentifier: String,
        timestamp: Date
    ) -> ReadingProgressImportRequest {
        ReadingProgressImportRequest(
            update: .percentage(
                normalizedProgress: normalizedProgress,
                occurredAt: timestamp,
                stableIdentifier: "provider:\(externalIdentifier)"
            ),
            source: ReadingSessionSource(
                medium: .ebook,
                provider: .googleBooks,
                progressUnit: .percentage,
                origin: .providerImport,
                totalValue: 100
            ),
            externalIdentifier: externalIdentifier,
            deduplicationKey: ReadingProgressEventFingerprint.importedProgressKey(
                provider: .googleBooks,
                externalIdentifier: externalIdentifier
            ),
            importedAt: timestamp
        )
    }
}

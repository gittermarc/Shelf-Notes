import Foundation
import SwiftData
import Testing
@testable import Shelf_Notes

struct ReadingSessionDeletionServiceTests {

    @Test @MainActor func deletingSessionRemovesOnlyLinkedProgressEvents() throws {
        let container = try ModelContainerFactory.makeContainer(mode: .inMemory)
        let context = ModelContext(container)
        let book = Book(title: "Delete", status: .reading)
        book.pageCount = 200
        context.insert(book)
        let timing = ReadingSessionLogging.Timing(
            startedAt: Date(timeIntervalSince1970: 2_300),
            endedAt: Date(timeIntervalSince1970: 2_400)
        )
        let sessionMutation = try ReadingSessionMutationService.saveSession(
            book: book,
            modelContext: context,
            timing: timing,
            pages: 20,
            note: nil,
            allSessions: [],
            now: timing.endedAt
        ).get()
        let importRequest = ReadingProgressImportRequest(
            update: .percentage(
                normalizedProgress: 0.4,
                occurredAt: Date(timeIntervalSince1970: 2_450)
            ),
            source: ReadingSessionSource(
                medium: .ebook,
                provider: .other,
                progressUnit: .percentage,
                origin: .providerImport,
                totalValue: 100
            ),
            externalIdentifier: "unrelated",
            deduplicationKey: "provider-progress:other:unrelated",
            importedAt: Date(timeIntervalSince1970: 2_450)
        )
        let otherBook = Book(title: "Other", status: .toRead)
        context.insert(otherBook)
        let imported = try ReadingProgressImportMutationService.saveProgress(
            book: otherBook,
            modelContext: context,
            request: importRequest,
            allSessions: [],
            now: Date(timeIntervalSince1970: 2_450)
        ).get()

        let deletion = try ReadingSessionDeletionService.delete(
            session: sessionMutation.session,
            modelContext: context,
            now: Date(timeIntervalSince1970: 2_500)
        ).get()
        let sessions = try context.fetch(FetchDescriptor<ReadingSession>())
        let events = try context.fetch(FetchDescriptor<ReadingProgressEvent>())

        #expect(deletion.snapshots.map(\.id) == [sessionMutation.session.id])
        #expect(sessions.isEmpty)
        #expect(events.map(\.id) == [imported.event.id])
        #expect(events.first?.sourceSessionID == nil)
    }

    @Test @MainActor func deletionRemovesLinkedEventWhenSessionBookRelationshipIsMissing() throws {
        let container = try ModelContainerFactory.makeContainer(mode: .inMemory)
        let context = ModelContext(container)
        let book = Book(title: "Partial Relationship", status: .reading)
        book.pageCount = 100
        context.insert(book)
        let timing = ReadingSessionLogging.Timing(
            startedAt: Date(timeIntervalSince1970: 2_600),
            endedAt: Date(timeIntervalSince1970: 2_700)
        )
        let mutation = try ReadingSessionMutationService.saveSession(
            book: book,
            modelContext: context,
            timing: timing,
            pages: 10,
            note: nil,
            allSessions: [],
            now: timing.endedAt
        ).get()
        mutation.session.book = nil
        try context.save()

        _ = try ReadingSessionDeletionService.delete(
            session: mutation.session,
            modelContext: context,
            now: Date(timeIntervalSince1970: 2_800)
        ).get()
        let sessions = try context.fetch(FetchDescriptor<ReadingSession>())
        let events = try context.fetch(FetchDescriptor<ReadingProgressEvent>())

        #expect(sessions.isEmpty)
        #expect(events.isEmpty)
        #expect(book.readingProgressEventsSafe.isEmpty)
    }
}

import Foundation
import SwiftData
import Testing
@testable import Shelf_Notes

struct ReadingShareInboxProcessingTests {
    @Test @MainActor func existingExternalReferenceProducesSafeMatch() throws {
        let (context, _) = try makeContext()
        let book = Book(title: "Demo", author: "Author", status: .reading)
        let reference = BookExternalReference(
            book: book,
            provider: .appleBooks,
            providerItemIdentifier: "id123",
            canonicalURL: "https://books.apple.com/de/book/demo/id123"
        )
        book.externalReferencesSafe = [reference]
        context.insert(book)
        context.insert(reference)
        try context.save()

        let item = ReadingShareInboxItem(payload: applePayload(text: "Ein Highlight"))
        let resolution = ReadingShareInboxProcessor.resolve(item: item, modelContext: context)

        guard case .matched(let match) = resolution else {
            Issue.record("Expected an external reference match.")
            return
        }
        #expect(match.bookID == book.id)
        #expect(match.confidence == .confirmed)
    }

    @Test @MainActor func isbnProducesSafeMatchAfterReferences() throws {
        let (context, _) = try makeContext()
        let book = Book(title: "ISBN Book", author: "Author", status: .reading)
        book.isbn13 = "9783161484100"
        context.insert(book)
        try context.save()

        let item = ReadingShareInboxItem(
            payload: ReadingSharePayload(
                kind: .text,
                provider: .other,
                text: "ISBN 978-3-16-148410-0"
            )
        )
        let resolution = ReadingShareInboxProcessor.resolve(item: item, modelContext: context)

        guard case .matched(let match) = resolution else {
            Issue.record("Expected an ISBN match.")
            return
        }
        #expect(match.bookID == book.id)
        #expect(match.reason == "ISBN-Treffer")
    }

    @Test @MainActor func titleOnlyMatchRequiresConfirmation() throws {
        let (context, _) = try makeContext()
        let book = Book(title: "Unsicheres Buch", author: "Author", status: .reading)
        context.insert(book)
        try context.save()

        let item = ReadingShareInboxItem(
            payload: ReadingSharePayload(kind: .text, provider: .other, title: "Unsicheres Buch", text: "Notiz")
        )
        let resolution = ReadingShareInboxProcessor.resolve(item: item, modelContext: context)

        guard case .needsConfirmation(let match) = resolution else {
            Issue.record("Expected title-only candidate to require confirmation.")
            return
        }
        #expect(match.bookID == book.id)
        #expect(match.confidence == .needsUserConfirmation)
    }

    @Test @MainActor func missingMatchPreparesImportAndKeepsInboxEntry() throws {
        let (context, _) = try makeContext()
        let store = try makeStore()
        let item = ReadingShareInboxItem(payload: applePayload(text: nil))
        try store.append(item)

        let resolution = ReadingShareInboxProcessor.resolve(item: item, modelContext: context)

        guard case .needsImport(let preparedImport) = resolution else {
            Issue.record("Expected prepared import for unknown book.")
            return
        }
        #expect(!preparedImport.query.isEmpty)
        #expect(try store.readItems().map(\.id) == [item.id])
    }

    @Test @MainActor func interruptedProcessingKeepsInboxEntry() throws {
        let (context, _) = try makeContext()
        let store = try makeStore()
        let item = ReadingShareInboxItem(payload: applePayload(text: "Nicht speichern"))
        try store.append(item)

        #expect(throws: ReadingShareInboxProcessingError.bookNotFound) {
            try ReadingShareInboxProcessor.saveAnnotation(
                for: item,
                bookID: UUID(),
                modelContext: context,
                store: store,
                attachCanonicalReference: false
            )
        }

        #expect(try store.readItems().map(\.id) == [item.id])
        #expect(try context.fetch(FetchDescriptor<ReadingAnnotation>()).isEmpty)
    }

    @Test @MainActor func saveCreatesShareExtensionAnnotationAndNoSession() throws {
        let (context, _) = try makeContext()
        let store = try makeStore()
        let book = Book(title: "Demo", author: "Author", status: .reading)
        context.insert(book)
        try context.save()

        let item = ReadingShareInboxItem(payload: applePayload(text: "Highlight"))
        try store.append(item)

        let annotation = try ReadingShareInboxProcessor.saveAnnotation(
            for: item,
            bookID: book.id,
            modelContext: context,
            store: store,
            attachCanonicalReference: true,
            now: Date(timeIntervalSince1970: 500)
        )

        let annotations = try context.fetch(FetchDescriptor<ReadingAnnotation>())
        let sessions = try context.fetch(FetchDescriptor<ReadingSession>())
        #expect(annotations.count == 1)
        #expect(annotation.origin == .shareExtension)
        #expect(annotation.kind == .highlight)
        #expect(annotation.selectedText == "Highlight")
        #expect(annotation.externalIdentifier == item.id)
        #expect(sessions.isEmpty)
        #expect(try store.readItems().isEmpty)
    }

    @Test @MainActor func duplicateShareDoesNotCreateSecondAnnotationAfterRestart() throws {
        let (context, _) = try makeContext()
        let store = try makeStore()
        let book = Book(title: "Demo", author: "Author", status: .reading)
        context.insert(book)
        try context.save()

        let item = ReadingShareInboxItem(payload: applePayload(text: "Highlight"))
        try store.append(item)
        _ = try ReadingShareInboxProcessor.saveAnnotation(
            for: item,
            bookID: book.id,
            modelContext: context,
            store: store,
            attachCanonicalReference: false
        )

        try store.append(item)
        #expect(throws: ReadingShareInboxProcessingError.duplicateAnnotation) {
            try ReadingShareInboxProcessor.saveAnnotation(
                for: item,
                bookID: book.id,
                modelContext: context,
                store: store,
                attachCanonicalReference: false
            )
        }

        #expect(try context.fetch(FetchDescriptor<ReadingAnnotation>()).count == 1)
        #expect(try store.readItems().isEmpty)
    }

    @Test @MainActor func confirmedReferenceAttachmentAddsCanonicalURL() throws {
        let (context, _) = try makeContext()
        let store = try makeStore()
        let book = Book(title: "Demo", author: "Author", status: .reading)
        context.insert(book)
        try context.save()

        let item = ReadingShareInboxItem(payload: applePayload(text: nil))
        try store.append(item)
        _ = try ReadingShareInboxProcessor.saveAnnotation(
            for: item,
            bookID: book.id,
            modelContext: context,
            store: store,
            attachCanonicalReference: true
        )

        #expect(book.externalReferencesSafe.count == 1)
        #expect(book.externalReferencesSafe.first?.provider == .appleBooks)
        #expect(book.externalReferencesSafe.first?.canonicalURL == "https://books.apple.com/de/book/demo/id123")
    }

    private func applePayload(text: String?) -> ReadingSharePayload {
        ReadingSharePayload(
            kind: text == nil ? .bookLink : .textWithURL,
            provider: .appleBooks,
            title: "Demo",
            text: text,
            canonicalURL: "https://books.apple.com/de/book/demo/id123",
            providerItemIdentifier: "id123"
        )
    }

    @MainActor private func makeContext() throws -> (ModelContext, ModelContainer) {
        let container = try ModelContainerFactory.makeContainer(mode: .inMemory)
        return (ModelContext(container), container)
    }

    private func makeStore() throws -> ReadingShareInboxStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadingShareProcessingTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return ReadingShareInboxStore(directoryURL: directory)
    }
}

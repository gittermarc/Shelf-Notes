import Foundation
import Testing
@testable import Shelf_Notes

struct ReadingShareInboxCodecTests {
    @Test func codecRoundtripsVersionedInboxFile() throws {
        let item = ReadingShareInboxItem(
            createdAt: Date(timeIntervalSince1970: 100),
            payload: ReadingSharePayload(
                kind: .bookLink,
                provider: .appleBooks,
                title: "Demo",
                canonicalURL: "https://books.apple.com/de/book/demo/id123"
            )
        )

        let data = try ReadingShareInboxCodec.encode([item])
        let decoded = try ReadingShareInboxCodec.decode(data)

        #expect(decoded == [item])
    }

    @Test func codecRejectsFutureSchema() throws {
        let data = Data(#"{"schemaVersion":99,"items":[]}"#.utf8)

        #expect(throws: ReadingShareInboxCodecError.unsupportedSchema(99)) {
            try ReadingShareInboxCodec.decode(data)
        }
    }

    @Test func codecRejectsFutureItemSchema() throws {
        let item = ReadingShareInboxItem(
            schemaVersion: 99,
            payload: ReadingSharePayload(kind: .text, provider: .other, text: "Future")
        )
        let file = ReadingShareInboxFile(items: [item])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(file)

        #expect(throws: ReadingShareInboxCodecError.unsupportedItemSchema(99)) {
            try ReadingShareInboxCodec.decode(data)
        }
    }

    @Test func storeReportsCorruptInboxFiles() throws {
        let store = try makeStore()
        try FileManager.default.createDirectory(at: store.directoryURL, withIntermediateDirectories: true)
        try Data("not-json".utf8).write(to: store.inboxFileURL)

        #expect(throws: ReadingShareInboxStoreError.corruptInboxFile) {
            try store.readItems()
        }
    }

    @Test func storeDeduplicatesByIDAndFingerprint() throws {
        let store = try makeStore()
        let payload = ReadingSharePayload(kind: .text, provider: .other, text: "Highlight")
        let first = ReadingShareInboxItem(payload: payload)
        let second = ReadingShareInboxItem(id: "different-id", payload: payload)

        let firstResult = try store.append(first)
        let secondResult = try store.append(second)

        #expect(firstResult.inserted)
        #expect(!secondResult.inserted)
        #expect(try store.readItems().count == 1)
    }

    @Test func storeRemovesProcessedItemsAndKeepsDifferentHighlights() throws {
        let store = try makeStore()
        let first = ReadingShareInboxItem(payload: ReadingSharePayload(kind: .text, provider: .other, text: "Highlight eins"))
        let second = ReadingShareInboxItem(payload: ReadingSharePayload(kind: .text, provider: .other, text: "Highlight zwei"))

        try store.append(first)
        try store.append(second)
        try store.removeItems(withIDs: [first.id])

        let remaining = try store.readItems()
        #expect(remaining.map(\.id) == [second.id])
    }

    @Test func storeMovesCorruptFileToRecovery() throws {
        let store = try makeStore()
        try FileManager.default.createDirectory(at: store.directoryURL, withIntermediateDirectories: true)
        try Data("broken".utf8).write(to: store.inboxFileURL)

        let recoveredURL = try #require(try store.recoverCorruptFileIfNeeded(now: Date(timeIntervalSince1970: 200)))

        #expect(!FileManager.default.fileExists(atPath: store.inboxFileURL.path))
        #expect(FileManager.default.fileExists(atPath: recoveredURL.path))
    }

    private func makeStore() throws -> ReadingShareInboxStore {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadingShareInboxTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return ReadingShareInboxStore(directoryURL: directory)
    }
}

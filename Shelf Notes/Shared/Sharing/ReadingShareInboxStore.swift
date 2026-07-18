//
//  ReadingShareInboxStore.swift
//  Shelf Notes
//

import Foundation

nonisolated enum ReadingShareInboxStoreError: Error, Equatable, Sendable {
    case missingAppGroupContainer
    case corruptInboxFile
}

nonisolated struct ReadingShareInboxAppendResult: Equatable, Sendable {
    var item: ReadingShareInboxItem
    var inserted: Bool
}

nonisolated struct ReadingShareInboxStore: Sendable {
    static let appGroupIdentifier = "group.de.marcfechner.Shelf-Notes"

    let directoryURL: URL
    let fileManager: FileManager

    init(directoryURL: URL, fileManager: FileManager = .default) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
    }

    init(fileManager: FileManager = .default) throws {
        #if os(iOS)
        guard let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
        ) else {
            throw ReadingShareInboxStoreError.missingAppGroupContainer
        }
        self.init(
            directoryURL: containerURL.appendingPathComponent("ReadingShareInbox", isDirectory: true),
            fileManager: fileManager
        )
        #else
        throw ReadingShareInboxStoreError.missingAppGroupContainer
        #endif
    }

    var inboxFileURL: URL {
        directoryURL.appendingPathComponent("inbox-v1.json", isDirectory: false)
    }

    func readItems() throws -> [ReadingShareInboxItem] {
        guard fileManager.fileExists(atPath: inboxFileURL.path) else { return [] }
        let data = try Data(contentsOf: inboxFileURL)
        do {
            return try ReadingShareInboxCodec.decode(data)
        } catch let error as ReadingShareInboxCodecError {
            throw error
        } catch {
            throw ReadingShareInboxStoreError.corruptInboxFile
        }
    }

    func readItemsSafely() -> [ReadingShareInboxItem] {
        (try? readItems()) ?? []
    }

    @discardableResult
    func append(_ item: ReadingShareInboxItem) throws -> ReadingShareInboxAppendResult {
        var items = try readItems()
        if let existing = items.first(where: { existing in
            existing.id == item.id || existing.contentFingerprint == item.contentFingerprint
        }) {
            return ReadingShareInboxAppendResult(item: existing, inserted: false)
        }

        items.append(item)
        try write(items)
        return ReadingShareInboxAppendResult(item: item, inserted: true)
    }

    func removeItems(withIDs ids: Set<String>) throws {
        guard !ids.isEmpty else { return }
        let remaining = try readItems().filter { !ids.contains($0.id) }
        try write(remaining)
    }

    func discard(_ item: ReadingShareInboxItem) throws {
        try removeItems(withIDs: [item.id])
    }

    func recoverCorruptFileIfNeeded(now: Date = Date()) throws -> URL? {
        guard fileManager.fileExists(atPath: inboxFileURL.path) else { return nil }
        do {
            _ = try readItems()
            return nil
        } catch ReadingShareInboxStoreError.corruptInboxFile {
            return try moveInboxFileToRecovery(now: now)
        } catch is DecodingError {
            return try moveInboxFileToRecovery(now: now)
        }
    }

    private func write(_ items: [ReadingShareInboxItem]) throws {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try ReadingShareInboxCodec.encode(items)
        try data.write(to: inboxFileURL, options: [.atomic])
    }

    private func moveInboxFileToRecovery(now: Date) throws -> URL {
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let timestamp = Int(now.timeIntervalSince1970)
        let recoveryURL = directoryURL.appendingPathComponent("inbox-v1.corrupt-\(timestamp).json")
        if fileManager.fileExists(atPath: recoveryURL.path) {
            try fileManager.removeItem(at: recoveryURL)
        }
        try fileManager.moveItem(at: inboxFileURL, to: recoveryURL)
        return recoveryURL
    }
}

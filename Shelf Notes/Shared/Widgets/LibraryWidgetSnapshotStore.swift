//
//  LibraryWidgetSnapshotStore.swift
//  Shelf Notes
//
//  Persists the Library widget snapshot as JSON in the shared App Group container.
//

import Foundation

nonisolated struct LibraryWidgetSnapshotStore {
    static let fileName = "LibraryWidgetSnapshot.json"

    private let directoryURLProvider: () -> URL?
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        directoryURLProvider: @escaping () -> URL? = { LiveActivitySharedStore.appGroupContainerURL },
        fileManager: FileManager = .default,
        encoder: JSONEncoder = LibraryWidgetSnapshotStore.makeEncoder(),
        decoder: JSONDecoder = LibraryWidgetSnapshotStore.makeDecoder()
    ) {
        self.directoryURLProvider = directoryURLProvider
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
    }

    init(
        directoryURL: URL,
        fileManager: FileManager = .default,
        encoder: JSONEncoder = LibraryWidgetSnapshotStore.makeEncoder(),
        decoder: JSONDecoder = LibraryWidgetSnapshotStore.makeDecoder()
    ) {
        self.init(
            directoryURLProvider: { directoryURL },
            fileManager: fileManager,
            encoder: encoder,
            decoder: decoder
        )
    }

    var snapshotFileURL: URL? {
        guard let directoryURL = directoryURLProvider() else { return nil }
        return directoryURL.appendingPathComponent(Self.fileName, isDirectory: false)
    }

    func load() -> LibraryWidgetSnapshot? {
        guard let url = snapshotFileURL else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let snapshot = try? decoder.decode(LibraryWidgetSnapshot.self, from: data) else { return nil }
        guard snapshot.hasSupportedSchemaVersion else { return nil }
        return snapshot
    }

    @discardableResult
    func save(_ snapshot: LibraryWidgetSnapshot) -> Bool {
        guard let url = snapshotFileURL else { return false }
        do {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try encoder.encode(snapshot)
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func removeSnapshot() -> Bool {
        guard let url = snapshotFileURL else { return false }
        guard fileManager.fileExists(atPath: url.path) else { return true }
        do {
            try fileManager.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }
}

//
//  LibraryOverviewWidgetStore.swift
//  ShelfNotesLiveActivity
//
//  Reads the app-generated LibraryWidgetSnapshot.json from the shared App Group.
//

import Foundation

enum LibraryOverviewWidgetSnapshotLoadState: Hashable, Sendable {
    case loaded(LibraryOverviewWidgetSnapshot)
    case unavailable
}

struct LibraryOverviewWidgetStore {
    static let fileName = "LibraryWidgetSnapshot.json"

    private let directoryURLProvider: () -> URL?
    private let fileManager: FileManager
    private let decoder: JSONDecoder

    init(
        directoryURLProvider: @escaping () -> URL? = { LiveActivitySharedStore.appGroupContainerURL },
        fileManager: FileManager = .default,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.directoryURLProvider = directoryURLProvider
        self.fileManager = fileManager
        self.decoder = decoder
    }

    func loadState() -> LibraryOverviewWidgetSnapshotLoadState {
        guard let directoryURL = directoryURLProvider() else { return .unavailable }
        let url = directoryURL.appendingPathComponent(Self.fileName, isDirectory: false)
        guard fileManager.fileExists(atPath: url.path) else { return .unavailable }
        guard let data = try? Data(contentsOf: url) else { return .unavailable }
        guard let snapshot = try? decoder.decode(LibraryOverviewWidgetSnapshot.self, from: data) else { return .unavailable }
        guard snapshot.hasSupportedSchemaVersion else { return .unavailable }
        return .loaded(snapshot)
    }
}

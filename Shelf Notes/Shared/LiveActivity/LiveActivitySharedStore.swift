//
//  LiveActivitySharedStore.swift
//  Shelf Notes
//
//  Shared utilities for the Reading Session Live Activity.
//  - Shared UserDefaults via App Group
//  - Shared file container for the cover thumbnail
//

import Foundation

nonisolated enum LiveActivitySharedStore {

    /// Must match the App Group enabled for both the app and the widget extension.
    static let appGroupID: String = "group.de.marcfechner.Shelf-Notes"

    static var userDefaults: UserDefaults {
        if let defaults = UserDefaults(suiteName: appGroupID) {
            return defaults
        }
        return .standard
    }

    static var appGroupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static var coverDirectoryURL: URL? {
        guard let base = appGroupContainerURL else { return nil }
        return base.appendingPathComponent("LiveActivityCovers", isDirectory: true)
    }

    static func coverFileName(bookIDString: String) -> String {
        "la_cover_\(bookIDString).jpg"
    }

    static func bookIDString(fromCoverFileName fileName: String) -> String? {
        guard fileName.hasPrefix("la_cover_"), fileName.hasSuffix(".jpg") else { return nil }
        let withoutPrefix = fileName.dropFirst("la_cover_".count)
        let withoutSuffix = withoutPrefix.dropLast(".jpg".count)
        let candidate = String(withoutSuffix)
        guard UUID(uuidString: candidate) != nil else { return nil }
        return candidate
    }

    static func coverFileURL(bookIDString: String) -> URL? {
        guard let dir = coverDirectoryURL else { return nil }
        return dir.appendingPathComponent(coverFileName(bookIDString: bookIDString), isDirectory: false)
    }

    static func ensureCoverDirectoryExists() {
        guard let dir = coverDirectoryURL else { return }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            // Non-fatal. We simply won't show covers if the directory can't be created.
        }
    }

    static func removeCoverFile(bookIDString: String) {
        guard let url = coverFileURL(bookIDString: bookIDString) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func removeOrphanedCoverFiles(keepingBookIDStrings keepers: Set<String>) {
        guard let directory = coverDirectoryURL else { return }
        let fileNames = ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
        for fileName in LiveActivityCoverCleanupPolicy.fileNamesToRemove(
            existingFileNames: fileNames,
            keepingBookIDStrings: keepers
        ) {
            let url = directory.appendingPathComponent(fileName, isDirectory: false)
            try? FileManager.default.removeItem(at: url)
        }
    }
}

nonisolated enum LiveActivityCoverCleanupPolicy {
    static func fileNamesToRemove(
        existingFileNames: [String],
        keepingBookIDStrings: Set<String>
    ) -> [String] {
        existingFileNames.filter { fileName in
            guard let bookIDString = LiveActivitySharedStore.bookIDString(fromCoverFileName: fileName) else {
                return false
            }
            return !keepingBookIDStrings.contains(bookIDString)
        }
    }
}

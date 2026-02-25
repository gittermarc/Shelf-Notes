//
//  LiveActivitySharedStore.swift
//  Shelf Notes
//
//  Shared utilities for the Reading Session Live Activity.
//  - Shared UserDefaults via App Group
//  - Shared file container for the cover thumbnail
//

import Foundation

enum LiveActivitySharedStore {

    /// ⚠️ Must match the App Group you enable in Xcode for both the app and the widget extension.
    ///
    /// Suggested value (based on current bundle id):
    /// `group.de.marcfechner.Shelf-Notes`
    static let appGroupID: String = "group.de.marcfechner.Shelf-Notes"

    static var userDefaults: UserDefaults {
        if let d = UserDefaults(suiteName: appGroupID) {
            return d
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

    static func coverFileURL(bookIDString: String) -> URL? {
        guard let dir = coverDirectoryURL else { return nil }
        return dir.appendingPathComponent("la_cover_\(bookIDString).jpg", isDirectory: false)
    }

    static func ensureCoverDirectoryExists() {
        guard let dir = coverDirectoryURL else { return }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            // Non-fatal. We simply won't show covers if the directory can't be created.
        }
    }
}

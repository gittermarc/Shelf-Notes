//
//  UserCoverStore.swift
//  Shelf Notes
//

import Foundation

/// Stores full-resolution user-selected cover images locally on disk.
///
/// CloudKit/SwiftData syncs only the thumbnail (`Book.userCoverData`), not these files.
/// We persist just the file name (`Book.userCoverFileName`) to be able to re-open the local full-res image.
final class UserCoverStore {
    private static let fm = FileManager.default

    private static var folderURL: URL {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("user-covers", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir
    }

    static func fileURL(for filename: String) -> URL? {
        let t = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return folderURL.appendingPathComponent(t, isDirectory: false)
    }

    /// Saves JPEG data and returns the generated file name.
    static func saveJPEGData(_ data: Data) throws -> String {
        let name = UUID().uuidString + ".jpg"
        let url = folderURL.appendingPathComponent(name, isDirectory: false)
        try data.write(to: url, options: [.atomic])
        return name
    }

    static func delete(filename: String) {
        guard let url = fileURL(for: filename) else { return }
        try? fm.removeItem(at: url)
    }
}

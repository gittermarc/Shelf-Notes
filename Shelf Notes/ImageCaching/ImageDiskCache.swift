//
//  ImageDiskCache.swift
//  Shelf Notes
//

import Foundation
import CryptoKit

#if canImport(UIKit)
import UIKit
#endif

enum ImageDiskCacheKey {
    static func fileName(for url: URL) -> String {
        let key = sha256Hex(url.absoluteString)
        let ext = url.pathExtension.isEmpty ? "img" : url.pathExtension
        return key + "." + ext
    }

    private static func sha256Hex(_ string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// Simple local-only disk cache stored in the app's Caches directory.
/// Prevents re-downloading covers on every app launch.
final class ImageDiskCache: @unchecked Sendable {
    static let shared = ImageDiskCache()
    static let defaultMaxDiskUsageBytes: Int64 = 120 * 1024 * 1024

    private let fm: FileManager
    private let folderURL: URL
    private let maxDiskUsageBytes: Int64
    private let lock = NSLock()

    private convenience init() {
        let fm = FileManager.default
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("cover-cache", isDirectory: true)
        self.init(
            folderURL: dir,
            maxDiskUsageBytes: Self.defaultMaxDiskUsageBytes,
            fileManager: fm
        )
    }

    init(
        folderURL: URL,
        maxDiskUsageBytes: Int64 = defaultMaxDiskUsageBytes,
        fileManager: FileManager = .default
    ) {
        self.folderURL = folderURL
        self.maxDiskUsageBytes = max(0, maxDiskUsageBytes)
        self.fm = fileManager
        ensureDirectoryExists()
    }

    private func cacheFileURL(for url: URL) -> URL {
        folderURL.appendingPathComponent(ImageDiskCacheKey.fileName(for: url), isDirectory: false)
    }

    #if canImport(UIKit)
    func image(for url: URL) -> UIImage? {
        let fileURL = cacheFileURL(for: url)

        lock.lock()
        defer { lock.unlock() }

        guard fm.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        touchLocked(fileURL)
        return UIImage(data: data)
    }
    #endif

    /// Returns the raw cached bytes for a URL if present on disk.
    ///
    /// This is useful when the caller wants to decode/resize using ImageIO without creating a full UIImage.
    func data(for url: URL) -> Data? {
        let fileURL = cacheFileURL(for: url)

        lock.lock()
        defer { lock.unlock() }

        guard fm.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        touchLocked(fileURL)
        return data
    }

    func store(data: Data, for url: URL) {
        let fileURL = cacheFileURL(for: url)

        lock.lock()
        defer { lock.unlock() }

        ensureDirectoryExistsLocked()
        try? data.write(to: fileURL, options: [.atomic])
        touchLocked(fileURL)
        pruneIfNeededLocked()
    }

    func clearAll() {
        lock.lock()
        defer { lock.unlock() }

        try? fm.removeItem(at: folderURL)
        ensureDirectoryExistsLocked()
    }

    /// Returns the currently used disk space in bytes for the cover-cache folder.
    ///
    /// Note: This only measures the local disk cache used by `CachedAsyncImage`.
    /// It does not include the in-memory cache, nor iOS URLCache.
    func diskUsageBytes() -> Int64 {
        lock.lock()
        defer { lock.unlock() }

        return diskUsageBytesLocked()
    }

    /// Returns a human readable string like "12,3 MB" for the current cache size.
    func diskUsageString() -> String {
        let bytes = diskUsageBytes()
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    func pruneIfNeeded() {
        lock.lock()
        defer { lock.unlock() }

        pruneIfNeededLocked()
    }

    private func ensureDirectoryExists() {
        lock.lock()
        defer { lock.unlock() }

        ensureDirectoryExistsLocked()
    }

    private func ensureDirectoryExistsLocked() {
        if !fm.fileExists(atPath: folderURL.path) {
            try? fm.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        }
    }

    private func touchLocked(_ fileURL: URL) {
        try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
    }

    private struct DiskEntry {
        let url: URL
        let size: Int64
        let lastAccessedAt: Date
    }

    private func entriesLocked() -> [DiskEntry] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = fm.enumerator(
            at: folderURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return []
        }

        var entries: [DiskEntry] = []
        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: keys)
                guard values.isRegularFile == true else { continue }
                entries.append(
                    DiskEntry(
                        url: fileURL,
                        size: Int64(values.fileSize ?? 0),
                        lastAccessedAt: values.contentModificationDate ?? .distantPast
                    )
                )
            } catch {
                continue
            }
        }
        return entries
    }

    private func diskUsageBytesLocked() -> Int64 {
        entriesLocked().reduce(Int64(0)) { partial, entry in
            partial + entry.size
        }
    }

    private func pruneIfNeededLocked() {
        guard maxDiskUsageBytes > 0 else { return }

        var entries = entriesLocked()
        var total = entries.reduce(Int64(0)) { $0 + $1.size }
        guard total > maxDiskUsageBytes else { return }

        entries.sort { lhs, rhs in
            if lhs.lastAccessedAt != rhs.lastAccessedAt {
                return lhs.lastAccessedAt < rhs.lastAccessedAt
            }
            return lhs.url.lastPathComponent < rhs.url.lastPathComponent
        }

        for entry in entries where total > maxDiskUsageBytes {
            do {
                try fm.removeItem(at: entry.url)
                total -= entry.size
            } catch {
                continue
            }
        }
    }
}

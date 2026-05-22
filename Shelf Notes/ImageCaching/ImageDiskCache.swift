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
final class ImageDiskCache {
    static let shared = ImageDiskCache()

    private let fm = FileManager.default
    private let folderURL: URL

    private init() {
        let base = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("cover-cache", isDirectory: true)
        self.folderURL = dir

        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
    }

    private func cacheFileURL(for url: URL) -> URL {
        folderURL.appendingPathComponent(ImageDiskCacheKey.fileName(for: url), isDirectory: false)
    }

    #if canImport(UIKit)
    func image(for url: URL) -> UIImage? {
        let fileURL = cacheFileURL(for: url)
        guard fm.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    #endif

    /// Returns the raw cached bytes for a URL if present on disk.
    ///
    /// This is useful when the caller wants to decode/resize using ImageIO without creating a full UIImage.
    func data(for url: URL) -> Data? {
        let fileURL = cacheFileURL(for: url)
        guard fm.fileExists(atPath: fileURL.path) else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    func store(data: Data, for url: URL) {
        let fileURL = cacheFileURL(for: url)
        try? data.write(to: fileURL, options: [.atomic])
    }

    func clearAll() {
        try? fm.removeItem(at: folderURL)
        try? fm.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
    }

    /// Returns the currently used disk space in bytes for the cover-cache folder.
    ///
    /// Note: This only measures the local disk cache used by `CachedAsyncImage`.
    /// It does not include the in-memory cache, nor iOS URLCache.
    func diskUsageBytes() -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        guard let enumerator = fm.enumerator(
            at: folderURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let values = try fileURL.resourceValues(forKeys: keys)
                guard values.isRegularFile == true else { continue }
                total += Int64(values.fileSize ?? 0)
            } catch {
                continue
            }
        }
        return total
    }

    /// Returns a human readable string like "12,3 MB" for the current cache size.
    func diskUsageString() -> String {
        let bytes = diskUsageBytes()
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

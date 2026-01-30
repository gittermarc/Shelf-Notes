//
//  CachedAsyncImage.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 20.12.25.
//

import SwiftUI
import UIKit
import CryptoKit

// MARK: - Memory cache

final class ImageMemoryCache {
    static let shared = ImageMemoryCache()

    private let cache = NSCache<NSURL, UIImage>()

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func setImage(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }

    func clear() {
        cache.removeAllObjects()
    }
}

// MARK: - Disk cache (local-only)

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

    private func sha256Hex(_ s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func cacheFileURL(for url: URL) -> URL {
        let key = sha256Hex(url.absoluteString)
        let ext = url.pathExtension.isEmpty ? "img" : url.pathExtension
        return folderURL.appendingPathComponent(key).appendingPathExtension(ext)
    }

    func image(for url: URL) -> UIImage? {
        let fileURL = cacheFileURL(for: url)
        guard fm.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    /// Returns the raw cached bytes for a URL if present on disk.
    ///
    /// This is useful when the caller wants to decode/resize using ImageIO (without creating a full UIImage).
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
        // remove folder and recreate
        try? fm.removeItem(at: folderURL)
        try? fm.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
    }

    /// Returns the currently used disk space in **bytes** for the cover-cache folder.
    ///
    /// Note: This only measures the *local disk cache* used by `CachedAsyncImage`.
    /// (It does not include the in-memory cache, nor iOS URLCache.)
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
                // ignore single file errors; best-effort measurement
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



// MARK: - User cover store (local-only user uploads)

/// Stores **full-resolution** user-selected cover images locally on disk.
///
/// CloudKit/SwiftData syncs only the *thumbnail* (Book.userCoverData), not these files.
/// We persist just the file name (Book.userCoverFileName) to be able to re-open the local full-res image.
///
/// Why:
/// - Full-res images can be big.
/// - Thumbnails are tiny and sync reliably across devices.
final class UserCoverStore {
    private static let fm = FileManager.default

    private static var folderURL: URL {
        // Application Support is the right place for user data that the app manages.
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

// MARK: - CachedAsyncImage

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let transaction: Transaction
    let contentMode: ContentMode
    let onLoadResult: ((Bool) -> Void)?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var uiImage: UIImage? = nil
    @State private var isLoading: Bool = false

    init(
        url: URL?,
        transaction: Transaction = Transaction(),
        contentMode: ContentMode = .fill,
        onLoadResult: ((Bool) -> Void)? = nil,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.transaction = transaction
        self.contentMode = contentMode
        self.onLoadResult = onLoadResult
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        ZStack {
            if let uiImage {
                let image = Image(uiImage: uiImage)
                content(image)
                    .aspectRatio(contentMode: contentMode)
                    .transaction { t in
                        // Some SwiftUI versions only provide the closure-based modifier.
                        t = transaction
                    }
            } else {
                placeholder()
            }
        }
        .onChange(of: url) { _, _ in
            uiImage = nil
            isLoading = false
        }
        .task(id: url) {
            await loadIfNeeded()
        }
    }

    @MainActor
    private func loadIfNeeded() async {
        guard !isLoading else { return }
        guard uiImage == nil else { return }
        guard let url else { return }

        isLoading = true
        defer { isLoading = false }

        let img = await CoverImageLoader.loadImage(for: url)

        if Task.isCancelled { return }

        if let img {
            uiImage = img
            onLoadResult?(true)
        } else {
            onLoadResult?(false)
        }
    }
}

// MARK: - CoverCandidatesImage (tries next URL if loading fails)

struct CoverCandidatesImage<Content: View, Placeholder: View>: View {
    let urlStrings: [String]
    let preferredURLString: String?
    let transaction: Transaction
    let contentMode: ContentMode
    let onResolvedURL: ((String) -> Void)?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var index: Int = 0
    @State private var resolved: Bool = false

    private var cleaned: [String] {
        var out: [String] = []
        for s in urlStrings {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                out.append(t)
            }
        }
        return out
    }

    private var currentURL: URL? {
        let arr = cleaned
        guard index >= 0, index < arr.count else { return nil }
        return URL(string: arr[index])
    }

    init(
        urlStrings: [String],
        preferredURLString: String? = nil,
        transaction: Transaction = Transaction(),
        contentMode: ContentMode = .fill,
        onResolvedURL: ((String) -> Void)? = nil,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.urlStrings = urlStrings
        self.preferredURLString = preferredURLString
        self.transaction = transaction
        self.contentMode = contentMode
        self.onResolvedURL = onResolvedURL
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let url = currentURL {
                CachedAsyncImage(
                    url: url,
                    transaction: transaction,
                    contentMode: contentMode,
                    onLoadResult: { success in
                        guard !resolved else { return }
                        if success {
                            resolved = true
                            onResolvedURL?(url.absoluteString)
                        } else {
                            advance()
                        }
                    },
                    content: content,
                    placeholder: placeholder
                )
                .id(url)
            } else {
                placeholder()
            }
        }
        .onAppear {
            let arr = cleaned
            if let preferredURLString {
                let pref = preferredURLString.trimmingCharacters(in: .whitespacesAndNewlines)
                if let i = arr.firstIndex(where: { $0.caseInsensitiveCompare(pref) == .orderedSame }) {
                    index = i
                }
            }
        }
        .onChange(of: cleaned) { _, _ in
            index = 0
            resolved = false
        }
    }

    private func advance() {
        let arr = cleaned
        if index + 1 < arr.count {
            withAnimation(.easeInOut(duration: 0.15)) {
                index += 1
            }
        }
    }
}

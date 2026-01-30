//
//  CoverImageLoader.swift
//  Shelf Notes
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(UIKit)

/// Loads and decodes cover images without blocking the MainActor.
///
/// Implementation detail:
/// We use a global DispatchQueue for synchronous file I/O + `UIImage(data:)` decoding.
enum CoverImageLoader {

    /// Loads raw bytes for an image URL, preferring caches and keeping work off the MainActor.
    ///
    /// - For remote URLs we:
    ///   1) check the local disk cache (cover-cache)
    ///   2) fall back to the network (URLCache-friendly)
    ///   3) store the fetched bytes back to disk
    ///
    /// This is intentionally separate from `loadImage(for:)` so callers can decode/resize via ImageIO
    /// without instantiating a full `UIImage` (which is more memory-heavy).
    static func loadImageData(for url: URL) async -> Data? {
        if Task.isCancelled { return nil }

        // 1) Local file URLs (user uploaded covers)
        if url.isFileURL {
            return await background(qos: .userInitiated) {
                try? Data(contentsOf: url)
            }
        }

        // 2) Disk cache (local-only)
        if let diskData = await background(qos: .userInitiated, work: {
            ImageDiskCache.shared.data(for: url)
        }) {
            return diskData
        }

        if Task.isCancelled { return nil }

        // 3) Network (URLCache as a bonus)
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if Task.isCancelled { return nil }

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return nil
            }

            // Disk write off-main
            _ = await background(qos: .utility) {
                ImageDiskCache.shared.store(data: data, for: url)
            }

            return data
        } catch {
            return nil
        }
    }

    static func loadImage(for url: URL) async -> UIImage? {
        if Task.isCancelled { return nil }

        // 1) Local file URLs (user uploaded covers)
        if url.isFileURL {
            if let cached = ImageMemoryCache.shared.image(for: url) {
                return cached
            }

            let img: UIImage? = await background(qos: .userInitiated) {
                guard let data = try? Data(contentsOf: url) else { return nil }
                return autoreleasepool { UIImage(data: data) }
            }

            if let img {
                ImageMemoryCache.shared.setImage(img, for: url)
            }
            return img
        }

        // 2) Memory cache
        if let cached = ImageMemoryCache.shared.image(for: url) {
            return cached
        }

        // 3) Disk cache (local-only)
        if let diskImg = await background(qos: .userInitiated, work: {
            ImageDiskCache.shared.image(for: url)
        }) {
            ImageMemoryCache.shared.setImage(diskImg, for: url)
            return diskImg
        }

        if Task.isCancelled { return nil }

        // 4) Network (URLCache as a bonus)
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if Task.isCancelled { return nil }

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return nil
            }

            // Decode + disk write off-main (these are the expensive parts)
            let decoded: UIImage? = await background(qos: .userInitiated) {
                guard let img = autoreleasepool(invoking: { UIImage(data: data) }) else { return nil }
                ImageDiskCache.shared.store(data: data, for: url)
                return img
            }

            if let decoded {
                ImageMemoryCache.shared.setImage(decoded, for: url)
            }
            return decoded
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    private static func background<T>(
        qos: DispatchQoS.QoSClass,
        work: @escaping () -> T
    ) async -> T {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: qos).async {
                continuation.resume(returning: work())
            }
        }
    }
}

#endif

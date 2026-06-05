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
            return await CoverImageRequestDeduper.shared.data(for: url) {
                await background(qos: .userInitiated) {
                    try? Data(contentsOf: url)
                }
            }
        }

        // 2) Disk cache (local-only)
        if let diskData = await background(qos: .userInitiated, work: {
            ImageDiskCache.shared.data(for: url)
        }) {
            RemoteCoverFailureCache.shared.recordSuccess(for: url)
            return diskData
        }

        if Task.isCancelled { return nil }
        if RemoteCoverFailureCache.shared.shouldSkip(url) { return nil }

        // 3) Network (URLCache as a bonus), deduped across concurrent consumers.
        return await CoverImageRequestDeduper.shared.data(for: url) {
            if RemoteCoverFailureCache.shared.shouldSkip(url) { return nil }

            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if Task.isCancelled { return nil }

                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    RemoteCoverFailureCache.shared.recordFailure(for: url)
                    return nil
                }

                // Disk write + pruning off-main
                _ = await background(qos: .utility) {
                    ImageDiskCache.shared.store(data: data, for: url)
                }

                RemoteCoverFailureCache.shared.recordSuccess(for: url)
                return data
            } catch {
                RemoteCoverFailureCache.shared.recordFailure(for: url)
                return nil
            }
        }
    }

    static func loadImage(for url: URL) async -> UIImage? {
        if Task.isCancelled { return nil }

        // 1) Memory cache
        if let cached = ImageMemoryCache.shared.image(for: url) {
            return cached
        }

        // 2) Raw bytes are deduped and failure-cached by `loadImageData(for:)`.
        guard let data = await loadImageData(for: url) else {
            return nil
        }

        if Task.isCancelled { return nil }

        // 3) Decode off-main.
        let decoded: UIImage? = await background(qos: .userInitiated) {
            autoreleasepool(invoking: { UIImage(data: data) })
        }

        if let decoded {
            ImageMemoryCache.shared.setImage(decoded, for: url)
        }
        return decoded
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

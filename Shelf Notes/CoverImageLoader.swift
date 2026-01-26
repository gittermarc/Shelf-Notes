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
        if let diskImg: UIImage? = await background(qos: .userInitiated, work: {
            ImageDiskCache.shared.image(for: url)
        }), let diskImg {
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

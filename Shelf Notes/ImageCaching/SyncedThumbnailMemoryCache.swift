//
//  SyncedThumbnailMemoryCache.swift
//  Shelf Notes
//

import Foundation

#if canImport(UIKit)
import UIKit

final class SyncedThumbnailMemoryCache {
    static let shared = SyncedThumbnailMemoryCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        // Rough budget: about 48 MB for decoded thumbnails.
        // Enough for a few hundred tiny row images and avoids eviction churn while scrolling.
        cache.totalCostLimit = 48 * 1024 * 1024
    }

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String, cost: Int) {
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}
#endif

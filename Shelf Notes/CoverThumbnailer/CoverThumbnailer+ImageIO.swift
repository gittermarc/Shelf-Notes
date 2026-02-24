//
//  CoverThumbnailer+ImageIO.swift
//  Shelf Notes
//
//  Split from CoverThumbnailer.swift (ImageIO / JPEG / pixel sizing)
//

import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
import ImageIO
import UniformTypeIdentifiers

extension CoverThumbnailer {

    // MARK: ImageIO-based thumbnail pipeline (off-main)

    static func makeThumbnailData(from imageData: Data) async -> Data? {
        let maxPixel = max(1, Int(thumbnailMaxPixel.rounded(.toNearestOrAwayFromZero)))
        let quality = thumbnailJPEGQuality

        return await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                thumbnailJPEGData(from: imageData, maxPixel: maxPixel, quality: quality)
            }
        }.value
    }

    /// Convenience wrapper (rarely used). Prefer `makeThumbnailData(from imageData:)`.
    ///
    /// Note: we intentionally do the potentially expensive `jpegData` conversion off-main.
    static func makeThumbnailData(from image: UIImage) async -> Data? {
        let maxPixel = max(1, Int(thumbnailMaxPixel.rounded(.toNearestOrAwayFromZero)))
        let quality = thumbnailJPEGQuality

        // Convert UIImage -> bytes on the caller context, then do ImageIO work off-main.
        guard let raw = image.jpegData(compressionQuality: 1.0) ?? image.pngData() else { return nil }

        return await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                return thumbnailJPEGData(from: raw, maxPixel: maxPixel, quality: quality)
            }
        }.value
    }

    /// Heuristic: treat very small synced thumbnails as "low-res".
    ///
    /// Why:
    /// - Some remote sources return tiny thumbnails (or even "image not available" placeholders).
    /// - Low-res thumbs look bad in detail views AND can "stick" as userCoverData.
    static func isLowResSyncedThumbnail(_ data: Data) -> Bool {
        guard let (w, h) = pixelSize(from: data) else { return true }
        // ~420px is enough to look crisp for a 120x180pt cover on 3x screens (360x540px).
        return max(w, h) < 420
    }

    // MARK: - ImageIO helpers

    nonisolated static func pixelSize(from data: Data) -> (Int, Int)? {
        let opts: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let src = CGImageSourceCreateWithData(data as CFData, opts as CFDictionary) else { return nil }
        guard let props = CGImageSourceCopyPropertiesAtIndex(src, 0, opts as CFDictionary) as? [CFString: Any] else { return nil }

        func intVal(_ v: Any?) -> Int? {
            if let i = v as? Int { return i }
            if let n = v as? NSNumber { return n.intValue }
            return nil
        }

        guard let w = intVal(props[kCGImagePropertyPixelWidth]),
              let h = intVal(props[kCGImagePropertyPixelHeight]),
              w > 0, h > 0 else { return nil }

        return (w, h)
    }

    /// Creates a JPEG thumbnail from raw image bytes using ImageIO.
    ///
    /// This respects EXIF orientation (`kCGImageSourceCreateThumbnailWithTransform`) and avoids creating full UIImages.
    nonisolated static func thumbnailJPEGData(from data: Data, maxPixel: Int, quality: CGFloat) -> Data? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let src = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else { return nil }

        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixel),
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCache: false,
            kCGImageSourceShouldCacheImmediately: false
        ]

        guard let cgThumb = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOptions as CFDictionary) else { return nil }

        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(dest, cgThumb, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }

    /// Converts any image bytes to JPEG while keeping max resolution (no downscale) and normalizing orientation.
    nonisolated static func convertToJPEGKeepingMaxResolution(_ data: Data, quality: CGFloat) -> Data? {
        guard let (w, h) = pixelSize(from: data) else { return nil }
        let maxPx = max(w, h)
        return thumbnailJPEGData(from: data, maxPixel: maxPx, quality: quality)
    }
}
#endif

//
//  LiveActivityCoverWriter.swift
//  Shelf Notes
//
//  Writes a small JPEG cover thumbnail into the App Group container so the
//  Live Activity extension can render a premium-looking cover on the lock screen.
//

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum LiveActivityCoverWriter {

    /// Writes a downsampled JPEG into the App Group container.
    ///
    /// - Note: This is best called from a background task.
    static func writeCoverThumbnailIfPossible(bookID: UUID, sourceThumbnailData: Data) {
        let bookIDString = bookID.uuidString
        LiveActivitySharedStore.ensureCoverDirectoryExists()
        guard let url = LiveActivitySharedStore.coverFileURL(bookIDString: bookIDString) else { return }

        // If writing fails we simply don't show a cover.
        guard let jpeg = downsampleToSmallJPEG(sourceThumbnailData, maxPixelSize: 560, quality: 0.84) else { return }

        do {
            try jpeg.write(to: url, options: [.atomic])
        } catch {
            // Non-fatal.
        }
    }

    // MARK: - ImageIO

    private static func downsampleToSmallJPEG(_ data: Data, maxPixelSize: Int, quality: CGFloat) -> Data? {
        let cfData = data as CFData
        guard let src = CGImageSourceCreateWithData(cfData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(64, maxPixelSize)
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else { return nil }

        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }

        let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: min(1.0, max(0.1, quality))]
        CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)

        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}

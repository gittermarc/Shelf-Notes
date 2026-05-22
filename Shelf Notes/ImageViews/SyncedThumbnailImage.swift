//
//  SyncedThumbnailImage.swift
//  Shelf Notes
//

import SwiftUI

#if canImport(UIKit)
import ImageIO
import UIKit

struct SyncedThumbnailImage: View {
    let bookID: UUID
    let data: Data
    let targetSize: CGSize
    let contentMode: ContentMode
    let cornerRadius: CGFloat

    @Environment(\.displayScale) private var displayScale

    @State private var uiImage: UIImage? = nil

    private var cacheKey: String {
        SyncedThumbnailCacheKey.make(bookID: bookID, data: data)
    }

    var body: some View {
        ZStack {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: contentMode)
            } else {
                BookCoverPlaceholder(cornerRadius: cornerRadius)
            }
        }
        .task(id: cacheKey) {
            await loadIfNeeded()
        }
    }

    @MainActor
    private func loadIfNeeded() async {
        if let cached = SyncedThumbnailMemoryCache.shared.image(forKey: cacheKey) {
            uiImage = cached
            return
        }

        let maxPixel = max(targetSize.width, targetSize.height) * displayScale * 1.25
        let maxPixelInt = Int(max(1, maxPixel).rounded(.up))

        let decoded: UIImage? = await Self.background(qos: .userInitiated) {
            autoreleasepool {
                Self.decodeDownscaledJPEG(data: data, maxPixel: maxPixelInt)
                    ?? UIImage(data: data)
            }
        }

        if Task.isCancelled { return }

        if let decoded {
            SyncedThumbnailMemoryCache.shared.setImage(decoded, forKey: cacheKey, cost: data.count)
            uiImage = decoded
        }
    }

    private static func decodeDownscaledJPEG(data: Data, maxPixel: Int) -> UIImage? {
        guard maxPixel > 0 else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private static func background<T>(qos: DispatchQoS.QoSClass, work: @escaping () -> T) async -> T {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: qos).async {
                continuation.resume(returning: work())
            }
        }
    }
}
#endif

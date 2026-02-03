//
//  LibraryRowCoverView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 27.01.26.
//
//  Purpose:
//  - Fast, side-effect free cover rendering for list rows.
//  - No SwiftData saves, no URL resolution persistence, no thumbnail backfill.
//  - Avoids main-thread JPEG decoding by decoding `Book.userCoverData` off-main.
//

import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
import ImageIO
#endif

// MARK: - In-memory cache for synced thumbnails (Book.userCoverData)

#if canImport(UIKit)
final class SyncedThumbnailMemoryCache {
    static let shared = SyncedThumbnailMemoryCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        // Rough budget: ~48 MB for decoded thumbnails.
        // (Enough for a few hundred tiny row images, avoids eviction churn while scrolling.)
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

// MARK: - LibraryRowCoverView

/// A performance-optimized cover renderer for list rows.
///
/// Differences vs. `BookCoverThumbnailView`:
/// - **No persistence** (no `persistResolvedCoverURL`, no `userCoverData` refresh).
/// - Decodes `Book.userCoverData` off-main and caches the decoded UIImage.
/// - Uses existing `CoverCandidatesImage` (with `onResolvedURL = nil`) as a read-only fallback.
struct LibraryRowCoverView: View {
    @Bindable var book: Book

    var size: CGSize
    var cornerRadius: CGFloat
    var contentMode: ContentMode = .fit

    /// When `true`, we prefer loading a higher-resolution remote cover (zoom-upgraded when possible)
    /// and use the synced thumbnail only as a fallback/placeholder.
    ///
    /// This is intended for **Grid** tiles and **Detail** surfaces where the cover is physically larger.
    /// The synced thumbnail is optimized for fast list scrolling + CloudKit payload size and can look soft
    /// when scaled up.
    var prefersHighResCover: Bool = false

    var body: some View {
        Group {
            #if canImport(UIKit)
            if prefersHighResCover {
                highResCandidatesView
            } else if let data = book.userCoverData {
                SyncedThumbnailImage(
                    bookID: book.id,
                    data: data,
                    targetSize: size,
                    contentMode: contentMode,
                    cornerRadius: cornerRadius
                )
            } else {
                readOnlyCandidatesFallback
            }
            #else
            readOnlyCandidatesFallback
            #endif
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// High-resolution cover rendering:
    /// - tries remote candidates with a best-effort zoom upgrade (Google Books)
    /// - keeps the view **side-effect free** (no SwiftData saves)
    /// - uses the synced thumbnail while the high-res image is loading
    @ViewBuilder
    private var highResCandidatesView: some View {
        let candidates = Self.displayCandidates(from: book.coverCandidatesAll)
        let preferred = Self.preferredHighResURLString(for: book)

        if !candidates.isEmpty {
            CoverCandidatesImage(
                urlStrings: candidates,
                preferredURLString: preferred,
                contentMode: contentMode,
                onResolvedURL: nil
            ) { image in
                image
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: contentMode)
            } placeholder: {
                #if canImport(UIKit)
                if let data = book.userCoverData {
                    SyncedThumbnailImage(
                        bookID: book.id,
                        data: data,
                        targetSize: size,
                        contentMode: contentMode,
                        cornerRadius: cornerRadius
                    )
                } else {
                    BookCoverPlaceholder(cornerRadius: cornerRadius)
                }
                #else
                BookCoverPlaceholder(cornerRadius: cornerRadius)
                #endif
            }
        } else {
            // No candidates at all → fall back to thumbnail if present, else placeholder.
            #if canImport(UIKit)
            if let data = book.userCoverData {
                SyncedThumbnailImage(
                    bookID: book.id,
                    data: data,
                    targetSize: size,
                    contentMode: contentMode,
                    cornerRadius: cornerRadius
                )
            } else {
                BookCoverPlaceholder(cornerRadius: cornerRadius)
            }
            #else
            BookCoverPlaceholder(cornerRadius: cornerRadius)
            #endif
        }
    }

    @ViewBuilder
    private var readOnlyCandidatesFallback: some View {
        // `coverCandidatesAll` can include a local file URL (user cover). That is okay here:
        // `CoverImageLoader` handles file URLs off-main and caches them.
        let candidates = book.coverCandidatesAll

        if !candidates.isEmpty {
            CoverCandidatesImage(
                urlStrings: candidates,
                preferredURLString: book.thumbnailURL,
                contentMode: contentMode,
                onResolvedURL: nil
            ) { image in
                image
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: contentMode)
            } placeholder: {
                BookCoverPlaceholder(cornerRadius: cornerRadius)
            }
        } else {
            BookCoverPlaceholder(cornerRadius: cornerRadius)
        }
    }
}

// MARK: - SyncedThumbnailImage

#if canImport(UIKit)
private struct SyncedThumbnailImage: View {
    let bookID: UUID
    let data: Data
    let targetSize: CGSize
    let contentMode: ContentMode
    let cornerRadius: CGFloat

    @Environment(\.displayScale) private var displayScale

    @State private var uiImage: UIImage? = nil

    private var cacheKey: String {
        // Lightweight fingerprint: count + first/last 8 bytes.
        // (Avoids full hashing of JPEG bytes on every render.)
        let fp = Self.fingerprint(data)
        return "\(bookID.uuidString)-\(fp)"
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

        // Decode off-main and downscale to what we need for the list.
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

    // MARK: - Decode helpers

    private static func decodeDownscaledJPEG(data: Data, maxPixel: Int) -> UIImage? {
        guard maxPixel > 0 else { return nil }
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]

        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    private static func fingerprint(_ data: Data) -> String {
        func readUInt64(_ slice: Data) -> UInt64 {
            var v: UInt64 = 0
            withUnsafeMutableBytes(of: &v) { buf in
                // `copyBytes` is safe regardless of alignment.
                _ = slice.copyBytes(to: buf)
            }
            return v
        }

        let first: UInt64
        let last: UInt64

        if data.count >= 8 {
            first = readUInt64(data.prefix(8))
            last = readUInt64(data.suffix(8))
        } else if !data.isEmpty {
            first = UInt64(data.first ?? 0)
            last = UInt64(data.last ?? 0)
        } else {
            first = 0
            last = 0
        }

        return "\(data.count)-\(first)-\(last)"
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

// MARK: - High-res candidate helpers

extension LibraryRowCoverView {

    /// Creates a best-effort list of display candidates:
    /// - For remote URLs we add a zoom-upgraded variant (Google Books) **before** the original.
    /// - File URLs are kept as-is.
    /// - Deduped, order preserved.
    static func displayCandidates(from raw: [String]) -> [String] {
        var out: [String] = []

        func add(_ s: String) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                out.append(t)
            }
        }

        for s in raw {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }

            if let u = URL(string: t), u.isFileURL {
                add(t)
                continue
            }

            // Prefer upgraded display variant first (for crisp Grid/Detail covers), but keep original as fallback.
            let upgraded = CoverThumbnailer.upgradedRemoteURLString(t, target: .display)
            if upgraded.caseInsensitiveCompare(t) == .orderedSame {
                add(t)
            } else {
                add(upgraded)
                add(t)
            }
        }

        return out
    }

    /// Picks a preferred starting URL for high-res rendering.
    /// - User photo cover (local file) wins.
    /// - Otherwise we prefer the upgraded display variant of the persisted primary URL.
    static func preferredHighResURLString(for book: Book) -> String? {
        if let name = book.userCoverFileName,
           let fileURL = UserCoverStore.fileURL(for: name) {
            return fileURL.absoluteString
        }

        if let s = book.thumbnailURL?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            return CoverThumbnailer.upgradedRemoteURLString(s, target: .display)
        }

        if let s = book.coverURLCandidates.first?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            return CoverThumbnailer.upgradedRemoteURLString(s, target: .display)
        }

        return nil
    }
}

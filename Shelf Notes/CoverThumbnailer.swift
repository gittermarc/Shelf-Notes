//
//  CoverThumbnailer.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 04.01.26.
//

import Foundation
import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Thumbnail generation + backfill

enum CoverThumbnailer {

    // Tweak these if you want sharper thumbnails or smaller sync payload.
    static let thumbnailMaxPixel: CGFloat = 600
    static let thumbnailJPEGQuality: CGFloat = 0.82

    // For user-uploaded covers: keep a high-quality, full-resolution JPEG locally.
    static let fullResJPEGQuality: CGFloat = 0.95

    #if canImport(UIKit)

    static func makeThumbnailData(from image: UIImage) async -> Data? {
        let maxPixel = thumbnailMaxPixel
        let quality = thumbnailJPEGQuality

        return await MainActor.run {
            let normalized = image.normalizedOrientation()

            let w = normalized.size.width
            let h = normalized.size.height
            guard w > 0, h > 0 else { return nil }

            let maxSide = max(w, h)
            let scale = (maxSide > maxPixel) ? (maxPixel / maxSide) : 1
            let targetSize = CGSize(width: max(1, floor(w * scale)), height: max(1, floor(h * scale)))

            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let scaled = renderer.image { _ in
                normalized.draw(in: CGRect(origin: .zero, size: targetSize))
            }

            return scaled.jpegData(compressionQuality: quality)
        }
    }

    static func makeThumbnailData(from imageData: Data) async -> Data? {
        guard let ui = UIImage(data: imageData) else { return nil }
        return await makeThumbnailData(from: ui)
    }

    /// Loads a UIImage for a given URL, preferring memory/disk caches.
    /// - Remote URLs will be cached in ImageDiskCache + ImageMemoryCache.
    static func loadUIImage(for url: URL) async -> UIImage? {
        if url.isFileURL {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }

        if let cached = ImageMemoryCache.shared.image(for: url) {
            return cached
        }

        if let disk = ImageDiskCache.shared.image(for: url) {
            ImageMemoryCache.shared.setImage(disk, for: url)
            return disk
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return nil
            }
            guard let img = UIImage(data: data) else { return nil }

            // Cache
            ImageDiskCache.shared.store(data: data, for: url)
            ImageMemoryCache.shared.setImage(img, for: url)

            return img
        } catch {
            return nil
        }
    }

    /// Produces thumbnail data for a remote URL string (best effort).
    static func thumbnailData(forRemoteURLString urlString: String) async -> Data? {
        let t = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: t), !url.isFileURL else { return nil }
        guard let img = await loadUIImage(for: url) else { return nil }
        return await makeThumbnailData(from: img)
    }

    /// Ensures `book.userCoverData` is set (synced thumbnail). Also keeps full-res user cover local.
    ///
    /// Rules:
    /// - If user cover file exists -> thumbnail is derived from that file.
    /// - Else tries the best remote candidates (thumbnailURL / coverURLCandidates / OpenLibrary) and persists the working hit.
    @MainActor
    static func backfillThumbnailIfNeeded(for book: Book, modelContext: ModelContext) async {
        if book.userCoverData != nil {
            return
        }

        // 1) User cover file (full-res local)
        if let fileName = book.userCoverFileName,
           let fileURL = UserCoverStore.fileURL(for: fileName),
           let img = UIImage(contentsOfFile: fileURL.path),
           let data = await makeThumbnailData(from: img) {
            book.userCoverData = data
            try? modelContext.save()
            return
        }

        // 2) Remote candidates
        let candidates = book.coverCandidatesAll
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter {
                guard let u = URL(string: $0) else { return false }
                return !u.isFileURL
            }

        for s in candidates {
            if let data = await thumbnailData(forRemoteURLString: s) {
                // Persist the working URL (https-normalized + moved best-first)
                book.persistResolvedCoverURL(s)
                book.userCoverData = data
                try? modelContext.save()
                return
            }
        }
    }

    /// One-time backfill for the entire library.
    ///
    /// This will generate synced thumbnails for books that don't have `userCoverData` yet.
    /// It is throttled to avoid hammering the network.
    @MainActor
    static func backfillAllBooksIfNeeded(modelContext: ModelContext) async {
        #if canImport(UIKit)
        do {
            let fd = FetchDescriptor<Book>()
            let books = try modelContext.fetch(fd)

            var processed = 0
            for b in books {
                if b.userCoverData != nil { continue }
                processed += 1
                await backfillThumbnailIfNeeded(for: b, modelContext: modelContext)

                // Light throttle to keep the UI snappy and be nice to the network.
                if processed % 6 == 0 {
                    try? await Task.sleep(nanoseconds: 120_000_000)
                }
            }
        } catch {
            // ignore
        }
        #endif
    }

    /// Called when the user picked a photo cover.
    /// Saves full-res locally and sets the synced thumbnail on the book.
    @MainActor
    static func applyUserPickedCover(imageData: Data, to book: Book, modelContext: ModelContext) async throws {
        // Convert to JPEG (Photos can be HEIC), but keep full resolution.
        let fullResJPEG: Data
        if let ui = UIImage(data: imageData), let jpg = ui.normalizedOrientation().jpegData(compressionQuality: fullResJPEGQuality) {
            fullResJPEG = jpg
        } else {
            fullResJPEG = imageData
        }

        // Remove previous user cover (avoid orphaned files)
        if let old = book.userCoverFileName {
            UserCoverStore.delete(filename: old)
        }

        let filename = try UserCoverStore.saveJPEGData(fullResJPEG)
        book.userCoverFileName = filename

        // Generate and set synced thumbnail
        if let ui = UIImage(data: fullResJPEG), let thumb = await makeThumbnailData(from: ui) {
            book.userCoverData = thumb
        } else {
            book.userCoverData = nil
        }

        try? modelContext.save()
    }

    /// Called when the user explicitly selects a remote cover URL.
    /// Clears any user photo cover (since the intent is "use online cover") and sets a synced thumbnail.
    @MainActor
    static func applyRemoteCover(urlString: String, to book: Book, modelContext: ModelContext) async {
        let t = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }

        // If a user photo cover exists, remove it.
        if let old = book.userCoverFileName {
            UserCoverStore.delete(filename: old)
            book.userCoverFileName = nil
        }

        // Persist the chosen URL as primary
        book.persistResolvedCoverURL(t)

        if let data = await thumbnailData(forRemoteURLString: t) {
            book.userCoverData = data
        } else {
            // If we couldn't download, still keep URL for later; UI will fallback to placeholder.
            book.userCoverData = nil
        }

        try? modelContext.save()
    }

    #endif
}

#if !canImport(UIKit)
extension CoverThumbnailer {
    @MainActor
    static func makeThumbnailData(from imageData: Data) async -> Data? { nil }

    @MainActor
    static func backfillThumbnailIfNeeded(for book: Book, modelContext: ModelContext) async { }

    @MainActor
    static func backfillAllBooksIfNeeded(modelContext: ModelContext) async { }

    @MainActor
    static func applyUserPickedCover(imageData: Data, to book: Book, modelContext: ModelContext) async throws { }

    @MainActor
    static func applyRemoteCover(urlString: String, to book: Book, modelContext: ModelContext) async { }
}
#endif

#if canImport(UIKit)
private extension UIImage {
    /// Returns a copy with orientation normalized to `.up`.
    func normalizedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
#endif

// MARK: - UI helpers

struct BookCoverPlaceholder: View {
    var cornerRadius: CGFloat = 10

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.secondary.opacity(0.12))
            .overlay(
                Image(systemName: "book")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.55))
            )
    }
}

/// Standard cover renderer used throughout the app.
/// - Prefers synced thumbnail data (`book.userCoverData`).
/// - Falls back to remote candidates and caches the resolved cover as thumbnail.
struct BookCoverThumbnailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var book: Book

    var size: CGSize
    var cornerRadius: CGFloat
    var contentMode: ContentMode = .fit

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let data = book.userCoverData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                remoteFallback
            }
            #else
            remoteFallback
            #endif
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    private var remoteFallback: some View {
        let candidates = book.coverCandidatesAll

        if !candidates.isEmpty {
            CoverCandidatesImage(
                urlStrings: candidates,
                preferredURLString: book.thumbnailURL,
                contentMode: contentMode,
                onResolvedURL: { resolvedURL in
                    // Persist best URL (remote only) and generate synced thumbnail.
                    book.persistResolvedCoverURL(resolvedURL)

                    #if canImport(UIKit)
                    Task { @MainActor in
                        // If we don't have a synced thumbnail yet, try to backfill it now.
                        // This handles both cases:
                        // - local user photo exists (file on disk)
                        // - remote URL succeeded
                        if book.userCoverData == nil {
                            await CoverThumbnailer.backfillThumbnailIfNeeded(for: book, modelContext: modelContext)
                        } else {
                            try? modelContext.save()
                        }
                    }
                    #else
                    try? modelContext.save()
                    #endif
                }
            ) { image in
                image.resizable().aspectRatio(contentMode: contentMode)
            } placeholder: {
                BookCoverPlaceholder(cornerRadius: cornerRadius)
            }
        } else {
            BookCoverPlaceholder(cornerRadius: cornerRadius)
        }
    }
}

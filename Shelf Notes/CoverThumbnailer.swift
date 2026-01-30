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
import ImageIO
import UniformTypeIdentifiers
#endif

// MARK: - Thumbnail generation + backfill

enum CoverThumbnailer {

    // Tweak these if you want sharper thumbnails or smaller sync payload.
    static let thumbnailMaxPixel: CGFloat = 600
    static let thumbnailJPEGQuality: CGFloat = 0.82

    // For user-uploaded covers: keep a high-quality, full-resolution JPEG locally.
    static let fullResJPEGQuality: CGFloat = 0.95

    enum RemoteCoverTarget {
        case thumbnail
        case display
    }

    /// Attempts to upgrade known remote cover URLs to a higher resolution variant.
    /// This is best-effort and falls back to the original string if parsing fails.
    static func upgradedRemoteURLString(_ urlString: String, target: RemoteCoverTarget) -> String {
        let t = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return urlString }
        guard let comps = URLComponents(string: t), let host = comps.host?.lowercased() else { return urlString }
        // Never touch local file URLs.
        if let u = URL(string: t), u.isFileURL { return urlString }

        // Google Books cover URLs: bump `zoom=` for better quality.
        if host.contains("books.google") || host.contains("books.googleusercontent") {
            let targetZoom = (target == .display) ? 3 : 2
            var c = comps
            var items = c.queryItems ?? []
            if let idx = items.firstIndex(where: { $0.name.lowercased() == "zoom" }) {
                let current = Int(items[idx].value ?? "") ?? 1
                if current < targetZoom { items[idx].value = String(targetZoom) }
            } else {
                items.append(URLQueryItem(name: "zoom", value: String(targetZoom)))
            }
            c.queryItems = items
            return c.url?.absoluteString ?? urlString
        }

        // OpenLibrary already supports -L/-M/-S in the path; we don't rewrite here.
        return urlString
    }

    #if canImport(UIKit)

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

        return await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                guard let data = image.jpegData(compressionQuality: 1.0) ?? image.pngData() else { return nil }
                return thumbnailJPEGData(from: data, maxPixel: maxPixel, quality: quality)
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

    /// Ensures `book.userCoverData` (synced thumbnail) exists and is not low-res.
    ///
    /// - If a full-res user cover file exists, we derive the thumbnail from that file.
    /// - Otherwise we try remote URLs (preferring the freshly resolved one if provided).
    @MainActor
    static func refreshSyncedThumbnailIfNeeded(for book: Book, resolvedURLString: String? = nil, modelContext: ModelContext) async {
        if let data = book.userCoverData, !isLowResSyncedThumbnail(data) {
            return
        }

        // 1) User cover file (full-res local)
        if let fileName = book.userCoverFileName,
           let fileURL = UserCoverStore.fileURL(for: fileName),
           let bytes = await CoverImageLoader.loadImageData(for: fileURL),
           let thumb = await makeThumbnailData(from: bytes) {
            book.userCoverData = thumb
            modelContext.saveWithDiagnostics()
            return
        }

        // 2) Remote candidates (resolved first, then persisted candidates, then OpenLibrary fallback)
        var pool: [String] = []
        if let s = resolvedURLString?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            pool.append(s)
        }
        pool.append(contentsOf: book.coverCandidatesAll)

        // Deduplicate + skip file URLs
        var candidates: [String] = []
        for s in pool {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            guard let u = URL(string: t), !u.isFileURL else { continue }
            if !candidates.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                candidates.append(t)
            }
        }

        for s in candidates {
            if let data = await thumbnailData(forRemoteURLString: s) {
                book.persistResolvedCoverURL(s)
                book.userCoverData = data
                modelContext.saveWithDiagnostics()
                return
            }
        }
    }

    /// Produces thumbnail data for a remote URL string (best effort).
    ///
    /// IMPORTANT:
    /// We try the ORIGINAL URL first.
    /// Reason: some Google Books URLs return a valid placeholder image at zoom=2/3 ("image not available"),
    /// while zoom=1 returns the real cover. If we prefer upgraded first, we may "stick" the placeholder into userCoverData.
    static func thumbnailData(forRemoteURLString urlString: String) async -> Data? {
        let t = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }

        // Never try to thumbnail local file URLs here.
        guard let rawURL = URL(string: t), !rawURL.isFileURL else { return nil }

        let upgradedString = upgradedRemoteURLString(t, target: .thumbnail)

        let attempts: [String]
        if upgradedString.caseInsensitiveCompare(t) == .orderedSame {
            attempts = [t]
        } else {
            // ORIGINAL first, then upgraded.
            attempts = [t, upgradedString]
        }

        for s in attempts {
            guard let url = URL(string: s), !url.isFileURL else { continue }
            guard let bytes = await CoverImageLoader.loadImageData(for: url) else { continue }
            if let thumb = await makeThumbnailData(from: bytes) {
                return thumb
            }
        }

        return nil
    }

    /// Ensures `book.userCoverData` is set (synced thumbnail). Also keeps full-res user cover local.
    ///
    /// Rules:
    /// - If user cover file exists -> thumbnail is derived from that file.
    /// - Else try remote URLs (best-first) to derive a synced thumbnail.
    static func backfillThumbnailIfNeeded(for book: Book, modelContext: ModelContext) async {
        if let data = book.userCoverData, !isLowResSyncedThumbnail(data) {
            return
        }

        // 1) User cover file (full-res local)
        if let fileName = book.userCoverFileName,
           let fileURL = UserCoverStore.fileURL(for: fileName),
           let bytes = await CoverImageLoader.loadImageData(for: fileURL),
           let thumb = await makeThumbnailData(from: bytes) {
            book.userCoverData = thumb
            modelContext.saveWithDiagnostics()
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
                modelContext.saveWithDiagnostics()
                return
            }
        }
    }

    /// One-time backfill for the entire library.
    ///
    /// This will generate synced thumbnails for books that don't have `userCoverData` yet
    /// OR have a low-res synced thumbnail.
    /// It is throttled to avoid hammering the network and to keep the UI responsive.
    @MainActor
    static func backfillAllBooksIfNeeded(modelContext: ModelContext) async {
        await backfillAllBooksIfNeeded(
            modelContext: modelContext,
            batchSize: 6,
            interBatchDelayNanoseconds: 120_000_000
        )
    }

    /// Backfills synced cover thumbnails in small bursts.
    ///
    /// This is intentionally `@MainActor` because SwiftData `ModelContext` is main-actor-bound in this app,
    /// but we continuously yield/sleep so we don't monopolize the main thread.
    @MainActor
    static func backfillAllBooksIfNeeded(
        modelContext: ModelContext,
        batchSize: Int,
        interBatchDelayNanoseconds: UInt64
    ) async {
        let batch = max(1, batchSize)

        do {
            let fd = FetchDescriptor<Book>()
            let books = try modelContext.fetch(fd)

            // Build a work list first so we don't keep re-checking conditions while updating.
            let pending = books.filter { book in
                guard let data = book.userCoverData else { return true }
                return isLowResSyncedThumbnail(data)
            }

            guard !pending.isEmpty else { return }

            var processed = 0
            for b in pending {
                if Task.isCancelled { return }

                await backfillThumbnailIfNeeded(for: b, modelContext: modelContext)
                processed += 1

                // Keep the UI responsive: yield often and sleep between batches.
                if processed % batch == 0 {
                    await Task.yield()
                    if interBatchDelayNanoseconds > 0 {
                        try? await Task.sleep(nanoseconds: interBatchDelayNanoseconds)
                    }
                } else if processed % 2 == 0 {
                    // small cooperative yield even within a batch
                    await Task.yield()
                }
            }
        } catch {
            // ignore
        }
    }

    /// Called when the user picked a photo cover.
    /// Saves full-res locally and sets the synced thumbnail on the book.
    @MainActor
    static func applyUserPickedCover(imageData: Data, to book: Book, modelContext: ModelContext) async throws {
        // Convert to JPEG (Photos can be HEIC), but keep full resolution and normalize orientation.
        let fullResJPEG: Data = await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                convertToJPEGKeepingMaxResolution(imageData, quality: fullResJPEGQuality) ?? imageData
            }
        }.value

        // Remove previous user cover (avoid orphaned files)
        if let old = book.userCoverFileName {
            UserCoverStore.delete(filename: old)
        }

        let filename = try UserCoverStore.saveJPEGData(fullResJPEG)
        book.userCoverFileName = filename

        // Synced thumbnail
        if let thumb = await makeThumbnailData(from: fullResJPEG) {
            book.userCoverData = thumb
        } else {
            book.userCoverData = nil
        }

        modelContext.saveWithDiagnostics()
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

        // Persist the chosen remote URL
        book.persistResolvedCoverURL(t)

        // Generate synced thumbnail from remote
        if let data = await thumbnailData(forRemoteURLString: t) {
            book.userCoverData = data
        } else {
            book.userCoverData = nil
        }

        modelContext.saveWithDiagnostics()
    }

    // MARK: - ImageIO helpers

    private static func pixelSize(from data: Data) -> (Int, Int)? {
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
    private static func thumbnailJPEGData(from data: Data, maxPixel: Int, quality: CGFloat) -> Data? {
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
    private static func convertToJPEGKeepingMaxResolution(_ data: Data, quality: CGFloat) -> Data? {
        guard let (w, h) = pixelSize(from: data) else { return nil }
        let maxPx = max(w, h)
        return thumbnailJPEGData(from: data, maxPixel: maxPx, quality: quality)
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
    static func backfillAllBooksIfNeeded(
        modelContext: ModelContext,
        batchSize: Int,
        interBatchDelayNanoseconds: UInt64
    ) async { }

    @MainActor
    static func applyUserPickedCover(imageData: Data, to book: Book, modelContext: ModelContext) async throws { }

    @MainActor
    static func applyRemoteCover(urlString: String, to book: Book, modelContext: ModelContext) async { }
}
#endif

// MARK: - UI helpers

struct BookCoverPlaceholder: View {
    var cornerRadius: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.secondary.opacity(0.18))
            .overlay {
                Image(systemName: "book.closed")
                    .font(.title3)
                    .foregroundStyle(.secondary.opacity(0.45))
            }
    }
}

struct BookCoverThumbnailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var book: Book

    var size: CGSize
    var cornerRadius: CGFloat
    var contentMode: ContentMode = .fit

    private var prefersFullRes: Bool {
        max(size.width, size.height) >= 110
    }

    var body: some View {
        Group {
            #if canImport(UIKit)

            // 1) User-selected photo cover (local full-res) — always wins for large surfaces
            if prefersFullRes,
               let ui = localUserCoverUIImage() {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)

            // 2) Synced thumbnail (fast path)
            } else if let data = book.userCoverData,
                      let ui = UIImage(data: data) {

                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    // If the synced thumb is low-res (or "stuck" as a tiny placeholder),
                    // try to refresh it in the background.
                    .task(id: data) {
                        guard CoverThumbnailer.isLowResSyncedThumbnail(data) else { return }
                        await CoverThumbnailer.refreshSyncedThumbnailIfNeeded(
                            for: book,
                            resolvedURLString: book.thumbnailURL,
                            modelContext: modelContext
                        )
                    }

            // 3) Remote candidates
            } else {
                remoteFallback(prefersFullRes: prefersFullRes)
            }

            #else
            remoteFallback(prefersFullRes: prefersFullRes)
            #endif
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    #if canImport(UIKit)
    private func localUserCoverUIImage() -> UIImage? {
        guard let fileName = book.userCoverFileName,
              let fileURL = UserCoverStore.fileURL(for: fileName) else { return nil }
        return UIImage(contentsOfFile: fileURL.path)
    }
    #endif

    @ViewBuilder
    private func remoteFallback(prefersFullRes: Bool) -> some View {
        let rawAll = book.coverCandidatesAll

        // IMPORTANT: CoverCandidatesImage is remote-oriented; skip local file URLs here.
        let raw = rawAll.filter { s in
            guard let u = URL(string: s.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
            return !u.isFileURL
        }

        // For large covers: try ORIGINAL first, then upgraded.
        // This avoids "image not available" placeholders at higher zoom levels winning.
        let candidates = prefersFullRes
        ? raw.flatMap { original -> [String] in
            let upgraded = CoverThumbnailer.upgradedRemoteURLString(original, target: .display)
            if upgraded.caseInsensitiveCompare(original) == .orderedSame {
                return [original]
            } else {
                return [original, upgraded]
            }
        }
        : raw

        let preferred = book.thumbnailURL // keep original as preferred

        if !candidates.isEmpty {
            CoverCandidatesImage(
                urlStrings: candidates,
                preferredURLString: preferred,
                contentMode: contentMode,
                onResolvedURL: { resolvedURL in
                    // Persist best URL (remote only) and generate synced thumbnail.
                    book.persistResolvedCoverURL(resolvedURL)

                    #if canImport(UIKit)
                    Task { @MainActor in
                        await CoverThumbnailer.refreshSyncedThumbnailIfNeeded(
                            for: book,
                            resolvedURLString: resolvedURL,
                            modelContext: modelContext
                        )
                    }
                    #else
                    modelContext.saveWithDiagnostics()
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

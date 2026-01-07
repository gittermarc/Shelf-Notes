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

    /// Heuristic: treat very small synced thumbnails as "low-res" (often caused by low-res remote thumbnails).
    static func isLowResSyncedThumbnail(_ data: Data) -> Bool {
        guard let ui = UIImage(data: data) else { return true }
        let pxW = ui.size.width * ui.scale
        let pxH = ui.size.height * ui.scale
        // ~420px is enough to look crisp for a 120x180pt cover on 3x screens (360x540px).
        return max(pxW, pxH) < 420
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
           let img = UIImage(contentsOfFile: fileURL.path),
           let data = await makeThumbnailData(from: img) {
            book.userCoverData = data
            try? modelContext.save()
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
                try? modelContext.save()
                return
            }
        }
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
        guard !t.isEmpty else { return nil }

        // Never try to thumbnail local file URLs here.
        guard let rawURL = URL(string: t), !rawURL.isFileURL else { return nil }

        // Try to fetch a higher-res variant first, then downscale to our synced thumbnail size.
        let upgradedString = upgradedRemoteURLString(t, target: .thumbnail)
        let url = URL(string: upgradedString) ?? rawURL
        guard !url.isFileURL else { return nil }

        guard let img = await loadUIImage(for: url) else { return nil }
        return await makeThumbnailData(from: img)
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

                await backfillThumbnailIfNeeded(for: b, modelContext: modelContext)
                processed += 1

                // Throttle a bit every few items
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

        // Synced thumbnail
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

        // Persist the chosen remote URL
        book.persistResolvedCoverURL(t)

        // Generate synced thumbnail from remote
        if let data = await thumbnailData(forRemoteURLString: t) {
            book.userCoverData = data
        } else {
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
            if !prefersFullRes, let data = book.userCoverData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
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

    @ViewBuilder
    private func remoteFallback(prefersFullRes: Bool) -> some View {
        let raw = book.coverCandidatesAll
        let candidates = prefersFullRes ? raw.map { CoverThumbnailer.upgradedRemoteURLString($0, target: .display) } : raw
        let preferred = prefersFullRes ? book.thumbnailURL.map { CoverThumbnailer.upgradedRemoteURLString($0, target: .display) } : book.thumbnailURL

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
                        await CoverThumbnailer.refreshSyncedThumbnailIfNeeded(for: book, resolvedURLString: resolvedURL, modelContext: modelContext)
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

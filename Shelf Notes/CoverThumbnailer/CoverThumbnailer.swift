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

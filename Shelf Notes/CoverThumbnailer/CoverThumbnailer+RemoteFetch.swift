//
//  CoverThumbnailer+RemoteFetch.swift
//  Shelf Notes
//
//  Split from CoverThumbnailer.swift (remote bytes + cache reading/writing)
//

import Foundation
import SwiftData

#if canImport(UIKit)
extension CoverThumbnailer {

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
}
#endif

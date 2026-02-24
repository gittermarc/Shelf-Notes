//
//  CoverThumbnailer+Backfill.swift
//  Shelf Notes
//
//  Split from CoverThumbnailer.swift (batch backfill, per-book refresh)
//

import Foundation
import SwiftData

#if canImport(UIKit)
extension CoverThumbnailer {

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
}
#endif

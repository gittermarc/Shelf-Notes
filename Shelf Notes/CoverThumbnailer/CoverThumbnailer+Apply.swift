//
//  CoverThumbnailer+Apply.swift
//  Shelf Notes
//
//  Split from CoverThumbnailer.swift (applyRemoteCover / applyUserCover)
//

import Foundation
import SwiftData

#if canImport(UIKit)
extension CoverThumbnailer {

    /// Called when the user picked a photo cover.
    /// Saves full-res locally and sets the synced thumbnail on the book.
    @MainActor
    static func applyUserPickedCover(imageData: Data, to book: Book, modelContext: ModelContext) async throws {
        // Convert to JPEG (Photos can be HEIC), but keep full resolution and normalize orientation.
        let quality = fullResJPEGQuality
        let fullResJPEG: Data = await Task.detached(priority: .userInitiated) {
            autoreleasepool {
                convertToJPEGKeepingMaxResolution(imageData, quality: quality) ?? imageData
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
}
#endif

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

import SwiftData
import SwiftUI

/// A performance-optimized cover renderer for list rows.
///
/// Differences vs. `BookCoverThumbnailView`:
/// - No persistence (no `persistResolvedCoverURL`, no `userCoverData` refresh).
/// - Decodes `Book.userCoverData` off-main and caches the decoded UIImage.
/// - Uses existing `CoverCandidatesImage` with `onResolvedURL = nil` as a read-only fallback.
struct LibraryRowCoverView: View {
    @Bindable var book: Book

    var size: CGSize
    var cornerRadius: CGFloat
    var contentMode: ContentMode = .fit

    /// When `true`, we prefer loading a higher-resolution remote cover (zoom-upgraded when possible)
    /// and use the synced thumbnail only as a fallback/placeholder.
    ///
    /// This is intended for Grid tiles and Detail surfaces where the cover is physically larger.
    /// The synced thumbnail is optimized for fast list scrolling and CloudKit payload size and can look soft
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
    /// - keeps the view side-effect free (no SwiftData saves)
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

extension LibraryRowCoverView {
    static func displayCandidates(from raw: [String]) -> [String] {
        CoverDisplayCandidates.make(from: raw)
    }

    static func preferredHighResURLString(for book: Book) -> String? {
        CoverDisplayCandidates.preferredHighResURLString(for: book)
    }
}

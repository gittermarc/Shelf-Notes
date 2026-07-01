//
//  TimelineCoverView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 01.07.26.
//
//  Purpose:
//  - Side-effect-free cover rendering for the horizontal reading timeline.
//  - No SwiftData saves, no resolved URL persistence, no thumbnail refresh and no backfill.
//

import SwiftUI

struct TimelineCoverView: View {
    let book: Book
    let size: CGSize
    let cornerRadius: CGFloat
    var contentMode: ContentMode = .fill

    var body: some View {
        LibraryRowCoverView(
            book: book,
            size: size,
            cornerRadius: cornerRadius,
            contentMode: contentMode,
            prefersHighResCover: false
        )
    }
}
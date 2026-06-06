//
//  GoalSlotCoverView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 06.06.26.
//
//  Purpose:
//  - Read-only cover rendering for the small annual goal slots.
//  - Keeps the Goals grid free of cover persistence and thumbnail backfill work.
//  - Reuses the scroll-optimized LibraryRowCoverView fast path.
//

import SwiftUI

struct GoalSlotCoverView: View {
    let book: Book
    let size: CGSize
    var cornerRadius: CGFloat = 12

    var body: some View {
        LibraryRowCoverView(
            book: book,
            size: size,
            cornerRadius: cornerRadius,
            contentMode: .fill,
            prefersHighResCover: false
        )
    }
}

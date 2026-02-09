//
//  TagChip.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Split from ContentView.swift on 05.01.26.
//

import SwiftUI

struct TagChip: View {
    let text: String
    let systemImage: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)

            Text(text)
                .font(.caption)
                .lineLimit(1)

            Button { onRemove() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial)
        .clipShape(Capsule())
    }
}

// MARK: - Library UI Bits

/// Wird in LibraryView verwendet (Header-Stat-Karten).
struct LibraryStatCard: View {
    let title: String
    let value: Int
    let systemImage: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(isActive ? .primary : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("\(value)")
                        .font(.headline)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isActive ? .ultraThinMaterial : .thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title): \(value)")
    }
}

/// Kleines Cover-Thumbnail für die horizontale Mini-Shelf im Library-Header.
struct LibraryCoverThumb: View {
    let book: Book

    var body: some View {
        // PERF: Avoid decoding `userCoverData` in SwiftUI body during header animations.
        // `LibraryRowCoverView` decodes off-main and caches the decoded thumbnail.
        LibraryRowCoverView(
            book: book,
            size: CGSize(width: 44, height: 66),
            cornerRadius: 10,
            contentMode: .fill,
            prefersHighResCover: false
        )
    }
}

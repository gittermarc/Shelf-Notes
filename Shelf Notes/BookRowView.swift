//
//  BookRowView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Split from ContentView.swift on 05.01.26.
//

import SwiftUI

struct BookRowView: View {
    let book: Book
    let appearance: LibraryRowAppearanceSnapshot

    private enum MetaPart {
        case status(String)
        case readDate(String)
        case rating(Double)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if appearance.showCovers {
                cover
            }

            VStack(alignment: .leading, spacing: appearance.resolvedRowContentSpacing) {
                Text(book.title.isEmpty ? "Ohne Titel" : book.title)
                    .font(.headline)

                if appearance.showAuthor, !book.author.isEmpty {
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Status + (Monat/Jahr, wenn gelesen)
                if !metaParts.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(metaParts.enumerated()), id: \.offset) { idx, part in
                            if idx > 0 {
                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            switch part {
                            case .status(let text):
                                Text(text)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            case .readDate(let text):
                                Text(text)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            case .rating(let value):
                                HStack(spacing: 4) {
                                    StarsView(rating: value)
                                    Text(String(format: "%.1f", value))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }

                // Tags eine Zeile tiefer
                if appearance.showTags, !book.tags.isEmpty, appearance.maxTags > 0 {
                    let n = max(1, min(appearance.maxTags, book.tags.count))
                    let visible = Array(book.tags.prefix(n))
                    let remaining = max(0, book.tags.count - visible.count)

                    switch appearance.tagStyle {
                    case .hashtags:
                        Text(visible.map { "#\($0)" }.joined(separator: " "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .chips:
                        TagPillsRow(tags: visible, remainingCount: remaining)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var readMonthYearText: String? {
        guard appearance.showReadDate else { return nil }
        guard book.status == .finished else { return nil }
        guard let d = book.readTo ?? book.readFrom else { return nil }
        return d.formatted(.dateTime.month(.abbreviated).year())
    }

    private var rowUserRating: Double? {
        guard appearance.showRating else { return nil }
        guard book.status == .finished else { return nil }
        return book.userRatingAverage1
    }

    private var metaParts: [MetaPart] {
        var parts: [MetaPart] = []

        if appearance.showStatus {
            parts.append(.status(book.status.displayName))
        }

        if let monthYear = readMonthYearText {
            parts.append(.readDate(monthYear))
        }

        if let avg = rowUserRating {
            parts.append(.rating(avg))
        }

        return parts
    }

    @ViewBuilder
    private var cover: some View {
        LibraryRowCoverView(
            book: book,
            size: appearance.resolvedCoverSize,
            cornerRadius: appearance.resolvedCoverCornerRadius,
            contentMode: appearance.resolvedCoverContentMode
        )
        .shadow(
            color: appearance.coverShadowEnabled ? .black.opacity(0.12) : .clear,
            radius: appearance.coverShadowEnabled ? 4 : 0,
            x: 0,
            y: appearance.coverShadowEnabled ? 2 : 0
        )
    }
}

//
//  LibraryView+Grid.swift
//  Shelf Notes
//
//  Grid layout for the library (List vs Grid).
//

import SwiftUI

extension LibraryView {

    // MARK: - Grid

    var gridView: some View {
        GeometryReader { geo in
            let sidePadding: CGFloat = 16
            let spacing: CGFloat = 14
            let contentWidth = max(0, geo.size.width - sidePadding * 2)

            // Heuristics: iPhone usually lands on 2 columns; iPad on 3–4 columns.
            let minTileWidth: CGFloat = (contentWidth >= 700) ? 190 : 150
            let columnsCount = max(2, Int((contentWidth + spacing) / (minTileWidth + spacing)))
            let itemWidth = (contentWidth - CGFloat(columnsCount - 1) * spacing) / CGFloat(columnsCount)

            let columns = Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .top), count: columnsCount)

            ScrollView {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(displayedBooks) { book in
                        NavigationLink {
                            BookDetailView(book: book)
                        } label: {
                            LibraryGridItemView(
                                book: book,
                                itemWidth: itemWidth,
                                onRequestDelete: {
                                    bookToDelete = book
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, sidePadding)
                .padding(.vertical, 12)
            }
        }
    }
}

private struct LibraryGridItemView: View {
    let book: Book
    let itemWidth: CGFloat
    let onRequestDelete: () -> Void

    // Keep behavior aligned with the existing row appearance settings.
    @AppStorage(AppearanceStorageKey.libraryShowCovers) private var showCovers: Bool = true
    @AppStorage(AppearanceStorageKey.libraryCoverCornerRadius) private var coverCornerRadius: Double = 8
    @AppStorage(AppearanceStorageKey.libraryCoverContentMode) private var coverContentModeRaw: String = LibraryCoverContentModeOption.fit.rawValue
    @AppStorage(AppearanceStorageKey.libraryCoverShadowEnabled) private var coverShadowEnabled: Bool = false

    @AppStorage(AppearanceStorageKey.libraryRowShowAuthor) private var showAuthor: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowStatus) private var showStatus: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowReadDate) private var showReadDate: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowRating) private var showRating: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowTags) private var showTags: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowMaxTags) private var maxTags: Int = 2
    @AppStorage(AppearanceStorageKey.libraryTagStyle) private var tagStyleRaw: String = LibraryTagStyleOption.hashtags.rawValue
    @AppStorage(AppearanceStorageKey.libraryRowContentSpacing) private var rowContentSpacing: Double = 2

    private var resolvedCoverRadius: CGFloat {
        CGFloat(coverCornerRadius)
    }

    private var resolvedContentMode: ContentMode {
        (LibraryCoverContentModeOption(rawValue: coverContentModeRaw) ?? .fit).contentMode
    }

    private var resolvedTagStyle: LibraryTagStyleOption {
        LibraryTagStyleOption(rawValue: tagStyleRaw) ?? .hashtags
    }

    private enum MetaPart {
        case status(String)
        case readDate(String)
        case rating(Double)
    }

    private var readMonthYearText: String? {
        guard showReadDate else { return nil }
        guard book.status == .finished else { return nil }
        guard let d = book.readTo ?? book.readFrom else { return nil }
        return d.formatted(.dateTime.month(.abbreviated).year())
    }

    private var userRating: Double? {
        guard showRating else { return nil }
        guard book.status == .finished else { return nil }
        return book.userRatingAverage1
    }

    private var metaParts: [MetaPart] {
        var parts: [MetaPart] = []

        if showStatus {
            parts.append(.status(book.status.displayName))
        }

        if let monthYear = readMonthYearText {
            parts.append(.readDate(monthYear))
        }

        if let avg = userRating {
            parts.append(.rating(avg))
        }

        return parts
    }

    private var coverSize: CGSize {
        CGSize(width: itemWidth, height: itemWidth * 1.5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: max(4, CGFloat(rowContentSpacing))) {
            if showCovers {
                LibraryRowCoverView(
                    book: book,
                    size: coverSize,
                    cornerRadius: resolvedCoverRadius,
                    contentMode: resolvedContentMode,
                    prefersHighResCover: true
                )
                .shadow(
                    color: coverShadowEnabled ? .black.opacity(0.12) : .clear,
                    radius: coverShadowEnabled ? 4 : 0,
                    x: 0,
                    y: coverShadowEnabled ? 2 : 0
                )
            } else {
                placeholder
            }

            Text(book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ohne Titel" : book.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if showAuthor, !book.author.isEmpty {
                Text(book.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

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

                    Spacer(minLength: 0)
                }
            }

            if showTags, !book.tags.isEmpty, maxTags > 0 {
                let n = max(1, min(maxTags, book.tags.count))
                let visible = Array(book.tags.prefix(n))
                let remaining = max(0, book.tags.count - visible.count)

                switch resolvedTagStyle {
                case .hashtags:
                    Text(visible.map { "#\($0)" }.joined(separator: " "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                case .chips:
                    TagPillsRow(tags: visible, remainingCount: remaining)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.secondary.opacity(0.18), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contextMenu {
            Button(role: .destructive) {
                onRequestDelete()
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(book.title)
        .accessibilityHint("Tippen für Details. Long-Press für Aktionen")
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: resolvedCoverRadius, style: .continuous)
                .fill(.secondary.opacity(0.16))

            Image(systemName: "book.closed")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: coverSize.width, height: coverSize.height)
    }
}

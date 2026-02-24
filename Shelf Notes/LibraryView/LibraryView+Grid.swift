//
//  LibraryView+Grid.swift
//  Shelf Notes
//
//  Grid layout for the library (List vs Grid).
//

import SwiftUI

extension LibraryView {

    // MARK: - Grid

    func gridView(displayedBooks: [Book]) -> some View {
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
                        if isSelectionMode {
                            Button {
                                toggleSelection(book)
                            } label: {
                                LibraryGridItemView(
                                    book: book,
                                    itemWidth: itemWidth,
                                    isSelectionMode: true,
                                    isSelected: isSelected(book),
                                    onRequestDelete: {
                                        bookToDelete = book
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink {
                                BookDetailView(book: book)
                            } label: {
                                LibraryGridItemView(
                                    book: book,
                                    itemWidth: itemWidth,
                                    isSelectionMode: false,
                                    isSelected: false,
                                    onRequestDelete: {
                                        bookToDelete = book
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        }
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
    let isSelectionMode: Bool
    let isSelected: Bool
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
        card
    }

    // MARK: - Card Composition

    private var card: some View {
        VStack(alignment: .leading, spacing: max(4, CGFloat(rowContentSpacing))) {
            coverBlock
            titleBlock
            authorBlock
            metaBlock
            tagsBlock
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(cardBackground)
        .overlay(cardBorder)
        .overlay(alignment: .topTrailing) {
            selectionBadge
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contextMenu { contextMenuContent }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(book.title)
        .accessibilityHint(isSelectionMode ? "Tippen zum Auswählen" : "Tippen für Details. Long-Press für Aktionen")
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.thinMaterial)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(borderStrokeStyle, lineWidth: borderLineWidth)
    }

    private var borderLineWidth: CGFloat {
        (isSelectionMode && isSelected) ? 2 : 1
    }

    private var borderStrokeStyle: AnyShapeStyle {
        if isSelectionMode && isSelected {
            return AnyShapeStyle(.tint)
        }
        return AnyShapeStyle(.secondary.opacity(0.18))
    }

    // MARK: - Blocks

    @ViewBuilder
    private var coverBlock: some View {
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
    }

    private var titleBlock: some View {
        Text(book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ohne Titel" : book.title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }

    @ViewBuilder
    private var authorBlock: some View {
        if showAuthor, !book.author.isEmpty {
            Text(book.author)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var metaBlock: some View {
        if !metaParts.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(metaParts.enumerated()), id: \.offset) { idx, part in
                    if idx > 0 {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    metaPartView(part)
                }

                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func metaPartView(_ part: MetaPart) -> some View {
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

    private var visibleTags: [String] {
        guard maxTags > 0 else { return [] }
        let n = max(1, min(maxTags, book.tags.count))
        return Array(book.tags.prefix(n))
    }

    private var remainingTagsCount: Int {
        max(0, book.tags.count - visibleTags.count)
    }

    @ViewBuilder
    private var tagsBlock: some View {
        if showTags, !visibleTags.isEmpty {
            switch resolvedTagStyle {
            case .hashtags:
                Text(visibleTags.map { "#\($0)" }.joined(separator: " "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            case .chips:
                TagPillsRow(tags: visibleTags, remainingCount: remainingTagsCount)
            }
        }
    }

    @ViewBuilder
    private var selectionBadge: some View {
        if isSelectionMode {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(selectionBadgeStyle)
                .padding(8)
                .background(.thinMaterial, in: Circle())
                .padding(6)
        }
    }

    private var selectionBadgeStyle: AnyShapeStyle {
        isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        if !isSelectionMode {
            Button(role: .destructive) {
                onRequestDelete()
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
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

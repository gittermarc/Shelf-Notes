//
//  LibraryView+Grid.swift
//  Shelf Notes
//
//  Grid layout for the library (List vs Grid).
//

import Foundation
import SwiftUI

extension LibraryView {

    // MARK: - Grid

    func gridView(
        displayedBooks: [Book],
        presentationsByBookID: [UUID: LibraryBookPresentation]
    ) -> some View {
        GeometryReader { geo in
            let sidePadding: CGFloat = 16
            let spacing: CGFloat = 16
            let contentWidth = max(0, geo.size.width - sidePadding * 2)

            let minTileWidth = libraryCoverSizeOption.gridMinimumTileWidth(for: contentWidth)
            let columnsCount = max(2, Int((contentWidth + spacing) / (minTileWidth + spacing)))
            let itemWidth = (contentWidth - CGFloat(columnsCount - 1) * spacing) / CGFloat(columnsCount)

            let columns = Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .top), count: columnsCount)
            let rowAppearance = libraryRowAppearance

            ScrollView {
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(displayedBooks) { book in
                        if isSelectionMode {
                            Button {
                                toggleSelection(book)
                            } label: {
                                LibraryGridItemView(
                                    book: book,
                                    presentation: presentationsByBookID[book.id],
                                    itemWidth: itemWidth,
                                    appearance: rowAppearance,
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
                                    presentation: presentationsByBookID[book.id],
                                    itemWidth: itemWidth,
                                    appearance: rowAppearance,
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
    let presentation: LibraryBookPresentation?
    let itemWidth: CGFloat
    let appearance: LibraryRowAppearanceSnapshot
    let isSelectionMode: Bool
    let isSelected: Bool
    let onRequestDelete: () -> Void

    private enum MetaPart {
        case status(String)
        case readDate(String)
        case rating(Double)
    }

    private var readMonthYearText: String? {
        guard appearance.showReadDate else { return nil }
        guard book.status == .finished else { return nil }
        guard let d = book.readTo ?? book.readFrom else { return nil }
        return d.formatted(.dateTime.month(.abbreviated).year())
    }

    private var userRating: Double? {
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

        if let avg = userRating {
            parts.append(.rating(avg))
        }

        return parts
    }

    private var metrics: LibraryGridCardMetrics {
        LibraryGridCardMetrics(
            itemWidth: itemWidth,
            rowContentSpacing: appearance.rowContentSpacing,
            showsCover: appearance.showCovers,
            coverSizeOption: appearance.coverSize
        )
    }

    var body: some View {
        card
    }

    // MARK: - Card Composition

    private var card: some View {
        VStack(alignment: .leading, spacing: metrics.contentSpacing) {
            if appearance.showCovers {
                coverBlock
            }

            detailsBlock
        }
        .frame(
            maxWidth: .infinity,
            minHeight: metrics.cardHeight,
            maxHeight: metrics.cardHeight,
            alignment: .topLeading
        )
        .padding(metrics.padding)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: metrics.cardCornerRadius, style: .continuous))
        .overlay(cardBorder)
        .overlay(alignment: .topTrailing) {
            selectionBadge
        }
        .contentShape(RoundedRectangle(cornerRadius: metrics.cardCornerRadius, style: .continuous))
        .contextMenu { contextMenuContent }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(book.title)
        .accessibilityHint(isSelectionMode ? "Tippen zum Auswählen" : "Tippen für Details. Long-Press für Aktionen")
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: metrics.cardCornerRadius, style: .continuous)
            .fill(.thinMaterial)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: metrics.cardCornerRadius, style: .continuous)
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
        if appearance.showCovers {
            LibraryRowCoverView(
                book: book,
                size: metrics.coverSize,
                cornerRadius: appearance.resolvedCoverCornerRadius,
                contentMode: appearance.resolvedCoverContentMode,
                prefersHighResCover: true
            )
            .frame(maxWidth: .infinity, alignment: .center)
            .shadow(
                color: appearance.coverShadowEnabled ? .black.opacity(0.12) : .clear,
                radius: appearance.coverShadowEnabled ? 4 : 0,
                x: 0,
                y: appearance.coverShadowEnabled ? 2 : 0
            )
            .overlay(alignment: .bottom) {
                gridProgressOverlay
            }
        }
    }

    @ViewBuilder
    private var gridProgressOverlay: some View {
        if appearance.showReadingProgress,
           let presentation,
           presentation.shouldShowReadingProgress {
            LibraryRowProgressView(presentation: presentation, style: .grid)
                .padding(6)
        }
    }

    private var detailsBlock: some View {
        VStack(alignment: .leading, spacing: metrics.contentSpacing) {
            titleBlock
                .frame(
                    maxWidth: .infinity,
                    minHeight: metrics.reservedTitleHeight,
                    maxHeight: metrics.reservedTitleHeight,
                    alignment: .topLeading
                )

            authorBlock
                .frame(
                    maxWidth: .infinity,
                    minHeight: metrics.reservedDetailHeight,
                    maxHeight: metrics.reservedDetailHeight,
                    alignment: .topLeading
                )

            metaBlock
                .frame(
                    maxWidth: .infinity,
                    minHeight: metrics.reservedDetailHeight,
                    maxHeight: metrics.reservedDetailHeight,
                    alignment: .topLeading
                )

            tagsBlock
                .frame(
                    maxWidth: .infinity,
                    minHeight: metrics.reservedDetailHeight,
                    maxHeight: metrics.reservedDetailHeight,
                    alignment: .topLeading
                )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var titleBlock: some View {
        Text(book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ohne Titel" : book.title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var authorBlock: some View {
        if appearance.showAuthor, !book.author.isEmpty {
            Text(book.author)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var metaBlock: some View {
        if let text = metaText, !text.isEmpty {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Color.clear
        }
    }

    private var visibleTags: [String] {
        guard appearance.maxTags > 0 else { return [] }
        let n = max(1, min(appearance.maxTags, book.tags.count))
        return Array(book.tags.prefix(n))
    }

    private var remainingTagsCount: Int {
        max(0, book.tags.count - visibleTags.count)
    }

    @ViewBuilder
    private var tagsBlock: some View {
        if let text = gridInlineProgressText, !text.isEmpty {
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if let text = tagsText, !text.isEmpty {
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Color.clear
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

    private var metaText: String? {
        let parts = metaParts.map { part in
            switch part {
            case .status(let text):
                return text
            case .readDate(let text):
                return text
            case .rating(let value):
                return "★ \(String(format: "%.1f", value))"
            }
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " • ")
    }

    private var gridInlineProgressText: String? {
        guard appearance.showCovers == false else { return nil }
        guard appearance.showReadingProgress else { return nil }
        guard let presentation, presentation.shouldShowReadingProgress else { return nil }

        let parts = [
            presentation.progressText,
            presentation.pageProgressText
        ].compactMap { $0 }

        guard parts.isEmpty == false else { return nil }
        return parts.joined(separator: " • ")
    }

    private var tagsText: String? {
        guard appearance.showTags, !visibleTags.isEmpty else { return nil }

        let body: String
        switch appearance.tagStyle {
        case .hashtags:
            body = visibleTags.map { "#\($0)" }.joined(separator: " ")
        case .chips:
            body = visibleTags.joined(separator: " · ")
        }

        guard !body.isEmpty else { return nil }

        if remainingTagsCount > 0 {
            return "\(body) +\(remainingTagsCount)"
        }

        return body
    }

}

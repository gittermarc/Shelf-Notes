//
//  LibraryContinueReadingCard.swift
//  Shelf Notes
//
//  Hero card for the current reading book in the Smart Shelf dashboard.
//

import SwiftUI

struct LibraryContinueReadingCard: View {
    let book: Book
    let presentation: LibraryBookPresentation?
    let appearance: LibraryRowAppearanceSnapshot

    private var title: String {
        let trimmed = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Ohne Titel" : trimmed
    }

    private var coverSize: CGSize {
        switch appearance.coverSize {
        case .small:
            return CGSize(width: 62, height: 92)
        case .standard:
            return CGSize(width: 72, height: 108)
        case .large:
            return CGSize(width: 82, height: 122)
        }
    }

    var body: some View {
        NavigationLink {
            BookDetailView(book: book)
        } label: {
            ViewThatFits(in: .horizontal) {
                horizontalContent
                verticalContent
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .overlay(cardBorder)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Öffnet das Buch")
    }

    private var horizontalContent: some View {
        HStack(alignment: .top, spacing: 14) {
            if appearance.showCovers {
                cover
            }

            textContent
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var verticalContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if appearance.showCovers {
                cover
            }

            textContent
        }
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Weiterlesen", systemImage: "book.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if book.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if appearance.showReadingProgress,
               let presentation,
               presentation.shouldShowReadingProgress {
                LibraryRowProgressView(presentation: presentation, style: .list)
            } else if let lastActivityText = presentation?.lastActivityText {
                Text(lastActivityText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Label("Öffnen", systemImage: "arrow.right.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
                .padding(.top, 2)
        }
    }

    private var cover: some View {
        LibraryRowCoverView(
            book: book,
            size: coverSize,
            cornerRadius: appearance.resolvedCoverCornerRadius,
            contentMode: appearance.resolvedCoverContentMode,
            prefersHighResCover: true
        )
        .shadow(
            color: appearance.coverShadowEnabled ? .black.opacity(0.16) : .clear,
            radius: appearance.coverShadowEnabled ? 6 : 0,
            x: 0,
            y: appearance.coverShadowEnabled ? 3 : 0
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.thinMaterial)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(.secondary.opacity(0.16), lineWidth: 1)
    }

    private var accessibilityLabel: String {
        var parts = ["Weiterlesen", title]

        if book.author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            parts.append(book.author)
        }

        if let presentation, presentation.accessibilitySummary.isEmpty == false {
            parts.append(presentation.accessibilitySummary)
        }

        return parts.joined(separator: ", ")
    }
}

//
//  LibraryShelfLaneView.swift
//  Shelf Notes
//
//  Horizontal cover lane for the Smart Shelf dashboard.
//

import SwiftUI

struct LibraryShelfLaneView: View {
    let lane: LibraryHomeResolvedLane
    let appearance: LibraryRowAppearanceSnapshot

    private var coverSize: CGSize {
        switch appearance.coverSize {
        case .small:
            return CGSize(width: 48, height: 72)
        case .standard:
            return CGSize(width: 56, height: 84)
        case .large:
            return CGSize(width: 64, height: 96)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(lane.title, systemImage: lane.systemImage)
                .font(.subheadline.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(lane.books) { book in
                        NavigationLink {
                            BookDetailView(book: book)
                        } label: {
                            laneItem(for: book)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 2)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func laneItem(for book: Book) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if appearance.showCovers {
                LibraryRowCoverView(
                    book: book,
                    size: coverSize,
                    cornerRadius: min(appearance.resolvedCoverCornerRadius, 10),
                    contentMode: appearance.resolvedCoverContentMode,
                    prefersHighResCover: true
                )
                .shadow(
                    color: appearance.coverShadowEnabled ? .black.opacity(0.12) : .clear,
                    radius: appearance.coverShadowEnabled ? 4 : 0,
                    x: 0,
                    y: appearance.coverShadowEnabled ? 2 : 0
                )
            }

            Text(title(for: book))
                .font(.caption2.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: itemTextWidth, alignment: .leading)

            if let progressText = lane.presentationsByBookID[book.id]?.progressText,
               lane.presentationsByBookID[book.id]?.shouldShowReadingProgress == true {
                Text(progressText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(width: itemTextWidth, alignment: .leading)
            }
        }
        .padding(8)
        .frame(width: itemWidth, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: book))
        .accessibilityHint("Öffnet das Buch")
    }

    private var itemWidth: CGFloat {
        appearance.showCovers ? max(coverSize.width + 16, 86) : 130
    }

    private var itemTextWidth: CGFloat {
        max(60, itemWidth - 16)
    }

    private func title(for book: Book) -> String {
        let trimmed = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Ohne Titel" : trimmed
    }

    private func accessibilityLabel(for book: Book) -> String {
        var parts = [lane.title, title(for: book)]
        let author = book.author.trimmingCharacters(in: .whitespacesAndNewlines)

        if author.isEmpty == false {
            parts.append(author)
        }

        if let summary = lane.presentationsByBookID[book.id]?.accessibilitySummary,
           summary.isEmpty == false {
            parts.append(summary)
        }

        return parts.joined(separator: ", ")
    }
}

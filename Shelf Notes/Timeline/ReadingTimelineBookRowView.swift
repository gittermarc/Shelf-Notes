//
//  ReadingTimelineBookRowView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 25.01.26.
//

import SwiftUI

struct ReadingTimelineBookRowView: View {
    let item: ReadingTimelineEntryDisplayItem
    let book: Book
    let coverSize: CGSize
    let tileWidth: CGFloat

    var body: some View {
        VStack(spacing: 10) {
            NavigationLink {
                BookDetailView(book: book)
            } label: {
                VStack(spacing: 10) {
                    TimelineCoverView(
                        book: book,
                        size: coverSize,
                        cornerRadius: 18,
                        contentMode: .fill
                    )
                    .shadow(radius: 8, y: 5)
                    .overlay(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [.black.opacity(0.0), .black.opacity(0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .allowsHitTesting(false)
                    }
                    .overlay(alignment: .bottomLeading) {
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .padding(10)
                            .allowsHitTesting(false)
                    }

                    VStack(spacing: 2) {
                        Text(item.dateText)
                            .font(.footnote.weight(.semibold))
                            .monospacedDigit()
                        Text(item.yearText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()

                        if let attemptLabel = item.attemptLabel {
                            Text(attemptLabel)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Text(item.sourceLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(.secondary.opacity(0.25))
                .frame(width: 2, height: 18)

            ReadingTimelineDot(isHighlighted: true)
        }
        .frame(width: tileWidth)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if let attemptLabel = item.attemptLabel {
            return "\(item.title), \(attemptLabel), \(item.sourceLabel), beendet am \(item.accessibilityDateText)"
        }
        return "\(item.title), \(item.sourceLabel), beendet am \(item.accessibilityDateText)"
    }
}

struct ReadingTimelineDot: View {
    var isHighlighted: Bool = false

    var body: some View {
        Circle()
            .fill(isHighlighted ? Color.primary : Color.secondary.opacity(0.7))
            .frame(width: 10, height: 10)
            .overlay {
                Circle()
                    .stroke(.background.opacity(0.9), lineWidth: 2)
            }
            .shadow(radius: isHighlighted ? 4 : 0)
            .accessibilityHidden(true)
    }
}

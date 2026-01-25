//
//  ReadingTimelineBookRowView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 25.01.26.
//

import SwiftUI
import SwiftData

struct ReadingTimelineBookRowView: View {
    @Bindable var book: Book
    let date: Date
    let coverSize: CGSize
    let tileWidth: CGFloat

    private var dateText: String {
        date.formatted(.dateTime.day().month(.twoDigits))
    }

    private var yearText: String {
        date.formatted(.dateTime.year())
    }

    var body: some View {
        VStack(spacing: 10) {
            NavigationLink {
                BookDetailView(book: book)
            } label: {
                VStack(spacing: 10) {
                    BookCoverThumbnailView(
                        book: book,
                        size: coverSize,
                        cornerRadius: 18,
                        contentMode: .fill
                    )
                    .shadow(radius: 10, y: 6)
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
                        Text(book.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .padding(10)
                            .allowsHitTesting(false)
                    }

                    VStack(spacing: 2) {
                        Text(dateText)
                            .font(.footnote.weight(.semibold))
                            .monospacedDigit()
                        Text(yearText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
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
        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1.0 : 0.94)
                .opacity(phase.isIdentity ? 1.0 : 0.85)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(book.title), beendet am \(date.formatted(date: .long, time: .omitted))")
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

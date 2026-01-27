//
//  BookRowView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Split from ContentView.swift on 05.01.26.
//

import SwiftUI
import SwiftData

struct BookRowView: View {
    let book: Book

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            cover

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title.isEmpty ? "Ohne Titel" : book.title)
                    .font(.headline)

                if !book.author.isEmpty {
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Status + (Monat/Jahr, wenn gelesen)
                HStack(spacing: 6) {
                    Text(book.status.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let monthYear = readMonthYearText {
                        Text("• \(monthYear)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    if let avg = rowUserRating {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        StarsView(rating: avg)

                        Text(String(format: "%.1f", avg))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                // Tags eine Zeile tiefer
                if !book.tags.isEmpty {
                    Text(book.tags.prefix(2).map { "#\($0)" }.joined(separator: " "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var readMonthYearText: String? {
        guard book.status == .finished else { return nil }
        guard let d = book.readTo ?? book.readFrom else { return nil }
        return d.formatted(.dateTime.month(.abbreviated).year())
    }

    private var rowUserRating: Double? {
        guard book.status == .finished else { return nil }
        return book.userRatingAverage1
    }


    @ViewBuilder
    private var cover: some View {
        LibraryRowCoverView(
            book: book,
            size: CGSize(width: 44, height: 66),
            cornerRadius: 8,
            contentMode: .fit
        )
    }
}


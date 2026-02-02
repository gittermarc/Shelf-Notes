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

    // Library row appearance
    @AppStorage(AppearanceStorageKey.libraryShowCovers) private var showCovers: Bool = true
    @AppStorage(AppearanceStorageKey.libraryCoverSize) private var coverSizeRaw: String = LibraryCoverSizeOption.standard.rawValue
    @AppStorage(AppearanceStorageKey.libraryCoverCornerRadius) private var coverCornerRadius: Double = 8
    @AppStorage(AppearanceStorageKey.libraryCoverContentMode) private var coverContentModeRaw: String = LibraryCoverContentModeOption.fit.rawValue
    @AppStorage(AppearanceStorageKey.libraryCoverShadowEnabled) private var coverShadowEnabled: Bool = false

    @AppStorage(AppearanceStorageKey.libraryRowShowAuthor) private var showAuthor: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowStatus) private var showStatus: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowReadDate) private var showReadDate: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowRating) private var showRating: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowTags) private var showTags: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowMaxTags) private var maxTags: Int = 2

    private enum MetaPart {
        case status(String)
        case readDate(String)
        case rating(Double)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if showCovers {
                cover
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title.isEmpty ? "Ohne Titel" : book.title)
                    .font(.headline)

                if showAuthor, !book.author.isEmpty {
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
                if showTags, !book.tags.isEmpty, maxTags > 0 {
                    let n = max(1, min(maxTags, book.tags.count))
                    Text(book.tags.prefix(n).map { "#\($0)" }.joined(separator: " "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var readMonthYearText: String? {
        guard showReadDate else { return nil }
        guard book.status == .finished else { return nil }
        guard let d = book.readTo ?? book.readFrom else { return nil }
        return d.formatted(.dateTime.month(.abbreviated).year())
    }

    private var rowUserRating: Double? {
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

        if let avg = rowUserRating {
            parts.append(.rating(avg))
        }

        return parts
    }


    @ViewBuilder
    private var cover: some View {
        let size = (LibraryCoverSizeOption(rawValue: coverSizeRaw) ?? .standard).size
        let mode = (LibraryCoverContentModeOption(rawValue: coverContentModeRaw) ?? .fit).contentMode
        let radius = CGFloat(coverCornerRadius)

        LibraryRowCoverView(
            book: book,
            size: size,
            cornerRadius: radius,
            contentMode: mode
        )
        .shadow(color: coverShadowEnabled ? .black.opacity(0.12) : .clear, radius: coverShadowEnabled ? 4 : 0, x: 0, y: coverShadowEnabled ? 2 : 0)
    }
}


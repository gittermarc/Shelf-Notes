//
//  LibraryView+AlphaIndex.swift
//  Shelf Notes
//
//  Extracted from LibraryView.swift to reduce file size and improve maintainability.
//

import SwiftUI
import Foundation

extension LibraryView {

    // MARK: - Alphabet indexing (Title sort)

    private struct AlphaSection: Identifiable {
        let id: String
        let key: String
        let books: [Book]
    }

    private func buildAlphaSections(from input: [Book]) -> [AlphaSection] {
        var buckets: [String: [Book]] = [:]

        for b in input {
            let key = alphaKey(for: bestTitle(b))
            buckets[key, default: []].append(b)
        }

        let keys = buckets.keys.sorted { a, b in
            if a == "#" { return false }
            if b == "#" { return true }
            return a < b
        }

        return keys.map { k in
            AlphaSection(id: k, key: k, books: buckets[k] ?? [])
        }
    }

    private func alphaKey(for title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "#" }

        let folded = String(first).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let upper = folded.uppercased()

        if upper.range(of: "^[A-Z]$", options: .regularExpression) != nil {
            return upper
        }
        return "#"
    }

    func alphaIndexedList(displayedBooks: [Book]) -> some View {
        let sections = buildAlphaSections(from: displayedBooks)
        let letters = sections.map(\.key)

        return ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                List {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.books) { book in
                                NavigationLink {
                                    BookDetailView(book: book)
                                } label: {
                                    BookRowView(book: book)
                                }
                                .listRowInsets(
                                    EdgeInsets(
                                        top: CGFloat(libraryRowVerticalInset),
                                        leading: 16,
                                        bottom: CGFloat(libraryRowVerticalInset),
                                        trailing: 16
                                    )
                                )
                            }
                            .onDelete { offsets in
                                deleteBooksInSection(section.books, offsets: offsets)
                            }
                        } header: {
                            Text(section.key)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 2)
                        }
                        .id(section.key)
                    }
                }

                VStack(spacing: 2) {
                    ForEach(letters, id: \.self) { letter in
                        Button {
                            withAnimation(.snappy) {
                                proxy.scrollTo(letter, anchor: .top)
                            }
                        } label: {
                            Text(letter)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 18, height: 14)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Springe zu \(letter)")
                    }
                }
                .padding(.trailing, 6)
                .padding(.vertical, 10)
            }
        }
    }
}

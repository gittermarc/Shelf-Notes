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

    struct AlphaSection: Identifiable {
        let id: String
        let key: String
        let books: [Book]
    }

    func makeAlphaSectionsForUI(
        descriptors: [AlphaSectionDescriptor],
        booksByID: [UUID: Book]
    ) -> [AlphaSection] {
        descriptors.map { descriptor in
            AlphaSection(
                id: descriptor.id,
                key: descriptor.key,
                books: descriptor.bookIDs.compactMap { booksByID[$0] }
            )
        }
    }

    func alphaIndexedList(displayedBooks: [Book]) -> some View {
        let source = LibrarySourceSnapshot(books: displayedBooks)
        let descriptors = LibraryDerivedStateBuilder.buildAlphaSections(from: source.books)
        let booksByID = Dictionary(uniqueKeysWithValues: displayedBooks.map { ($0.id, $0) })
        let sections = makeAlphaSectionsForUI(descriptors: descriptors, booksByID: booksByID)
        let letters = descriptors.map(\.key)
        return alphaIndexedList(sections: sections, letters: letters)
    }

    func alphaIndexedList(sections: [AlphaSection], letters: [String]) -> some View {
        let rowAppearance = libraryRowAppearance

        return ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                List {
                    ForEach(sections) { section in
                        Section {
                            if isSelectionMode {
                                ForEach(section.books) { book in
                                    selectableListRow(book, appearance: rowAppearance)
                                        .listRowInsets(
                                            EdgeInsets(
                                                top: CGFloat(libraryRowVerticalInset),
                                                leading: 16,
                                                bottom: CGFloat(libraryRowVerticalInset),
                                                trailing: 16
                                            )
                                        )
                                }
                            } else {
                                ForEach(section.books) { book in
                                    NavigationLink {
                                        BookDetailView(book: book)
                                    } label: {
                                        BookRowView(book: book, appearance: rowAppearance)
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

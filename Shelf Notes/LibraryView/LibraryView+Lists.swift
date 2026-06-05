//
//  LibraryView+Lists.swift
//  Shelf Notes
//
//  Extracted from LibraryView.swift to reduce file size and improve maintainability.
//

import SwiftUI

extension LibraryView {

    // MARK: - Lists

    func plainList(displayedBooks: [Book]) -> some View {
        let rowAppearance = libraryRowAppearance

        return List {
            if isSelectionMode {
                ForEach(displayedBooks) { book in
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
                ForEach(displayedBooks) { book in
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
                    deleteBooks(at: offsets, in: displayedBooks)
                }
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: books.isEmpty ? "books.vertical" : "magnifyingglass")
                .font(.system(size: 46))

            Text(books.isEmpty ? "Noch nichts im Regal" : "Keine Treffer")
                .font(.title2)
                .bold()

            Text(books.isEmpty
                 ? "Füge dein erstes Buch hinzu — oder importiere es direkt über Google Books."
                 : "Entweder deine Filter sind zu gut — oder du brauchst einen neuen Suchbegriff. 😄")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if books.isEmpty {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Erstes Buch hinzufügen", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            } else if selectedStatus != nil || selectedTag != nil || onlyWithNotes || !searchText.isEmpty {
                Button {
                    withAnimation {
                        selectedTag = nil
                        selectedStatus = nil
                        onlyWithNotes = false
                        searchText = ""
                    }
                } label: {
                    Label("Filter zurücksetzen", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
        }
        .padding(.top, 26)
    }
}

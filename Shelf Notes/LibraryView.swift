//
//  LibraryView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Split from ContentView.swift on 05.01.26.
//

import SwiftUI
import SwiftData
import StoreKit
import Combine

#if canImport(PhotosUI)
import PhotosUI
#endif

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Library
struct LibraryView: View {
    // NOTE: This view is split into multiple files via extensions.
    // `private` members are not visible across files, so these need to be
    // internal to keep the split compiling.
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Book.createdAt, order: .reverse) var books: [Book]

    @State var showingAddSheet = false

    @State var headerExpanded: Bool = false
    @State var searchText: String = ""
    @State var selectedStatus: ReadingStatus? = nil
    @State var selectedTag: String? = nil
    @State var onlyWithNotes: Bool = false

    // Grid delete (LazyVGrid has no swipe-to-delete)
    @State var bookToDelete: Book? = nil

    // Sorting (persisted)
    @AppStorage("library_sort_field") var sortFieldRaw: String = SortField.createdAt.rawValue
    @AppStorage("library_sort_ascending") var sortAscending: Bool = false

    // Appearance (Library-specific)
    // Note: Must be non-private to be accessible from the split extension files.
    @AppStorage(AppearanceStorageKey.libraryHeaderStyle) var libraryHeaderStyleRaw: String = LibraryHeaderStyleOption.standard.rawValue
    @AppStorage(AppearanceStorageKey.libraryHeaderDefaultExpanded) var libraryHeaderDefaultExpanded: Bool = false
    @AppStorage(AppearanceStorageKey.libraryRowVerticalInset) var libraryRowVerticalInset: Double = 8
    @AppStorage(AppearanceStorageKey.libraryLayoutMode) var libraryLayoutModeRaw: String = LibraryLayoutModeOption.list.rawValue

    // A–Z hint logic (only show when it’s actually helpful)
    static let alphaIndexHintThreshold: Int = 30

    init(initialTag: String? = nil) {
        _selectedTag = State(initialValue: initialTag)
    }

    var body: some View {
        NavigationStack {
            // PERF: Compute the derived list **once per render**.
            // Previously, multiple sub-views referenced `displayedBooks` independently, which
            // caused filtering + sorting to be re-run several times per frame (especially during
            // the header expand/collapse animation).
            let displayed = displayedBooks
            let counts = statusCounts(in: books)
            let showAlphaIndexHint = (libraryLayoutMode == .list) && (sortField == .title) && (displayed.count >= Self.alphaIndexHintThreshold)

            VStack(spacing: 0) {
                filterBar(displayedBooks: displayed, counts: counts, showAlphaIndexHint: showAlphaIndexHint)

                if showAlphaIndexHint {
                    alphaIndexHint
                }

                Group {
                    if displayed.isEmpty {
                        emptyState
                    } else {
                        if libraryLayoutMode == .grid {
                            gridView(displayedBooks: displayed)
                        } else {
                            // Alphabet index makes most sense for title sort
                            if sortField == .title {
                                alphaIndexedList(displayedBooks: displayed)
                            } else {
                                plainList(displayedBooks: displayed)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bibliothek")
            .searchable(text: $searchText, prompt: "Suche Titel, Autor, Tag …")
            .toolbar { libraryToolbar }
            .onAppear {
                if libraryHeaderStyle == .standard {
                    headerExpanded = libraryHeaderDefaultExpanded
                } else {
                    headerExpanded = false
                }

                if books.isEmpty { headerExpanded = true }
                enforceRatingRuleIfNeeded()
            }
            .onChange(of: libraryHeaderStyleRaw) { _, _ in
                withAnimation(.easeInOut(duration: 0.18)) {
                    if libraryHeaderStyle == .standard {
                        headerExpanded = libraryHeaderDefaultExpanded
                    } else {
                        headerExpanded = false
                    }
                }
            }
            .onChange(of: libraryHeaderDefaultExpanded) { _, newValue in
                guard libraryHeaderStyle == .standard else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    headerExpanded = newValue
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddBookView()
            }
            .alert("Buch löschen?", isPresented: Binding(
                get: { bookToDelete != nil },
                set: { if !$0 { bookToDelete = nil } }
            ), presenting: bookToDelete) { book in
                Button("Löschen", role: .destructive) {
                    deleteBook(book)
                    bookToDelete = nil
                }
                Button("Abbrechen", role: .cancel) {
                    bookToDelete = nil
                }
            } message: { book in
                Text("\"\(bestTitle(book))\" wird aus deiner Bibliothek gelöscht.")
            }
        }
    }

    var libraryHeaderStyle: LibraryHeaderStyleOption {
        LibraryHeaderStyleOption(rawValue: libraryHeaderStyleRaw) ?? .standard
    }

    var libraryLayoutMode: LibraryLayoutModeOption {
        LibraryLayoutModeOption(rawValue: libraryLayoutModeRaw) ?? .list
    }
}

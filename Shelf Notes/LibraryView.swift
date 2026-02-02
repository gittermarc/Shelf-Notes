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

    // Sorting (persisted)
    @AppStorage("library_sort_field") var sortFieldRaw: String = SortField.createdAt.rawValue
    @AppStorage("library_sort_ascending") var sortAscending: Bool = false

    // Appearance (Library-specific)
    // Note: Must be non-private to be accessible from the split extension files.
    @AppStorage(AppearanceStorageKey.libraryRowVerticalInset) var libraryRowVerticalInset: Double = 8

    // A–Z hint logic (only show when it’s actually helpful)
    static let alphaIndexHintThreshold: Int = 30

    init(initialTag: String? = nil) {
        _selectedTag = State(initialValue: initialTag)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar

                if shouldShowAlphaIndexHint {
                    alphaIndexHint
                }

                Group {
                    if displayedBooks.isEmpty {
                        emptyState
                    } else {
                        // Alphabet index makes most sense for title sort
                        if sortField == .title {
                            alphaIndexedList
                        } else {
                            plainList
                        }
                    }
                }
            }
            .navigationTitle("Bibliothek")
            .searchable(text: $searchText, prompt: "Suche Titel, Autor, Tag …")
            .toolbar { libraryToolbar }
            .onAppear {
                if books.isEmpty { headerExpanded = true }
                enforceRatingRuleIfNeeded()
            }
            .sheet(isPresented: $showingAddSheet) {
                AddBookView()
            }
        }
    }
}

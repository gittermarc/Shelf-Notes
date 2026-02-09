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

    // Multi-select (bulk actions)
    // Note: Must be non-private to be accessible from the split extension files.
    @State var isSelectionMode: Bool = false
    @State var selectedBookIDs: Set<UUID> = []
    @State var showingBulkAddTagAlert: Bool = false
    @State var bulkTagDraft: String = ""
    @State var showingBulkRemoveTagDialog: Bool = false
    @State var bulkRemoveTagOptions: [String] = []
    @State var showingBulkAddToCollectionSheet: Bool = false
    @State var showingBulkDeleteConfirm: Bool = false

    // PERF: Cache expensive derived state (filtering/sorting/alpha sections).
    // Header expand/collapse animates the layout and triggers many body recalculations.
    // Without caching, we would re-run filter+sort (+ alpha bucketing) every frame.
    @State var derivedReady: Bool = false
    @State var cachedDisplayedBooks: [Book] = []
    @State private var cachedCounts: LibraryStatusCounts = .zero
    @State private var cachedAlphaSections: [AlphaSection] = []
    @State private var cachedAlphaLetters: [String] = []
    @State private var pendingRecomputeTask: Task<Void, Never>? = nil

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
        attachSheetsAndAlerts(
            NavigationStack {
                libraryContent
            }
        )
    }

    // MARK: - Body building blocks (helps the Swift compiler and keeps the file readable)

    private var displayedForUI: [Book] {
        derivedReady ? cachedDisplayedBooks : displayedBooks
    }

    private var countsForUI: LibraryStatusCounts {
        derivedReady ? cachedCounts : statusCounts(in: books)
    }

    private func alphaSectionsForUI(displayed: [Book]) -> [AlphaSection] {
        derivedReady ? cachedAlphaSections : buildAlphaSections(from: displayed)
    }

    private func alphaLettersForUI(sections: [AlphaSection]) -> [String] {
        derivedReady ? cachedAlphaLetters : sections.map(\.key)
    }

    private func shouldShowAlphaIndexHint(displayedCount: Int) -> Bool {
        (libraryLayoutMode == .list)
        && (sortField == .title)
        && (displayedCount >= Self.alphaIndexHintThreshold)
    }

    @ViewBuilder
    private var libraryContent: some View {
        // Explicit types here massively reduce SwiftUI's generic inference work.
        let displayed: [Book] = displayedForUI
        let counts: LibraryStatusCounts = countsForUI

        let alphaSections: [AlphaSection] = alphaSectionsForUI(displayed: displayed)
        let alphaLetters: [String] = alphaLettersForUI(sections: alphaSections)

        let showAlphaIndexHint: Bool = shouldShowAlphaIndexHint(displayedCount: displayed.count)

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
                            alphaIndexedList(sections: alphaSections, letters: alphaLetters)
                        } else {
                            plainList(displayedBooks: displayed)
                        }
                    }
                }
            }
        }
        .navigationTitle(isSelectionMode ? "\(selectedBookIDs.count) ausgewählt" : "Bibliothek")
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

            // Ensure derived cache exists right away (and refresh when returning from detail views).
            updateDerivedCacheNow()
        }
        .onChange(of: books.count) { _, _ in
            updateDerivedCacheNow()
        }
        .onChange(of: selectedStatus) { _, _ in
            updateDerivedCacheNow()
        }
        .onChange(of: selectedTag) { _, _ in
            updateDerivedCacheNow()
        }
        .onChange(of: onlyWithNotes) { _, _ in
            updateDerivedCacheNow()
        }
        .onChange(of: sortFieldRaw) { _, _ in
            updateDerivedCacheNow()
        }
        .onChange(of: sortAscending) { _, _ in
            updateDerivedCacheNow()
        }
        .onChange(of: libraryLayoutModeRaw) { _, _ in
            // Clears/warms alpha cache depending on list vs grid.
            updateDerivedCacheNow()
        }
        .onChange(of: searchText) { _, _ in
            // Debounce typing to avoid re-filtering/sorting the full library for every keystroke.
            scheduleDerivedCacheRecomputeDebounced()
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
    }

    private func attachSheetsAndAlerts<Content: View>(_ content: Content) -> some View {
        content
            .sheet(isPresented: $showingAddSheet) {
                AddBookView()
            }
            .sheet(isPresented: $showingBulkAddToCollectionSheet) {
                BulkAddToCollectionSheet(selectionCount: selectedBookIDs.count) { col in
                    bulkAddSelectedBooks(to: col)
                    showingBulkAddToCollectionSheet = false
                }
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
            .alert("Bücher löschen?", isPresented: $showingBulkDeleteConfirm) {
                Button("Löschen", role: .destructive) {
                    bulkDeleteSelectedBooks()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("\(selectedBookIDs.count) Bücher werden aus deiner Bibliothek gelöscht.")
            }
            .alert("Tag hinzufügen", isPresented: $showingBulkAddTagAlert) {
                TextField("z.B. Thriller, NYC", text: $bulkTagDraft)

                Button("Hinzufügen") {
                    bulkAddTagsFromDraft()
                }

                Button("Abbrechen", role: .cancel) {
                    bulkTagDraft = ""
                }
            } message: {
                Text("Wird zu \(selectedBookIDs.count) Büchern hinzugefügt.")
            }
            .confirmationDialog("Tag entfernen", isPresented: $showingBulkRemoveTagDialog, titleVisibility: .visible) {
                ForEach(bulkRemoveTagOptions, id: \.self) { tag in
                    Button("#\(tag)", role: .destructive) {
                        bulkRemoveTag(tag)
                    }
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Von \(selectedBookIDs.count) Büchern entfernen.")
            }
    }

// MARK: - Derived cache updates

    @MainActor
    private func updateDerivedCacheNow() {
        pendingRecomputeTask?.cancel()
        pendingRecomputeTask = nil

        let displayed = displayedBooks
        cachedDisplayedBooks = displayed
        cachedCounts = statusCounts(in: books)

        if libraryLayoutMode == .list, sortField == .title {
            let sections = buildAlphaSections(from: displayed)
            cachedAlphaSections = sections
            cachedAlphaLetters = sections.map(\.key)
        } else {
            cachedAlphaSections = []
            cachedAlphaLetters = []
        }

        derivedReady = true
    }

    @MainActor
    private func scheduleDerivedCacheRecomputeDebounced() {
        pendingRecomputeTask?.cancel()
        pendingRecomputeTask = Task { @MainActor in
            // 200ms feels snappy but avoids churn while typing.
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled { return }
            updateDerivedCacheNow()
        }
    }

    var libraryHeaderStyle: LibraryHeaderStyleOption {
        LibraryHeaderStyleOption(rawValue: libraryHeaderStyleRaw) ?? .standard
    }

    var libraryLayoutMode: LibraryLayoutModeOption {
        LibraryLayoutModeOption(rawValue: libraryLayoutModeRaw) ?? .list
    }
}

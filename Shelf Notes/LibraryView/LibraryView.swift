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

    // Derived state cache. The pure builder owns filtering, sorting, counts and sections.
    @State private var derivedCoordinator = LibraryDerivedStateCoordinator()
    @State private var derivedSearchText: String = ""
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
    @AppStorage(AppearanceStorageKey.libraryCoverSize) var libraryCoverSizeRaw: String = LibraryCoverSizeOption.standard.rawValue

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

    var shouldBuildAlphaSections: Bool {
        libraryLayoutMode == .list && sortField == .title
    }

    var activeDerivedInput: LibraryDerivedInput {
        LibraryDerivedStateBuilder.makeInput(
            searchText: derivedSearchText,
            selectedStatus: selectedStatus,
            selectedTag: selectedTag,
            onlyWithNotes: onlyWithNotes,
            sortField: sortField,
            sortAscending: sortAscending,
            buildsAlphaSections: shouldBuildAlphaSections
        )
    }

    var activeDerivedTaskToken: LibraryDerivedInputToken {
        LibraryDerivedStateBuilder.makeInputToken(
            books: books,
            searchText: derivedSearchText,
            selectedStatus: selectedStatus,
            selectedTag: selectedTag,
            onlyWithNotes: onlyWithNotes,
            sortField: sortField,
            sortAscending: sortAscending,
            buildsAlphaSections: shouldBuildAlphaSections
        )
    }

    var currentDerivedStateForUI: LibraryDerivedState {
        derivedCoordinator.displayState(for: activeDerivedTaskToken)
    }

    var displayedBooksForCurrentDerivedState: [Book] {
        let booksByID = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })
        return currentDerivedStateForUI.displayedBookIDs.compactMap { booksByID[$0] }
    }

    private var countsForUI: LibraryStatusCounts {
        currentDerivedStateForUI.counts
    }

    private var alphaSectionsForUI: [AlphaSection] {
        let booksByID = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })
        return makeAlphaSectionsForUI(
            descriptors: currentDerivedStateForUI.alphaSections,
            booksByID: booksByID
        )
    }

    private var alphaLettersForUI: [String] {
        currentDerivedStateForUI.alphaLetters
    }

    private func shouldShowAlphaIndexHint(displayedCount: Int) -> Bool {
        shouldBuildAlphaSections && displayedCount >= Self.alphaIndexHintThreshold
    }

    @ViewBuilder
    private var libraryContent: some View {
        let displayed: [Book] = displayedBooksForCurrentDerivedState
        let counts: LibraryStatusCounts = countsForUI
        let alphaSections: [AlphaSection] = alphaSectionsForUI
        let alphaLetters: [String] = alphaLettersForUI
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
        .toolbar(isSelectionMode ? .hidden : .visible, for: .tabBar)
        .onAppear {
            if libraryHeaderStyle == .standard {
                headerExpanded = libraryHeaderDefaultExpanded
            } else {
                headerExpanded = false
            }

            if books.isEmpty {
                headerExpanded = true
            }

            enforceRatingRuleIfNeeded()
            syncDerivedSearchTextNow()
            seedDerivedStateIfNeeded()
        }
        .task(id: activeDerivedTaskToken) {
            rebuildDerivedState(for: activeDerivedTaskToken)
        }
        .onChange(of: searchText) { _, _ in
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
    private func rebuildDerivedState(for token: LibraryDerivedInputToken) {
        let source = LibrarySourceSnapshot(books: books)
        let input = activeDerivedInput
        derivedCoordinator.resolveIfNeeded(for: token, source: source, input: input)
    }

    @MainActor
    private func seedDerivedStateIfNeeded() {
        guard derivedCoordinator.hasStableState == false else { return }
        let token = activeDerivedTaskToken
        derivedCoordinator.invalidate(for: token)
        rebuildDerivedState(for: token)
    }

    @MainActor
    private func syncDerivedSearchTextNow() {
        pendingRecomputeTask?.cancel()
        pendingRecomputeTask = nil
        derivedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        derivedCoordinator.invalidate(for: activeDerivedTaskToken)
    }

    @MainActor
    private func scheduleDerivedCacheRecomputeDebounced() {
        pendingRecomputeTask?.cancel()
        pendingRecomputeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled {
                return
            }
            derivedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            derivedCoordinator.invalidate(for: activeDerivedTaskToken)
        }
    }

    var libraryHeaderStyle: LibraryHeaderStyleOption {
        LibraryHeaderStyleOption(rawValue: libraryHeaderStyleRaw) ?? .standard
    }

    var libraryLayoutMode: LibraryLayoutModeOption {
        LibraryLayoutModeOption(rawValue: libraryLayoutModeRaw) ?? .list
    }

    var libraryCoverSizeOption: LibraryCoverSizeOption {
        LibraryCoverSizeOption(rawValue: libraryCoverSizeRaw) ?? .standard
    }
}

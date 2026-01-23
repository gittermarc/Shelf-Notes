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
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]

    @State private var showingAddSheet = false

    @State private var headerExpanded: Bool = false
    @State private var searchText: String = ""
    @State private var selectedStatus: ReadingStatus? = nil
    @State private var selectedTag: String? = nil
    @State private var onlyWithNotes: Bool = false

    // Sorting (persisted)
    private enum SortField: String, CaseIterable, Identifiable {
        case createdAt = "Hinzugefügt"
        case readDate = "Gelesen"
        case rating = "Bewertung"
        case title = "Titel"
        case author = "Autor"

        var id: String { rawValue }
    }

    @AppStorage("library_sort_field") private var sortFieldRaw: String = SortField.createdAt.rawValue
    @AppStorage("library_sort_ascending") private var sortAscending: Bool = false

    private var sortField: SortField {
        get { SortField(rawValue: sortFieldRaw) ?? .createdAt }
        nonmutating set { sortFieldRaw = newValue.rawValue }
    }


    // Quick segment (optional): switch between "Zuletzt hinzugefügt" and "Zuletzt gelesen"
    private enum QuickSortMode: String, CaseIterable, Identifiable {
        case added = "Zuletzt hinzugefügt"
        case read = "Zuletzt gelesen"
        var id: String { rawValue }
    }

    private var quickSortModeBinding: Binding<QuickSortMode> {
        Binding(
            get: { sortField == .readDate ? .read : .added },
            set: { mode in
                withAnimation {
                    sortField = (mode == .read) ? .readDate : .createdAt
                    // sensible default: newest first
                    sortAscending = false
                }
            }
        )
    }

    private var isHomeState: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty && selectedStatus == nil && selectedTag == nil && !onlyWithNotes
    }

    private var shouldShowQuickSortSegment: Bool {
        // only show when it actually adds value
        books.count >= 8 && finishedCount > 0
    }

    // A–Z hint logic (only show when it’s actually helpful)
    private let alphaIndexHintThreshold: Int = 30
    private var shouldShowAlphaIndexHint: Bool {
        sortField == .title && displayedBooks.count >= alphaIndexHintThreshold
    }

    private var heroSubtitle: String {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if books.isEmpty { return "Dein ruhiges, soziales-freies Lesetagebuch." }
        if !trimmed.isEmpty { return "Suche: „\(trimmed)“" }
        if let selectedTag { return "Filter: #\(selectedTag)" }
        if let selectedStatus { return "Filter: \(selectedStatus.rawValue)" }
        if onlyWithNotes { return "Filter: nur mit Notizen" }
        return "Dein Regal — \(books.count) Bücher"
    }

    private var toReadCount: Int {
        books.filter { $0.status == .toRead }.count
    }

    private var readingCount: Int {
        books.filter { $0.status == .reading }.count
    }

    private var finishedCount: Int {
        books.filter { $0.status == .finished }.count
    }

    private func toggleStatusFilter(_ status: ReadingStatus) {
        if selectedStatus == status {
            selectedStatus = nil
        } else {
            selectedStatus = status
        }
    }

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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        // --- Sort ---
                        Section("Sortieren") {
                            Picker("Feld", selection: Binding(
                                get: { sortField.rawValue },
                                set: { sortFieldRaw = $0 }
                            )) {
                                ForEach(SortField.allCases) { f in
                                    Text(f.rawValue).tag(f.rawValue)
                                }
                            }

                            Toggle(isOn: $sortAscending) {
                                Text(sortAscendingLabel)
                            }
                        }

                        // --- Filter ---
                        Section("Filter") {
                            Picker("Status", selection: Binding(
                                get: { selectedStatus?.rawValue ?? "Alle" },
                                set: { newValue in
                                    selectedStatus = ReadingStatus.allCases.first(where: { $0.rawValue == newValue })
                                    if newValue == "Alle" { selectedStatus = nil }
                                }
                            )) {
                                Text("Alle").tag("Alle")
                                ForEach(ReadingStatus.allCases) { status in
                                    Text(status.rawValue).tag(status.rawValue)
                                }
                            }

                            Toggle("Nur mit Notizen", isOn: $onlyWithNotes)

                            if selectedTag != nil || selectedStatus != nil || onlyWithNotes || !searchText.isEmpty {
                                Button("Filter zurücksetzen") {
                                    withAnimation {
                                        selectedTag = nil
                                        selectedStatus = nil
                                        onlyWithNotes = false
                                        searchText = ""
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filter & Sortierung")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Buch hinzufügen")
                }
            }
            .onAppear {
                if books.isEmpty { headerExpanded = true }
                enforceRatingRuleIfNeeded()
            }
            .sheet(isPresented: $showingAddSheet) {
                AddBookView()
            }
        }
    }

    private var sortAscendingLabel: String {
        switch sortField {
        case .createdAt, .readDate:
            return sortAscending ? "Alt → Neu" : "Neu → Alt"
        case .rating:
            return sortAscending ? "Niedrig → Hoch" : "Hoch → Niedrig"
        case .title, .author:
            return sortAscending ? "A → Z" : "Z → A"
        }
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: headerExpanded ? 10 : 8) {
            headerTopRow

            if headerExpanded {
                expandedHeaderContent
            } else {
                collapsedHeaderContent
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private var headerTopRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Meine Bücher")
                    .font(.title3.weight(.semibold))

                Text(heroSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(headerExpanded ? 2 : 1)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Buch hinzufügen")

                Button {
                    toggleHeaderExpanded()
                } label: {
                    Image(systemName: headerExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(headerExpanded ? "Header einklappen" : "Header ausklappen")
            }
        }
    }

    private var collapsedHeaderContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Count line (always visible)
            countLine

            if shouldShowQuickSortSegment {
                Picker("", selection: quickSortModeBinding) {
                    Text(QuickSortMode.added.rawValue).tag(QuickSortMode.added)
                    Text(QuickSortMode.read.rawValue).tag(QuickSortMode.read)
                }
                .pickerStyle(.segmented)
            }

            activeFilterChips

            if shouldShowAlphaIndexHint {
                alphaIndexHint
            }
        }
    }

    private var expandedHeaderContent: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Status overview (tap = quick filter)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    LibraryStatCard(
                        title: "Will ich lesen",
                        value: toReadCount,
                        systemImage: "bookmark",
                        isActive: selectedStatus == .toRead
                    ) {
                        withAnimation {
                            toggleStatusFilter(.toRead)
                        }
                    }

                    LibraryStatCard(
                        title: "Lese ich gerade",
                        value: readingCount,
                        systemImage: "book",
                        isActive: selectedStatus == .reading
                    ) {
                        withAnimation {
                            toggleStatusFilter(.reading)
                        }
                    }

                    LibraryStatCard(
                        title: "Gelesen",
                        value: finishedCount,
                        systemImage: "checkmark.seal",
                        isActive: selectedStatus == .finished
                    ) {
                        withAnimation {
                            toggleStatusFilter(.finished)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            activeFilterChips

            countLine

            if shouldShowAlphaIndexHint {
                alphaIndexHint
            }

            if shouldShowQuickSortSegment {
                Picker("", selection: quickSortModeBinding) {
                    Text(QuickSortMode.added.rawValue).tag(QuickSortMode.added)
                    Text(QuickSortMode.read.rawValue).tag(QuickSortMode.read)
                }
                .pickerStyle(.segmented)
            }

            // Mini shelf (adds visual warmth without heavy UI)
            if isHomeState && displayedBooks.count >= 6 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(displayedBooks.prefix(12).enumerated()), id: \.element.id) { _, b in
                            NavigationLink {
                                BookDetailView(book: b)
                            } label: {
                                LibraryCoverThumb(book: b)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private var activeFilterChips: some View {
        // Active filters (chips)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let selectedStatus {
                    TagChip(text: selectedStatus.rawValue, systemImage: "flag.fill") {
                        withAnimation { self.selectedStatus = nil }
                    }
                }

                if let selectedTag {
                    TagChip(text: "#\(selectedTag)", systemImage: "tag.fill") {
                        withAnimation { self.selectedTag = nil }
                    }
                }

                if onlyWithNotes {
                    TagChip(text: "mit Notizen", systemImage: "note.text") {
                        withAnimation { self.onlyWithNotes = false }
                    }
                }

                // When collapsed and there are no active filters, keep it tiny.
                if (selectedStatus == nil && selectedTag == nil && !onlyWithNotes) {
                    Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Filter: keine (noch 😄)" : "Filter aktiv")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }

                if selectedStatus != nil || selectedTag != nil || onlyWithNotes || !searchText.isEmpty {
                    Button("Zurücksetzen") {
                        withAnimation {
                            selectedTag = nil
                            selectedStatus = nil
                            onlyWithNotes = false
                            searchText = ""
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var countLine: some View {
        HStack(spacing: 10) {
            Image(systemName: "number")
                .foregroundStyle(.secondary)

            Text("Bücher in deiner Liste: \(displayedBooks.count)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if shouldShowAlphaIndexHint {
                Text("A–Z")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }
        }
    }

    private func toggleHeaderExpanded() {
        withAnimation(.easeInOut(duration: 0.22)) {
            headerExpanded.toggle()
        }
    }

    private var alphaIndexHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "textformat.abc")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("A–Z Index aktiv")
                    .font(.caption.weight(.semibold))
                Text("Tippe rechts auf einen Buchstaben, um schnell zu springen.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Filtering + Sorting

    private var filteredBooks: [Book] {
        books.filter { book in
            if let selectedStatus, book.status != selectedStatus { return false }

            if let selectedTag, !book.tags.contains(where: { $0.caseInsensitiveCompare(selectedTag) == .orderedSame }) {
                return false
            }

            if onlyWithNotes {
                if book.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
            }

            let s = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty {
                let hay = [
                    book.title,
                    book.author,
                    book.isbn13 ?? "",
                    book.tags.joined(separator: " ")
                ].joined(separator: " ").lowercased()

                if !hay.contains(s.lowercased()) { return false }
            }

            return true
        }
    }

    private var displayedBooks: [Book] {
        sortBooks(filteredBooks)
    }

    private func sortBooks(_ input: [Book]) -> [Book] {
        switch sortField {
        case .createdAt:
            return input.sorted { a, b in
                if a.createdAt != b.createdAt {
                    return sortAscending ? (a.createdAt < b.createdAt) : (a.createdAt > b.createdAt)
                }
                return a.id.uuidString < b.id.uuidString
            }

        case .readDate:
            // Sort by readTo/readFrom for finished books.
            // Books without a read date fall back to createdAt, and we prefer "has read date" first.
            return input.sorted { a, b in
                let aRead = readKeyDate(a)
                let bRead = readKeyDate(b)

                let aHas = aRead != nil
                let bHas = bRead != nil

                if aHas != bHas {
                    // Prefer read-dated books first (so "Gelesen" sort is meaningful)
                    return aHas && !bHas
                }

                let da = aRead ?? a.createdAt
                let db = bRead ?? b.createdAt

                if da != db {
                    return sortAscending ? (da < db) : (da > db)
                }
                return a.id.uuidString < b.id.uuidString
            }

        
        case .rating:
            // User rating (only for finished books). Unrated books sink to the bottom.
            return input.sorted { a, b in
                let ar: Double? = (a.status == .finished) ? a.userRatingAverage1 : nil
                let br: Double? = (b.status == .finished) ? b.userRatingAverage1 : nil

                let aHas = ar != nil
                let bHas = br != nil

                if aHas != bHas {
                    // Prefer rated books first so sorting is meaningful.
                    return aHas && !bHas
                }

                let ra = ar ?? -1
                let rb = br ?? -1

                if ra != rb {
                    return sortAscending ? (ra < rb) : (ra > rb)
                }

                // Tie-breakers
                let da = readKeyDate(a) ?? a.createdAt
                let db = readKeyDate(b) ?? b.createdAt
                if da != db { return da > db }
                return a.id.uuidString < b.id.uuidString
            }

case .title:
            return input.sorted { a, b in
                let ta = bestTitle(a)
                let tb = bestTitle(b)
                let cmp = ta.localizedCaseInsensitiveCompare(tb)
                if cmp != .orderedSame {
                    return sortAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
                }
                return a.createdAt > b.createdAt
            }

        case .author:
            return input.sorted { a, b in
                let aa = a.author.trimmingCharacters(in: .whitespacesAndNewlines)
                let ab = b.author.trimmingCharacters(in: .whitespacesAndNewlines)
                let sa = aa.isEmpty ? "—" : aa
                let sb = ab.isEmpty ? "—" : ab
                let cmp = sa.localizedCaseInsensitiveCompare(sb)
                if cmp != .orderedSame {
                    return sortAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
                }

                let ta = bestTitle(a)
                let tb = bestTitle(b)
                let cmp2 = ta.localizedCaseInsensitiveCompare(tb)
                if cmp2 != .orderedSame {
                    return cmp2 == .orderedAscending
                }
                return a.createdAt > b.createdAt
            }
        }
    }

    private func readKeyDate(_ book: Book) -> Date? {
        guard book.status == .finished else { return nil }
        return book.readTo ?? book.readFrom
    }

    private func bestTitle(_ book: Book) -> String {
        let t = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Ohne Titel" : t
    }

    // MARK: - Alphabet indexing (Title sort)

    private struct AlphaSection: Identifiable {
        let id: String
        let key: String
        let books: [Book]
    }

    private var alphaSections: [AlphaSection] {
        let input = displayedBooks
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

    private var alphaIndexLetters: [String] {
        alphaSections.map(\.key)
    }

    private var alphaIndexedList: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                List {
                    ForEach(alphaSections) { section in
                        Section {
                            ForEach(section.books) { book in
                                NavigationLink {
                                    BookDetailView(book: book)
                                } label: {
                                    BookRowView(book: book)
                                }
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
                    ForEach(alphaIndexLetters, id: \.self) { letter in
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

    private var plainList: some View {
        List {
            ForEach(displayedBooks) { book in
                NavigationLink {
                    BookDetailView(book: book)
                } label: {
                    BookRowView(book: book)
                }
            }
            .onDelete(perform: deleteBooks)
        }
    }

    private var emptyState: some View {
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

    // MARK: - Data integrity

    private func enforceRatingRuleIfNeeded() {
        // Ratings are only allowed for finished books.
        // If older app versions left ratings on non-finished books, clean them up.
        let invalid = books.filter { b in
            b.status != .finished && b.userRatingValues.contains(where: { $0 > 0 })
        }

        guard !invalid.isEmpty else { return }

        for b in invalid {
            b.clearUserRatings()
        }

        modelContext.saveWithDiagnostics()
    }


    // MARK: - Delete

    private func deleteBooks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(displayedBooks[index])
        }
        modelContext.saveWithDiagnostics()
    }

    private func deleteBooksInSection(_ sectionBooks: [Book], offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sectionBooks[index])
        }
        modelContext.saveWithDiagnostics()
    }
}

// MARK: - Row

//
//  ContentView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//

import SwiftUI
import SwiftData
import StoreKit
import Combine

struct ContentView: View {
    var body: some View {
        RootView()
    }
}

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
                                LibraryCoverThumb(urlString: b.thumbnailURL)
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

    // MARK: - Delete

    private func deleteBooks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(displayedBooks[index])
        }
        try? modelContext.save()
    }

    private func deleteBooksInSection(_ sectionBooks: [Book], offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sectionBooks[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Row
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
                    Text(book.status.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let monthYear = readMonthYearText {
                        Text("• \(monthYear)")
                            .font(.caption)
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

    @ViewBuilder
    private var cover: some View {
        if let urlString = book.thumbnailURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 44, height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .frame(width: 44, height: 66)
                .opacity(0.15)
                .overlay(Image(systemName: "book").opacity(0.6))
        }
    }
}

// MARK: - Detail
struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var book: Book

    @State private var tagsText: String = ""

    // ✅ Collections: Auswahl direkt in den Buchdetails
    @Query(sort: \BookCollection.name, order: .forward)
    private var allCollections: [BookCollection]

    @State private var showingNewCollectionSheet = false
    @State private var showingPaywall = false

    @EnvironmentObject private var pro: ProManager

    var body: some View {
        Form {
            // MARK: - Overview
            Section("Überblick") {
                HStack(alignment: .top, spacing: 12) {
                    cover

                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Titel", text: $book.title)
                            .font(.headline)

                        // Untertitel: nur zeigen, wenn vorhanden ODER wenn importiert (damit man ihn leicht ergänzen kann)
                        if shouldShowSubtitleField {
                            TextField("Untertitel", text: Binding(
                                get: { book.subtitle ?? "" },
                                set: { newValue in
                                    let t = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                    book.subtitle = t.isEmpty ? nil : t
                                }
                            ))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }

                        TextField("Autor", text: $book.author)
                            .foregroundStyle(.secondary)

                        Picker("Status", selection: Binding(
                            get: { book.status },
                            set: { newStatus in
                                book.status = newStatus

                                if newStatus != .finished {
                                    book.readFrom = nil
                                    book.readTo = nil
                                } else {
                                    if book.readFrom == nil { book.readFrom = Date() }
                                    if book.readTo == nil { book.readTo = book.readFrom }
                                }
                            }
                        )) {
                            ForEach(ReadingStatus.allCases) { status in
                                Text(status.rawValue).tag(status)
                            }
                        }
                    }
                }

                // Bewertung kompakt direkt im Überblick
                if hasRating {
                    HStack(spacing: 10) {
                        StarsView(rating: book.averageRating ?? 0)

                        Text(ratingText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()

                        Spacer()
                    }
                    .padding(.top, 6)
                }
            }

            // MARK: - Read range
            if book.status == .finished {
                Section("Gelesen") {
                    if let readLine = formattedReadRangeLine(from: book.readFrom, to: book.readTo) {
                        Text(readLine)
                            .foregroundStyle(.secondary)
                    }

                    DatePicker(
                        "Von",
                        selection: Binding(
                            get: { book.readFrom ?? Date() },
                            set: { newValue in
                                book.readFrom = newValue
                                if let to = book.readTo, to < newValue {
                                    book.readTo = newValue
                                }
                            }
                        ),
                        displayedComponents: [.date]
                    )

                    DatePicker(
                        "Bis",
                        selection: Binding(
                            get: { book.readTo ?? (book.readFrom ?? Date()) },
                            set: { newValue in
                                book.readTo = newValue
                                if let from = book.readFrom, from > newValue {
                                    book.readFrom = newValue
                                }
                            }
                        ),
                        in: (book.readFrom ?? Date.distantPast)...Date(),
                        displayedComponents: [.date]
                    )
                }
            }

            // MARK: - Bibliophile block (human-friendly)
            if hasAnyBibliophileInfo {
                Section("Bibliophile Infos") {
                    // Online
                    if hasAnyLinks {
                        DisclosureGroup {
                            if let url = urlFromString(book.previewLink) {
                                PrettyLinkRow(title: "Leseprobe / Vorschau", url: url, systemImage: "book.pages")
                            }
                            if let url = urlFromString(book.infoLink) {
                                PrettyLinkRow(title: "Info-Seite", url: url, systemImage: "info.circle")
                            }
                            if let url = urlFromString(book.canonicalVolumeLink) {
                                PrettyLinkRow(title: "Original bei Google Books", url: url, systemImage: "link")
                            }
                        } label: {
                            Label("Online ansehen", systemImage: "safari")
                        }
                    }

                    // Formate & Verfügbarkeit
                    if hasAnyAvailability {
                        DisclosureGroup {
                            if let viewability = prettyViewability {
                                LabeledContent("Vorschauumfang", value: viewability)
                            }

                            LabeledContent("EPUB") { availabilityLabel(book.isEpubAvailable) }
                            LabeledContent("PDF") { availabilityLabel(book.isPdfAvailable) }

                            if let sale = prettySaleability {
                                LabeledContent("Kaufstatus", value: sale)
                            }

                            LabeledContent("E-Book") {
                                boolLabel(book.isEbook, trueText: "Ja", falseText: "Nein")
                            }

                            LabeledContent("Einbettbar") {
                                boolIcon(book.isEmbeddable)
                            }

                            LabeledContent("Public Domain") {
                                boolIcon(book.isPublicDomain)
                            }
                        } label: {
                            Label("Formate & Verfügbarkeit", systemImage: "doc.on.doc")
                        }
                    }

                    // Bewertung
                    if hasRating {
                        DisclosureGroup {
                            HStack(spacing: 10) {
                                StarsView(rating: book.averageRating ?? 0)
                                Text(ratingText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                Spacer()
                            }

                            Text("Hinweis: Bewertungen können je nach Buch/Edition stark variieren.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } label: {
                            Label("Bewertungen", systemImage: "star.bubble")
                        }
                    }

                    // Cover-Auswahl
                    if !book.coverURLCandidates.isEmpty {
                        DisclosureGroup {
                            Text("Tippe ein Cover an, um es als Standardcover zu setzen.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(book.coverURLCandidates, id: \.self) { s in
                                        Button {
                                            let current = (book.thumbnailURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                                            let isSame = current.caseInsensitiveCompare(s) == .orderedSame
                                            if !isSame {
                                                book.thumbnailURL = s
                                                try? modelContext.save()
                                            }
                                        } label: {
                                            CoverThumb(
                                                urlString: s,
                                                isSelected: ((book.thumbnailURL ?? "").caseInsensitiveCompare(s) == .orderedSame)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        } label: {
                            Label("Cover auswählen", systemImage: "photo.on.rectangle")
                        }
                    }
                }
            }

            // MARK: - Classic metadata

            Section("Listen") {
                if allCollections.isEmpty {
                    HStack {
                        Text("Noch keine Listen")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Anlegen") { requestNewCollection() }
                    }
                } else {
                    ForEach(allCollections) { col in
                        Toggle(isOn: Binding(
                            get: { book.isInCollection(col) },
                            set: { isOn in
                                setMembership(isOn, for: col)
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(col.name.isEmpty ? "Ohne Namen" : col.name)
                                Text("\(col.booksSafe.count) Bücher")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }

                    Button {
                        requestNewCollection()
                    } label: {
                        Label("Neue Liste …", systemImage: "plus")
                    }
                }
            }

            Section("Metadaten") {
                if let isbn = book.isbn13, !isbn.isEmpty {
                    LabeledContent("ISBN 13", value: isbn)
                }
                if let publisher = book.publisher, !publisher.isEmpty {
                    LabeledContent("Verlag", value: publisher)
                }
                if let publishedDate = book.publishedDate, !publishedDate.isEmpty {
                    LabeledContent("Erschienen", value: publishedDate)
                }
                if let pageCount = book.pageCount {
                    LabeledContent("Seiten", value: "\(pageCount)")
                }
                if let language = book.language, !language.isEmpty {
                    LabeledContent("Sprache", value: language)
                }

                if let main = book.mainCategory?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !main.isEmpty {
                    LabeledContent("Hauptkategorie", value: main)
                }

                if !book.categories.isEmpty {
                    Text("Kategorien: \(book.categories.joined(separator: ", "))")
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: - Tags + Notes
            Section("Tags") {
                TextField("Kommagetrennte Tags", text: $tagsText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: tagsText) { _, newValue in
                        book.tags = parseTags(newValue)
                    }
            }

            Section("Notizen") {
                TextEditor(text: $book.notes)
                    .frame(minHeight: 120)
            }

            if !book.bookDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Beschreibung") {
                    Text(book.bookDescription)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(book.title.isEmpty ? "Buchdetails" : book.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingNewCollectionSheet) {
            InlineNewCollectionSheet { name in
                createAndAttachCollection(named: name)
            }
        }
        .sheet(isPresented: $showingPaywall) {
            ProPaywallView(onPurchased: {
                showingNewCollectionSheet = true
            })
        }
        .onAppear { tagsText = book.tags.joined(separator: ", ") }
        .onDisappear { try? modelContext.save() }
    }

    // MARK: - Bibliophile computed properties

    private var shouldShowSubtitleField: Bool {
        if let s = book.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { return true }
        if let id = book.googleVolumeID, !id.isEmpty { return true }
        return false
    }

    private var hasAnyLinks: Bool {
        (book.previewLink?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        || (book.infoLink?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        || (book.canonicalVolumeLink?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    }

    private var hasAnyAvailability: Bool {
        (book.viewability?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        || book.isPublicDomain
        || book.isEmbeddable
        || book.isEpubAvailable
        || book.isPdfAvailable
        || (book.saleability?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        || book.isEbook
    }

    private var hasRating: Bool {
        if let avg = book.averageRating, avg > 0 { return true }
        return false
    }

    private var ratingText: String {
        let avg = book.averageRating ?? 0
        let count = book.ratingsCount ?? 0
        if count > 0 {
            return String(format: "%.1f", avg) + " (\(count))"
        }
        return String(format: "%.1f", avg)
    }

    private var prettyViewability: String? {
        guard let v = book.viewability?.trimmingCharacters(in: .whitespacesAndNewlines),
              !v.isEmpty else { return nil }

        switch v.uppercased() {
        case "NO_PAGES": return "Keine Vorschau"
        case "PARTIAL": return "Teilansicht"
        case "ALL_PAGES": return "Vollansicht"
        case "UNKNOWN": return "Unbekannt"
        default: return v
        }
    }

    private var prettySaleability: String? {
        guard let s = book.saleability?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty else { return nil }

        switch s.uppercased() {
        case "FOR_SALE": return "Käuflich"
        case "NOT_FOR_SALE": return "Nicht käuflich"
        case "FREE": return "Kostenlos"
        case "FOR_PREORDER": return "Vorbestellbar"
        default: return s
        }
    }

    private var hasAnyBibliophileInfo: Bool {
        hasAnyLinks || hasAnyAvailability || hasRating || !book.coverURLCandidates.isEmpty
    }

    // MARK: - Existing helpers

    @ViewBuilder
    private var cover: some View {
        if let urlString = book.thumbnailURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFit()
            } placeholder: { ProgressView() }
            .frame(width: 70, height: 105)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .frame(width: 70, height: 105)
                .opacity(0.15)
                .overlay(Image(systemName: "book").opacity(0.6))
        }
    }

    private func parseTags(_ input: String) -> [String] {
        input
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func formattedReadRangeLine(from: Date?, to: Date?) -> String? {
        guard from != nil || to != nil else { return nil }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none

        if let from, let to {
            return "Gelesen: \(df.string(from: from)) – \(df.string(from: to))"
        } else if let from {
            return "Gelesen ab: \(df.string(from: from))"
        } else if let to {
            return "Gelesen bis: \(df.string(from: to))"
        }
        return nil
    }


    // MARK: - Collections (Phase 1) helpers

    private func requestNewCollection() {
        let count = allCollections.count
        if pro.hasPro || count < ProManager.maxFreeCollections {
            showingNewCollectionSheet = true
        } else {
            showingPaywall = true
        }
    }


    private func setMembership(_ isMember: Bool, for collection: BookCollection) {
        // Keep both sides in sync (book <-> collection)
        var cols = book.collectionsSafe
        var books = collection.booksSafe

        if isMember {
            if !cols.contains(where: { $0.id == collection.id }) { cols.append(collection) }
            if !books.contains(where: { $0.id == book.id }) { books.append(book) }
        } else {
            cols.removeAll { $0.id == collection.id }
            books.removeAll { $0.id == book.id }
        }

        book.collectionsSafe = cols
        collection.booksSafe = books
        collection.updatedAt = Date()

        try? modelContext.save()
    }

    private func createAndAttachCollection(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // If same name exists already, just attach.
        if let existing = allCollections.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            setMembership(true, for: existing)
            return
        }

        let newCol = BookCollection(name: trimmed)
        modelContext.insert(newCol)
        setMembership(true, for: newCol)
    }

    private func urlFromString(_ s: String?) -> URL? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty else { return nil }
        return URL(string: s)
    }

    private func availabilityLabel(_ ok: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(ok ? .green : .secondary)
            Text(ok ? "verfügbar" : "nicht verfügbar")
                .foregroundStyle(.secondary)
        }
    }

    private func boolIcon(_ ok: Bool) -> some View {
        Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle")
            .foregroundStyle(ok ? .green : .secondary)
    }

    private func boolLabel(_ ok: Bool, trueText: String, falseText: String) -> some View {
        Text(ok ? trueText : falseText)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Small UI Components

private struct PrettyLinkRow: View {
    let title: String
    let url: URL
    let systemImage: String

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)

                    Text(prettyHost(url))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func prettyHost(_ url: URL) -> String {
        if let host = url.host, !host.isEmpty { return host }
        return url.absoluteString
    }
}

private struct StarsView: View {
    let rating: Double

    var body: some View {
        let clamped = min(max(rating, 0), 5)
        let full = Int(clamped.rounded(.down))
        let hasHalf = (clamped - Double(full)) >= 0.5
        let empty = max(0, 5 - full - (hasHalf ? 1 : 0))

        HStack(spacing: 2) {
            ForEach(0..<full, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
            if hasHalf {
                Image(systemName: "star.leadinghalf.filled")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }
            ForEach(0..<empty, id: \.self) { _ in
                Image(systemName: "star")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Bewertung \(String(format: "%.1f", clamped)) von 5")
    }
}

private struct CoverThumb: View {
    let urlString: String
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .opacity(0.12)

            if let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: "book")
                    .opacity(0.45)
            }

            if isSelected {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(lineWidth: 2)
                    .foregroundStyle(.primary.opacity(0.35))
            }
        }
        .frame(width: 56, height: 84)
        .clipped()
    }
}

// MARK: - Collections (Phase 1)

struct CollectionsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BookCollection.createdAt, order: .reverse)
    private var collections: [BookCollection]

    @State private var showingNew = false
    @State private var showingPaywall = false

    @EnvironmentObject private var pro: ProManager

    var body: some View {
        NavigationStack {
            List {
                if collections.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Listen",
                        systemImage: "rectangle.stack",
                        description: Text("Lege Listen an – z.B. „NYC“, „Justizthriller“, „KI“, „2025 Highlights“…")
                    )
                } else {
                    ForEach(collections) { c in
                        NavigationLink {
                            CollectionDetailView(collection: c)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.name.isEmpty ? "Ohne Namen" : c.name)

                                    // ✅ books ist optional -> safe count
                                    Text("\((c.books ?? []).count) Bücher")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .onDelete(perform: deleteCollections)
                }
            }
            .navigationTitle("Listen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        requestNewCollection()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Neue Liste")
                }
            }
            .sheet(isPresented: $showingNew) {
                NewCollectionSheet { name in
                    let col = BookCollection(name: name)
                    modelContext.insert(col)
                    try? modelContext.save()
                }
            }
            .sheet(isPresented: $showingPaywall) {
                ProPaywallView(onPurchased: {
                    showingNew = true
                })
            }
        }
    }


    private func requestNewCollection() {
        let count = collections.count
        if pro.hasPro || count < ProManager.maxFreeCollections {
            showingNew = true
        } else {
            showingPaywall = true
        }
    }

    private func deleteCollections(at offsets: IndexSet) {
        for index in offsets {
            let col = collections[index]

            // ✅ books ist optional
            let booksInCol = col.books ?? []

            // defensive: remove relation explicitly (CloudKit kann sonst manchmal zicken)
            for b in booksInCol {
                var current = b.collections ?? []
                current.removeAll(where: { $0.id == col.id })
                b.collections = current
            }

            modelContext.delete(col)
        }
        try? modelContext.save()
    }
}

// ✅ OUTSIDE now: can be linked from anywhere
struct CollectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var collection: BookCollection

    @State private var nameDraft: String = ""

    var body: some View {
        List {
            Section("Name") {
                TextField("Listenname", text: $nameDraft)
                    .onChange(of: nameDraft) { _, newValue in
                        let t = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        collection.name = t
                        collection.updatedAt = Date()
                        try? modelContext.save()
                    }
            }

            Section("Bücher") {
                if (collection.books ?? []).isEmpty {
                    ContentUnavailableView(
                        "Noch leer",
                        systemImage: "book",
                        description: Text("Öffne ein Buch → „Listen“ → Haken setzen.")
                    )
                } else {
                    ForEach(sortedBooks) { b in
                        NavigationLink {
                            BookDetailView(book: b)
                        } label: {
                            BookRowView(book: b)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                var current = b.collections ?? []
                                current.removeAll(where: { $0.id == collection.id })
                                b.collections = current
                                try? modelContext.save()
                            } label: {
                                Label("Entfernen", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(collection.name.isEmpty ? "Liste" : collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { nameDraft = collection.name }
    }

    private var sortedBooks: [Book] {
        (collection.books ?? []).sorted { a, b in
            let ta = a.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let tb = b.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return ta.localizedCaseInsensitiveCompare(tb) == .orderedAscending
        }
    }

}

// MARK: - Add Book
struct AddBookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title: String = ""
    @State private var author: String = ""
    @State private var status: ReadingStatus = .toRead

    @State private var readFrom: Date = Date()
    @State private var readTo: Date = Date()

    // Existing imported metadata
    @State private var isbn13: String?
    @State private var thumbnailURL: String?
    @State private var publisher: String?
    @State private var publishedDate: String?
    @State private var pageCount: Int?
    @State private var language: String?
    @State private var categories: [String] = []
    @State private var bookDescription: String = ""
    @State private var googleVolumeID: String?

    // ✅ New imported metadata (persisted into Book)
    @State private var subtitle: String?
    @State private var previewLink: String?
    @State private var infoLink: String?
    @State private var canonicalVolumeLink: String?

    @State private var averageRating: Double?
    @State private var ratingsCount: Int?
    @State private var mainCategory: String?

    @State private var coverURLCandidates: [String] = []

    @State private var viewability: String?
    @State private var isPublicDomain: Bool = false
    @State private var isEmbeddable: Bool = false

    @State private var isEpubAvailable: Bool = false
    @State private var isPdfAvailable: Bool = false
    @State private var epubAcsTokenLink: String?
    @State private var pdfAcsTokenLink: String?

    @State private var saleability: String?
    @State private var isEbook: Bool = false

    @State private var showingImportSheet = false

    // track if we currently have quick-added books in this session (and not undone)
    @State private var quickAddActive = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        quickAddActive = false
                        showingImportSheet = true
                    } label: {
                        Label("Aus Google Books suchen", systemImage: "magnifyingglass")
                    }
                }

                Section("Neues Buch") {
                    TextField("Titel", text: $title)
                    TextField("Autor", text: $author)

                    Picker("Status", selection: $status) {
                        ForEach(ReadingStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                }

                if status == .finished {
                    Section("Gelesen") {
                        DatePicker("Von", selection: $readFrom, displayedComponents: [.date])
                            .onChange(of: readFrom) { _, newValue in
                                if readTo < newValue { readTo = newValue }
                            }

                        DatePicker("Bis", selection: $readTo, in: readFrom...Date(), displayedComponents: [.date])
                            .onChange(of: readTo) { _, newValue in
                                if newValue < readFrom { readFrom = newValue }
                            }
                    }
                }

                if let thumbnailURL, let url = URL(string: thumbnailURL) {
                    Section("Cover") {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFit()
                        } placeholder: { ProgressView() }
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                    }
                }

                if hasAnyImportedMetadata {
                    Section("Übernommene Metadaten") {
                        if let isbn13 { LabeledContent("ISBN 13", value: isbn13) }
                        if let publisher { LabeledContent("Verlag", value: publisher) }
                        if let publishedDate { LabeledContent("Erschienen", value: publishedDate) }
                        if let pageCount { LabeledContent("Seiten", value: "\(pageCount)") }
                        if let language { LabeledContent("Sprache", value: language) }
                        if !categories.isEmpty {
                            Text("Kategorien: \(categories.joined(separator: ", "))")
                                .foregroundStyle(.secondary)
                        }
                        if !bookDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(bookDescription)
                                .foregroundStyle(.secondary)
                                .lineLimit(6)
                        }
                    }
                }
            }
            .navigationTitle("Buch hinzufügen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        addBook()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingImportSheet, onDismiss: {
                let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                if quickAddActive && trimmedTitle.isEmpty {
                    dismiss()
                }
            }) {
                BookImportView(
                    onPick: { imported in
                        title = imported.title
                        author = imported.author

                        isbn13 = imported.isbn13
                        thumbnailURL = imported.thumbnailURL
                        publisher = imported.publisher
                        publishedDate = imported.publishedDate
                        pageCount = imported.pageCount
                        language = imported.language
                        categories = imported.categories
                        bookDescription = imported.description
                        googleVolumeID = imported.googleVolumeID

                        // ✅ New rich metadata
                        subtitle = imported.subtitle
                        previewLink = imported.previewLink
                        infoLink = imported.infoLink
                        canonicalVolumeLink = imported.canonicalVolumeLink

                        averageRating = imported.averageRating
                        ratingsCount = imported.ratingsCount
                        mainCategory = imported.mainCategory

                        coverURLCandidates = imported.coverURLCandidates

                        viewability = imported.viewability
                        isPublicDomain = imported.isPublicDomain
                        isEmbeddable = imported.isEmbeddable

                        isEpubAvailable = imported.isEpubAvailable
                        isPdfAvailable = imported.isPdfAvailable
                        epubAcsTokenLink = imported.epubAcsTokenLink
                        pdfAcsTokenLink = imported.pdfAcsTokenLink

                        saleability = imported.saleability
                        isEbook = imported.isEbook
                    },
                    onQuickAddHappened: {
                        quickAddActive = true
                    },
                    onQuickAddActiveChanged: { isActive in
                        quickAddActive = isActive
                    }
                )
            }
        }
    }

    private var hasAnyImportedMetadata: Bool {
        isbn13 != nil
        || thumbnailURL != nil
        || publisher != nil
        || publishedDate != nil
        || pageCount != nil
        || language != nil
        || !categories.isEmpty
        || !bookDescription.isEmpty

        // new fields (optional)
        || subtitle != nil
        || previewLink != nil
        || infoLink != nil
        || canonicalVolumeLink != nil
        || averageRating != nil
        || ratingsCount != nil
        || mainCategory != nil
        || !coverURLCandidates.isEmpty
        || viewability != nil
        || isPublicDomain
        || isEmbeddable
        || isEpubAvailable
        || isPdfAvailable
        || epubAcsTokenLink != nil
        || pdfAcsTokenLink != nil
        || saleability != nil
        || isEbook
    }

    private func addBook() {
        let newBook = Book(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            author: author.trimmingCharacters(in: .whitespacesAndNewlines),
            status: status
        )

        if status == .finished {
            newBook.readFrom = readFrom
            newBook.readTo = readTo
        }

        // Existing mappings
        newBook.isbn13 = isbn13
        newBook.thumbnailURL = thumbnailURL
        newBook.publisher = publisher
        newBook.publishedDate = publishedDate
        newBook.pageCount = pageCount
        newBook.language = language
        newBook.categories = categories
        newBook.bookDescription = bookDescription
        newBook.googleVolumeID = googleVolumeID

        // ✅ New rich metadata mappings
        newBook.subtitle = subtitle
        newBook.previewLink = previewLink
        newBook.infoLink = infoLink
        newBook.canonicalVolumeLink = canonicalVolumeLink

        newBook.averageRating = averageRating
        newBook.ratingsCount = ratingsCount
        newBook.mainCategory = mainCategory

        newBook.coverURLCandidates = coverURLCandidates

        newBook.viewability = viewability
        newBook.isPublicDomain = isPublicDomain
        newBook.isEmbeddable = isEmbeddable

        newBook.isEpubAvailable = isEpubAvailable
        newBook.isPdfAvailable = isPdfAvailable
        newBook.epubAcsTokenLink = epubAcsTokenLink
        newBook.pdfAcsTokenLink = pdfAcsTokenLink

        newBook.saleability = saleability
        newBook.isEbook = isEbook

        modelContext.insert(newBook)
        try? modelContext.save()
    }
}

// MARK: - Goals View
struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReadingGoal.year, order: .reverse) private var goals: [ReadingGoal]
    @Query private var books: [Book]

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var targetCount: Int = 50

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 62), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    goalCard
                    progressCard
                    slotsGrid
                }
                .padding(.horizontal)
                .padding(.bottom, 18)
                .padding(.top, 12)
            }
            .navigationTitle("Leseziele")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { loadGoalForSelectedYear() }
            .onChange(of: selectedYear) { _, _ in loadGoalForSelectedYear() }
        }
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ziel definieren")
                .font(.headline)

            HStack(spacing: 12) {
                Picker("Jahr", selection: $selectedYear) {
                    ForEach(yearOptions, id: \.self) { y in
                        Text(String(y)).tag(y)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                Stepper(value: $targetCount, in: 1...200, step: 1) {
                    Text("\(targetCount) Bücher")
                        .monospacedDigit()
                }
                .onChange(of: targetCount) { _, newValue in
                    saveGoal(year: selectedYear, targetCount: newValue)
                }
            }

            Text("Tip: Füllt sich automatisch, sobald du bei „Gelesen“ den Zeitraum setzt.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var progressCard: some View {
        let done = finishedBooksInSelectedYear.count
        let total = max(targetCount, 1)
        let pct = min(Double(done) / Double(total), 1.0)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Fortschritt \(String(selectedYear))")
                    .font(.headline)
                Spacer()
                Text("\(done) / \(targetCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ProgressView(value: pct)

            HStack(spacing: 10) {
                StatPill(systemImage: "doc.plaintext", title: "Seiten", value: formatInt(pagesReadInSelectedYear))
                StatPill(systemImage: "divide.circle", title: "Ø/Buch", value: avgPagesPerBookText)
                StatPill(systemImage: "calendar", title: "/Monat", value: pagesPerMonthText)
            }
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var slotsGrid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0..<targetCount, id: \.self) { index in
                if index < finishedBooksInSelectedYear.count {
                    let book = finishedBooksInSelectedYear[index]
                    NavigationLink {
                        BookDetailView(book: book)
                    } label: {
                        GoalSlotView(thumbnailURL: book.thumbnailURL, isFilled: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    GoalSlotView(thumbnailURL: nil, isFilled: false)
                }
            }
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var yearOptions: [Int] {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        let nextYear = currentYear + 1

        var years = Set<Int>()
        years.insert(currentYear)
        years.insert(nextYear)

        for b in books {
            guard b.status == .finished else { continue }
            if let d = b.readTo ?? b.readFrom {
                years.insert(cal.component(.year, from: d))
            }
        }

        for g in goals {
            years.insert(g.year)
        }

        return years.sorted(by: >)
    }

    private var finishedBooksInSelectedYear: [Book] {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: selectedYear, month: 1, day: 1)) ?? Date.distantPast
        let end = cal.date(from: DateComponents(year: selectedYear + 1, month: 1, day: 1)) ?? Date.distantFuture

        let filtered = books.filter { book in
            guard book.status == .finished else { return false }
            let keyDate = book.readTo ?? book.readFrom
            guard let d = keyDate else { return false }
            return d >= start && d < end
        }

        return filtered.sorted { a, b in
            let da = a.readTo ?? a.readFrom ?? a.createdAt
            let db = b.readTo ?? b.readFrom ?? b.createdAt
            return da < db
        }
    }

    private var pagesReadInSelectedYear: Int {
        finishedBooksInSelectedYear.reduce(0) { partial, book in
            partial + (book.pageCount ?? 0)
        }
    }

    private var countedBooksWithPagesInSelectedYear: [Book] {
        finishedBooksInSelectedYear.filter { ($0.pageCount ?? 0) > 0 }
    }

    private var avgPagesPerBookText: String {
        let arr = countedBooksWithPagesInSelectedYear
        guard !arr.isEmpty else { return "–" }
        let pages = arr.reduce(0) { $0 + ($1.pageCount ?? 0) }
        let avg = Double(pages) / Double(arr.count)
        return formatInt(Int(avg.rounded()))
    }

    private var pagesPerMonthText: String {
        let months = monthsCountForSelectedYear()
        guard months > 0 else { return "–" }
        let perMonth = Double(pagesReadInSelectedYear) / Double(months)
        return formatInt(Int(perMonth.rounded()))
    }

    private func monthsCountForSelectedYear() -> Int {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())

        if selectedYear < currentYear { return 12 }
        if selectedYear > currentYear { return 12 }

        let month = cal.component(.month, from: Date())
        return max(1, month)
    }

    private func formatInt(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func loadGoalForSelectedYear() {
        if let existing = goals.first(where: { $0.year == selectedYear }) {
            targetCount = max(existing.targetCount, 1)
        } else {
            targetCount = 50
            saveGoal(year: selectedYear, targetCount: targetCount)
        }
    }

    private func saveGoal(year: Int, targetCount: Int) {
        if let existing = goals.first(where: { $0.year == year }) {
            existing.targetCount = targetCount
            existing.updatedAt = Date()
        } else {
            let goal = ReadingGoal(year: year, targetCount: targetCount)
            modelContext.insert(goal)
        }
        try? modelContext.save()
    }
}

private struct StatPill: View {
    let systemImage: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct GoalSlotView: View {
    let thumbnailURL: String?
    let isFilled: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .opacity(isFilled ? 0.18 : 0.12)

            if let thumbnailURL, let url = URL(string: thumbnailURL) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .clipped()
            } else {
                Image(systemName: "book")
                    .opacity(0.45)
            }
        }
        .aspectRatio(2.0/3.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Tags Tab (counts + tap to filter)
struct TagsView: View {
    @Query private var books: [Book]

    var body: some View {
        NavigationStack {
            List {
                if tagCounts.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Tags",
                        systemImage: "tag",
                        description: Text("Füge Tags bei einem Buch hinzu, dann tauchen sie hier auf.")
                    )
                } else {
                    ForEach(tagCounts, id: \.tag) { entry in
                        NavigationLink {
                            LibraryView(initialTag: entry.tag)
                        } label: {
                            HStack {
                                Text("#\(entry.tag)")
                                Spacer()
                                Text("\(entry.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tags")
        }
    }

    private var tagCounts: [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for b in books {
            for t in b.tags {
                let normalized = t.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalized.isEmpty else { continue }
                counts[normalized, default: 0] += 1
            }
        }
        return counts
            .map { ($0.key, $0.value) }
            .sorted { a, b in
                if a.1 != b.1 { return a.1 > b.1 }
                return a.0.localizedCaseInsensitiveCompare(b.0) == .orderedAscending
            }
    }
}

// MARK: - Settings
struct SettingsView: View {
    @EnvironmentObject private var pro: ProManager
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section("Export") {
                    Text("PDF-Export (kommt)")
                    Text("Markdown-Export (kommt)")
                }

                Section("Sync") {
                    Text("iCloud-Sync ist aktiv (CloudKit).")
                        .foregroundStyle(.secondary)
                }

                Section("Pro") {
                    if pro.hasPro {
                        Label("Pro ist aktiv", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.secondary)

                        Text("Unbegrenzte Listen sind freigeschaltet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Du kannst kostenlos bis zu \(ProManager.maxFreeCollections) Listen anlegen. Für weitere Listen brauchst du den Einmalkauf.")
                            .font(.subheadline)

                        Button {
                            showingPaywall = true
                        } label: {
                            Label("Einmalkauf freischalten", systemImage: "sparkles")
                        }
                    }

                    Button {
                        Task { await pro.restore() }
                    } label: {
                        Label("Käufe wiederherstellen", systemImage: "arrow.clockwise")
                    }

                    if let err = pro.lastError, !err.isEmpty {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .sheet(isPresented: $showingPaywall) {
                ProPaywallView()
            }
            .task {
                await pro.refreshEntitlements()
                await pro.loadProductIfNeeded()
            }
        }
    }
}

// MARK: - UI: removable chip
struct TagChip: View {
    let text: String
    let systemImage: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)

            Text(text)
                .font(.caption)
                .lineLimit(1)

            Button { onRemove() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial)
        .clipShape(Capsule())
    }
}

// MARK: - Library UI Bits

private struct LibraryStatCard: View {
    let title: String
    let value: Int
    let systemImage: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(isActive ? .primary : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("\(value)")
                        .font(.headline)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isActive ? .ultraThinMaterial : .thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title): \(value)")
    }
}

private struct LibraryCoverThumb: View {
    let urlString: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .opacity(0.10)

            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: "book")
                    .opacity(0.45)
            }
        }
        .frame(width: 44, height: 66)
        .clipped()
    }
}

// MARK: - New Collection Sheet

struct NewCollectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onCreate: (String) -> Void

    @State private var name: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("z.B. „NYC“, „Thriller 2025“, „KI“ …", text: $name)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit { create() }
                }

                Section {
                    Text("Tipp: Du kannst Bücher später in der Buch-Detailansicht zu Listen hinzufügen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Neue Liste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Erstellen") { create() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    focused = true
                }
            }
        }
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onCreate(trimmed)
        dismiss()
    }
}


// MARK: - Sheet: Neue Liste anlegen (Inline)

private struct InlineNewCollectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCreate: (String) -> Void

    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Listenname", text: $name)
                }
                Section {
                    Text("Du kannst das später jederzeit umbenennen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Neue Liste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Anlegen") {
                        onCreate(name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
// MARK: - Pro / Paywall (Einmalkauf für extra Listen)

@MainActor
final class ProManager: ObservableObject {
    /// ⚠️ TODO: Setze hier später genau die Product ID aus App Store Connect ein.
    static let productID = "001"
    static let maxFreeCollections = 2

    @Published private(set) var hasPro: Bool = false
    @Published private(set) var product: Product?
    @Published private(set) var isBusy: Bool = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { await listenForTransactions() }
        Task {
            await refreshEntitlements()
            await loadProductIfNeeded()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProductIfNeeded() async {
        guard product == nil else { return }
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var entitled = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.productID else { continue }
            // wenn revoked -> nicht gültig
            if transaction.revocationDate == nil {
                entitled = true
                break
            }
        }

        hasPro = entitled
    }

    func purchase() async -> Bool {
        lastError = nil
        await loadProductIfNeeded()

        guard let product else {
            lastError = "Produkt ist (noch) nicht verfügbar. Prüfe die Product ID und App Store Connect."
            return false
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return true

            case .userCancelled:
                return false

            case .pending:
                lastError = "Kauf ausstehend (z.B. Familienfreigabe/Bestätigung)."
                return false

            @unknown default:
                lastError = "Unbekanntes Kauf-Ergebnis."
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        lastError = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func listenForTransactions() async {
        for await update in Transaction.updates {
            do {
                let transaction = try checkVerified(update)
                // Entitlement-Status aktualisieren, dann finishen
                await refreshEntitlements()
                await transaction.finish()
            } catch {
                // ignore invalid transactions
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let signed):
            return signed
        }
    }
}

struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var pro: ProManager

    var onPurchased: (() -> Void)? = nil

    @State private var localError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 38))
                        .padding(.top, 6)

                    Text("Mehr Listen freischalten")
                        .font(.title2)
                        .bold()

                    Text("Kostenlos: bis zu \(ProManager.maxFreeCollections) Listen.\nMit Einmalkauf: unbegrenzt.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    featureRow("Unbegrenzte Collections/Listen")
                    featureRow("Ideal für Reihen, Themen, Challenges")
                    featureRow("Kauf gilt auf iPhone & iPad (Apple-ID)")
                }
                .padding(14)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal)

                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    Button {
                        Task {
                            localError = nil
                            let ok = await pro.purchase()
                            if ok {
                                dismiss()
                                onPurchased?()
                            } else if let err = pro.lastError, !err.isEmpty {
                                localError = err
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if pro.isBusy {
                                ProgressView()
                            } else {
                                Text(buyButtonTitle)
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pro.isBusy || pro.hasPro)

                    Button {
                        Task { await pro.restore() }
                    } label: {
                        Text("Käufe wiederherstellen")
                    }
                    .disabled(pro.isBusy)

                    if pro.hasPro {
                        Text("Pro ist bereits aktiv ✅")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let localError, !localError.isEmpty {
                        Text(localError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 18)
            }
            .navigationTitle("Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .task {
                await pro.refreshEntitlements()
                await pro.loadProductIfNeeded()
            }
        }
    }

    private var buyButtonTitle: String {
        if pro.hasPro { return "Bereits freigeschaltet" }
        if let product = pro.product {
            return "Einmalkauf \(product.displayPrice)"
        }
        return "Einmalkauf"
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
            Text(text)
            Spacer()
        }
        .font(.subheadline)
    }
}

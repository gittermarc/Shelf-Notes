//
//  ContentView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//

import SwiftUI
import SwiftData

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
        set { sortFieldRaw = newValue.rawValue }
    }

    // A–Z hint logic (only show when it’s actually helpful)
    private let alphaIndexHintThreshold: Int = 30
    private var shouldShowAlphaIndexHint: Bool {
        sortField == .title && displayedBooks.count >= alphaIndexHintThreshold
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
            .navigationTitle("Meine Bücher")
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
        VStack(alignment: .leading, spacing: 6) {
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

                    if (selectedStatus == nil && selectedTag == nil && !onlyWithNotes) {
                        Text("Filter: kein Filter gesetzt")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
            }

            // Count row (always, reflects current filtered list)
            HStack {
                Text("Bücher in deiner Liste: \(displayedBooks.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .background(.ultraThinMaterial)
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
            Image(systemName: "books.vertical")
                .font(.system(size: 46))

            Text("Keine Treffer")
                .font(.title2)
                .bold()

            Text("Entweder noch keine Bücher — oder deine Filter sind zu gut. 😄")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 30)
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

    var body: some View {
        Form {
            Section("Überblick") {
                HStack(alignment: .top, spacing: 12) {
                    cover
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Titel", text: $book.title)
                            .font(.headline)

                        // Subtitle (optional, only show if exists OR user wants to edit)
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

                // Rating row (nice + compact)
                if let ratingView = ratingLineView {
                    ratingView
                        .padding(.top, 6)
                }
            }

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

                // Categories + optional main category
                if let main = book.mainCategory?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !main.isEmpty {
                    LabeledContent("Hauptkategorie", value: main)
                }

                if !book.categories.isEmpty {
                    Text("Kategorien: \(book.categories.joined(separator: ", "))")
                        .foregroundStyle(.secondary)
                }
            }

            // ✅ New: Links
            if hasAnyLinks {
                Section("Links") {
                    if let url = urlFromString(book.previewLink) {
                        LinkRow(title: "Vorschau", subtitle: "previewLink", systemImage: "play.rectangle", url: url)
                    }
                    if let url = urlFromString(book.infoLink) {
                        LinkRow(title: "Info", subtitle: "infoLink", systemImage: "info.circle", url: url)
                    }
                    if let url = urlFromString(book.canonicalVolumeLink) {
                        LinkRow(title: "Original", subtitle: "canonical", systemImage: "link", url: url)
                    }
                }
            }

            // ✅ New: Access / Availability
            if hasAnyAccessInfo {
                Section("Zugriff & Formate") {
                    if let v = book.viewability?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !v.isEmpty {
                        LabeledContent("Viewability", value: prettifyViewability(v))
                    }

                    LabeledContent("Public Domain") {
                        Image(systemName: book.isPublicDomain ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(book.isPublicDomain ? .green : .secondary)
                    }

                    LabeledContent("Embeddable") {
                        Image(systemName: book.isEmbeddable ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(book.isEmbeddable ? .green : .secondary)
                    }

                    LabeledContent("EPUB") {
                        availabilityLabel(book.isEpubAvailable)
                    }

                    LabeledContent("PDF") {
                        availabilityLabel(book.isPdfAvailable)
                    }

                    if let s = book.saleability?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !s.isEmpty {
                        LabeledContent("Saleability", value: prettifySaleability(s))
                    }

                    LabeledContent("E-Book") {
                        Image(systemName: book.isEbook ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(book.isEbook ? .green : .secondary)
                    }
                }
            }

            // ✅ New: Cover variants (tap to use)
            if !book.coverURLCandidates.isEmpty {
                Section("Cover-Varianten") {
                    Text("Tippe ein Cover an, um es als Standardcover zu setzen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(book.coverURLCandidates, id: \.self) { s in
                                Button {
                                    let isSame = (book.thumbnailURL ?? "").caseInsensitiveCompare(s) == .orderedSame
                                    if !isSame {
                                        book.thumbnailURL = s
                                        try? modelContext.save()
                                    }
                                } label: {
                                    CoverThumb(urlString: s, isSelected: (book.thumbnailURL ?? "") == s)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

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
        .onAppear { tagsText = book.tags.joined(separator: ", ") }
        .onDisappear { try? modelContext.save() }
    }

    // MARK: - Helpers (UI)

    private var shouldShowSubtitleField: Bool {
        if let s = book.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { return true }
        // if we have a google volume id, user likely imported -> show field for convenience
        if let id = book.googleVolumeID, !id.isEmpty { return true }
        return false
    }

    private var hasAnyLinks: Bool {
        (book.previewLink?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        || (book.infoLink?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        || (book.canonicalVolumeLink?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    }

    private var hasAnyAccessInfo: Bool {
        (book.viewability?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        || book.isPublicDomain
        || book.isEmbeddable
        || book.isEpubAvailable
        || book.isPdfAvailable
        || (book.saleability?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        || book.isEbook
    }

    private var ratingLineView: AnyView? {
        guard let avg = book.averageRating, avg > 0 else { return nil }
        let count = book.ratingsCount ?? 0
        return AnyView(
            HStack(spacing: 8) {
                StarsView(rating: avg)

                Text(String(format: "%.1f", avg))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                if count > 0 {
                    Text("(\(count))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()
            }
        )
    }

    private func availabilityLabel(_ ok: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(ok ? .green : .secondary)
            Text(ok ? "verfügbar" : "nicht verfügbar")
                .foregroundStyle(.secondary)
        }
    }

    private func urlFromString(_ s: String?) -> URL? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty else { return nil }
        return URL(string: s)
    }

    private func prettifyViewability(_ v: String) -> String {
        // common values: NO_PAGES, PARTIAL, ALL_PAGES, UNKNOWN (depends on API)
        switch v.uppercased() {
        case "NO_PAGES": return "Keine Seiten"
        case "PARTIAL": return "Teilweise"
        case "ALL_PAGES": return "Alle Seiten"
        case "UNKNOWN": return "Unbekannt"
        default: return v
        }
    }

    private func prettifySaleability(_ s: String) -> String {
        switch s.uppercased() {
        case "FOR_SALE": return "Käuflich"
        case "NOT_FOR_SALE": return "Nicht käuflich"
        case "FREE": return "Kostenlos"
        case "FOR_PREORDER": return "Vorbestellbar"
        default: return s
        }
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
}

// MARK: - Small UI Components

private struct LinkRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct StarsView: View {
    let rating: Double

    var body: some View {
        let full = Int(rating.rounded(.down))
        let hasHalf = (rating - Double(full)) >= 0.5
        let empty = max(0, 5 - full - (hasHalf ? 1 : 0))

        HStack(spacing: 2) {
            ForEach(0..<full, id: \.self) { _ in
                Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow)
            }
            if hasHalf {
                Image(systemName: "star.leadinghalf.filled").font(.caption).foregroundStyle(.yellow)
            }
            ForEach(0..<empty, id: \.self) { _ in
                Image(systemName: "star").font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Bewertung \(String(format: "%.1f", rating)) von 5")
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

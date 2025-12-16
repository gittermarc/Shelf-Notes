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

    init(initialTag: String? = nil) {
        _selectedTag = State(initialValue: initialTag)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar

                Group {
                    if filteredBooks.isEmpty {
                        emptyState
                    } else {
                        List {
                            ForEach(filteredBooks) { book in
                                NavigationLink {
                                    BookDetailView(book: book)
                                } label: {
                                    BookRowView(book: book)
                                }
                            }
                            .onDelete(perform: deleteBooks)
                        }
                    }
                }
            }
            .navigationTitle("Meine Bücher")
            .searchable(text: $searchText, prompt: "Suche Titel, Autor, Tag …")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
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
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filter")
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

    private var filterBar: some View {
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
                    Text("Filter: keine (noch 😄)")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial)
    }

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

    private func deleteBooks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredBooks[index])
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

                HStack(spacing: 8) {
                    Text(book.status.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !book.tags.isEmpty {
                        Text("• \(book.tags.prefix(2).map { "#\($0)" }.joined(separator: " "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
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
                if !book.categories.isEmpty {
                    Text("Kategorien: \(book.categories.joined(separator: ", "))")
                        .foregroundStyle(.secondary)
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
        .onAppear {
            tagsText = book.tags.joined(separator: ", ")
        }
        .onDisappear {
            try? modelContext.save()
        }
    }

    @ViewBuilder
    private var cover: some View {
        if let urlString = book.thumbnailURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                ProgressView()
            }
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

// MARK: - Add Book
struct AddBookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title: String = ""
    @State private var author: String = ""
    @State private var status: ReadingStatus = .toRead

    @State private var readFrom: Date = Date()
    @State private var readTo: Date = Date()

    @State private var isbn13: String?
    @State private var thumbnailURL: String?
    @State private var publisher: String?
    @State private var publishedDate: String?
    @State private var pageCount: Int?
    @State private var language: String?
    @State private var categories: [String] = []
    @State private var bookDescription: String = ""
    @State private var googleVolumeID: String?

    @State private var showingImportSheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
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
                        } placeholder: {
                            ProgressView()
                        }
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
            .sheet(isPresented: $showingImportSheet) {
                BookImportView { imported in
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
                }
            }
        }
    }

    private var hasAnyImportedMetadata: Bool {
        isbn13 != nil || thumbnailURL != nil || publisher != nil || publishedDate != nil || pageCount != nil || language != nil || !categories.isEmpty || !bookDescription.isEmpty
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

        newBook.isbn13 = isbn13
        newBook.thumbnailURL = thumbnailURL
        newBook.publisher = publisher
        newBook.publishedDate = publishedDate
        newBook.pageCount = pageCount
        newBook.language = language
        newBook.categories = categories
        newBook.bookDescription = bookDescription
        newBook.googleVolumeID = googleVolumeID

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

    // IMPORTANT: Adaptive grid keeps slot width reasonable on iPad + landscape
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
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 3)...(current + 1)).reversed()
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
            // Background
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
        // IMPORTANT: enforce portrait cover ratio (2:3)
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

// MARK: - Settings placeholder
struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Export") {
                    Text("PDF-Export (kommt)")
                    Text("Markdown-Export (kommt)")
                }
                Section("Sync") {
                    Text("iCloud-Sync (kommt)")
                }
                Section("Pro") {
                    Text("Paywall/Subscription (kommt)")
                }
            }
            .navigationTitle("Einstellungen")
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

            Button {
                onRemove()
            } label: {
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

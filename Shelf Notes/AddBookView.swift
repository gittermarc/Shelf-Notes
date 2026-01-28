//
//  AddBookView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Split from ContentView.swift on 05.01.26.
//

import SwiftUI
import SwiftData

// MARK: - Add Book
struct AddBookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title: String = ""
    @State private var author: String = ""
    @State private var status: ReadingStatus = .toRead
    
    @State private var showingScannerSheet = false
    @State private var pendingScanISBN: String? = nil

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

    // UI state
    @State private var isDescriptionExpanded: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    heroCard
                    importActionsCard
                    basicsCard

                    if hasAnyImportedMetadata {
                        metadataCard
                    }

                    if !trimmedDescription.isEmpty {
                        descriptionCard
                    }

                    if hasAnyLinks {
                        linksCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Buch hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        addBook()
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                primaryActionBar
            }
            .sheet(isPresented: $showingImportSheet, onDismiss: {
                pendingScanISBN = nil
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
                    initialQuery: pendingScanISBN,
                    autoSearchOnAppear: true,
                    onQuickAddHappened: {
                        quickAddActive = true
                    },
                    onQuickAddActiveChanged: { isActive in
                        quickAddActive = isActive
                    }
                )
            }
            .sheet(isPresented: $showingScannerSheet) {
                BarcodeScannerSheet { isbn in
                    pendingScanISBN = isbn
                }
            }
            .onChange(of: showingScannerSheet) { _, isShowing in
                // Scanner ist zu -> wenn wir eine ISBN haben -> Import-Sheet öffnen
                if !isShowing, let isbn = pendingScanISBN, !isbn.isEmpty {
                    quickAddActive = false
                    showingImportSheet = true
                }
            }
        }
    }

    // MARK: - UI building blocks

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedAuthor: String {
        author.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedSubtitle: String {
        (subtitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedDescription: String {
        bookDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var publishedYear: String? {
        publishedYear(from: publishedDate)
    }

    private var coverCandidatesAll: [String] {
        var out: [String] = []

        func add(_ s: String?) {
            guard let s else { return }
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                out.append(t)
            }
        }

        add(thumbnailURL)
        for c in coverURLCandidates {
            add(c)
        }
        return out
    }

    private var bestCoverURL: URL? {
        // Best effort background: prefer thumbnail, otherwise first candidate.
        if let u = url(from: thumbnailURL) { return u }
        return url(from: coverURLCandidates.first)
    }

    private var previewURL: URL? { url(from: previewLink) }
    private var infoURL: URL? { url(from: infoLink) }
    private var canonicalURL: URL? { url(from: canonicalVolumeLink) }

    private var hasAnyLinks: Bool {
        previewURL != nil || infoURL != nil || canonicalURL != nil
    }

    @ViewBuilder
    private var heroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)

            if let bg = bestCoverURL {
                CachedAsyncImage(url: bg, contentMode: .fill) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Color.clear
                }
                .blur(radius: 18)
                .opacity(0.22)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            HStack(alignment: .top, spacing: 14) {
                coverView

                VStack(alignment: .leading, spacing: 8) {
                    Text(trimmedTitle.isEmpty ? "Neues Buch" : trimmedTitle)
                        .font(.title3.weight(.semibold))
                        .lineLimit(3)

                    if !trimmedSubtitle.isEmpty {
                        Text(trimmedSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    if !trimmedAuthor.isEmpty {
                        Text(trimmedAuthor)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    if let rating = averageRating {
                        HStack(spacing: 8) {
                            StarsView(rating: rating, size: 12)

                            Text(String(format: "%.1f", rating))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()

                            if let c = ratingsCount, c > 0 {
                                Text("(\(c))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }

                            Spacer(minLength: 0)
                        }
                    }

                    HStack(spacing: 8) {
                        if let pc = pageCount {
                            Chip(text: "\(pc) S.", systemImage: "doc.plaintext")
                        }
                        if let y = publishedYear {
                            Chip(text: y, systemImage: "calendar")
                        }
                        if let lang = language?.trimmingCharacters(in: .whitespacesAndNewlines), !lang.isEmpty {
                            Chip(text: lang.uppercased(), systemImage: "globe")
                        }
                        Spacer(minLength: 0)
                    }

                    if !categories.isEmpty {
                        WrapChipsView(chips: categories, maxVisible: 6)
                    } else if let mc = mainCategory?.trimmingCharacters(in: .whitespacesAndNewlines), !mc.isEmpty {
                        HStack {
                            Chip(text: mc, systemImage: "tag")
                            Spacer(minLength: 0)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(14)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var coverView: some View {
        if !coverCandidatesAll.isEmpty {
            CoverCandidatesImage(
                urlStrings: coverCandidatesAll,
                preferredURLString: thumbnailURL,
                contentMode: .fit,
                onResolvedURL: nil
            ) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                BookCoverPlaceholder(cornerRadius: 14)
            }
            .frame(width: 110, height: 165)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            BookCoverPlaceholder(cornerRadius: 14)
                .frame(width: 110, height: 165)
        }
    }

    private var importActionsCard: some View {
        AddBookCard(title: "Import") {
            HStack(spacing: 12) {
                AddBookActionTile(
                    title: "Google Books",
                    subtitle: "Suchen",
                    systemImage: "magnifyingglass"
                ) {
                    pendingScanISBN = nil
                    quickAddActive = false
                    showingImportSheet = true
                }

                AddBookActionTile(
                    title: "ISBN",
                    subtitle: "Scannen",
                    systemImage: "barcode.viewfinder"
                ) {
                    pendingScanISBN = nil
                    showingScannerSheet = true
                }
            }

            Text("Du kannst Titel, Autor und Status vor dem Speichern noch anpassen.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var basicsCard: some View {
        AddBookCard(title: "Details") {
            AddBookTextFieldRow(title: "Titel", systemImage: "textformat", text: $title)
            AddBookTextFieldRow(title: "Autor", systemImage: "person", text: $author)

            VStack(alignment: .leading, spacing: 8) {
                Text("Status")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Status", selection: $status) {
                    ForEach(ReadingStatus.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }

            if status == .finished {
                Divider().opacity(0.6)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Gelesen")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    DatePicker("Von", selection: $readFrom, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .onChange(of: readFrom) { _, newValue in
                            if readTo < newValue { readTo = newValue }
                        }

                    DatePicker("Bis", selection: $readTo, in: readFrom...Date(), displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .onChange(of: readTo) { _, newValue in
                            if newValue < readFrom { readFrom = newValue }
                        }
                }
            }
        }
    }

    private var metadataCard: some View {
        AddBookCard(title: "Metadaten") {
            AddBookSubsection(title: "Bibliografisch") {
                AddBookMetaRow(title: "Verlag", systemImage: "building.2", value: publisher)
                AddBookMetaRow(title: "Erschienen", systemImage: "calendar", value: publishedDate)
                AddBookMetaRow(title: "Seiten", systemImage: "doc.plaintext", value: pageCount.map(String.init))
                AddBookMetaRow(title: "Sprache", systemImage: "globe", value: language?.uppercased())
            }

            if !categories.isEmpty {
                AddBookSubsection(title: "Kategorien") {
                    WrapChipsView(chips: categories, maxVisible: 10)
                }
            } else if let mc = mainCategory?.trimmingCharacters(in: .whitespacesAndNewlines), !mc.isEmpty {
                AddBookSubsection(title: "Kategorie") {
                    HStack {
                        Chip(text: mc, systemImage: "tag")
                        Spacer(minLength: 0)
                    }
                }
            }

            AddBookSubsection(title: "IDs") {
                AddBookMetaRow(title: "ISBN 13", systemImage: "barcode", value: isbn13)
                AddBookMetaRow(title: "Google Volume ID", systemImage: "number", value: googleVolumeID)
            }

            if hasAvailabilityChips {
                AddBookSubsection(title: "Verfügbarkeit") {
                    availabilityChips
                }
            }
        }
    }

    private var hasAvailabilityChips: Bool {
        isEbook || isEpubAvailable || isPdfAvailable || isEmbeddable || isPublicDomain || saleability != nil || viewability != nil
    }

    private var availabilityChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if isEbook {
                    Chip(text: "E-Book", systemImage: "ipad.and.iphone")
                }
                if isEpubAvailable {
                    Chip(text: "EPUB", systemImage: "doc.richtext")
                }
                if isPdfAvailable {
                    Chip(text: "PDF", systemImage: "doc")
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                if isEmbeddable {
                    Chip(text: "Embeddable", systemImage: "checkmark.seal")
                }
                if isPublicDomain {
                    Chip(text: "Public Domain", systemImage: "globe.europe.africa")
                }
                Spacer(minLength: 0)
            }

            if let s = saleability?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                AddBookMetaRow(title: "Saleability", systemImage: "cart", value: s)
            }

            if let v = viewability?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty {
                AddBookMetaRow(title: "Viewability", systemImage: "eye", value: v)
            }
        }
    }

    private var descriptionCard: some View {
        AddBookCard(title: "Beschreibung") {
            Text(trimmedDescription)
                .foregroundStyle(.secondary)
                .lineLimit(isDescriptionExpanded ? nil : 6)

            if trimmedDescription.count > 240 {
                Button(isDescriptionExpanded ? "Weniger anzeigen" : "Mehr lesen") {
                    withAnimation(.snappy) {
                        isDescriptionExpanded.toggle()
                    }
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var linksCard: some View {
        AddBookCard(title: "Links") {
            if let u = previewURL {
                AddBookLinkRow(title: "Vorschau", systemImage: "play.rectangle", url: u)
            }
            if let u = infoURL {
                AddBookLinkRow(title: "Mehr Infos", systemImage: "safari", url: u)
            }
            if let u = canonicalURL {
                AddBookLinkRow(title: "Google Books", systemImage: "book", url: u)
            }
        }
    }

    private var primaryActionBar: some View {
        VStack(spacing: 10) {
            Divider()

            Button {
                addBook()
                dismiss()
            } label: {
                Label("In Bibliothek aufnehmen", systemImage: "tray.and.arrow.down.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(trimmedTitle.isEmpty)

            if trimmedTitle.isEmpty {
                Text("Titel fehlt noch – ohne Titel landet das Buch sonst als \"Neues Buch\" in deiner Bibliothek. (Und das wäre wirklich… mutig.)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private func publishedYear(from s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        // Accept "YYYY" or "YYYY-MM-DD" or similar.
        if s.count >= 4 {
            let y = String(s.prefix(4))
            if Int(y) != nil { return y }
        }
        return nil
    }

    private func url(from s: String?) -> URL? {
        guard let s else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        return URL(string: t)
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
        modelContext.saveWithDiagnostics()

        // Generate and sync thumbnail cover if we have any cover candidates.
        Task { @MainActor in
            await CoverThumbnailer.backfillThumbnailIfNeeded(for: newBook, modelContext: modelContext)
        }
    }
}

// MARK: - Components

private struct AddBookCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content

    init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(title)
                    .font(.headline)
            }

            content()
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct AddBookActionTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .frame(width: 26)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(subtitle)
                            .font(.subheadline.weight(.semibold))
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct AddBookTextFieldRow: View {
    let title: String
    let systemImage: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                TextField(title, text: $text)
                    .textInputAutocapitalization(.sentences)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

private struct AddBookSubsection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AddBookMetaRow: View {
    let title: String
    let systemImage: String
    let value: String?

    private var trimmedValue: String? {
        guard let value else { return nil }
        let t = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    @ViewBuilder
    var body: some View {
        if let v = trimmedValue {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label(title, systemImage: systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 130, alignment: .leading)

                Text(v)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }
}

private struct AddBookLinkRow: View {
    let title: String
    let systemImage: String
    let url: URL

    private var hostLabel: String {
        url.host ?? url.absoluteString
    }

    var body: some View {
        Link(destination: url) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(hostLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
}


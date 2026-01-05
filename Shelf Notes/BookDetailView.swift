//
//  BookDetailView.swift
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

// MARK: - Detail
struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var book: Book

    @State private var tagsText: String = ""
    @State private var tagDraft: String = ""

    // Cover upload (user photo)
    #if canImport(PhotosUI)
    @State private var pickedCoverItem: PhotosPickerItem?
    #endif
    @State private var isUploadingCover: Bool = false
    @State private var coverUploadError: String? = nil

    // ✅ Collections: Auswahl direkt in den Buchdetails
    @Query(sort: \BookCollection.name, order: .forward)
    private var allCollections: [BookCollection]
    
    // ✅ Für Top-Tags: alle Bücher laden
    @Query private var allBooks: [Book]


    @State private var showingNewCollectionSheet = false
    @State private var showingPaywall = false

    @EnvironmentObject private var pro: ProManager


    // MARK: - Bindings (Compiler-friendly)

    private var statusBinding: Binding<ReadingStatus> {
        Binding(
            get: { book.status },
            set: { newStatus in
                book.status = newStatus

                if newStatus == .finished {
                    if book.readFrom == nil { book.readFrom = Date() }
                    if book.readTo == nil { book.readTo = book.readFrom }
                }
            }
        )
    }

    private func membershipBinding(for col: BookCollection) -> Binding<Bool> {
        Binding(
            get: { book.isInCollection(col) },
            set: { isOn in
                setMembership(isOn, for: col)
            }
        )
    }

    var body: some View {
        Form {
            formContent
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
        .onAppear { tagsText = book.tags.joined(separator: ", "); tagDraft = "" }
        #if canImport(PhotosUI)
        .onChange(of: pickedCoverItem) { _, newValue in
            handlePickedCoverItem(newValue)
        }
        #endif
        .onDisappear { try? modelContext.save() }
    }

    // MARK: - Form content (extracted to help the compiler)

    @ViewBuilder
    private var formContent: some View {
        // MARK: - Overview
        Section("Überblick") {
            HStack(alignment: .top, spacing: 12) {
                cover

                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Ohne Titel" : book.title)
                        .font(.headline)

                    // Untertitel: nur zeigen, wenn vorhanden ODER wenn importiert (damit man ihn leicht ergänzen kann)
                    if shouldShowSubtitleField {
                        let s = (book.subtitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        Text(s.isEmpty ? "—" : s)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }

                    let a = book.author.trimmingCharacters(in: .whitespacesAndNewlines)
                    Text(a.isEmpty ? "—" : a)
                        .foregroundStyle(.secondary)



                    Picker("Status", selection: statusBinding) {
                        ForEach(ReadingStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                }
            }

            // Bewertung: bevorzugt deine Bewertung, sonst Google (falls vorhanden)
            if let overall = displayedOverallRating {
                HStack(spacing: 10) {
                    StarsView(rating: overall)

                    Text(displayedOverallRatingText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    if hasUserRating {
                        Text("deins")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                    }

                    Spacer()
                }
                .padding(.top, 6)
            }

            // ✅ Deine Bewertung (nur möglich wenn Status = „Gelesen“)
            if book.status == .finished {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Deine Bewertung")
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        if hasAnyUserRatingValue {
                            Button("Zurücksetzen") {
                                resetUserRating()
                            }
                            .font(.caption)
                        }
                    }

                    UserRatingRow(
                        title: "Handlung",
                        subtitle: "Originell, logisch, Tempo, Wendungen",
                        rating: $book.userRatingPlot
                    ) { try? modelContext.save() }

                    UserRatingRow(
                        title: "Charaktere",
                        subtitle: "Glaubwürdig & identifizierbar",
                        rating: $book.userRatingCharacters
                    ) { try? modelContext.save() }

                    UserRatingRow(
                        title: "Schreibstil",
                        subtitle: "Sprache, Rhythmus, Flow",
                        rating: $book.userRatingWritingStyle
                    ) { try? modelContext.save() }

                    UserRatingRow(
                        title: "Atmosphäre",
                        subtitle: "Welt & emotionale Wirkung",
                        rating: $book.userRatingAtmosphere
                    ) { try? modelContext.save() }

                    UserRatingRow(
                        title: "Genre-Fit",
                        subtitle: "Erwartungen ans Genre erfüllt?",
                        rating: $book.userRatingGenreFit
                    ) { try? modelContext.save() }

                    UserRatingRow(
                        title: "Aufmachung",
                        subtitle: "Cover/Design/Optik",
                        rating: $book.userRatingPresentation
                    ) { try? modelContext.save() }

                    HStack(spacing: 10) {
                        Text("Gesamt")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        if let avg = book.userRatingAverage1 {
                            StarsView(rating: avg)

                            Text(String(format: "%.1f", avg) + " / 5")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        } else {
                            Text("Noch nicht bewertet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 6)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal")
                        .foregroundStyle(.secondary)
                    Text("Bewertungen sind erst möglich, wenn der Status auf „Gelesen“ steht.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.top, 6)
            }
        }

        // MARK: - Cover (Upload/Fallback)
        Section("Cover") {
            #if canImport(PhotosUI)
            PhotosPicker(selection: $pickedCoverItem, matching: .images) {
                Label(isUploadingCover ? "Lade …" : "Cover aus Fotos wählen", systemImage: "photo")
            }
            .disabled(isUploadingCover)
            #else
            Text("Cover-Upload ist auf dieser Plattform nicht verfügbar.")
                .foregroundStyle(.secondary)
            #endif

            if book.userCoverFileName != nil {
                Button(role: .destructive) {
                    removeUserCover()
                } label: {
                    Label("Benutzer-Cover entfernen", systemImage: "trash")
                }
            }

            if let coverUploadError {
                Text(coverUploadError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Text("Tipp: Wenn Google Books und OpenLibrary kein Cover liefern, kannst du hier eins aus deinen Fotos wählen.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
                                        guard !isSame else { return }

                                        // User intent here is: "use this online cover".
                                        Task { @MainActor in
                                            await CoverThumbnailer.applyRemoteCover(urlString: s, to: book, modelContext: modelContext)
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
                    Toggle(isOn: membershipBinding(for: col)) {
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
            VStack(alignment: .leading, spacing: 10) {
                // Selected tags show up as pills (instead of plain comma text).
                if !book.tags.isEmpty {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 92), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(book.tags, id: \.self) { t in
                            SelectedTagPill(text: t) {
                                removeTag(t)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                TextField("Tag hinzufügen …", text: $tagDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { addTagsFromDraft() }
                    .onChange(of: tagDraft) { _, newValue in
                        // If user types commas, treat it as "commit".
                        if newValue.contains(",") {
                            addTagsFromDraft()
                        }
                    }

                Text("Tipp: Tippe unten auf ein häufiges Tag – oder schreibe ein neues und bestätige mit Return oder Komma.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !topTagCounts30.isEmpty {
                Text("Häufige Tags (Tippen = hinzufügen/entfernen)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 92), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(topTagCounts30, id: \.tag) { entry in
                        TagPickPill(
                            text: entry.tag,
                            count: entry.count,
                            isSelected: isTagSelected(entry.tag),
                            onTap: { toggleTag(entry.tag) }
                        )
                    }
                }
                .padding(.vertical, 4)
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


    private var hasUserRating: Bool {
        book.userRatingAverage != nil
    }

    private var hasAnyUserRatingValue: Bool {
        book.userRatingValues.contains(where: { $0 > 0 })
    }

    private var displayedOverallRating: Double? {
        if let u = book.userRatingAverage1 { return u }
        if let g = book.averageRating, g > 0 { return g }
        return nil
    }

    private var displayedOverallRatingText: String {
        if let u = book.userRatingAverage1 {
            return String(format: "%.1f", u) + " / 5"
        }
        return ratingText
    }

    private func resetUserRating() {
        book.userRatingPlot = 0
        book.userRatingCharacters = 0
        book.userRatingWritingStyle = 0
        book.userRatingAtmosphere = 0
        book.userRatingGenreFit = 0
        book.userRatingPresentation = 0
        try? modelContext.save()
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

    // MARK: - Cover upload helpers

    #if canImport(PhotosUI)
    private func handlePickedCoverItem(_ item: PhotosPickerItem?) {
        guard let item else { return }

        isUploadingCover = true
        coverUploadError = nil

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw NSError(domain: "CoverUpload", code: 1, userInfo: [NSLocalizedDescriptionKey: "Konnte Bilddaten nicht laden."])
                }

                // Saves full-res locally + sets synced thumbnail (`book.userCoverData`).
                try await CoverThumbnailer.applyUserPickedCover(imageData: data, to: book, modelContext: modelContext)
            } catch {
                await MainActor.run {
                    coverUploadError = error.localizedDescription
                }
            }

            await MainActor.run {
                isUploadingCover = false
                pickedCoverItem = nil
            }
        }
    }
    #endif

    private func removeUserCover() {
        if let old = book.userCoverFileName {
            UserCoverStore.delete(filename: old)
        }
        book.userCoverFileName = nil
        book.userCoverData = nil
        try? modelContext.save()

        // Re-populate from remote candidates if available (so the cover doesn't turn blank).
        Task { @MainActor in
            await CoverThumbnailer.backfillThumbnailIfNeeded(for: book, modelContext: modelContext)
        }
    }


    // MARK: - Existing helpers

    @ViewBuilder
    private var cover: some View {
        BookCoverThumbnailView(
            book: book,
            size: CGSize(width: 70, height: 105),
            cornerRadius: 10
        )
    }
    
    private var topTagCounts30: [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]

        for b in allBooks {
            for t in b.tags {
                let n = normalizeTagString(t)
                guard !n.isEmpty else { continue }
                counts[n, default: 0] += 1
            }
        }

        let sorted = counts
            .map { (tag: $0.key, count: $0.value) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.tag.localizedCaseInsensitiveCompare(b.tag) == .orderedAscending
            }

        return Array(sorted.prefix(30))
    }

    private func isTagSelected(_ tag: String) -> Bool {
        let n = normalizeTagString(tag)
        return book.tags.contains { normalizeTagString($0).caseInsensitiveCompare(n) == .orderedSame }
    }

    private func toggleTag(_ tag: String) {
        let n = normalizeTagString(tag)
        guard !n.isEmpty else { return }

        var current = book.tags.map(normalizeTagString).filter { !$0.isEmpty }

        if let idx = current.firstIndex(where: { $0.caseInsensitiveCompare(n) == .orderedSame }) {
            current.remove(at: idx)
        } else {
            current.append(n)
        }

        // dedupe case-insensitive, preserve order
        var out: [String] = []
        for t in current {
            if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                out.append(t)
            }
        }

        book.tags = out
        tagsText = out.joined(separator: ", ")
        try? modelContext.save()
    }

private func addTagsFromDraft() {
    // Allows typing: "thriller, nyc" + return/comma
    let parts = tagDraft
        .split(separator: ",")
        .map { normalizeTagString(String($0)) }
        .filter { !$0.isEmpty }

    // Also allow "single tag + return" without comma
    let single = normalizeTagString(tagDraft)
    let candidates = parts.isEmpty ? ([single].filter { !$0.isEmpty }) : parts

    guard !candidates.isEmpty else {
        tagDraft = ""
        return
    }

    var current = book.tags.map(normalizeTagString).filter { !$0.isEmpty }

    for p in candidates {
        if !current.contains(where: { $0.caseInsensitiveCompare(p) == .orderedSame }) {
            current.append(p)
        }
    }

    // Dedup case-insensitive, preserve order
    var out: [String] = []
    for t in current {
        if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
            out.append(t)
        }
    }

    book.tags = out
    tagsText = out.joined(separator: ", ")
    tagDraft = ""
    try? modelContext.save()
}

private func removeTag(_ tag: String) {
    let n = normalizeTagString(tag)
    guard !n.isEmpty else { return }

    var current = book.tags.map(normalizeTagString).filter { !$0.isEmpty }
    current.removeAll { $0.caseInsensitiveCompare(n) == .orderedSame }

    // Dedup case-insensitive, preserve order
    var out: [String] = []
    for t in current {
        if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
            out.append(t)
        }
    }

    book.tags = out
    tagsText = out.joined(separator: ", ")
    try? modelContext.save()
}


    private func parseTags(_ input: String) -> [String] {
        let raw = input
            .split(separator: ",")
            .map { normalizeTagString(String($0)) }
            .filter { !$0.isEmpty }

        var out: [String] = []
        for t in raw {
            if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                out.append(t)
            }
        }
        return out
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



private struct StarRatingPicker: View {
    @Binding var rating: Int
    var onChange: (() -> Void)? = nil

    private let maxStars: Int = 5

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...maxStars, id: \.self) { i in
                Button {
                    // Tap same star again -> clear (0)
                    if rating == i {
                        rating = 0
                    } else {
                        rating = i
                    }
                    onChange?()
                } label: {
                    Image(systemName: i <= rating ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(i <= rating ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Bewertung \(i) von \(maxStars)")
            }
        }
    }
}

private struct UserRatingRow: View {
    let title: String
    let subtitle: String
    @Binding var rating: Int
    let onChange: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            StarRatingPicker(rating: $rating, onChange: onChange)
                .accessibilityLabel(title)
        }
        .contentShape(Rectangle())
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
                CachedAsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    BookCoverPlaceholder(cornerRadius: 10)
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

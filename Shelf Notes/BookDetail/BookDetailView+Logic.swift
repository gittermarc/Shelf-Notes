import SwiftUI
import SwiftData

#if canImport(PhotosUI)
import PhotosUI
#endif

// MARK: - Bindings + Logic
extension BookDetailView {

    // MARK: Bindings (Compiler-friendly)

    var statusBinding: Binding<ReadingStatus> {
        Binding(
            get: { book.status },
            set: { newStatus in
                book.status = newStatus

                if newStatus == .finished {
                    if book.readFrom == nil { book.readFrom = Date() }
                    if book.readTo == nil { book.readTo = book.readFrom }
                }
                _ = modelContext.saveWithDiagnostics()
            }
        )
    }

    func membershipBinding(for col: BookCollection) -> Binding<Bool> {
        Binding(
            get: { book.isInCollection(col) },
            set: { isOn in
                setMembership(isOn, for: col)
            }
        )
    }

    // MARK: - Bibliophile computed properties

    var hasAnyLinks: Bool {
        (book.previewLink?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        || (book.infoLink?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        || (book.canonicalVolumeLink?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    }

    var hasAnyAvailability: Bool {
        (book.viewability?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        || book.isPublicDomain
        || book.isEmbeddable
        || book.isEpubAvailable
        || book.isPdfAvailable
        || (book.saleability?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        || book.isEbook
    }

    var hasRating: Bool {
        if let avg = book.averageRating, avg > 0 { return true }
        return false
    }

    var ratingText: String {
        let avg = book.averageRating ?? 0
        let count = book.ratingsCount ?? 0
        if count > 0 {
            return String(format: "%.1f", avg) + " (\(count))"
        }
        return String(format: "%.1f", avg)
    }

    var hasUserRating: Bool {
        book.userRatingAverage != nil
    }

    var hasAnyUserRatingValue: Bool {
        book.userRatingValues.contains(where: { $0 > 0 })
    }

    var displayedOverallRating: Double? {
        if let u = book.userRatingAverage1 { return u }
        if let g = book.averageRating, g > 0 { return g }
        return nil
    }

    var displayedOverallRatingText: String {
        if let u = book.userRatingAverage1 {
            return String(format: "%.1f", u) + " / 5"
        }
        return ratingText
    }

    func resetUserRating() {
        book.userRatingPlot = 0
        book.userRatingCharacters = 0
        book.userRatingWritingStyle = 0
        book.userRatingAtmosphere = 0
        book.userRatingGenreFit = 0
        book.userRatingPresentation = 0
        _ = modelContext.saveWithDiagnostics()
    }

    var prettyViewability: String? {
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

    var prettySaleability: String? {
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

    var hasAnyBibliophileInfo: Bool {
        hasAnyLinks || hasAnyAvailability || hasRating || !book.coverURLCandidates.isEmpty
    }

    // MARK: - More Info blocks

    var bibliophileBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasAnyLinks {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        if let url = urlFromString(book.previewLink) {
                            PrettyLinkRow(title: "Leseprobe / Vorschau", url: url, systemImage: "book.pages")
                        }
                        if let url = urlFromString(book.infoLink) {
                            PrettyLinkRow(title: "Info-Seite", url: url, systemImage: "info.circle")
                        }
                        if let url = urlFromString(book.canonicalVolumeLink) {
                            PrettyLinkRow(title: "Original bei Google Books", url: url, systemImage: "link")
                        }
                    }
                } label: {
                    Label("Online ansehen", systemImage: "safari")
                }
            }

            if hasAnyAvailability {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        if let viewability = prettyViewability {
                            LabeledContent("Vorschauumfang", value: viewability)
                        }

                        LabeledContent("EPUB") { availabilityLabel(book.isEpubAvailable) }
                        LabeledContent("PDF") { availabilityLabel(book.isPdfAvailable) }

                        if let sale = prettySaleability {
                            LabeledContent("Kaufstatus", value: sale)
                        }

                        LabeledContent("E-Book") { boolLabel(book.isEbook, trueText: "Ja", falseText: "Nein") }
                        LabeledContent("Einbettbar") { boolIcon(book.isEmbeddable) }
                        LabeledContent("Public Domain") { boolIcon(book.isPublicDomain) }
                    }
                } label: {
                    Label("Formate & Verfügbarkeit", systemImage: "doc.on.doc")
                }
            }

            if hasRating {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
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
                    }
                } label: {
                    Label("Google-Bewertungen", systemImage: "star.bubble")
                }
            }

            if !book.coverURLCandidates.isEmpty {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 10) {
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
                    }
                } label: {
                    Label("Cover auswählen", systemImage: "photo.on.rectangle")
                }
            }
        }
    }

    var metadataBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Metadaten")
                .font(.subheadline.weight(.semibold))

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
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var descriptionBlock: some View {
        let desc = book.bookDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .leading, spacing: 10) {
            if !desc.isEmpty {
                Text("Beschreibung")
                    .font(.subheadline.weight(.semibold))

                Text(desc)
                    .foregroundStyle(.secondary)
                    .lineLimit(isDescriptionExpanded ? nil : 6)

                Button(isDescriptionExpanded ? "Weniger" : "Mehr anzeigen") {
                    withAnimation(.snappy) { isDescriptionExpanded.toggle() }
                }
                .font(.caption.weight(.semibold))
            }
        }
    }

    // MARK: - Cover upload helpers

    #if canImport(PhotosUI)
    func handlePickedCoverItem(_ item: PhotosPickerItem?) {
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

    func removeUserCover() {
        if let old = book.userCoverFileName {
            UserCoverStore.delete(filename: old)
        }
        book.userCoverFileName = nil
        book.userCoverData = nil
        _ = modelContext.saveWithDiagnostics()

        Task { @MainActor in
            await CoverThumbnailer.backfillThumbnailIfNeeded(for: book, modelContext: modelContext)
        }
    }

    // MARK: - Delete

    func deleteBook() {
        // Clean up local user cover file if any
        if let old = book.userCoverFileName {
            UserCoverStore.delete(filename: old)
        }

        modelContext.delete(book)
        _ = modelContext.saveWithDiagnostics()
        dismiss()
    }

    // MARK: - Tags

    /// Alle bekannten Tags (case-insensitive dedupliziert) mit Nutzungsanzahl,
    /// sortiert nach Häufigkeit (desc) und Name (asc).
    private var tagCountsSorted: [(tag: String, count: Int)] {
        var counts: [String: (display: String, count: Int)] = [:]

        for b in allBooks {
            for t in b.tags {
                let n = normalizeTagString(t)
                let key = n.lowercased()
                guard !key.isEmpty else { continue }

                if var existing = counts[key] {
                    existing.count += 1
                    counts[key] = existing
                } else {
                    counts[key] = (display: n, count: 1)
                }
            }
        }

        return counts
            .values
            .map { (tag: $0.display, count: $0.count) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.tag.localizedCaseInsensitiveCompare(b.tag) == .orderedAscending
            }
    }

    /// Query-String für Autocomplete (aktueller Text im Tag-Field).
    private var tagDraftQuery: String {
        normalizeTagString(tagDraft)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Vorschläge passend zur aktuellen Eingabe.
    /// - Priorität: Prefix-Matches vor Contains-Matches.
    /// - Excludes: Tags, die am Buch bereits gesetzt sind.
    var tagAutocompleteSuggestions: [String] {
        let q = tagDraftQuery.lowercased()
        guard !q.isEmpty else { return [] }

        let selected = Set(book.tags.map { normalizeTagString($0).lowercased() })
        let ordered = tagCountsSorted.filter { !selected.contains($0.tag.lowercased()) }

        let prefix = ordered.filter { $0.tag.lowercased().hasPrefix(q) }
        let contains = ordered.filter {
            let low = $0.tag.lowercased()
            return !low.hasPrefix(q) && low.contains(q)
        }

        return Array((prefix + contains).prefix(8)).map { $0.tag }
    }

    var topTagCounts30: [(tag: String, count: Int)] {
        Array(tagCountsSorted.prefix(30))
    }

    func isTagSelected(_ tag: String) -> Bool {
        let n = normalizeTagString(tag)
        return book.tags.contains { normalizeTagString($0).caseInsensitiveCompare(n) == .orderedSame }
    }

    func toggleTag(_ tag: String) {
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
        _ = modelContext.saveWithDiagnostics()
    }

    func addTagsFromDraft() {
        let parts = tagDraft
            .split(separator: ",")
            .map { normalizeTagString(String($0)) }
            .filter { !$0.isEmpty }

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

        var out: [String] = []
        for t in current {
            if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                out.append(t)
            }
        }

        book.tags = out
        tagsText = out.joined(separator: ", ")
        tagDraft = ""
        _ = modelContext.saveWithDiagnostics()
    }

    func acceptTagSuggestion(_ suggestion: String) {
        let n = normalizeTagString(suggestion)
        guard !n.isEmpty else { return }

        var current = book.tags.map(normalizeTagString).filter { !$0.isEmpty }
        if !current.contains(where: { $0.caseInsensitiveCompare(n) == .orderedSame }) {
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
        tagDraft = ""
        _ = modelContext.saveWithDiagnostics()
    }

    func removeTag(_ tag: String) {
        let n = normalizeTagString(tag)
        guard !n.isEmpty else { return }

        var current = book.tags.map(normalizeTagString).filter { !$0.isEmpty }
        current.removeAll { $0.caseInsensitiveCompare(n) == .orderedSame }

        var out: [String] = []
        for t in current {
            if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                out.append(t)
            }
        }

        book.tags = out
        tagsText = out.joined(separator: ", ")
        _ = modelContext.saveWithDiagnostics()
    }

    func parseTags(_ input: String) -> [String] {
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

    // MARK: - Read range

    func formattedReadRangeLine(from: Date?, to: Date?) -> String? {
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

    // MARK: - Collections helpers

    func requestNewCollection() {
        let count = allCollections.count
        if pro.hasPro || count < ProManager.maxFreeCollections {
            showingNewCollectionSheet = true
        } else {
            showingPaywall = true
        }
    }

    func setMembership(_ isMember: Bool, for collection: BookCollection) {
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

        _ = modelContext.saveWithDiagnostics()
    }

    func createAndAttachCollection(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let existing = allCollections.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            setMembership(true, for: existing)
            return
        }

        let newCol = BookCollection(name: trimmed)
        modelContext.insert(newCol)
        setMembership(true, for: newCol)
    }

    // MARK: - Small helpers

    func urlFromString(_ s: String?) -> URL? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty else { return nil }
        return URL(string: s)
    }

    func availabilityLabel(_ ok: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(ok ? .green : .secondary)
            Text(ok ? "verfügbar" : "nicht verfügbar")
                .foregroundStyle(.secondary)
        }
    }

    func boolIcon(_ ok: Bool) -> some View {
        Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle")
            .foregroundStyle(ok ? .green : .secondary)
    }

    func boolLabel(_ ok: Bool, trueText: String, falseText: String) -> some View {
        Text(ok ? trueText : falseText)
            .foregroundStyle(.secondary)
    }
}

import SwiftUI
import SwiftData

// MARK: - Bindings + Derived State
extension BookDetailView {

    // MARK: Bindings (compiler-friendly)

    var statusBinding: Binding<ReadingStatus> {
        Binding(
            get: { book.status },
            set: { newStatus in
                book.status = newStatus

                if newStatus == .finished {
                    if book.readFrom == nil { book.readFrom = Date() }
                    if book.readTo == nil { book.readTo = book.readFrom }
                }
                _ = saveDetail()
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

    var notesMetrics: BookNotesMetrics {
        BookNotesMetrics(text: book.notes)
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

    // MARK: - Tags (derived data)

    /// Cached tag counts for the whole library.
    ///
    /// Backed by the central `TagsIndexStore` so we don't run O(n·tags) aggregation during render.
    private var cachedTagCountsSorted: [TagsIndexStore.TagCount] {
        tagsIndexStore.tagCounts
    }

    /// Query-String für Autocomplete (aktueller Text im Tag-Field).
    var tagDraftQuery: String {
        normalizeTagString(tagDraft)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var tagSuggestionsDomainIndex: TagsDomainIndex {
        TagsDomainIndex(
            suggestionSnapshots: TagSuggestionEngine.makeSnapshots(books: allBooks)
        )
    }

    /// Vorschläge passend zur aktuellen Eingabe.
    /// - Priorität: Prefix-Matches vor Contains-Matches.
    /// - Excludes: Tags, die am Buch bereits gesetzt sind.
    var tagAutocompleteSuggestions: [String] {
        tagAutocompleteSuggestions(domainIndex: tagSuggestionsDomainIndex)
    }

    func tagAutocompleteSuggestions(domainIndex: TagsDomainIndex) -> [String] {
        domainIndex.autocompleteSuggestions(
            query: tagDraftQuery,
            selectedTags: book.tags
        )
    }

    var topTagCounts30: [(tag: String, count: Int)] {
        cachedTagCountsSorted
            .prefix(30)
            .map { (tag: $0.tag, count: $0.count) }
    }

    var tagSuggestionViewState: TagSuggestionViewState {
        tagSuggestionViewState(
            target: TagSuggestionEngine.makeSnapshot(book: book),
            domainIndex: tagSuggestionsDomainIndex
        )
    }

    func tagSuggestionViewState(
        target: TagSuggestionBookSnapshot,
        domainIndex: TagsDomainIndex
    ) -> TagSuggestionViewState {
        TagSuggestionViewStateBuilder.make(
            target: target,
            domainIndex: domainIndex,
            selectedTags: book.tags,
            suggestionLimit: 8,
            smartLimit: 6,
            frequentLimit: 18
        )
    }

    var smartTagSuggestionItems: [TagSuggestionDisplayItem] {
        tagSuggestionViewState.smartItems
    }

    var frequentTagItems: [FrequentTagDisplayItem] {
        tagSuggestionViewState.frequentItems
    }

    func isTagSelected(_ tag: String) -> Bool {
        let n = normalizeTagString(tag)
        return book.tags.contains { normalizeTagString($0).caseInsensitiveCompare(n) == .orderedSame }
    }

    func parseTags(_ input: String) -> [String] {
        TagsIndexBuilder.parsedTags(from: input)
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

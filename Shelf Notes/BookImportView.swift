//
//  BookImportView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//

import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

struct ImportedBook {
    let googleVolumeID: String
    let title: String
    let author: String
    let isbn13: String?

    /// Primary cover used across the app
    let thumbnailURL: String?

    let publisher: String?
    let publishedDate: String?
    let pageCount: Int?
    let language: String?
    let categories: [String]
    let description: String

    // ✅ New rich metadata
    let subtitle: String?
    let previewLink: String?
    let infoLink: String?
    let canonicalVolumeLink: String?

    let averageRating: Double?
    let ratingsCount: Int?
    let mainCategory: String?

    let coverURLCandidates: [String]

    let viewability: String?
    let isPublicDomain: Bool
    let isEmbeddable: Bool

    let isEpubAvailable: Bool
    let isPdfAvailable: Bool
    let epubAcsTokenLink: String?
    let pdfAcsTokenLink: String?

    let saleability: String?
    let isEbook: Bool
}

struct BookImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var existingBooks: [Book]

    let onPick: (ImportedBook) -> Void

    // ✅ Neu: Vorbelegung der Suche (z.B. ISBN aus Barcode-Scan)
    var initialQuery: String? = nil
    var autoSearchOnAppear: Bool = true

    /// Legacy: einmalig beim ersten Quick-Add (kannst du weiter nutzen)
    var onQuickAddHappened: (() -> Void)? = nil

    /// Neu: true sobald in dieser Session mindestens 1 Quick-Add existiert (und wieder false, wenn alles rückgängig gemacht wurde)
    var onQuickAddActiveChanged: ((Bool) -> Void)? = nil

    // Persisted search history (simple JSON array of strings)
    @AppStorage("gb_search_history_json") private var historyJSON: String = "[]"

    @State private var queryText: String = ""
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?

    // We keep fetched unfiltered results, and derive displayed results via local quality filters.
    @State private var fetchedVolumes: [GoogleBookVolume] = []
    @State private var results: [GoogleBookVolume] = []

    // Pagination / "mehr Ergebnisse" (Google Books: max 40 pro Request)
    @State private var activeQuery: String = ""
    @State private var totalItems: Int = 0
    @State private var nextStartIndex: Int = 0
    @State private var didReachEnd: Bool = false

    // Prevent repeated infinite-scroll triggers for the same bottom item
    @State private var lastInfiniteTriggerID: String?

    @FocusState private var searchFocused: Bool

    private let maxHistoryItems = 10
    private let pageSize = 40

    // Filter / Qualität
    @State private var showFilters: Bool = false

    // API-side filters
    @State private var language: LanguageOption = .any
    @State private var orderBy: GoogleBooksOrderBy = .relevance
    @State private var apiFilter: GoogleBooksFilter = .none

    // Local "quality" filters
    @State private var onlyWithCover: Bool = false
    @State private var onlyWithISBN: Bool = false
    @State private var hideAlreadyInLibrary: Bool = false

    // Local UI: what was added during this session (fast feedback)
    @State private var addedVolumeIDs: Set<String> = []
    @State private var didTriggerQuickAddCallback = false

    // Undo / Snackbar
    private struct UndoPayload: Identifiable, Equatable {
        let id = UUID()
        let bookID: UUID
        let volumeID: String
        let title: String
        let status: ReadingStatus
        let thumbnailURL: String?
    }

    @State private var undoPayload: UndoPayload?
    @State private var undoHideTask: Task<Void, Never>?
    @State private var sessionQuickAddCount: Int = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 12) {
                        searchSection

                        if isLoading {
                            ProgressView("Suche läuft …")
                                .padding(.top, 4)
                        }

                        if let errorMessage {
                            errorCard(errorMessage)
                        }

                        if results.isEmpty, !isLoading, errorMessage == nil {
                            emptyState
                                .padding(.top, 8)
                        } else {
                            if !results.isEmpty {
                                resultsMeta
                                    .padding(.top, 6)
                            }
                            resultsList
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }

                if let payload = undoPayload {
                    UndoToastView(
                        title: payload.title,
                        status: payload.status,
                        thumbnailURL: payload.thumbnailURL,
                        onUndo: {
                            Task { await undoLastAdd(payload) }
                        },
                        onDismiss: {
                            hideUndo()
                        }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Google Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .onAppear {
                // 1) Wenn initialQuery da ist und das Feld leer ist: setzen und sofort suchen
                if autoSearchOnAppear,
                   let initialQuery,
                   !initialQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {

                    queryText = initialQuery
                    Task { await search() }
                    return
                }

                // 2) Sonst: wie bisher Fokus auf Suche
                if queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        searchFocused = true
                    }
                }
            }
            .onDisappear {
                undoHideTask?.cancel()
                undoHideTask = nil
            }
            // Re-apply local filters immediately (no new API call required)
            .onChange(of: onlyWithCover) { _, _ in applyLocalFilters() }
            .onChange(of: onlyWithISBN) { _, _ in applyLocalFilters() }
            .onChange(of: hideAlreadyInLibrary) { _, _ in applyLocalFilters() }
            // API-side filters: new search (because server-side results should change)
            .onChange(of: language) { _, _ in
                guard !activeQuery.isEmpty else { return }
                Task { await search() }
            }
            .onChange(of: orderBy) { _, _ in
                guard !activeQuery.isEmpty else { return }
                Task { await search() }
            }
            .onChange(of: apiFilter) { _, _ in
                guard !activeQuery.isEmpty else { return }
                Task { await search() }
            }
        }
    }

    // MARK: - UI

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suche nach Titel, Autor oder ISBN")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            searchBar

            filtersSection

            if !history.isEmpty {
                historyChips
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Titel, Autor oder ISBN …", text: $queryText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .focused($searchFocused)
                    .onSubmit { Task { await search() } }

                if !queryText.isEmpty {
                    Button {
                        queryText = ""
                        errorMessage = nil

                        fetchedVolumes = []
                        results = []

                        // Reset paging
                        activeQuery = ""
                        totalItems = 0
                        nextStartIndex = 0
                        didReachEnd = false
                        isLoadingMore = false
                        lastInfiniteTriggerID = nil

                        searchFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Suche löschen")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Button {
                Task { await search() }
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
            }
            .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading || isLoadingMore)
            .buttonStyle(.plain)
            .accessibilityLabel("Suchen")
        }
    }

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy) { showFilters.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("Filter & Qualität")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: showFilters ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if showFilters {
                VStack(alignment: .leading, spacing: 12) {
                    // API filters
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Filter (Google)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            Picker("Sprache", selection: $language) {
                                ForEach(LanguageOption.allCases) { opt in
                                    Text(opt.title).tag(opt)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Sortierung", selection: $orderBy) {
                                ForEach(GoogleBooksOrderBy.allCases) { opt in
                                    Text(opt.title).tag(opt)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Typ", selection: $apiFilter) {
                                ForEach(GoogleBooksFilter.allCases) { opt in
                                    Text(opt.title).tag(opt)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    Divider()

                    // Local quality filters
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Qualität (lokal)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Toggle("Nur mit Cover", isOn: $onlyWithCover)
                        Toggle("Nur mit ISBN", isOn: $onlyWithISBN)
                        Toggle("Bereits in Bibliothek ausblenden", isOn: $hideAlreadyInLibrary)
                    }
                    .font(.subheadline)
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var historyChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Letzte Suchen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Löschen") { clearHistory() }
                    .font(.caption)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(history, id: \.self) { term in
                        Button {
                            queryText = term
                            Task { await search() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(term)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var resultsList: some View {
        LazyVStack(spacing: 10) {
            ForEach(results) { volume in
                let already = isAlreadyAdded(volume)
                ResultCard(
                    volume: volume,
                    isAlreadyInLibrary: already,
                    onDetails: { pick(volume) },
                    onQuickAdd: { status in
                        Task { await quickAdd(volume, status: status) }
                    }
                )
                .onAppear {
                    // ✅ Robust Infinite Scroll: trigger when the last *visible* item appears.
                    guard errorMessage == nil else { return }
                    guard shouldShowLoadMore else { return }
                    guard !isLoading, !isLoadingMore else { return }

                    guard let lastID = results.last?.id else { return }
                    guard volume.id == lastID else { return }

                    // prevent duplicate triggers for same last item
                    if lastInfiniteTriggerID == lastID { return }
                    lastInfiniteTriggerID = lastID

                    Task { await loadMore() }
                }
            }

            if shouldShowLoadMore {
                loadMoreRow
                    .padding(.top, 6)
            }
        }
    }

    private var resultsMeta: some View {
        HStack(spacing: 8) {
            let totalText = totalItems > 0 ? " von \(totalItems)" : ""
            Text("Zeige \(results.count)\(totalText) Ergebnisse")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var shouldShowLoadMore: Bool {
        guard !isLoading else { return false }
        guard !didReachEnd else { return false }
        guard !activeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        if totalItems > 0 {
            // Next page exists if nextStartIndex is still before total.
            return nextStartIndex < totalItems
        }

        // If totalItems unknown, continue until API returns empty page and sets didReachEnd.
        return true
    }

    private var loadMoreRow: some View {
        HStack {
            Spacer()
            if isLoadingMore {
                ProgressView()
                    .padding(.vertical, 10)
            } else {
                Button {
                    Task { await loadMore() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                        Text("Mehr laden")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "books.vertical")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)

            Text(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Starte eine Suche" : "Keine Treffer")
                .font(.headline)

            Text(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                 ? "Gib z.B. „Stephen King“ oder eine ISBN ein."
                 : "Versuch’s mit einem anderen Begriff oder nur dem Nachnamen.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Fehler")
                    .font(.headline)
            }
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Search

    private enum LanguageOption: String, CaseIterable, Identifiable {
        case any
        case de
        case en
        case fr
        case es
        case it

        var id: String { rawValue }

        var title: String {
            switch self {
            case .any: return "Alle Sprachen"
            case .de: return "Deutsch"
            case .en: return "Englisch"
            case .fr: return "Französisch"
            case .es: return "Spanisch"
            case .it: return "Italienisch"
            }
        }

        var apiValue: String? {
            switch self {
            case .any: return nil
            default: return rawValue
            }
        }
    }

    private func normalizedQuery(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isNumber)
        if digits.count == 10 || digits.count == 13 {
            return "isbn:\(digits)"
        }
        return trimmed
    }

    private func search() async {
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        addToHistory(trimmed)

        // Freeze query for paging (user may edit the text field while results are on screen)
        let normalized = normalizedQuery(trimmed)

        await MainActor.run {
            errorMessage = nil
            fetchedVolumes = []
            results = []
            isLoading = true

            // Reset paging
            activeQuery = normalized
            totalItems = 0
            nextStartIndex = 0
            didReachEnd = false
            isLoadingMore = false
            lastInfiniteTriggerID = nil
        }

        await fetchPage(startIndex: 0, append: false)
    }

    private func loadMore() async {
        guard shouldShowLoadMore else { return }
        guard !isLoadingMore, !isLoading else { return }

        await MainActor.run {
            isLoadingMore = true
            errorMessage = nil
        }

        await fetchPage(startIndex: nextStartIndex, append: true)

        await MainActor.run {
            isLoadingMore = false
        }
    }

    private func currentQueryOptions() -> GoogleBooksQueryOptions {
        var opt = GoogleBooksQueryOptions.default
        opt.langRestrict = language.apiValue
        opt.orderBy = orderBy
        opt.filter = apiFilter
        opt.projection = .lite
        return opt
    }

    private func fetchPage(startIndex: Int, append: Bool) async {
        do {
            let res = try await GoogleBooksClient.shared.searchVolumesWithDebug(
                query: activeQuery,
                startIndex: startIndex,
                maxResults: pageSize,
                options: currentQueryOptions()
            )

            await MainActor.run {
                totalItems = res.totalItems

                // Merge fetched (defensive against duplicates across pages)
                if append {
                    var existing = Set(fetchedVolumes.map { $0.id })
                    let newOnes = res.volumes.filter { existing.insert($0.id).inserted }
                    fetchedVolumes.append(contentsOf: newOnes)
                } else {
                    fetchedVolumes = res.volumes
                }

                applyLocalFilters()

                // ✅ IMPORTANT: advance based on what the API actually returned.
                // This prevents skipping and avoids falsely concluding "end reached"
                let returnedCount = res.volumes.count
                nextStartIndex = startIndex + returnedCount

                // ✅ Robust end-of-list detection:
                // - if API returns empty page -> end
                // - if totalItems known and we've reached/overrun it -> end
                if returnedCount == 0 {
                    didReachEnd = true
                } else if res.totalItems > 0, nextStartIndex >= res.totalItems {
                    didReachEnd = true
                } else {
                    didReachEnd = false
                }

                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
                // If the *first* page fails, we stop. If a later page fails, allow manual retry.
                if !append { didReachEnd = true }
            }
        }
    }

    private func applyLocalFilters() {
        var filtered = fetchedVolumes

        if onlyWithCover {
            filtered = filtered.filter { vol in
                let cover = vol.bestCoverURLString ?? vol.bestThumbnailURLString
                return (cover?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            }
        }

        if onlyWithISBN {
            filtered = filtered.filter { vol in
                let isbn = vol.isbn13?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return !isbn.isEmpty
            }
        }

        if hideAlreadyInLibrary {
            filtered = filtered.filter { !isAlreadyAdded($0) }
        }

        results = filtered
    }

    // MARK: - Add

    private func isAlreadyAdded(_ volume: GoogleBookVolume) -> Bool {
        if addedVolumeIDs.contains(volume.id) { return true }

        if existingBooks.contains(where: { $0.googleVolumeID == volume.id }) {
            return true
        }

        if let isbn = volume.isbn13,
           existingBooks.contains(where: { ($0.isbn13 ?? "").caseInsensitiveCompare(isbn) == .orderedSame }) {
            return true
        }

        return false
    }

    @MainActor
    private func quickAdd(_ volume: GoogleBookVolume, status: ReadingStatus) async {
        guard !isAlreadyAdded(volume) else { return }

        let info = volume.volumeInfo

        let newBook = Book(
            title: volume.bestTitle,
            author: volume.bestAuthors,
            status: status
        )

        if status == .finished {
            newBook.readFrom = Date()
            newBook.readTo = Date()
        } else {
            newBook.readFrom = nil
            newBook.readTo = nil
        }

        // Existing mappings
        newBook.googleVolumeID = volume.id
        newBook.isbn13 = volume.isbn13

        // Prefer best cover candidate (if your DTO has it), otherwise thumbnail
        let bestCover = (volume.bestCoverURLString ?? volume.bestThumbnailURLString)
        newBook.thumbnailURL = bestCover

        newBook.publisher = info.publisher
        newBook.publishedDate = info.publishedDate
        newBook.pageCount = info.pageCount
        newBook.language = info.language

        // Prefer merged categories (mainCategory + categories) if available
        newBook.categories = volume.allCategories
        newBook.bookDescription = info.description ?? ""

        // ✅ New rich metadata mappings
        newBook.subtitle = volume.bestSubtitle
        newBook.previewLink = volume.previewLink
        newBook.infoLink = volume.infoLink
        newBook.canonicalVolumeLink = volume.canonicalVolumeLink

        newBook.averageRating = volume.averageRating
        newBook.ratingsCount = volume.ratingsCount
        newBook.mainCategory = info.mainCategory

        newBook.coverURLCandidates = volume.coverURLCandidates

        newBook.viewability = volume.viewability
        newBook.isPublicDomain = volume.isPublicDomain
        newBook.isEmbeddable = volume.isEmbeddable

        newBook.isEpubAvailable = volume.isEpubAvailable
        newBook.isPdfAvailable = volume.isPdfAvailable
        newBook.epubAcsTokenLink = volume.epubAcsTokenLink
        newBook.pdfAcsTokenLink = volume.pdfAcsTokenLink

        newBook.saleability = volume.saleability
        newBook.isEbook = volume.isEbook

        modelContext.insert(newBook)
        modelContext.saveWithDiagnostics()

        // Generate a synced thumbnail (so covers work offline + across devices).
        Task { @MainActor in
            await CoverThumbnailer.backfillThumbnailIfNeeded(for: newBook, modelContext: modelContext)
        }

        _ = withAnimation(.snappy) {
            addedVolumeIDs.insert(volume.id)
        }

        sessionQuickAddCount += 1
        onQuickAddActiveChanged?(sessionQuickAddCount > 0)

        if !didTriggerQuickAddCallback {
            didTriggerQuickAddCallback = true
            onQuickAddHappened?()
        }

        showUndo(for: newBook, volumeID: volume.id, status: status)

        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        #endif
    }

    // MARK: - Undo

    @MainActor
    private func showUndo(for book: Book, volumeID: String, status: ReadingStatus) {
        undoHideTask?.cancel()
        undoHideTask = nil

        let payload = UndoPayload(
            bookID: book.id,
            volumeID: volumeID,
            title: book.title.isEmpty ? "Ohne Titel" : book.title,
            status: status,
            thumbnailURL: book.thumbnailURL
        )

        withAnimation(.snappy) {
            undoPayload = payload
        }

        undoHideTask = Task {
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            await MainActor.run {
                guard undoPayload?.id == payload.id else { return }
                withAnimation(.snappy) {
                    undoPayload = nil
                }
            }
        }
    }

    @MainActor
    private func hideUndo() {
        undoHideTask?.cancel()
        undoHideTask = nil
        withAnimation(.snappy) {
            undoPayload = nil
        }
    }

    @MainActor
    private func undoLastAdd(_ payload: UndoPayload) async {
        undoHideTask?.cancel()
        undoHideTask = nil

        withAnimation(.snappy) {
            undoPayload = nil
        }

        // ✅ IMPORTANT: copy to local constant so #Predicate sees a plain UUID constant
        let bookID = payload.bookID

        do {
            let fd = FetchDescriptor<Book>(predicate: #Predicate<Book> { $0.id == bookID })
            if let book = try modelContext.fetch(fd).first {
                modelContext.delete(book)
                modelContext.saveWithDiagnostics()
            }
        } catch {
            // ignore – UI is still consistent
        }

        _ = withAnimation(.snappy) {
            addedVolumeIDs.remove(payload.volumeID)
        }

        if sessionQuickAddCount > 0 { sessionQuickAddCount -= 1 }
        onQuickAddActiveChanged?(sessionQuickAddCount > 0)

        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.warning)
        #endif
    }

    // MARK: - Pick (Detail flow)

    private func pick(_ volume: GoogleBookVolume) {
        let info = volume.volumeInfo

        let bestCover = (volume.bestCoverURLString ?? volume.bestThumbnailURLString)

        let imported = ImportedBook(
            googleVolumeID: volume.id,
            title: volume.bestTitle,
            author: volume.bestAuthors,
            isbn13: volume.isbn13,
            thumbnailURL: bestCover,
            publisher: info.publisher,
            publishedDate: info.publishedDate,
            pageCount: info.pageCount,
            language: info.language,
            categories: volume.allCategories,
            description: info.description ?? "",

            // ✅ New rich metadata
            subtitle: volume.bestSubtitle,
            previewLink: volume.previewLink,
            infoLink: volume.infoLink,
            canonicalVolumeLink: volume.canonicalVolumeLink,
            averageRating: volume.averageRating,
            ratingsCount: volume.ratingsCount,
            mainCategory: info.mainCategory,
            coverURLCandidates: volume.coverURLCandidates,
            viewability: volume.viewability,
            isPublicDomain: volume.isPublicDomain,
            isEmbeddable: volume.isEmbeddable,
            isEpubAvailable: volume.isEpubAvailable,
            isPdfAvailable: volume.isPdfAvailable,
            epubAcsTokenLink: volume.epubAcsTokenLink,
            pdfAcsTokenLink: volume.pdfAcsTokenLink,
            saleability: volume.saleability,
            isEbook: volume.isEbook
        )

        onPick(imported)
        dismiss()
    }

    // MARK: - History persistence

    private var history: [String] {
        guard let data = historyJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }

    private func saveHistory(_ items: [String]) {
        let trimmed = Array(items.prefix(maxHistoryItems))
        if let data = try? JSONEncoder().encode(trimmed),
           let json = String(data: data, encoding: .utf8) {
            historyJSON = json
        }
    }

    private func addToHistory(_ term: String) {
        let normalized = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        var items = history
        items.removeAll { $0.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        items.insert(normalized, at: 0)
        saveHistory(items)
    }

    private func clearHistory() {
        saveHistory([])
    }
}

// MARK: - Result Card UI

private struct ResultCard: View {
    let volume: GoogleBookVolume
    let isAlreadyInLibrary: Bool
    let onDetails: () -> Void
    let onQuickAdd: (ReadingStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onDetails) {
                HStack(alignment: .top, spacing: 12) {
                    cover

                    VStack(alignment: .leading, spacing: 6) {
                        Text(volume.bestTitle)
                            .font(.headline)
                            .lineLimit(2)

                        if !volume.bestAuthors.isEmpty {
                            Text(volume.bestAuthors)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        HStack(spacing: 8) {
                            if let isbn = volume.isbn13 {
                                metaPill(text: "ISBN \(isbn)", systemImage: "barcode")
                            }

                            if let year = volume.volumeInfo.publishedDate, !year.isEmpty {
                                metaPill(text: year, systemImage: "calendar")
                            }
                        }
                        .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
            }
            .buttonStyle(.plain)

            if isAlreadyInLibrary {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Bereits in deiner Bibliothek")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)
            } else {
                HStack(spacing: 8) {
                    QuickAddButton(title: "Will lesen", systemImage: "bookmark") { onQuickAdd(.toRead) }
                    QuickAddButton(title: "Lese gerade", systemImage: "book") { onQuickAdd(.reading) }
                    QuickAddButton(title: "Gelesen", systemImage: "checkmark.circle") { onQuickAdd(.finished) }
                }
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var cover: some View {
        let best = volume.bestCoverURLString ?? volume.bestThumbnailURLString

        if let urlString = best,
           let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 10)
                    .opacity(0.12)
                    .overlay(ProgressView())
            }
            .frame(width: 54, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .frame(width: 54, height: 78)
                .opacity(0.12)
                .overlay(Image(systemName: "book").opacity(0.6))
        }
    }

    private func metaPill(text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .foregroundStyle(.secondary)
    }
}

private struct QuickAddButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption2)
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) hinzufügen")
    }
}

// MARK: - Undo Toast UI

private struct UndoToastView: View {
    let title: String
    let status: ReadingStatus
    let thumbnailURL: String?
    let onUndo: () -> Void
    let onDismiss: () -> Void

    private var statusLabel: String {
        switch status {
        case .toRead: return "Will lesen"
        case .reading: return "Lese gerade"
        case .finished: return "Gelesen"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            cover

            VStack(alignment: .leading, spacing: 2) {
                Text("Hinzugefügt")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)

                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button("Rückgängig") {
                onUndo()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderedProminent)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hinweis schließen")
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 8, y: 3)
    }

    @ViewBuilder
    private var cover: some View {
        if let thumbnailURL, let url = URL(string: thumbnailURL) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 10)
                    .opacity(0.12)
                    .overlay(ProgressView())
            }
            .frame(width: 40, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .frame(width: 40, height: 56)
                .opacity(0.12)
                .overlay(Image(systemName: "book").opacity(0.6))
        }
    }
}

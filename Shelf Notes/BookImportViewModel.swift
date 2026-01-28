//
/*  BookImportViewModel.swift
    Shelf Notes

    View-model for Google Books import flow.
    Extracted from BookImportView.swift to reduce file size and improve maintainability.
*/

import Foundation
import SwiftUI
import SwiftData
import Combine

#if canImport(UIKit)
import UIKit
#endif

enum BookImportLanguageOption: String, CaseIterable, Identifiable {
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

enum BookImportSearchScope: String, CaseIterable, Identifiable {
    case any
    case title
    case author

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any: return "Alles"
        case .title: return "Titel"
        case .author: return "Autor"
        }
    }
}

enum BookImportSortOption: String, CaseIterable, Identifiable {
    /// Keep the API's order ("relevance" from Google).
    case relevance
    /// Sort by published year (desc) locally and also request Google's "newest" order.
    case newest
    /// Prefer "high quality" hits (cover + isbn + metadata), locally.
    case quality
    case titleAZ

    var id: String { rawValue }

    var title: String {
        switch self {
        case .relevance: return "Relevanz"
        case .newest: return "Neueste"
        case .quality: return "Qualität"
        case .titleAZ: return "Titel A–Z"
        }
    }

    var apiOrderBy: GoogleBooksOrderBy {
        switch self {
        case .newest: return .newest
        default: return .relevance
        }
    }
}

@MainActor
final class BookImportViewModel: ObservableObject {

    // MARK: - Types

    struct UndoPayload: Identifiable, Equatable {
        let id = UUID()
        let bookID: UUID
        let volumeID: String
        let title: String
        let status: ReadingStatus
        let thumbnailURL: String?
    }

    // MARK: - Dependencies

    private let historyStore = SearchHistoryStore(key: "gb_search_history_json", maxItems: 10)
    private let pageSize: Int = 40

    private static let popularCategories: [String] = [
        "Fiction",
        "Nonfiction",
        "Biography & Autobiography",
        "Business & Economics",
        "Self-Help",
        "Computers",
        "Science",
        "History",
        "Health & Fitness",
        "Travel",
        "True Crime",
        "Fantasy",
        "Young Adult",
        "Juvenile Fiction"
    ]

    // MARK: - Published UI State

    @Published var queryText: String = ""

    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?

    @Published private(set) var results: [GoogleBookVolume] = []

    // Meta for UI
    @Published private(set) var totalItems: Int = 0

    // Filter / Qualität
    @Published var showFilters: Bool = false

    // API-side filters (plus local preview filters for instant feedback)

    /// Where to apply the user's text query.
    @Published var scope: BookImportSearchScope = .any {
        didSet { triggerSearchIfActive() }
    }

    @Published var language: BookImportLanguageOption = .any {
        didSet {
            applyLocalFilters()      // instant feedback
            triggerSearchIfActive()  // and re-fetch for better recall
        }
    }

    /// Sort mode shown in the UI. Some modes map to Google's server-side order.
    @Published var sortOption: BookImportSortOption = .relevance {
        didSet {
            applyLocalFilters()      // instant feedback
            // Only re-fetch when the selected sort maps to Google's server-side ordering.
            if sortOption == .relevance || sortOption == .newest {
                triggerSearchIfActive()
            }
        }
    }

    @Published var apiFilter: GoogleBooksFilter = .none {
        didSet {
            applyLocalFilters()      // instant feedback
            triggerSearchIfActive()
        }
    }

    /// Category / subject filter. Empty = no category.
    @Published var category: String = "" {
        didSet {
            applyLocalFilters()
            triggerSearchIfActive()
        }
    }

    // Local "quality" filters
    @Published var onlyWithCover: Bool = false {
        didSet { applyLocalFilters() }
    }

    @Published var onlyWithISBN: Bool = false {
        didSet { applyLocalFilters() }
    }

    @Published var hideAlreadyInLibrary: Bool = false {
        didSet { applyLocalFilters() }
    }

    @Published var onlyWithDescription: Bool = false {
        didSet { applyLocalFilters() }
    }

    /// Collapses near-duplicates (same ISBN, or same title+author) for less noise.
    @Published var collapseDuplicates: Bool = true {
        didSet { applyLocalFilters() }
    }

    /// Categories found in the currently fetched result set.
    @Published private(set) var availableCategories: [String] = []

    /// Debug info for the last Google request (helps verify filters are applied).
    @Published private(set) var lastDebugInfo: GoogleBooksDebugInfo?

    // Search history for chips
    @Published private(set) var history: [String] = []

    // Undo / Snackbar
    @Published var undoPayload: UndoPayload?

    // MARK: - Private State

    private var fetchedVolumes: [GoogleBookVolume] = []

    private var activeQuery: String = ""
    private var nextStartIndex: Int = 0
    private var didReachEnd: Bool = false

    private var lastInfiniteTriggerID: String?

    private var undoHideTask: Task<Void, Never>?

    private var addedVolumeIDs: Set<String> = []
    private var sessionQuickAddCount: Int = 0
    private var didTriggerQuickAddCallback: Bool = false

    private var libraryVolumeIDs: Set<String> = []
    private var libraryISBNsLowercased: Set<String> = []

    // Callbacks (used by AddBookView to close the sheet when quick-add started)
    var onQuickAddHappened: (() -> Void)?
    var onQuickAddActiveChanged: ((Bool) -> Void)?

    // Prevent search spam when initializing default values
    private var isBootstrapping: Bool = true

    init(
        onQuickAddHappened: (() -> Void)? = nil,
        onQuickAddActiveChanged: ((Bool) -> Void)? = nil
    ) {
        self.onQuickAddHappened = onQuickAddHappened
        self.onQuickAddActiveChanged = onQuickAddActiveChanged
        self.history = historyStore.load()

        // Allow didSet hooks to fire after init
        self.isBootstrapping = false
    }

    // MARK: - Lifecycle

    func cancelTasks() {
        undoHideTask?.cancel()
        undoHideTask = nil
    }

    // MARK: - Public helpers for UI

    var resultsCount: Int { results.count }

    /// A compact description of the currently active filters/sorting.
    var activeFiltersSummary: String {
        var parts: [String] = []

        parts.append("Sort: \(sortOption.title)")

        if scope != .any {
            parts.append("Suche: \(scope.title)")
        }

        if language != .any {
            parts.append("Sprache: \(language.title)")
        }

        if apiFilter != .none {
            parts.append("Filter: \(apiFilter.title)")
        }

        let cat = category.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cat.isEmpty {
            parts.append("Kategorie: \(cat)")
        }

        if onlyWithCover { parts.append("Cover") }
        if onlyWithISBN { parts.append("ISBN") }
        if onlyWithDescription { parts.append("Beschreibung") }
        if hideAlreadyInLibrary { parts.append("Ohne vorhandene") }
        if collapseDuplicates { parts.append("Duplikate reduziert") }

        return parts.joined(separator: " • ")
    }

    var categoryPickerOptions: [String] {
        if !availableCategories.isEmpty { return availableCategories }
        return Self.popularCategories
    }

    var lastRequestURLString: String? {
        lastDebugInfo?.requestURL
    }

    var lastRequestDebugSummary: String? {
        guard let d = lastDebugInfo else { return nil }
        var parts: [String] = []
        if let status = d.httpStatus {
            parts.append("HTTP \(status)")
        }
        if d.responseBytes > 0 {
            let kb = Double(d.responseBytes) / 1024.0
            parts.append(String(format: "%.0f KB", kb))
        }
        return parts.isEmpty ? nil : ("Google: " + parts.joined(separator: " • "))
    }

    var totalItemsText: String {
        totalItems > 0 ? " von \(totalItems)" : ""
    }

    var shouldShowLoadMore: Bool {
        guard !isLoading else { return false }
        guard !didReachEnd else { return false }
        guard !activeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        if totalItems > 0 {
            return nextStartIndex < totalItems
        }

        return true
    }

    func updateExistingBooks(_ books: [Book]) {
        // index: volumeIDs
        libraryVolumeIDs = Set(books.compactMap { b in
            let id = (b.googleVolumeID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return id.isEmpty ? nil : id
        })

        // index: ISBNs
        libraryISBNsLowercased = Set(books.compactMap { b in
            let isbn = (b.isbn13 ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return isbn.isEmpty ? nil : isbn.lowercased()
        })

        if hideAlreadyInLibrary {
            applyLocalFilters()
        }
    }

    func clearQueryAndResults() {
        queryText = ""
        errorMessage = nil

        fetchedVolumes = []
        results = []
        availableCategories = []
        lastDebugInfo = nil
        isLoading = false

        // Reset paging
        activeQuery = ""
        totalItems = 0
        nextStartIndex = 0
        didReachEnd = false
        isLoadingMore = false
        lastInfiniteTriggerID = nil
    }

    func clearHistory() {
        historyStore.clear()
        history = []
    }

    func useHistoryTerm(_ term: String) async {
        queryText = term
        await search()
    }

    // MARK: - Infinite scroll hook

    func handleResultAppeared(volumeID: String) async {
        guard errorMessage == nil else { return }
        guard shouldShowLoadMore else { return }
        guard !isLoading, !isLoadingMore else { return }

        guard let lastID = results.last?.id else { return }
        guard volumeID == lastID else { return }

        if lastInfiniteTriggerID == lastID { return }
        lastInfiniteTriggerID = lastID

        await loadMore()
    }

    // MARK: - Search

    func search() async {
        await performSearch(addToHistory: true, keepCurrentResults: false)
    }

    private func refreshFromFilters() async {
        await performSearch(addToHistory: false, keepCurrentResults: true)
    }

    private func performSearch(addToHistory: Bool, keepCurrentResults: Bool) async {
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if addToHistory {
            history = historyStore.add(trimmed)
        }

        // Freeze query for paging (user may edit the text field while results are on screen)
        let base = normalizedQuery(trimmed)
        let effective = buildEffectiveQuery(from: base)

        errorMessage = nil
        isLoading = true

        // Reset paging (but optionally keep the existing list on screen while we refresh)
        activeQuery = effective
        totalItems = 0
        nextStartIndex = 0
        didReachEnd = false
        isLoadingMore = false
        lastInfiniteTriggerID = nil

        if !keepCurrentResults {
            fetchedVolumes = []
            results = []
            availableCategories = []
            lastDebugInfo = nil
        }

        await fetchPage(startIndex: 0, append: false)
    }

    func loadMore() async {
        guard shouldShowLoadMore else { return }
        guard !isLoadingMore, !isLoading else { return }

        isLoadingMore = true
        errorMessage = nil

        await fetchPage(startIndex: nextStartIndex, append: true)

        isLoadingMore = false
    }

    // MARK: - Add

    func isAlreadyAdded(_ volume: GoogleBookVolume) -> Bool {
        if addedVolumeIDs.contains(volume.id) { return true }
        if libraryVolumeIDs.contains(volume.id) { return true }

        if let isbn = volume.isbn13?.trimmingCharacters(in: .whitespacesAndNewlines),
           !isbn.isEmpty,
           libraryISBNsLowercased.contains(isbn.lowercased()) {
            return true
        }

        return false
    }

    func quickAdd(_ volume: GoogleBookVolume, status: ReadingStatus, modelContext: ModelContext) async {
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

        newBook.googleVolumeID = volume.id
        newBook.isbn13 = volume.isbn13

        let bestCover = (volume.bestCoverURLString ?? volume.bestThumbnailURLString)
        newBook.thumbnailURL = bestCover

        newBook.publisher = info.publisher
        newBook.publishedDate = info.publishedDate
        newBook.pageCount = info.pageCount
        newBook.language = info.language

        newBook.categories = volume.allCategories
        newBook.bookDescription = info.description ?? ""

        // ✅ Rich metadata mappings
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

        addedVolumeIDs.insert(volume.id)

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

    func hideUndo() {
        undoHideTask?.cancel()
        undoHideTask = nil
        withAnimation(.snappy) {
            undoPayload = nil
        }
    }

    func undoLastAdd(_ payload: UndoPayload, modelContext: ModelContext) async {
        undoHideTask?.cancel()
        undoHideTask = nil

        withAnimation(.snappy) {
            undoPayload = nil
        }

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

        addedVolumeIDs.remove(payload.volumeID)

        if sessionQuickAddCount > 0 { sessionQuickAddCount -= 1 }
        onQuickAddActiveChanged?(sessionQuickAddCount > 0)

        #if canImport(UIKit)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.warning)
        #endif
    }

    // MARK: - Private

    private func triggerSearchIfActive() {
        guard !isBootstrapping else { return }
        guard !activeQuery.isEmpty else { return }
        Task { await refreshFromFilters() }
    }

    private func normalizedQuery(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isNumber)
        if digits.count == 10 || digits.count == 13 {
            return "isbn:\(digits)"
        }
        return trimmed
    }

    private func buildEffectiveQuery(from base: String) -> String {
        let trimmed = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        // If the user already uses advanced operators (isbn:, intitle:, inauthor:, subject: ...),
        // we don't try to be clever – we only add the category filter when it's safe.
        let lower = trimmed.lowercased()
        let isISBNQuery = lower.hasPrefix("isbn:")
        let usesOperators = lower.contains("isbn:") || lower.contains("intitle:") || lower.contains("inauthor:") || lower.contains("subject:")

        var q = trimmed

        if !usesOperators && !isISBNQuery {
            switch scope {
            case .any:
                break
            case .title:
                q = "intitle:\(quoteIfNeeded(trimmed))"
            case .author:
                q = "inauthor:\(quoteIfNeeded(trimmed))"
            }
        }

        // Category filter as Google Books "subject:" operator.
        let cat = category.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cat.isEmpty && !isISBNQuery {
            q += " subject:\(quoteIfNeeded(cat))"
        }

        return q
    }

    private func quoteIfNeeded(_ value: String) -> String {
        let cleaned = value.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return cleaned }
        if cleaned.contains(" ") {
            return "\"\(cleaned)\""
        }
        return cleaned
    }

    private func currentQueryOptions() -> GoogleBooksQueryOptions {
        var opt = GoogleBooksQueryOptions.default
        opt.langRestrict = language.apiValue
        opt.orderBy = sortOption.apiOrderBy
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

            lastDebugInfo = res.debug
            totalItems = res.totalItems

            if append {
                var existing = Set(fetchedVolumes.map { $0.id })
                let newOnes = res.volumes.filter { existing.insert($0.id).inserted }
                fetchedVolumes.append(contentsOf: newOnes)
            } else {
                fetchedVolumes = res.volumes
            }

            applyLocalFilters()

            let returnedCount = res.volumes.count
            nextStartIndex = startIndex + returnedCount

            if returnedCount == 0 {
                didReachEnd = true
            } else if res.totalItems > 0, nextStartIndex >= res.totalItems {
                didReachEnd = true
            } else {
                didReachEnd = false
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            if !append { didReachEnd = true }
        }
    }

    private func applyLocalFilters() {
        // Keep category list in sync with the fetched set.
        availableCategories = computeAvailableCategories(from: fetchedVolumes, includeSelected: category)

        var filtered = fetchedVolumes

        // Local preview for language (instant feedback even before the server responds).
        if let code = language.apiValue?.lowercased(), !code.isEmpty {
            filtered = filtered.filter { vol in
                let lang = (vol.volumeInfo.language ?? "").lowercased()
                return lang == code
            }
        }

        // Local preview for "Filter (Google)" (best effort; Google's server-side filter is still authoritative).
        if apiFilter != .none {
            filtered = filtered.filter(matchesAPIFilterLocally)
        }

        // Local category filter (works immediately on the already fetched pages).
        let cat = category.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cat.isEmpty {
            filtered = filtered.filter { volumeHasCategory($0, matching: cat) }
        }

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

        if onlyWithDescription {
            filtered = filtered.filter { vol in
                let d = (vol.volumeInfo.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return !d.isEmpty
            }
        }

        if hideAlreadyInLibrary {
            filtered = filtered.filter { !isAlreadyAdded($0) }
        }

        if collapseDuplicates {
            filtered = collapseNearDuplicates(filtered)
        }

        filtered = sortVolumes(filtered)

        results = filtered
    }

    private func computeAvailableCategories(from volumes: [GoogleBookVolume], includeSelected selected: String) -> [String] {
        var map: [String: (display: String, count: Int)] = [:]

        func add(_ raw: String) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let key = trimmed.lowercased()
            if let existing = map[key] {
                map[key] = (existing.display, existing.count + 1)
            } else {
                map[key] = (trimmed, 1)
            }
        }

        for v in volumes {
            for c in v.allCategories { add(c) }
        }

        let trimmedSelected = selected.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSelected.isEmpty {
            add(trimmedSelected)
        }

        return map.values
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                return a.display.localizedCaseInsensitiveCompare(b.display) == .orderedAscending
            }
            .map { $0.display }
    }

    private func volumeHasCategory(_ volume: GoogleBookVolume, matching selected: String) -> Bool {
        let needle = selected.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return true }

        for c in volume.allCategories {
            let hay = c.lowercased()
            if hay == needle { return true }
            if hay.contains(needle) { return true }
        }

        return false
    }

    private func matchesAPIFilterLocally(_ volume: GoogleBookVolume) -> Bool {
        switch apiFilter {
        case .none:
            return true
        case .ebooks:
            return volume.isEbook
        case .freeEbooks:
            return (volume.saleability ?? "").uppercased().contains("FREE")
        case .paidEbooks:
            return (volume.saleability ?? "").uppercased().contains("FOR_SALE")
        case .partial:
            return (volume.viewability ?? "").uppercased().contains("PARTIAL")
        case .full:
            let v = (volume.viewability ?? "").uppercased()
            return v.contains("ALL_PAGES") || v.contains("FULL") || v.contains("PUBLIC_DOMAIN")
        }
    }

    private func collapseNearDuplicates(_ input: [GoogleBookVolume]) -> [GoogleBookVolume] {
        var seen: Set<String> = []
        var out: [GoogleBookVolume] = []
        out.reserveCapacity(input.count)

        for v in input {
            let key: String
            if let isbn = v.isbn13?.trimmingCharacters(in: .whitespacesAndNewlines), !isbn.isEmpty {
                key = "isbn|\(isbn.lowercased())"
            } else {
                let t = v.bestTitle.lowercased()
                let a = v.bestAuthors.lowercased()
                key = "ta|\(t)|\(a)"
            }

            if seen.insert(key).inserted {
                out.append(v)
            }
        }

        return out
    }

    private func sortVolumes(_ input: [GoogleBookVolume]) -> [GoogleBookVolume] {
        switch sortOption {
        case .relevance:
            return input

        case .newest:
            return input.sorted { a, b in
                let ya = publishedYear(a)
                let yb = publishedYear(b)
                if ya != yb { return (ya ?? Int.min) > (yb ?? Int.min) }
                return a.bestTitle.localizedCaseInsensitiveCompare(b.bestTitle) == .orderedAscending
            }

        case .titleAZ:
            return input.sorted { a, b in
                a.bestTitle.localizedCaseInsensitiveCompare(b.bestTitle) == .orderedAscending
            }

        case .quality:
            return input.sorted { a, b in
                let sa = qualityScore(a)
                let sb = qualityScore(b)
                if sa != sb { return sa > sb }
                let ya = publishedYear(a)
                let yb = publishedYear(b)
                if ya != yb { return (ya ?? Int.min) > (yb ?? Int.min) }
                return a.bestTitle.localizedCaseInsensitiveCompare(b.bestTitle) == .orderedAscending
            }
        }
    }

    private func publishedYear(_ volume: GoogleBookVolume) -> Int? {
        let raw = (volume.volumeInfo.publishedDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard raw.count >= 4 else { return nil }
        let prefix = String(raw.prefix(4))
        return Int(prefix)
    }

    private func qualityScore(_ volume: GoogleBookVolume) -> Int {
        var score = 0

        if let c = (volume.bestCoverURLString ?? volume.bestThumbnailURLString), !c.isEmpty { score += 6 }
        if let isbn = volume.isbn13, !isbn.isEmpty { score += 6 }
        if (volume.volumeInfo.pageCount ?? 0) > 0 { score += 2 }
        if !(volume.bestAuthors.isEmpty) { score += 2 }
        if let d = volume.volumeInfo.description, !d.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 2 }
        if let _ = publishedYear(volume) { score += 1 }

        // A tiny bump if there are ratings (many volumes don't have them).
        if let rc = volume.ratingsCount, rc > 0 { score += 1 }

        return score
    }

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
}

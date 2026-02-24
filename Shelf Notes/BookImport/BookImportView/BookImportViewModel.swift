//
/*  BookImportViewModel.swift
    Shelf Notes

    View-model for Google Books import flow.
    Split into smaller collaborators:
    - BookImportTypes.swift (enums)
    - BookImportQueryBuilder.swift
    - BookImportFilterEngine.swift
    - GoogleVolumeBookMapper.swift
*/

import Foundation
import SwiftUI
import SwiftData
import Combine

#if canImport(UIKit)
import UIKit
#endif

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

    let historyStore = SearchHistoryStore(key: "gb_search_history_json", maxItems: 10)
    let pageSize: Int = 40

    let filterEngine = BookImportFilterEngine()
    let volumeMapper = GoogleVolumeBookMapper()

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

    /// The effective Google `q` value used for the current results.
    ///
    /// This is shown in the UI to make the search transparent (no hidden rewrites).
    @Published var effectiveQueryForUI: String = ""

    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?

    @Published var results: [GoogleBookVolume] = []

    // Meta for UI
    @Published var totalItems: Int = 0

    // Filter / Qualität
    @Published var showFilters: Bool = false

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
    @Published var availableCategories: [String] = []

    /// Debug info for the last Google request (helps verify filters are applied).
    @Published var lastDebugInfo: GoogleBooksDebugInfo?

    // Search history for chips
    @Published var history: [String] = []

    // Undo / Snackbar
    @Published var undoPayload: UndoPayload?

    // MARK: - Private State

    var fetchedVolumes: [GoogleBookVolume] = []

    /// Remembers where the current/active query originated from.
    /// We keep this stable across filter toggles (so the behavior does not silently change).
    var activeSearchOrigin: BookImportSearchOrigin = .userTyped

    /// Used for one-off searches (e.g. seed picker -> auto-search on appear).
    var nextSearchOrigin: BookImportSearchOrigin? = nil

    /// The trimmed query text that produced the currently displayed results.
    /// Used to detect when a "filter refresh" is actually running against newly typed text.
    var lastSearchedInputText: String = ""

    var activeQuery: String = ""
    var compositeQueries: [String] = []
    var isCompositeQuery: Bool = false
    var nextStartIndex: Int = 0
    var didReachEnd: Bool = false

    var lastInfiniteTriggerID: String?

    var undoHideTask: Task<Void, Never>?

    // MARK: - Search task management (cancel + debounce)

    /// Debounced refresh triggered by filter changes.
    var debouncedRefreshTask: Task<Void, Never>?

    /// The currently running "main" search task (initial search or filter refresh).
    var searchTask: Task<Void, Never>?

    /// The currently running pagination task (load more).
    var loadMoreTask: Task<Void, Never>?

    /// Monotonically increasing generation counter used to ignore stale async responses.
    var searchGeneration: UInt64 = 0

    /// Debounce delay for filter-driven refreshes.
    let filterRefreshDebounceNanos: UInt64 = 350_000_000

    var addedVolumeIDs: Set<String> = []
    var sessionQuickAddCount: Int = 0
    var didTriggerQuickAddCallback: Bool = false

    var libraryVolumeIDs: Set<String> = []
    var libraryISBNsLowercased: Set<String> = []

    // Callbacks (used by AddBookView to close the sheet when quick-add started)
    var onQuickAddHappened: (() -> Void)?
    var onQuickAddActiveChanged: ((Bool) -> Void)?

    // Prevent search spam when initializing default values
    var isBootstrapping: Bool = true

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

    /// Applies the app-wide default language preference from Settings.
    ///
    /// This should be called once when the search sheet appears, before an auto-search runs.
    func applyDefaultLanguagePreferenceIfNeeded() {
        // Only preselect when the user hasn't chosen a language yet (default is .any).
        guard language == .any else { return }

        let pref = BookSearchLanguagePreference.load()
        let desired = pref.resolvedImportLanguageOption()
        guard desired != .any else { return }

        language = desired
    }

    /// Marks the next explicit search as coming from a seed (or user typing).
    ///
    /// This allows us to apply seed-specific optimizations without touching user-entered queries.
    func setNextSearchOrigin(_ origin: BookImportSearchOrigin) {
        nextSearchOrigin = origin
    }


    // MARK: - Public helpers for UI

    var resultsCount: Int { results.count }

    /// Number of volumes returned by Google (after merging pages), before local quality filters are applied.
    var fetchedVolumesCount: Int { fetchedVolumes.count }

    /// totalItems as reported by the API (or parsed from debug JSON).
    /// Useful to distinguish "Google returned 0" vs "Google had hits but local filters hide them".
    var lastReportedTotalItems: Int {
        if let parsed = lastResponseParsedTotalItems { return parsed }
        return totalItems
    }

    /// True when the API returned volumes, but local quality filters removed all of them.
    var isEmptyBecauseOfLocalFilters: Bool {
        let hasQuery = !queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasQuery && !isLoading && errorMessage == nil && results.isEmpty && fetchedVolumesCount > 0
    }

    /// A compact list of active local quality filters that can hide results.
    var activeLocalQualityFilters: [String] {
        var parts: [String] = []
        if onlyWithCover { parts.append("Nur mit Cover") }
        if onlyWithISBN { parts.append("Nur mit ISBN") }
        if onlyWithDescription { parts.append("Nur mit Beschreibung") }
        if hideAlreadyInLibrary { parts.append("Ohne vorhandene") }
        if collapseDuplicates { parts.append("Duplikate reduziert") }
        return parts
    }

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

    var lastRequestURLSanitized: String? {
        guard let raw = lastDebugInfo?.requestURL else { return nil }
        return Self.sanitizeURLRemovingKey(raw)
    }

    var lastResponseSnippet: String? {
        lastDebugInfo?.responseBodySnippet
    }

    var lastResponseHasErrorObject: Bool? {
        lastDebugInfo?.hasErrorObject
    }

    var lastResponseParsedTotalItems: Int? {
        lastDebugInfo?.parsedTotalItems
    }

    var lastRequestUsedApiKey: Bool? {
        lastDebugInfo?.usedApiKey
    }

    var lastRequestDebugSummary: String? {
        guard let d = lastDebugInfo else { return nil }
        var parts: [String] = []
        if let status = d.httpStatus {
            parts.append("HTTP \(status)")
        }
        parts.append(Self.formatBytes(d.responseBytes))
        if let ti = d.parsedTotalItems {
            parts.append("totalItems \(ti)")
        }
        parts.append(d.usedApiKey ? "key" : "no-key")
        return "Google: " + parts.joined(separator: " • ")
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


    private static func formatBytes(_ bytes: Int) -> String {
        if bytes <= 0 { return "0 B" }
        if bytes < 1024 { return "\(bytes) B" }

        let kb = Double(bytes) / 1024.0
        if kb < 1024.0 {
            return String(format: "%.1f KB", kb)
        }

        let mb = kb / 1024.0
        return String(format: "%.1f MB", mb)
    }

    private static func sanitizeURLRemovingKey(_ urlString: String) -> String {
        guard var comps = URLComponents(string: urlString) else { return urlString }
        if let items = comps.queryItems, !items.isEmpty {
            comps.queryItems = items.filter { $0.name.lowercased() != "key" }
        }
        return comps.url?.absoluteString ?? urlString
    }


    func clearQueryAndResults() {
        // If a request is currently in-flight and the user clears the query,
        // we must cancel it to avoid stale results re-appearing.
        cancelSearchWork(resetLoadingState: false)
        // Invalidate any async responses that might still arrive.
        searchGeneration &+= 1

        queryText = ""
        errorMessage = nil

        fetchedVolumes = []
        results = []
        availableCategories = []
        lastDebugInfo = nil
        isLoading = false

        // Reset paging
        activeQuery = ""
        effectiveQueryForUI = ""
        activeSearchOrigin = .userTyped
        nextSearchOrigin = nil
        lastSearchedInputText = ""
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


    /// Resets all filter / quality toggles in the search panel back to their defaults.
    /// Keeps the current query text. If a query is present, triggers a fresh search once.
    func resetFiltersToDefaults() {
        // Avoid triggering multiple debounced refreshes while we flip many toggles.
        isBootstrapping = true
        defer { isBootstrapping = false }

        scope = .any
        language = .any
        sortOption = .relevance
        apiFilter = .none
        category = ""

        onlyWithCover = false
        onlyWithISBN = false
        onlyWithDescription = false
        hideAlreadyInLibrary = false
        collapseDuplicates = true

        // Clear debug meta, so the next request is clearly attributable.
        lastDebugInfo = nil

        applyLocalFilters()

        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { await search() }
    }
    // MARK: - Add

    func quickAdd(_ volume: GoogleBookVolume, status: ReadingStatus, modelContext: ModelContext) async {
        guard !isAlreadyAdded(volume) else { return }

        let newBook = volumeMapper.makeBook(from: volume, status: status)

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

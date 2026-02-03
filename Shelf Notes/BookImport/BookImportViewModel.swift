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

    private let historyStore = SearchHistoryStore(key: "gb_search_history_json", maxItems: 10)
    private let pageSize: Int = 40

    private let filterEngine = BookImportFilterEngine()
    private let volumeMapper = GoogleVolumeBookMapper()

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
    @Published private(set) var effectiveQueryForUI: String = ""

    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var errorMessage: String?

    @Published private(set) var results: [GoogleBookVolume] = []

    // Meta for UI
    @Published private(set) var totalItems: Int = 0

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
    @Published private(set) var availableCategories: [String] = []

    /// Debug info for the last Google request (helps verify filters are applied).
    @Published private(set) var lastDebugInfo: GoogleBooksDebugInfo?

    // Search history for chips
    @Published private(set) var history: [String] = []

    // Undo / Snackbar
    @Published var undoPayload: UndoPayload?

    // MARK: - Private State

    private var fetchedVolumes: [GoogleBookVolume] = []

    /// Remembers where the current/active query originated from.
    /// We keep this stable across filter toggles (so the behavior does not silently change).
    private var activeSearchOrigin: BookImportSearchOrigin = .userTyped

    /// Used for one-off searches (e.g. seed picker -> auto-search on appear).
    private var nextSearchOrigin: BookImportSearchOrigin? = nil

    /// The trimmed query text that produced the currently displayed results.
    /// Used to detect when a "filter refresh" is actually running against newly typed text.
    private var lastSearchedInputText: String = ""

    private var activeQuery: String = ""
    private var compositeQueries: [String] = []
    private var isCompositeQuery: Bool = false
    private var nextStartIndex: Int = 0
    private var didReachEnd: Bool = false

    private var lastInfiniteTriggerID: String?

    private var undoHideTask: Task<Void, Never>?

    // MARK: - Search task management (cancel + debounce)

    /// Debounced refresh triggered by filter changes.
    private var debouncedRefreshTask: Task<Void, Never>?

    /// The currently running "main" search task (initial search or filter refresh).
    private var searchTask: Task<Void, Never>?

    /// The currently running pagination task (load more).
    private var loadMoreTask: Task<Void, Never>?

    /// Monotonically increasing generation counter used to ignore stale async responses.
    private var searchGeneration: UInt64 = 0

    /// Debounce delay for filter-driven refreshes.
    private let filterRefreshDebounceNanos: UInt64 = 350_000_000

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


    func cancelTasks() {
        undoHideTask?.cancel()
        undoHideTask = nil

        cancelSearchWork(resetLoadingState: true)
    }

    private func cancelSearchWork(resetLoadingState: Bool) {
        debouncedRefreshTask?.cancel()
        debouncedRefreshTask = nil

        searchTask?.cancel()
        searchTask = nil

        loadMoreTask?.cancel()
        loadMoreTask = nil

        if resetLoadingState {
            isLoading = false
            isLoadingMore = false
        }
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
        // User explicitly started a new search -> cancel any pending filter refresh.
        debouncedRefreshTask?.cancel()
        debouncedRefreshTask = nil

        await startSearch(addToHistory: true, keepCurrentResults: false)
    }

    private func startSearch(addToHistory: Bool, keepCurrentResults: Bool) async {
        // Cancel any in-flight work that could mutate the same state.
        loadMoreTask?.cancel()
        loadMoreTask = nil

        searchTask?.cancel()

        // New generation -> stale async results get ignored.
        searchGeneration &+= 1
        let generation = searchGeneration

        let task = Task { [weak self] in
            guard let self else { return }
            await self.performSearch(addToHistory: addToHistory, keepCurrentResults: keepCurrentResults, generation: generation)
        }

        searchTask = task
        await task.value
    }

    private func performSearch(addToHistory: Bool, keepCurrentResults: Bool, generation: UInt64) async {
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard !Task.isCancelled else { return }
        guard generation == searchGeneration else { return }

        if addToHistory {
            history = historyStore.add(trimmed)
        }

        // Determine where this search came from.
        // - For explicit searches (user hit Search / enter / auto-seed), we use `nextSearchOrigin`.
        // - For filter refreshes, we keep the previously active origin to avoid silent behavior changes.
        let origin: BookImportSearchOrigin
        if keepCurrentResults {
            // If the user edited the text field since the last search,
            // treat this as user input (not a seed) to avoid applying seed-only optimizations.
            if trimmed != lastSearchedInputText {
                origin = .userTyped
                activeSearchOrigin = origin
            } else {
                origin = activeSearchOrigin
            }
        } else {
            origin = nextSearchOrigin ?? .userTyped
            activeSearchOrigin = origin
            nextSearchOrigin = nil
            lastSearchedInputText = trimmed
        }

        // Freeze query for paging (user may edit the text field while results are on screen).
        let baseRaw = BookImportQueryBuilder.normalizedQuery(trimmed)
        let base = (origin == .seed)
            ? BookImportSeedQueryOptimizer.optimize(query: baseRaw, language: language)
            : baseRaw

        let builder = BookImportQueryBuilder(scope: scope, category: category)

        let orParts = splitTopLevelOR(base)
        let effective = (orParts == nil) ? builder.buildEffectiveQuery(from: base) : ""

        errorMessage = nil
        isLoading = true

        // Reset paging (but optionally keep the existing list on screen while we refresh)
        isCompositeQuery = false
        compositeQueries = []
        activeQuery = effective
        effectiveQueryForUI = effective

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

        // Composite queries (e.g. "A OR B") are common for "Für dich" seeds.
        // Google Books API's q semantics are AND-centric, so we run each side separately and merge.
        if let orParts {
            let parts = orParts
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if parts.count >= 2 {
                let effectiveParts = parts
                    .prefix(4)
                    .map { builder.buildEffectiveQuery(from: $0) }
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

                isCompositeQuery = true
                compositeQueries = effectiveParts
                activeQuery = effectiveParts.first ?? ""
                effectiveQueryForUI = effectiveParts.joined(separator: "\nOR\n")

                await fetchCompositeFirstPage(queries: effectiveParts, generation: generation)
                return
            }
        }

        await fetchPage(startIndex: 0, append: false, generation: generation)
    }

    func loadMore() async {
        guard shouldShowLoadMore else { return }
        guard !isLoadingMore, !isLoading else { return }

        isLoadingMore = true
        errorMessage = nil

        let generation = searchGeneration

        loadMoreTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            await self.fetchPage(startIndex: self.nextStartIndex, append: true, generation: generation)
        }
        loadMoreTask = task
        await task.value

        if generation == searchGeneration {
            isLoadingMore = false
        }
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

    private func triggerSearchIfActive() {
        guard !isBootstrapping else { return }
        guard !activeQuery.isEmpty else { return }
        scheduleDebouncedRefresh()
    }

    private func scheduleDebouncedRefresh() {
        debouncedRefreshTask?.cancel()

        debouncedRefreshTask = Task { [weak self] in
            guard let self else { return }
            // Debounce rapid filter changes.
            try? await Task.sleep(nanoseconds: self.filterRefreshDebounceNanos)
            guard !Task.isCancelled else { return }

            await self.startSearch(addToHistory: false, keepCurrentResults: true)
        }
    }

    private func currentQueryOptions() -> GoogleBooksQueryOptions {
        let builder = BookImportQueryBuilder(scope: scope, category: category)
        return builder.makeQueryOptions(language: language, sortOption: sortOption, apiFilter: apiFilter)
    }

    /// Splits a query of the form "A OR B" (outside quotes) into its parts.
    ///
    /// We use this for certain "Für dich" seeds to avoid relying on undocumented OR parsing.
    private func splitTopLevelOR(_ query: String) -> [String]? {
        let needle = " OR "
        guard query.contains(needle) else { return nil }

        var parts: [String] = []
        var current = ""
        var inQuotes = false

        var i = query.startIndex
        while i < query.endIndex {
            let ch = query[i]
            if ch == "\"" {
                inQuotes.toggle()
                current.append(ch)
                i = query.index(after: i)
                continue
            }

            if !inQuotes, query[i...].hasPrefix(needle) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    parts.append(trimmed)
                }
                current = ""
                i = query.index(i, offsetBy: needle.count)
                continue
            }

            current.append(ch)
            i = query.index(after: i)
        }

        let last = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !last.isEmpty {
            parts.append(last)
        }

        // Valid OR split requires at least 2 non-empty parts.
        return parts.count >= 2 ? parts : nil
    }

    private func interleavingUniqueVolumes(lists: [[GoogleBookVolume]]) -> [GoogleBookVolume] {
        guard !lists.isEmpty else { return [] }

        var out: [GoogleBookVolume] = []
        out.reserveCapacity(lists.reduce(0) { $0 + $1.count })

        var seen: Set<String> = []
        let maxLen = lists.map { $0.count }.max() ?? 0

        for i in 0..<maxLen {
            for list in lists {
                guard i < list.count else { continue }
                let v = list[i]
                if seen.insert(v.id).inserted {
                    out.append(v)
                }
            }
        }

        return out
    }

    private func fetchCompositeFirstPage(queries: [String], generation: UInt64) async {
        do {
            guard generation == searchGeneration else { return }
            guard !Task.isCancelled else { return }
            let list = queries
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(4)

            guard !list.isEmpty else { return }

            // Fetch each query's first page.
            let baseOptions = currentQueryOptions()

            var responses: [GoogleBooksSearchResult] = []
            responses.reserveCapacity(list.count)

            for q in list {
                let res = try await GoogleBooksClient.shared.searchVolumesWithDebug(
                    query: q,
                    startIndex: 0,
                    maxResults: pageSize,
                    options: baseOptions
                )
                responses.append(res)
            }

            guard !Task.isCancelled else { return }
            guard generation == searchGeneration else { return }

            // Prefer showing a mixed feed (interleave) instead of dumping all from the first query.
            var finalResponses = responses
            var finalMerged = interleavingUniqueVolumes(lists: responses.map { $0.volumes })

            lastDebugInfo = finalResponses.first?.debug
            totalItems = finalMerged.count
            fetchedVolumes = finalMerged

            applyLocalFilters()

            nextStartIndex = finalMerged.count
            didReachEnd = true
            isLoading = false
            isLoadingMore = false
        } catch {
            if error is CancellationError {
                if generation == searchGeneration {
                    isLoading = false
                    isLoadingMore = false
                }
                return
            }

            guard generation == searchGeneration else { return }
            errorMessage = error.localizedDescription
            isLoading = false
            didReachEnd = true
        }
    }

    private func fetchPage(startIndex: Int, append: Bool, generation: UInt64) async {
        do {
            // If a newer search was started, don't waste cycles.
            guard generation == searchGeneration else { return }
            guard !Task.isCancelled else { return }

            let options = currentQueryOptions()
            let res = try await GoogleBooksClient.shared.searchVolumesWithDebug(
                query: activeQuery,
                startIndex: startIndex,
                maxResults: pageSize,
                options: options
            )

            guard !Task.isCancelled else { return }
            guard generation == searchGeneration else { return }

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
            // Cancellation is expected when the user tweaks filters quickly.
            if error is CancellationError {
                if generation == searchGeneration {
                    isLoading = false
                    isLoadingMore = false
                }
                return
            }

            guard generation == searchGeneration else { return }

            errorMessage = error.localizedDescription
            isLoading = false
            if !append { didReachEnd = true }
        }
    }

    private func applyLocalFilters() {
        let input = BookImportFilterEngine.Input(
            volumes: fetchedVolumes,
            selectedCategory: category,
            onlyWithCover: onlyWithCover,
            onlyWithISBN: onlyWithISBN,
            onlyWithDescription: onlyWithDescription,
            hideAlreadyInLibrary: hideAlreadyInLibrary,
            collapseDuplicates: collapseDuplicates,
            sortOption: sortOption
        )

        let output = filterEngine.apply(input: input, isAlreadyAdded: { [weak self] in
            guard let self else { return false }
            return self.isAlreadyAdded($0)
        })

        availableCategories = output.availableCategories
        results = output.results
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

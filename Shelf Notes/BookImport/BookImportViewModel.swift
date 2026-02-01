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

    private var activeQuery: String = ""
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

        // Freeze query for paging (user may edit the text field while results are on screen)
        let base = BookImportQueryBuilder.normalizedQuery(trimmed)
        let builder = BookImportQueryBuilder(scope: scope, category: category)
        let effective = builder.buildEffectiveQuery(from: base)

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

    private func fetchPage(startIndex: Int, append: Bool, generation: UInt64) async {
        do {
            // If a newer search was started, don't waste cycles.
            guard generation == searchGeneration else { return }
            guard !Task.isCancelled else { return }

            let res = try await GoogleBooksClient.shared.searchVolumesWithDebug(
                query: activeQuery,
                startIndex: startIndex,
                maxResults: pageSize,
                options: currentQueryOptions()
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
            language: language,
            apiFilter: apiFilter,
            category: category,
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

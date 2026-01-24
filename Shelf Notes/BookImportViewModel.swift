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

    // API-side filters
    @Published var language: BookImportLanguageOption = .any {
        didSet { triggerSearchIfActive() }
    }

    @Published var orderBy: GoogleBooksOrderBy = .relevance {
        didSet { triggerSearchIfActive() }
    }

    @Published var apiFilter: GoogleBooksFilter = .none {
        didSet { triggerSearchIfActive() }
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
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // persist history
        history = historyStore.add(trimmed)

        // Freeze query for paging (user may edit the text field while results are on screen)
        let normalized = normalizedQuery(trimmed)

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
        Task { await search() }
    }

    private func normalizedQuery(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isNumber)
        if digits.count == 10 || digits.count == 13 {
            return "isbn:\(digits)"
        }
        return trimmed
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

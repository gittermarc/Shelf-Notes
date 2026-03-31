//
/*  BookImportViewModel.swift
    Shelf Notes

    View-model for Google Books import flow.
    Split into smaller collaborators:
    - BookImportTypes.swift (enums)
    - BookImportQueryBuilder.swift
    - BookImportFilterEngine.swift
    - GoogleVolumeBookMapper.swift
    - BookImportViewModel+State.swift
    - BookImportViewModel+Search.swift
    - BookImportViewModel+Persistence.swift
    - BookImportViewModel+DebugAndUndo.swift
    - BookImportViewModel+Tasks.swift
*/

import Foundation
import Combine

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

    static let popularCategories: [String] = [
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
            applyLocalFilters()
            triggerSearchIfActive()
        }
    }

    /// Sort mode shown in the UI. Some modes map to Google's server-side order.
    @Published var sortOption: BookImportSortOption = .relevance {
        didSet {
            applyLocalFilters()
            if sortOption == .relevance || sortOption == .newest {
                triggerSearchIfActive()
            }
        }
    }

    @Published var apiFilter: GoogleBooksFilter = .none {
        didSet {
            applyLocalFilters()
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

        self.isBootstrapping = false
    }

    // MARK: - Lifecycle

    /// Applies the app-wide default language preference from Settings.
    ///
    /// This should be called once when the search sheet appears, before an auto-search runs.
    func applyDefaultLanguagePreferenceIfNeeded() {
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
}

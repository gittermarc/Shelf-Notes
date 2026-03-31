//
//  BookImportViewModel+State.swift
//  Shelf Notes
//
//  UI-facing computed state, history helpers and filter reset logic.
//

import Foundation

@MainActor
extension BookImportViewModel {

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

    func clearQueryAndResults() {
        cancelSearchWork(resetLoadingState: false)
        searchGeneration &+= 1

        queryText = ""
        errorMessage = nil

        fetchedVolumes = []
        results = []
        availableCategories = []
        lastDebugInfo = nil
        isLoading = false

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

        lastDebugInfo = nil

        applyLocalFilters()

        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task { await search() }
    }
}

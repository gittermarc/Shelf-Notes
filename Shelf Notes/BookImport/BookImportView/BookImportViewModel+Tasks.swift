//
//  BookImportViewModel+Tasks.swift
//  Shelf Notes
//
//  Search/Debounce/Pagination/Cancellation for Google Books import.
//

import Foundation

@MainActor
extension BookImportViewModel {

    func cancelTasks() {
        undoHideTask?.cancel()
        undoHideTask = nil

        cancelSearchWork(resetLoadingState: true)
    }

    func cancelSearchWork(resetLoadingState: Bool) {
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

    // MARK: - Private

    func triggerSearchIfActive() {
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
            let finalResponses = responses
            let finalMerged = interleavingUniqueVolumes(lists: responses.map { $0.volumes })

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

}

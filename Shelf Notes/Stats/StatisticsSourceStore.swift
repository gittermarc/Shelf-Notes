import Combine
import Foundation
import Observation

@MainActor
final class StatisticsSourceStore: ObservableObject {
    nonisolated enum CacheDecision: Equatable, Sendable {
        case missing
        case stale
        case updating
        case reusable
    }

    nonisolated struct ViewState: Sendable {
        let booksSignature: Int?
        let sourceSnapshot: StatisticsSourceSnapshot?
        let statsKey: StatisticsStatsCacheKey?
        let heatmapKey: StatisticsHeatmapCacheKey?
        let exactStatsCache: StatisticsStatsCache?
        let scopeStatsCache: StatisticsStatsCache?
        let exactHeatmapCache: StatisticsHeatmapCache?
        let statsDecision: CacheDecision
        let heatmapDecision: CacheDecision
        let yearOptions: [Int]
        let sessionSourceRequestToken: Int?
    }

    private nonisolated struct SessionSourceIdentity: Equatable, Sendable {
        let sessionsSignature: Int
        let scopeSignature: Int
    }

    @Published private(set) var sourceSnapshot: StatisticsSourceSnapshot?
    @Published private(set) var sessionSourceSnapshot: StatisticsSessionSourceSnapshot?
    @Published private(set) var statsCache: StatisticsStatsCache?
    @Published private(set) var heatmapCache: StatisticsHeatmapCache?
    @Published private(set) var isUpdatingStatsCache = false
    @Published private(set) var isUpdatingHeatmapCache = false
    @Published private(set) var isUpdatingSessionSource = false
    private(set) var completedSessionSourceBuildCount = 0

    private var trackingGeneration = 0
    private var sessionTrackingGeneration = 0
    private var sessionInvalidationGeneration = 0
    private var observedBooks: [Book] = []
    private var sessionSourceRefreshTask: Task<Void, Never>?
    private var sessionSourceNeedsRefresh = false

    deinit {
        sessionSourceRefreshTask?.cancel()
    }

    var currentBooksSignature: Int? {
        sourceSnapshot?.booksSignature
    }

    func refreshSourceAndTrack(books: [Book]) {
        PerformanceSignposter.measure("Statistics Source Refresh") {
            observedBooks = books
            refreshObservedBooksAndTrack()
        }
    }

    func refreshSessionSourceAndTrack(
        books: [Book],
        now: Date? = nil,
        calendar: Calendar = .current
    ) {
        PerformanceSignposter.measure("Statistics Session Source Refresh") {
            let resolvedNow = now ?? Date()
            observedBooks = books
            sessionTrackingGeneration += 1
            let generation = sessionTrackingGeneration

            guard !observedBooks.isEmpty else {
                invalidateSessionSource()
                return
            }

            if sourceSnapshot == nil {
                refreshObservedBooksAndTrack()
            }

            guard let booksSignature = sourceSnapshot?.booksSignature else {
                invalidateSessionSource()
                return
            }

            isUpdatingSessionSource = true
            defer { isUpdatingSessionSource = false }

            let identity = withObservationTracking {
                SessionSourceIdentity(
                    sessionsSignature: Self.sessionsSignature(observedBooks),
                    scopeSignature: Self.sessionScopeSignature(observedBooks)
                )
            } onChange: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.sessionTrackingGeneration == generation else { return }
                    self.refreshSessionSourceAndTrack(
                        books: self.observedBooks,
                        now: now,
                        calendar: calendar
                    )
                }
            }

            updateSessionSource(
                booksSignature: booksSignature,
                scopeSignature: identity.scopeSignature,
                sessionsSignature: identity.sessionsSignature,
                books: observedBooks,
                now: resolvedNow,
                calendar: calendar
            )
        }
    }

    func requestSessionSourceRefresh(books: [Book]) {
        observedBooks = books
        sessionSourceRefreshTask?.cancel()
        sessionSourceRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            self.refreshSessionSourceAndTrack(books: self.observedBooks)
        }
    }

    func invalidateSessionSource() {
        sessionTrackingGeneration += 1
        sessionInvalidationGeneration &+= 1
        sessionSourceNeedsRefresh = true
        sessionSourceSnapshot = nil
        isUpdatingSessionSource = false
    }

    func markSessionSourceStale() {
        sessionInvalidationGeneration &+= 1
        sessionSourceNeedsRefresh = true
    }

    private func refreshObservedBooksAndTrack() {
        trackingGeneration += 1
        let generation = trackingGeneration

        guard !observedBooks.isEmpty else {
            reset()
            return
        }

        let signature = withObservationTracking {
            Self.booksSignature(observedBooks)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.trackingGeneration == generation else { return }
                self.refreshObservedBooksAndTrack()
            }
        }

        updateSource(signature: signature, books: observedBooks)
    }

    func makeViewState(
        selectedYear: Int,
        scope: StatisticsScope,
        activityMetric: StatisticsActivityMetric
    ) -> ViewState {
        guard let sourceSnapshot else {
            return ViewState(
                booksSignature: nil,
                sourceSnapshot: nil,
                statsKey: nil,
                heatmapKey: nil,
                exactStatsCache: nil,
                scopeStatsCache: nil,
                exactHeatmapCache: nil,
                statsDecision: .missing,
                heatmapDecision: .missing,
                yearOptions: [selectedYear],
                sessionSourceRequestToken: nil
            )
        }

        let signature = sourceSnapshot.booksSignature
        let statsKey = StatisticsStatsCacheKey(
            selectedYear: selectedYear,
            scope: scope,
            booksSignature: signature
        )
        let activitySignature = heatmapActivitySignature(
            for: activityMetric,
            booksSignature: signature
        )
        let heatmapKey = activitySignature.map { activitySignature in
            StatisticsHeatmapCacheKey(
                selectedYear: selectedYear,
                scope: scope,
                activityMetric: activityMetric,
                booksSignature: signature,
                activitySignature: activitySignature
            )
        }
        let exactStatsCache = statsCache?.key == statsKey ? statsCache : nil
        let sourceStatsCache = statsCache?.key.booksSignature == signature ? statsCache : nil
        let scopeStatsCache = makeScopeStatsCache(signature: signature, scope: scope)
        let exactHeatmapCache: StatisticsHeatmapCache?
        if let heatmapKey {
            exactHeatmapCache = heatmapCache?.key == heatmapKey ? heatmapCache : nil
        } else {
            exactHeatmapCache = nil
        }

        let heatmapDecision: CacheDecision
        if let heatmapKey {
            heatmapDecision = cacheDecision(
                desiredKey: heatmapKey,
                cachedKey: heatmapCache?.key,
                exactCacheAvailable: exactHeatmapCache != nil,
                isUpdating: isUpdatingHeatmapCache || isUpdatingSessionSource
            )
        } else if isUpdatingSessionSource {
            heatmapDecision = .updating
        } else {
            heatmapDecision = .missing
        }

        return ViewState(
            booksSignature: signature,
            sourceSnapshot: sourceSnapshot,
            statsKey: statsKey,
            heatmapKey: heatmapKey,
            exactStatsCache: exactStatsCache,
            scopeStatsCache: scopeStatsCache,
            exactHeatmapCache: exactHeatmapCache,
            statsDecision: cacheDecision(
                desiredKey: statsKey,
                cachedKey: statsCache?.key,
                exactCacheAvailable: exactStatsCache != nil,
                isUpdating: isUpdatingStatsCache
            ),
            heatmapDecision: heatmapDecision,
            yearOptions: sourceStatsCache?.summary.yearOptions ?? [selectedYear],
            sessionSourceRequestToken: sessionSourceRequestToken(
                for: activityMetric,
                booksSignature: signature
            )
        )
    }

    func refreshStatsCache(
        for key: StatisticsStatsCacheKey,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async {
        guard statsCache?.key != key else { return }
        guard let sourceSnapshot, sourceSnapshot.booksSignature == key.booksSignature else { return }

        isUpdatingStatsCache = true
        defer { isUpdatingStatsCache = false }

        let pipeline = StatisticsComputePipeline(source: sourceSnapshot, now: now, calendar: calendar)
        let cache = await PerformanceSignposter.measureAsync("Statistics Stats Cache Refresh") {
            await pipeline.makeStatsCache(for: key)
        }
        guard !Task.isCancelled else { return }
        guard self.sourceSnapshot?.booksSignature == key.booksSignature else { return }
        statsCache = cache
    }

    func refreshHeatmapCache(
        for key: StatisticsHeatmapCacheKey,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async {
        guard heatmapCache?.key != key else { return }
        guard let sourceSnapshot, sourceSnapshot.booksSignature == key.booksSignature else { return }

        let sessionSource = matchingSessionSource(for: key)
        if key.activityMetric == .readingMinutes, sessionSource == nil {
            return
        }

        isUpdatingHeatmapCache = true
        defer { isUpdatingHeatmapCache = false }

        let pipeline = StatisticsComputePipeline(
            source: sourceSnapshot,
            sessionSource: sessionSource,
            now: now,
            calendar: calendar
        )
        let cache = await PerformanceSignposter.measureAsync("Statistics Heatmap Cache Refresh") {
            await pipeline.makeHeatmapCache(for: key)
        }
        guard !Task.isCancelled else { return }
        guard self.sourceSnapshot?.booksSignature == key.booksSignature else { return }
        if key.activityMetric == .readingMinutes {
            guard matchingSessionSource(for: key) != nil else { return }
        }
        heatmapCache = cache
    }

    func reset() {
        observedBooks = []
        sourceSnapshot = nil
        sessionSourceSnapshot = nil
        statsCache = nil
        heatmapCache = nil
        isUpdatingStatsCache = false
        isUpdatingHeatmapCache = false
        isUpdatingSessionSource = false
        sessionSourceNeedsRefresh = false
    }

    @discardableResult
    private func updateSource(signature: Int, books: [Book]) -> StatisticsSourceSnapshot {
        if let sourceSnapshot, sourceSnapshot.booksSignature == signature {
            return sourceSnapshot
        }

        let snapshot = StatisticsSourceSnapshot(signature: signature, books: books)
        sourceSnapshot = snapshot

        return snapshot
    }

    @discardableResult
    private func updateSessionSource(
        booksSignature: Int,
        scopeSignature: Int,
        sessionsSignature: Int,
        books: [Book],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> StatisticsSessionSourceSnapshot {
        if let sessionSourceSnapshot,
           sessionSourceSnapshot.scopeSignature == scopeSignature,
           sessionSourceSnapshot.sessionsSignature == sessionsSignature {
            if sessionSourceSnapshot.booksSignature == booksSignature {
                sessionSourceNeedsRefresh = false
                return sessionSourceSnapshot
            }
            let rebased = sessionSourceSnapshot.rebased(booksSignature: booksSignature)
            self.sessionSourceSnapshot = rebased
            sessionSourceNeedsRefresh = false
            return rebased
        }

        let snapshot = StatisticsSessionSourceSnapshot(
            booksSignature: booksSignature,
            scopeSignature: scopeSignature,
            sessionsSignature: sessionsSignature,
            books: books,
            now: now,
            calendar: calendar
        )
        completedSessionSourceBuildCount += 1
        sessionSourceSnapshot = snapshot
        sessionSourceNeedsRefresh = false
        return snapshot
    }

    private func makeScopeStatsCache(
        signature: Int,
        scope: StatisticsScope
    ) -> StatisticsStatsCache? {
        guard let statsCache,
              statsCache.key.scope == scope,
              statsCache.key.booksSignature == signature else {
            return nil
        }
        return statsCache
    }

    private func heatmapActivitySignature(
        for activityMetric: StatisticsActivityMetric,
        booksSignature: Int
    ) -> Int? {
        guard activityMetric == .readingMinutes else {
            return booksSignature
        }
        guard sessionSourceNeedsRefresh == false else {
            return nil
        }
        guard let sessionSourceSnapshot,
              sessionSourceSnapshot.booksSignature == booksSignature else {
            return nil
        }
        return sessionSourceSnapshot.sessionsSignature
    }

    private func sessionSourceRequestToken(
        for activityMetric: StatisticsActivityMetric,
        booksSignature: Int
    ) -> Int? {
        guard activityMetric == .readingMinutes else { return nil }
        if sessionSourceNeedsRefresh == false,
           sessionSourceSnapshot?.booksSignature == booksSignature {
            return nil
        }

        return booksSignature &* 31 &+ sessionInvalidationGeneration
    }

    private func matchingSessionSource(
        for key: StatisticsHeatmapCacheKey
    ) -> StatisticsSessionSourceSnapshot? {
        guard key.activityMetric == .readingMinutes else {
            return nil
        }
        guard let sessionSourceSnapshot,
              sessionSourceNeedsRefresh == false,
              sessionSourceSnapshot.booksSignature == key.booksSignature,
              sessionSourceSnapshot.sessionsSignature == key.activitySignature else {
            return nil
        }
        return sessionSourceSnapshot
    }

    private func cacheDecision<Key: Equatable>(
        desiredKey: Key,
        cachedKey: Key?,
        exactCacheAvailable: Bool,
        isUpdating: Bool
    ) -> CacheDecision {
        if exactCacheAvailable {
            return .reusable
        }
        if isUpdating {
            return .updating
        }
        if cachedKey != nil {
            return .stale
        }
        return .missing
    }
}

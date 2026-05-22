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
    }

    @Published private(set) var sourceSnapshot: StatisticsSourceSnapshot?
    @Published private(set) var statsCache: StatisticsStatsCache?
    @Published private(set) var heatmapCache: StatisticsHeatmapCache?
    @Published private(set) var isUpdatingStatsCache = false
    @Published private(set) var isUpdatingHeatmapCache = false

    private var trackingGeneration = 0
    private var observedBooks: [Book] = []

    var currentBooksSignature: Int? {
        sourceSnapshot?.booksSignature
    }

    func refreshSourceAndTrack(books: [Book]) {
        observedBooks = books
        refreshObservedBooksAndTrack()
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
                yearOptions: [selectedYear]
            )
        }

        let signature = sourceSnapshot.booksSignature
        let statsKey = StatisticsStatsCacheKey(
            selectedYear: selectedYear,
            scope: scope,
            booksSignature: signature
        )
        let heatmapKey = StatisticsHeatmapCacheKey(
            selectedYear: selectedYear,
            scope: scope,
            activityMetric: activityMetric,
            booksSignature: signature
        )
        let exactStatsCache = statsCache?.key == statsKey ? statsCache : nil
        let sourceStatsCache = statsCache?.key.booksSignature == signature ? statsCache : nil
        let scopeStatsCache = makeScopeStatsCache(signature: signature, scope: scope)
        let exactHeatmapCache = heatmapCache?.key == heatmapKey ? heatmapCache : nil

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
            heatmapDecision: cacheDecision(
                desiredKey: heatmapKey,
                cachedKey: heatmapCache?.key,
                exactCacheAvailable: exactHeatmapCache != nil,
                isUpdating: isUpdatingHeatmapCache
            ),
            yearOptions: sourceStatsCache?.summary.yearOptions ?? [selectedYear]
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
        let cache = await pipeline.makeStatsCache(for: key)
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

        isUpdatingHeatmapCache = true
        defer { isUpdatingHeatmapCache = false }

        let pipeline = StatisticsComputePipeline(source: sourceSnapshot, now: now, calendar: calendar)
        let cache = await pipeline.makeHeatmapCache(for: key)
        guard !Task.isCancelled else { return }
        guard self.sourceSnapshot?.booksSignature == key.booksSignature else { return }
        heatmapCache = cache
    }

    func reset() {
        observedBooks = []
        sourceSnapshot = nil
        statsCache = nil
        heatmapCache = nil
        isUpdatingStatsCache = false
        isUpdatingHeatmapCache = false
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

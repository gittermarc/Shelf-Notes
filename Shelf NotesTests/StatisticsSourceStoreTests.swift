import Foundation
import Testing
@testable import Shelf_Notes

struct StatisticsSourceStoreTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        ) ?? .distantPast
    }

    @MainActor
    private func makeFinishedBook(
        title: String = "Alpha",
        author: String = "Ada",
        readFrom: Date? = nil,
        readTo: Date? = nil,
        pageCount: Int = 320
    ) -> Book {
        let book = Book(title: title, author: author, status: .finished, tags: ["Crime"])
        book.readFrom = readFrom ?? date(2026, 1, 1)
        book.readTo = readTo ?? date(2026, 1, 5)
        book.pageCount = pageCount
        book.publisher = "Pub A"
        book.language = "DE"
        book.categories = ["Fiction / Thriller / Noir"]
        book.mainCategory = "Fiction / Thriller / Noir"
        book.userRatingPlot = 5
        book.userRatingCharacters = 4
        book.userRatingWritingStyle = 4
        book.userRatingAtmosphere = 5
        book.userRatingGenreFit = 5
        book.userRatingPresentation = 4
        return book
    }

    @MainActor
    @Test func bookSignatureChangesForRelevantBookMutations() {
        let book = makeFinishedBook()
        let initial = StatisticsSourceStore.booksSignature([book])

        book.pageCount = 444
        let afterPageChange = StatisticsSourceStore.booksSignature([book])

        book.readTo = date(2026, 2, 3)
        let afterDateChange = StatisticsSourceStore.booksSignature([book])

        book.status = .reading
        let afterStatusChange = StatisticsSourceStore.booksSignature([book])

        #expect(afterPageChange != initial)
        #expect(afterDateChange != afterPageChange)
        #expect(afterStatusChange != afterDateChange)
    }

    @MainActor
    @Test func bookSignatureStaysStableWhenOnlyReadingSessionChanges() {
        let book = makeFinishedBook()
        let session = ReadingSession(
            book: book,
            startedAt: date(2026, 1, 2, 20, 0),
            endedAt: date(2026, 1, 2, 21, 0),
            pagesRead: 40
        )
        book.readingSessionsSafe = [session]

        let initial = StatisticsSourceStore.booksSignature([book])

        session.endedAt = date(2026, 1, 2, 21, 30)
        session.recomputeDuration()
        let changed = StatisticsSourceStore.booksSignature([book])

        #expect(changed == initial)
    }

    @MainActor
    @Test func sessionSignatureChangesWhenReadingSessionChanges() {
        let book = makeFinishedBook()
        let session = ReadingSession(
            book: book,
            startedAt: date(2026, 1, 2, 20, 0),
            endedAt: date(2026, 1, 2, 21, 0),
            pagesRead: 40
        )
        book.readingSessionsSafe = [session]

        let initial = StatisticsSourceStore.sessionsSignature([book])

        session.endedAt = date(2026, 1, 2, 21, 30)
        session.recomputeDuration()
        let changed = StatisticsSourceStore.sessionsSignature([book])

        #expect(changed != initial)
    }

    @MainActor
    @Test func sessionSignatureChangesWhenPagesChange() {
        let book = makeFinishedBook()
        let session = ReadingSession(
            book: book,
            startedAt: date(2026, 1, 2, 20, 0),
            endedAt: date(2026, 1, 2, 21, 0),
            pagesRead: 40
        )
        book.readingSessionsSafe = [session]

        let initial = StatisticsSourceStore.sessionsSignature([book])

        session.pagesRead = 70
        let changed = StatisticsSourceStore.sessionsSignature([book])

        #expect(changed != initial)
    }

    @MainActor
    @Test func bookSignatureStaysStableForSameBooksInDifferentOrder() {
        let first = makeFinishedBook(title: "Alpha", author: "Ada")
        let second = makeFinishedBook(title: "Beta", author: "Bea", readTo: date(2026, 2, 8), pageCount: 210)

        let left = StatisticsSourceStore.booksSignature([first, second])
        let right = StatisticsSourceStore.booksSignature([second, first])

        #expect(left == right)
    }

    @MainActor
    @Test func storeReusesSnapshotAndCacheDecisionsForSameSignature() async throws {
        let book = makeFinishedBook()
        let store = StatisticsSourceStore()
        store.refreshSourceAndTrack(books: [book])

        let initialState = store.makeViewState(
            selectedYear: 2026,
            scope: .all,
            activityMetric: .readingDays
        )
        let initialSignature = initialState.booksSignature
        let statsKey = try #require(initialState.statsKey)
        let heatmapKey = try #require(initialState.heatmapKey)

        await store.refreshStatsCache(for: statsKey, now: date(2026, 4, 15), calendar: calendar)
        await store.refreshHeatmapCache(for: heatmapKey, now: date(2026, 4, 15), calendar: calendar)

        store.refreshSourceAndTrack(books: [book])
        let reusedState = store.makeViewState(
            selectedYear: 2026,
            scope: .all,
            activityMetric: .readingDays
        )

        #expect(reusedState.booksSignature == initialSignature)
        #expect(reusedState.statsDecision == .reusable)
        #expect(reusedState.heatmapDecision == .reusable)
        #expect(reusedState.exactStatsCache?.key == statsKey)
        #expect(reusedState.exactHeatmapCache?.key == heatmapKey)
    }

    @MainActor
    @Test func storeInvalidatesStatsDecisionForScopeAndYearSwitches() async throws {
        let book = makeFinishedBook()
        let store = StatisticsSourceStore()
        store.refreshSourceAndTrack(books: [book])

        let baseState = store.makeViewState(
            selectedYear: 2026,
            scope: .all,
            activityMetric: .readingDays
        )
        let statsKey = try #require(baseState.statsKey)
        await store.refreshStatsCache(for: statsKey, now: date(2026, 4, 15), calendar: calendar)

        let sameState = store.makeViewState(
            selectedYear: 2026,
            scope: .all,
            activityMetric: .readingDays
        )
        let yearChanged = store.makeViewState(
            selectedYear: 2027,
            scope: .all,
            activityMetric: .readingDays
        )
        let scopeChanged = store.makeViewState(
            selectedYear: 2026,
            scope: .finished,
            activityMetric: .readingDays
        )

        #expect(sameState.statsDecision == .reusable)
        #expect(yearChanged.statsDecision == .stale)
        #expect(scopeChanged.statsDecision == .stale)
        #expect(yearChanged.statsKey != sameState.statsKey)
        #expect(scopeChanged.statsKey != sameState.statsKey)
    }

    @MainActor
    @Test func storeInvalidatesHeatmapDecisionForMetricSwitches() async throws {
        let book = makeFinishedBook()
        let store = StatisticsSourceStore()
        store.refreshSourceAndTrack(books: [book])

        let baseState = store.makeViewState(
            selectedYear: 2026,
            scope: .all,
            activityMetric: .readingDays
        )
        let heatmapKey = try #require(baseState.heatmapKey)
        await store.refreshHeatmapCache(for: heatmapKey, now: date(2026, 4, 15), calendar: calendar)

        let sameState = store.makeViewState(
            selectedYear: 2026,
            scope: .all,
            activityMetric: .readingDays
        )
        let metricChanged = store.makeViewState(
            selectedYear: 2026,
            scope: .all,
            activityMetric: .readingMinutes
        )

        #expect(sameState.heatmapDecision == .reusable)
        #expect(metricChanged.heatmapDecision == .missing)
        #expect(metricChanged.heatmapKey == nil)
        #expect(metricChanged.sessionSourceRequestToken != nil)
    }

    @MainActor
    @Test func storeInvalidatesCacheDecisionWhenBookSignatureChanges() async throws {
        let book = makeFinishedBook()
        let store = StatisticsSourceStore()
        store.refreshSourceAndTrack(books: [book])

        let baseState = store.makeViewState(
            selectedYear: 2026,
            scope: .all,
            activityMetric: .readingDays
        )
        let statsKey = try #require(baseState.statsKey)
        await store.refreshStatsCache(for: statsKey, now: date(2026, 4, 15), calendar: calendar)

        book.readTo = date(2026, 3, 9)
        store.refreshSourceAndTrack(books: [book])

        let changedState = store.makeViewState(
            selectedYear: 2026,
            scope: .all,
            activityMetric: .readingDays
        )

        #expect(changedState.booksSignature != baseState.booksSignature)
        #expect(changedState.statsKey != baseState.statsKey)
        #expect(changedState.statsDecision == .stale)
    }
    @MainActor
    @Test func readingMinutesHeatmapUsesSeparateSessionSignature() throws {
        let book = makeFinishedBook()
        let session = ReadingSession(
            book: book,
            startedAt: date(2026, 1, 2, 20, 0),
            endedAt: date(2026, 1, 2, 21, 0),
            pagesRead: 40
        )
        book.readingSessionsSafe = [session]

        let store = StatisticsSourceStore()
        store.refreshSourceAndTrack(books: [book])

        let readingDaysState = store.makeViewState(
            selectedYear: 2026,
            scope: .all,
            activityMetric: .readingDays
        )
        #expect(readingDaysState.heatmapKey != nil)
        #expect(readingDaysState.sessionSourceRequestToken == nil)

        let waitingState = store.makeViewState(
            selectedYear: 2026,
            scope: .all,
            activityMetric: .readingMinutes
        )
        #expect(waitingState.heatmapKey == nil)
        #expect(waitingState.sessionSourceRequestToken != nil)

        store.refreshSessionSourceAndTrack(books: [book])
        let readyState = store.makeViewState(
            selectedYear: 2026,
            scope: .all,
            activityMetric: .readingMinutes
        )
        let readyHeatmapKey = try #require(readyState.heatmapKey)
        let readyStatsKey = try #require(readyState.statsKey)
        let readyBooksSignature = try #require(readyState.booksSignature)

        #expect(readyHeatmapKey.booksSignature == readyBooksSignature)
        #expect(readyHeatmapKey.activitySignature == StatisticsSourceStore.sessionsSignature([book]))
        #expect(readyStatsKey.booksSignature == readyBooksSignature)

        session.endedAt = date(2026, 1, 2, 21, 30)
        session.recomputeDuration()
        store.invalidateSessionSource()
        store.refreshSessionSourceAndTrack(books: [book])

        let changedState = store.makeViewState(
            selectedYear: 2026,
            scope: .all,
            activityMetric: .readingMinutes
        )
        let changedHeatmapKey = try #require(changedState.heatmapKey)

        #expect(changedState.booksSignature == readyBooksSignature)
        #expect(changedState.statsKey == readyStatsKey)
        #expect(changedHeatmapKey.booksSignature == readyHeatmapKey.booksSignature)
        #expect(changedHeatmapKey.activitySignature != readyHeatmapKey.activitySignature)
    }

    @MainActor
    @Test func bookOnlyChangeRebasesSessionSourceWithoutAggregateRebuild() throws {
        let book = makeFinishedBook()
        let session = ReadingSession(
            book: book,
            startedAt: date(2026, 1, 2, 20, 0),
            endedAt: date(2026, 1, 2, 21, 0),
            pagesRead: 40
        )
        book.readingSessionsSafe = [session]

        let store = StatisticsSourceStore()
        store.refreshSourceAndTrack(books: [book])
        store.refreshSessionSourceAndTrack(books: [book])
        let firstSnapshot = try #require(store.sessionSourceSnapshot)
        let firstBuildCount = store.completedSessionSourceBuildCount

        book.title = "Only Display Title Changed"
        store.refreshSourceAndTrack(books: [book])
        let changedState = store.makeViewState(
            selectedYear: 2026,
            scope: .all,
            activityMetric: .readingMinutes
        )

        #expect(changedState.sessionSourceRequestToken != nil)

        store.refreshSessionSourceAndTrack(books: [book])
        let rebasedSnapshot = try #require(store.sessionSourceSnapshot)

        #expect(store.completedSessionSourceBuildCount == firstBuildCount)
        #expect(rebasedSnapshot.booksSignature != firstSnapshot.booksSignature)
        #expect(rebasedSnapshot.scopeSignature == firstSnapshot.scopeSignature)
        #expect(rebasedSnapshot.sessionsSignature == firstSnapshot.sessionsSignature)
        #expect(rebasedSnapshot.aggregates == firstSnapshot.aggregates)
    }

    @MainActor
    @Test func sessionChangeInvalidatesOnlySessionRelevantCaches() async throws {
        let book = makeFinishedBook()
        let session = ReadingSession(
            book: book,
            startedAt: date(2026, 1, 2, 20, 0),
            endedAt: date(2026, 1, 2, 21, 0),
            pagesRead: 40
        )
        book.readingSessionsSafe = [session]

        let store = StatisticsSourceStore()
        store.refreshSourceAndTrack(books: [book])
        let baseState = store.makeViewState(
            selectedYear: 2026,
            scope: .all,
            activityMetric: .readingDays
        )
        let statsKey = try #require(baseState.statsKey)
        await store.refreshStatsCache(for: statsKey, now: date(2026, 4, 15), calendar: calendar)

        let cachedStatsKey = store.statsCache?.key
        store.invalidateSessionSource()

        #expect(store.statsCache?.key == cachedStatsKey)
        #expect(store.sessionSourceSnapshot == nil)

        let afterInvalidation = store.makeViewState(
            selectedYear: 2026,
            scope: .all,
            activityMetric: .readingDays
        )
        #expect(afterInvalidation.statsDecision == .reusable)
        #expect(afterInvalidation.sessionSourceRequestToken == nil)
    }

    @MainActor
    @Test func markedStaleSessionSourceRefreshesOnlyWhenMetricNeedsSessions() throws {
        let book = makeFinishedBook()
        let session = ReadingSession(
            book: book,
            startedAt: date(2026, 1, 2, 20, 0),
            endedAt: date(2026, 1, 2, 21, 0),
            pagesRead: 40
        )
        book.readingSessionsSafe = [session]

        let store = StatisticsSourceStore()
        store.refreshSourceAndTrack(books: [book])
        store.refreshSessionSourceAndTrack(books: [book])
        let existingSource = try #require(store.sessionSourceSnapshot)

        store.markSessionSourceStale()

        let readingDaysState = store.makeViewState(
            selectedYear: 2026,
            scope: .all,
            activityMetric: .readingDays
        )
        let readingMinutesState = store.makeViewState(
            selectedYear: 2026,
            scope: .all,
            activityMetric: .readingMinutes
        )

        #expect(store.sessionSourceSnapshot?.sessionsSignature == existingSource.sessionsSignature)
        #expect(readingDaysState.sessionSourceRequestToken == nil)
        #expect(readingMinutesState.sessionSourceRequestToken != nil)
        #expect(readingMinutesState.heatmapKey == nil)
    }

    @MainActor
    @Test func largeFixtureBuildsSessionAggregatesForStatsAndProgress() async throws {
        let fixture = LargeReadingDatasetBuilder.make1000BookMixedDataset()
        let store = StatisticsSourceStore()

        store.refreshSourceAndTrack(books: fixture.books)
        store.refreshSessionSourceAndTrack(
            books: fixture.books,
            now: fixture.now,
            calendar: fixture.calendar
        )

        let sessionSource = try #require(store.sessionSourceSnapshot)
        #expect(store.completedSessionSourceBuildCount == 1)
        #expect(sessionSource.aggregates.totalSessionCount == fixture.sessions.count)
        #expect(sessionSource.aggregates.recentActivity.minutesLast7 > 0)
        #expect(sessionSource.aggregates.booksByID.isEmpty == false)
        #expect(sessionSource.aggregates.yearsByYear.isEmpty == false)

        let state = store.makeViewState(
            selectedYear: 2026,
            scope: .all,
            activityMetric: .readingMinutes
        )
        let heatmapKey = try #require(state.heatmapKey)
        await store.refreshHeatmapCache(for: heatmapKey, now: fixture.now, calendar: fixture.calendar)

        #expect(store.heatmapCache?.key == heatmapKey)
        #expect(store.heatmapCache?.counts.isEmpty == false)
    }

}

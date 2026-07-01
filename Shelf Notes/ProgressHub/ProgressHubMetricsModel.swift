//
//  ProgressHubMetricsModel.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 24.02.26.
//  P0.2: Cache ProgressHub hero metrics (keeps O(n)/O(m) aggregations out of the render path).
//

import Foundation
import Combine
import Observation
import SwiftData

@MainActor
final class ProgressHubMetricsModel: ObservableObject {

    // MARK: - Types

    struct Metrics: Equatable {
        let year: Int
        let finishedThisYear: Int
        let goalTarget: Int?
        let minutesLast7: Int
        let activeDaysLast7: Int
        let currentStreak: Int

        static func placeholder(year: Int) -> Metrics {
            Metrics(
                year: year,
                finishedThisYear: 0,
                goalTarget: nil,
                minutesLast7: 0,
                activeDaysLast7: 0,
                currentStreak: 0
            )
        }
    }

    struct SourceRefreshToken: Hashable {
        let year: Int
        let bookCount: Int
        let goalCount: Int
    }

    /// Small, Hashable input token retained for tests and compatibility. The SwiftUI view no longer builds it.
    struct InputToken: Hashable {
        let year: Int
        let booksSignature: UInt64
        let goalsSignature: UInt64
        let sessionsSignature: UInt64
    }

    nonisolated struct GoalSnapshot: Hashable, Sendable {
        let year: Int
        let targetCount: Int
        let updatedAt: Date

        @MainActor init(goal: ReadingGoal) {
            self.year = goal.year
            self.targetCount = goal.targetCount
            self.updatedAt = goal.updatedAt
        }
    }

    nonisolated struct SourceSnapshot: Sendable {
        let year: Int
        let booksSignature: UInt64
        let goalsSignature: UInt64
        let bookRecords: [ReadingAnalyticsBookRecord]
        let goals: [GoalSnapshot]
    }

    // MARK: - State

    @Published private(set) var metrics: Metrics

    private var lastToken: InputToken?
    private var sourceSnapshot: SourceSnapshot?
    private var observedBooks: [Book] = []
    private var observedGoals: [ReadingGoal] = []
    private var observedModelContext: ModelContext?
    private var trackingGeneration = 0
    private var sessionRefreshTask: Task<Void, Never>?

    init() {
        let year = Calendar.current.component(.year, from: Date())
        self.metrics = Metrics.placeholder(year: year)
    }

    deinit {
        sessionRefreshTask?.cancel()
    }

    // MARK: - Public API

    static func makeRefreshToken(
        year: Int,
        books: [Book],
        goals: [ReadingGoal]
    ) -> SourceRefreshToken {
        SourceRefreshToken(
            year: year,
            bookCount: books.count,
            goalCount: goals.count
        )
    }

    static func makeInputToken(
        year: Int,
        books: [Book],
        goals: [ReadingGoal],
        sessionRefreshSeed: Int
    ) -> InputToken {
        InputToken(
            year: year,
            booksSignature: computeBooksSignature(books: books),
            goalsSignature: computeGoalsSignature(goals: goals),
            sessionsSignature: UInt64(bitPattern: Int64(sessionRefreshSeed))
        )
    }

    func refreshSourceAndTrack(
        year: Int,
        books: [Book],
        goals: [ReadingGoal],
        modelContext: ModelContext
    ) {
        observedBooks = books
        observedGoals = goals
        observedModelContext = modelContext
        trackingGeneration += 1
        let generation = trackingGeneration

        let snapshot = withObservationTracking {
            Self.makeSourceSnapshot(year: year, books: observedBooks, goals: observedGoals)
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.trackingGeneration == generation else { return }
                guard let modelContext = self.observedModelContext else { return }
                self.refreshSourceAndTrack(
                    year: year,
                    books: self.observedBooks,
                    goals: self.observedGoals,
                    modelContext: modelContext
                )
            }
        }

        let oldSnapshot = sourceSnapshot
        sourceSnapshot = snapshot

        let sourceChanged = oldSnapshot?.year != snapshot.year
            || oldSnapshot?.booksSignature != snapshot.booksSignature
            || oldSnapshot?.goalsSignature != snapshot.goalsSignature

        if sourceChanged || lastToken == nil {
            refreshSessionMetrics(modelContext: modelContext)
        }
    }

    func requestSessionMetricsRefresh(modelContext: ModelContext) {
        observedModelContext = modelContext
        sessionRefreshTask?.cancel()
        sessionRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            guard let self, let modelContext = self.observedModelContext else { return }
            self.refreshSessionMetrics(modelContext: modelContext)
        }
    }

    func recompute(
        year: Int,
        books: [Book],
        goals: [ReadingGoal],
        modelContext: ModelContext
    ) {
        let source = Self.makeSourceSnapshot(year: year, books: books, goals: goals)
        sourceSnapshot = source
        refreshSessionMetrics(modelContext: modelContext)
    }

    static func makeMetrics(
        year: Int,
        books: [Book],
        goals: [ReadingGoal],
        recentActivity: ReadingAnalyticsRecentActivity,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Metrics {
        makeMetrics(
            year: year,
            bookRecords: ReadingAnalyticsInputMapper.bookRecords(from: books),
            goals: goals.map { GoalSnapshot(goal: $0) },
            recentActivity: recentActivity,
            now: now,
            calendar: calendar
        )
    }

    nonisolated static func makeMetrics(
        year: Int,
        bookRecords: [ReadingAnalyticsBookRecord],
        goals: [GoalSnapshot],
        recentActivity: ReadingAnalyticsRecentActivity,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Metrics {
        let analyticsIndex = ReadingAnalyticsIndexBuilder.make(
            books: bookRecords,
            sessions: [],
            now: now,
            calendar: calendar
        )
        let yearSummary = analyticsIndex.summary(forYear: year)
        let goalTarget = goals.first(where: { $0.year == year })?.targetCount

        return Metrics(
            year: year,
            finishedThisYear: yearSummary.finishedBookCount,
            goalTarget: goalTarget,
            minutesLast7: recentActivity.minutesLast7,
            activeDaysLast7: recentActivity.activeDaysLast7,
            currentStreak: recentActivity.currentStreak
        )
    }

    // MARK: - Refresh pipeline

    private func refreshSessionMetrics(modelContext: ModelContext) {
        guard let sourceSnapshot else {
            let year = Calendar.current.component(.year, from: Date())
            metrics = .placeholder(year: year)
            return
        }

        PerformanceSignposter.measure("ProgressHub Metrics Refresh") {
            let sessionSnapshot = ProgressHubSessionMetricsProvider.makeSnapshot(
                modelContext: modelContext
            )
            let token = InputToken(
                year: sourceSnapshot.year,
                booksSignature: sourceSnapshot.booksSignature,
                goalsSignature: sourceSnapshot.goalsSignature,
                sessionsSignature: sessionSnapshot.signature
            )
            guard token != lastToken else { return }
            lastToken = token

            let newMetrics = Self.makeMetrics(
                year: sourceSnapshot.year,
                bookRecords: sourceSnapshot.bookRecords,
                goals: sourceSnapshot.goals,
                recentActivity: sessionSnapshot.recentActivity
            )

            if newMetrics != metrics {
                metrics = newMetrics
            }
        }
    }

    private static func makeSourceSnapshot(
        year: Int,
        books: [Book],
        goals: [ReadingGoal]
    ) -> SourceSnapshot {
        let bookRecords = ReadingAnalyticsInputMapper.bookRecords(from: books)
        let goalSnapshots = goals.map { GoalSnapshot(goal: $0) }
        return SourceSnapshot(
            year: year,
            booksSignature: computeBookRecordSignature(bookRecords),
            goalsSignature: computeGoalSnapshotSignature(goalSnapshots),
            bookRecords: bookRecords,
            goals: goalSnapshots
        )
    }

    // MARK: - Signatures

    private static func computeBooksSignature(books: [Book]) -> UInt64 {
        computeBookRecordSignature(ReadingAnalyticsInputMapper.bookRecords(from: books))
    }

    private static func computeGoalsSignature(goals: [ReadingGoal]) -> UInt64 {
        computeGoalSnapshotSignature(goals.map { GoalSnapshot(goal: $0) })
    }

    private nonisolated static func computeBookRecordSignature(_ records: [ReadingAnalyticsBookRecord]) -> UInt64 {
        var aggregate: UInt64 = 0xD6E8_FEB8_6659_FD93
        aggregate &+= UInt64(records.count) &* 0xBF58_476D_1CE4_E5B9

        for record in records.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            var hasher = Hasher()
            hasher.combine(record.id)
            hasher.combine(record.statusRawValue)
            hasher.combine(record.createdAt.timeIntervalSinceReferenceDate)
            hasher.combine(record.readFrom?.timeIntervalSinceReferenceDate)
            hasher.combine(record.readTo?.timeIntervalSinceReferenceDate)
            hasher.combine(record.pageCount)

            for completion in record.readingCompletions {
                hasher.combine(completion.id)
                hasher.combine(completion.bookID)
                hasher.combine(completion.finishedAt.timeIntervalSinceReferenceDate)
                hasher.combine(completion.pageCount)
                hasher.combine(completion.isReread)
            }

            let hash = UInt64(bitPattern: Int64(hasher.finalize()))
            aggregate ^= hash &+ 0x9E37_79B9_7F4A_7C15 &+ (aggregate << 6) &+ (aggregate >> 2)
        }
        return aggregate
    }

    private nonisolated static func computeGoalSnapshotSignature(_ goals: [GoalSnapshot]) -> UInt64 {
        var aggregate: UInt64 = 0xA5A3_56D7_6F7A_19D3
        aggregate &+= UInt64(goals.count) &* 0x94D0_49BB_1331_11EB

        for goal in goals.sorted(by: { $0.year < $1.year }) {
            var hasher = Hasher()
            hasher.combine(goal.year)
            hasher.combine(goal.targetCount)
            hasher.combine(goal.updatedAt.timeIntervalSinceReferenceDate)
            let hash = UInt64(bitPattern: Int64(hasher.finalize()))
            aggregate ^= hash &+ 0x9E37_79B9_7F4A_7C15 &+ (aggregate << 6) &+ (aggregate >> 2)
        }
        return aggregate
    }

}

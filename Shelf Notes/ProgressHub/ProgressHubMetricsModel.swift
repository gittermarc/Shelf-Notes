//
//  ProgressHubMetricsModel.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 24.02.26.
//  P0.2: Cache ProgressHub hero metrics (keeps O(n)/O(m) aggregations out of the render path).
//

import Foundation
import Combine

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

    /// Small, Hashable input token used by `.task(id:)` to run recomputation only when needed.
    struct InputToken: Hashable {
        let year: Int
        let booksSignature: UInt64
        let goalsSignature: UInt64
        let sessionsSignature: UInt64
    }

    // MARK: - State

    @Published private(set) var metrics: Metrics

    private var lastToken: InputToken?

    init() {
        let year = Calendar.current.component(.year, from: Date())
        self.metrics = Metrics.placeholder(year: year)
    }

    // MARK: - Public API

    static func makeInputToken(
        year: Int,
        books: [Book],
        goals: [ReadingGoal],
        sessions: [ReadingSession]
    ) -> InputToken {
        InputToken(
            year: year,
            booksSignature: computeBooksSignature(books: books),
            goalsSignature: computeGoalsSignature(goals: goals),
            sessionsSignature: computeSessionsSignature(sessions: sessions)
        )
    }

    func recompute(
        year: Int,
        books: [Book],
        goals: [ReadingGoal],
        sessions: [ReadingSession]
    ) {
        let token = Self.makeInputToken(year: year, books: books, goals: goals, sessions: sessions)
        guard token != lastToken else { return }
        lastToken = token

        let newMetrics = Self.makeMetrics(
            year: year,
            books: books,
            goals: goals,
            sessions: sessions
        )

        if newMetrics != metrics {
            metrics = newMetrics
        }
    }

    static func makeMetrics(
        year: Int,
        books: [Book],
        goals: [ReadingGoal],
        sessions: [ReadingSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Metrics {
        let analyticsIndex = ReadingAnalyticsIndexBuilder.make(
            books: ReadingAnalyticsInputMapper.bookRecords(from: books),
            sessions: ReadingAnalyticsInputMapper.sessionRecords(from: sessions),
            now: now,
            calendar: calendar
        )
        let yearSummary = analyticsIndex.summary(forYear: year)
        let goalTarget = goals.first(where: { $0.year == year })?.targetCount
        let recentActivity = analyticsIndex.recentActivity

        return Metrics(
            year: year,
            finishedThisYear: yearSummary.finishedBookCount,
            goalTarget: goalTarget,
            minutesLast7: recentActivity.minutesLast7,
            activeDaysLast7: recentActivity.activeDaysLast7,
            currentStreak: recentActivity.currentStreak
        )
    }

    // MARK: - Signatures

    private static func computeBooksSignature(books: [Book]) -> UInt64 {
        var aggregate: UInt64 = 0xD6E8_FEB8_6659_FD93
        aggregate &+= UInt64(books.count) &* 0xBF58_476D_1CE4_E5B9

        for book in books {
            var hasher = Hasher()
            hasher.combine(book.id)
            hasher.combine(book.statusRawValue)
            hasher.combine(book.readFrom?.timeIntervalSinceReferenceDate)
            hasher.combine(book.readTo?.timeIntervalSinceReferenceDate)
            let hash = UInt64(bitPattern: Int64(hasher.finalize()))
            aggregate ^= hash &+ 0x9E37_79B9_7F4A_7C15 &+ (aggregate << 6) &+ (aggregate >> 2)
        }
        return aggregate
    }

    private static func computeGoalsSignature(goals: [ReadingGoal]) -> UInt64 {
        var aggregate: UInt64 = 0xA5A3_56D7_6F7A_19D3
        aggregate &+= UInt64(goals.count) &* 0x94D0_49BB_1331_11EB

        for goal in goals {
            var hasher = Hasher()
            hasher.combine(goal.year)
            hasher.combine(goal.targetCount)
            hasher.combine(goal.updatedAt.timeIntervalSinceReferenceDate)
            let hash = UInt64(bitPattern: Int64(hasher.finalize()))
            aggregate ^= hash &+ 0x9E37_79B9_7F4A_7C15 &+ (aggregate << 6) &+ (aggregate >> 2)
        }
        return aggregate
    }

    private static func computeSessionsSignature(sessions: [ReadingSession]) -> UInt64 {
        var aggregate: UInt64 = 0x1D3D_0A2C_89E3_2B7F
        aggregate &+= UInt64(sessions.count) &* 0xBF58_476D_1CE4_E5B9

        let maxSample = 256
        let sampleCount = min(maxSample, sessions.count)

        if sampleCount == 0 {
            return aggregate
        }

        for index in 0..<sampleCount {
            let session = sessions[index]
            var hasher = Hasher()
            hasher.combine(session.id)
            hasher.combine(session.startedAt.timeIntervalSinceReferenceDate)
            hasher.combine(session.durationSeconds)
            hasher.combine(session.createdAt.timeIntervalSinceReferenceDate)
            let hash = UInt64(bitPattern: Int64(hasher.finalize()))
            aggregate ^= hash &+ 0x9E37_79B9_7F4A_7C15 &+ (aggregate << 6) &+ (aggregate >> 2)
        }

        return aggregate
    }
}

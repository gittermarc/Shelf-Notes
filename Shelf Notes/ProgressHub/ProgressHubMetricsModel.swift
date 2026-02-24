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
        let y = Calendar.current.component(.year, from: Date())
        self.metrics = Metrics.placeholder(year: y)
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

        let goalTarget = goals.first(where: { $0.year == year })?.targetCount
        let finishedCount = Self.computeFinishedBooksCount(in: year, books: books)
        let last7 = Self.computeLast7DaysAndStreak(sessions: sessions)

        let newMetrics = Metrics(
            year: year,
            finishedThisYear: finishedCount,
            goalTarget: goalTarget,
            minutesLast7: last7.minutes,
            activeDaysLast7: last7.activeDays,
            currentStreak: last7.currentStreak
        )

        if newMetrics != metrics {
            metrics = newMetrics
        }
    }

    // MARK: - Implementation

    private static func computeFinishedBooksCount(in year: Int, books: [Book]) -> Int {
        let cal = Calendar.current
        let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date.distantPast
        let end = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? Date.distantFuture

        var count = 0
        for b in books {
            guard b.status == .finished else { continue }
            let key = b.readTo ?? b.readFrom
            guard let d = key else { continue }
            if d >= start && d < end { count += 1 }
        }
        return count
    }

    /// Computes:
    /// - total minutes in the last 7 days
    /// - active reading days in that 7-day window
    /// - current streak from today backwards
    ///
    /// Optimization: sessions are sorted desc by startedAt; we stop scanning once
    /// (a) the streak is already broken AND (b) we passed below the 7-day window.
    private static func computeLast7DaysAndStreak(
        sessions: [ReadingSession]
    ) -> (minutes: Int, activeDays: Int, currentStreak: Int) {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current

        let today = cal.startOfDay(for: Date())
        let windowStart = cal.date(byAdding: .day, value: -6, to: today) ?? today

        var secondsTotal = 0
        var daysWithActivityWindow = Set<Date>()

        var streak = 0
        var expectedStreakDay = today
        var lastCountedStreakDay: Date? = nil
        var streakDone = false

        for s in sessions {
            let dur = max(0, s.durationSeconds)
            if dur <= 0 { continue }

            let day = cal.startOfDay(for: s.startedAt)

            if day >= windowStart {
                secondsTotal += dur
                daysWithActivityWindow.insert(day)
            }

            if streakDone == false {
                if day == expectedStreakDay {
                    if lastCountedStreakDay != day {
                        streak += 1
                        lastCountedStreakDay = day
                        expectedStreakDay = cal.date(byAdding: .day, value: -1, to: expectedStreakDay) ?? expectedStreakDay
                    }
                } else if day < expectedStreakDay {
                    streakDone = true
                }
            }

            if day < windowStart && streakDone {
                break
            }
        }

        let minutes = Int((Double(secondsTotal) / 60.0).rounded())
        return (minutes: minutes, activeDays: daysWithActivityWindow.count, currentStreak: streak)
    }

    private static func computeBooksSignature(books: [Book]) -> UInt64 {
        var aggregate: UInt64 = 0xD6E8_FEB8_6659_FD93
        aggregate &+= UInt64(books.count) &* 0xBF58_476D_1CE4_E5B9

        for b in books {
            var hasher = Hasher()
            hasher.combine(b.id)
            hasher.combine(b.statusRawValue)
            hasher.combine(b.readFrom?.timeIntervalSinceReferenceDate)
            hasher.combine(b.readTo?.timeIntervalSinceReferenceDate)
            let h = UInt64(bitPattern: Int64(hasher.finalize()))
            aggregate ^= h &+ 0x9E37_79B9_7F4A_7C15 &+ (aggregate << 6) &+ (aggregate >> 2)
        }
        return aggregate
    }

    private static func computeGoalsSignature(goals: [ReadingGoal]) -> UInt64 {
        var aggregate: UInt64 = 0xA5A3_56D7_6F7A_19D3
        aggregate &+= UInt64(goals.count) &* 0x94D0_49BB_1331_11EB

        for g in goals {
            var hasher = Hasher()
            hasher.combine(g.year)
            hasher.combine(g.targetCount)
            hasher.combine(g.updatedAt.timeIntervalSinceReferenceDate)
            let h = UInt64(bitPattern: Int64(hasher.finalize()))
            aggregate ^= h &+ 0x9E37_79B9_7F4A_7C15 &+ (aggregate << 6) &+ (aggregate >> 2)
        }
        return aggregate
    }

    private static func computeSessionsSignature(sessions: [ReadingSession]) -> UInt64 {
        var aggregate: UInt64 = 0x1D3D_0A2C_89E3_2B7F
        aggregate &+= UInt64(sessions.count) &* 0xBF58_476D_1CE4_E5B9

        let maxSample = 256
        let sampleCount = min(maxSample, sessions.count)

        if sampleCount == 0 { return aggregate }

        for i in 0..<sampleCount {
            let s = sessions[i]
            var hasher = Hasher()
            hasher.combine(s.id)
            hasher.combine(s.startedAt.timeIntervalSinceReferenceDate)
            hasher.combine(s.durationSeconds)
            hasher.combine(s.createdAt.timeIntervalSinceReferenceDate)
            let h = UInt64(bitPattern: Int64(hasher.finalize()))
            aggregate ^= h &+ 0x9E37_79B9_7F4A_7C15 &+ (aggregate << 6) &+ (aggregate >> 2)
        }

        return aggregate
    }
}

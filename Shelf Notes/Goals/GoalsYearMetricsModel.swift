//
//  GoalsYearMetricsModel.swift
//  Shelf Notes
//
//  Keeps GoalsView yearly metrics out of the SwiftUI render path.
//

import Combine
import Foundation

@MainActor
final class GoalsYearMetricsModel: ObservableObject {
    struct InputToken: Hashable {
        let selectedYear: Int
        let booksSignature: UInt64
        let goalsSignature: UInt64
    }

    @Published private(set) var metrics: GoalsYearMetrics

    private var lastToken: InputToken?

    init(now: Date = Date(), calendar: Calendar = .current) {
        let currentYear = calendar.component(.year, from: now)
        self.metrics = GoalsYearMetrics.placeholder(
            selectedYear: currentYear,
            now: now,
            calendar: calendar
        )
    }

    static func makeInputToken(
        selectedYear: Int,
        books: [Book],
        goals: [ReadingGoal]
    ) -> InputToken {
        InputToken(
            selectedYear: selectedYear,
            booksSignature: computeBooksSignature(books: books),
            goalsSignature: computeGoalsSignature(goals: goals)
        )
    }

    func recompute(
        selectedYear: Int,
        books: [Book],
        goals: [ReadingGoal],
        token providedToken: InputToken? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let token = providedToken ?? Self.makeInputToken(
            selectedYear: selectedYear,
            books: books,
            goals: goals
        )

        guard token != lastToken else {
            return
        }
        lastToken = token

        let newMetrics = GoalsYearMetricsBuilder.make(
            selectedYear: selectedYear,
            books: books,
            goals: goals,
            now: now,
            calendar: calendar
        )

        if newMetrics != metrics {
            metrics = newMetrics
        }
    }

    private static func computeBooksSignature(books: [Book]) -> UInt64 {
        var aggregate: UInt64 = 0x7C9E_15A8_476D_31F2
        aggregate &+= UInt64(books.count) &* 0x9E37_79B9_7F4A_7C15

        for book in books {
            var hasher = Hasher()
            hasher.combine(book.id)
            hasher.combine(book.title)
            hasher.combine(book.author)
            hasher.combine(book.statusRawValue)
            hasher.combine(book.createdAt.timeIntervalSinceReferenceDate)
            hasher.combine(book.readFrom?.timeIntervalSinceReferenceDate)
            hasher.combine(book.readTo?.timeIntervalSinceReferenceDate)
            hasher.combine(book.pageCount)

            for attempt in book.orderedReadingAttempts {
                hasher.combine(attempt.id)
                hasher.combine(attempt.sequenceNumber)
                hasher.combine(attempt.statusRawValue)
                hasher.combine(attempt.startedAt?.timeIntervalSinceReferenceDate)
                hasher.combine(attempt.finishedAt?.timeIntervalSinceReferenceDate)
                hasher.combine(attempt.pageCountSnapshot)
                hasher.combine(attempt.updatedAt.timeIntervalSinceReferenceDate)
            }

            let hash = UInt64(bitPattern: Int64(hasher.finalize()))
            aggregate ^= hash &+ 0x9E37_79B9_7F4A_7C15 &+ (aggregate << 6) &+ (aggregate >> 2)
        }

        return aggregate
    }

    private static func computeGoalsSignature(goals: [ReadingGoal]) -> UInt64 {
        var aggregate: UInt64 = 0xA24B_AED4_963E_E407
        aggregate &+= UInt64(goals.count) &* 0xBF58_476D_1CE4_E5B9

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
}

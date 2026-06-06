//
//  ChallengeCadence.swift
//  Shelf Notes
//
//  Central cadence metadata and date math for challenge periods.
//

import Foundation

nonisolated enum ChallengeCadence {
    struct Definition: Equatable, Identifiable, Sendable {
        let kind: ChallengeKind
        let displayName: String
        let badgeSystemImage: String
        let sortOrder: Int
        let baselineLookbackDays: Int
        let baselineDivisor: Int
        let historyLimit: Int
        let generatesByDefault: Bool

        var id: ChallengeKind { kind }
    }

    static let supportedKinds: [ChallengeKind] = [.daily, .weekly, .monthly, .yearly]
    static let defaultGenerationKinds: [ChallengeKind] = [.weekly, .monthly]

    static func definition(for kind: ChallengeKind) -> Definition {
        switch kind {
        case .daily:
            return Definition(
                kind: .daily,
                displayName: "Tag",
                badgeSystemImage: "sun.max",
                sortOrder: 0,
                baselineLookbackDays: 14,
                baselineDivisor: 14,
                historyLimit: 14,
                generatesByDefault: false
            )
        case .weekly:
            return Definition(
                kind: .weekly,
                displayName: "Woche",
                badgeSystemImage: "calendar.badge.clock",
                sortOrder: 1,
                baselineLookbackDays: 28,
                baselineDivisor: 4,
                historyLimit: 12,
                generatesByDefault: true
            )
        case .monthly:
            return Definition(
                kind: .monthly,
                displayName: "Monat",
                badgeSystemImage: "calendar",
                sortOrder: 2,
                baselineLookbackDays: 90,
                baselineDivisor: 3,
                historyLimit: 12,
                generatesByDefault: true
            )
        case .yearly:
            return Definition(
                kind: .yearly,
                displayName: "Jahr",
                badgeSystemImage: "calendar.circle",
                sortOrder: 3,
                baselineLookbackDays: 365,
                baselineDivisor: 1,
                historyLimit: 5,
                generatesByDefault: false
            )
        case .unknown:
            return Definition(
                kind: .unknown,
                displayName: "Unbekannt",
                badgeSystemImage: "questionmark.diamond",
                sortOrder: Int.max,
                baselineLookbackDays: 28,
                baselineDivisor: 1,
                historyLimit: 0,
                generatesByDefault: false
            )
        }
    }

    static func calendar() -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }

    static func periodBounds(
        for kind: ChallengeKind,
        now: Date,
        calendar: Calendar = ChallengeCadence.calendar()
    ) -> ChallengeEngine.PeriodBounds {
        switch kind {
        case .daily:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24 * 60 * 60)
            return ChallengeEngine.PeriodBounds(start: start, end: end)

        case .weekly:
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? calendar.startOfDay(for: now)
            let start = calendar.startOfDay(for: weekStart)
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 24 * 60 * 60)
            return ChallengeEngine.PeriodBounds(start: start, end: end)

        case .monthly:
            let comps = calendar.dateComponents([.year, .month], from: now)
            let monthStart = calendar.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)) ?? calendar.startOfDay(for: now)
            let start = calendar.startOfDay(for: monthStart)
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start.addingTimeInterval(30 * 24 * 60 * 60)
            return ChallengeEngine.PeriodBounds(start: start, end: end)

        case .yearly:
            let comps = calendar.dateComponents([.year], from: now)
            let yearStart = calendar.date(from: DateComponents(year: comps.year, month: 1, day: 1)) ?? calendar.startOfDay(for: now)
            let start = calendar.startOfDay(for: yearStart)
            let end = calendar.date(byAdding: .year, value: 1, to: start) ?? start.addingTimeInterval(365 * 24 * 60 * 60)
            return ChallengeEngine.PeriodBounds(start: start, end: end)

        case .unknown:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(24 * 60 * 60)
            return ChallengeEngine.PeriodBounds(start: start, end: end)
        }
    }

    static func baselineStart(
        for kind: ChallengeKind,
        baselineEnd: Date,
        calendar: Calendar = ChallengeCadence.calendar()
    ) -> Date {
        let daysBack = definition(for: kind).baselineLookbackDays
        return calendar.date(byAdding: .day, value: -daysBack, to: baselineEnd)
            ?? baselineEnd.addingTimeInterval(TimeInterval(-daysBack * 24 * 60 * 60))
    }

    static func baselineDivisor(for kind: ChallengeKind) -> Int {
        max(1, definition(for: kind).baselineDivisor)
    }
}

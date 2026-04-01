//
//  ChallengeEngine+Compute.swift
//  Shelf Notes
//
//  Pure compute (value-only) for challenges.
//  All functions in this file are SwiftData-free and safe to run off-main.
//

import Foundation

nonisolated extension ChallengeEngine {

    struct PeriodBounds: Sendable {
        let start: Date
        let end: Date

        init(start: Date, end: Date) {
            self.start = start
            self.end = end
        }
    }

    struct EnsurePlan: Sendable {
        let kind: ChallengeKind
        let metric: ChallengeMetric
        let periodStart: Date
        let periodEnd: Date
        let title: String
        let detail: String
        let targetValue: Int
    }

    struct CompletionPlan: Sendable {
        let challengeID: UUID
        let completedAt: Date
    }

    struct BaselineStats: Sendable {
        var minutes: Int
        var activeDays: Int
        var sessions: Int
        var pagesRead: Int
        var finishedBooks: Int
    }

    struct GeneratedChallenge: Sendable {
        let metric: ChallengeMetric
        let title: String
        let detail: String
        let targetValue: Int
    }

    static func planEnsures(
        weekly: PeriodBounds,
        monthly: PeriodBounds,
        existingWeekly: ChallengeRecordSnapshot?,
        existingMonthly: ChallengeRecordSnapshot?,
        snapshot: Snapshot
    ) -> [EnsurePlan] {
        var plans: [EnsurePlan] = []

        if existingWeekly == nil {
            let metric = pickMetric(kind: .weekly, periodStart: weekly.start, snapshot: snapshot)
            let generated = generateChallenge(
                kind: .weekly,
                metric: metric,
                periodStart: weekly.start,
                periodEnd: weekly.end,
                snapshot: snapshot
            )
            plans.append(
                EnsurePlan(
                    kind: .weekly,
                    metric: generated.metric,
                    periodStart: weekly.start,
                    periodEnd: weekly.end,
                    title: generated.title,
                    detail: generated.detail,
                    targetValue: generated.targetValue
                )
            )
        }

        if existingMonthly == nil {
            let metric = pickMetric(kind: .monthly, periodStart: monthly.start, snapshot: snapshot)
            let generated = generateChallenge(
                kind: .monthly,
                metric: metric,
                periodStart: monthly.start,
                periodEnd: monthly.end,
                snapshot: snapshot
            )
            plans.append(
                EnsurePlan(
                    kind: .monthly,
                    metric: generated.metric,
                    periodStart: monthly.start,
                    periodEnd: monthly.end,
                    title: generated.title,
                    detail: generated.detail,
                    targetValue: generated.targetValue
                )
            )
        }

        return plans
    }

    static func planCompletions(now: Date, active: [ChallengeRecordSnapshot], snapshot: Snapshot) -> [CompletionPlan] {
        guard !active.isEmpty else { return [] }

        var plans: [CompletionPlan] = []
        plans.reserveCapacity(active.count)

        for ch in active {
            guard ch.completedAt == nil else { continue }
            let progress = computeProgress(metric: ch.metric, window: ch.periodStart..<ch.periodEnd, snapshot: snapshot)
            if progress.value >= ch.targetValue {
                plans.append(CompletionPlan(challengeID: ch.id, completedAt: now))
            }
        }

        return plans
    }

    static func computeProgress(metric: ChallengeMetric, window: Range<Date>, snapshot: Snapshot) -> ChallengeProgress {
        switch metric {
        case .readingMinutes:
            let seconds = totalReadingSeconds(in: window, snapshot: snapshot)
            return ChallengeProgress(value: max(0, seconds / 60), unitSuffix: metric.unitSuffix)

        case .readingDays:
            let days = activeReadingDays(in: window, snapshot: snapshot)
            return ChallengeProgress(value: days.count, unitSuffix: metric.unitSuffix)

        case .sessions:
            let count = sessionCount(in: window, snapshot: snapshot)
            return ChallengeProgress(value: count, unitSuffix: metric.unitSuffix)

        case .pagesRead:
            let pages = totalPagesRead(in: window, snapshot: snapshot)
            return ChallengeProgress(value: pages, unitSuffix: metric.unitSuffix)

        case .booksFinished:
            let books = finishedBooksCount(in: window, snapshot: snapshot)
            return ChallengeProgress(value: books, unitSuffix: metric.unitSuffix)
        }
    }

    static func allowedMetrics(for kind: ChallengeKind) -> [ChallengeMetric] {
        switch kind {
        case .weekly:
            return [.readingDays, .readingMinutes, .sessions, .pagesRead]
        case .monthly:
            return [.readingMinutes, .booksFinished, .readingDays, .sessions, .pagesRead]
        }
    }

    static func generateChallenge(
        kind: ChallengeKind,
        metric: ChallengeMetric,
        periodStart: Date,
        periodEnd: Date,
        snapshot: Snapshot
    ) -> GeneratedChallenge {
        let baseline = baselineStats(kind: kind, baselineEnd: periodStart, snapshot: snapshot)

        switch (kind, metric) {
        case (.weekly, .readingDays):
            let avgDays = max(0, baseline.activeDays / 4)
            let target = clampInt(avgDays + 1, min: 2, max: 6)
            return GeneratedChallenge(
                metric: metric,
                title: "Lies an \(target) Tagen",
                detail: "Diese Woche zählt jeder Tag mit mindestens 1 Minute Lesesession.",
                targetValue: target
            )

        case (.weekly, .readingMinutes):
            let avgMinutes = max(0, baseline.minutes / 4)
            let scaled = avgMinutes > 0 ? Int(Double(avgMinutes) * 1.15) : 60
            let target = max(60, roundUp(scaled, toMultipleOf: 10))
            return GeneratedChallenge(
                metric: metric,
                title: "\(target) Minuten lesen",
                detail: "Diese Woche: Leseminuten aus deinen Sessions sammeln (auch kleine Häppchen zählen).",
                targetValue: target
            )

        case (.weekly, .sessions):
            let avgSessions = max(0, baseline.sessions / 4)
            let scaled = Int((Double(max(1, avgSessions)) * 1.25).rounded(.up))
            let target = max(3, min(14, scaled))
            return GeneratedChallenge(
                metric: metric,
                title: "\(target) Sessions loggen",
                detail: "Kurze Sessions zählen auch – Hauptsache du bleibst dran.",
                targetValue: target
            )

        case (.weekly, .pagesRead):
            let avgPages = max(0, baseline.pagesRead / 4)
            let scaled = avgPages > 0 ? Int(Double(avgPages) * 1.15) : 80
            let target = max(50, roundUp(scaled, toMultipleOf: 10))
            return GeneratedChallenge(
                metric: metric,
                title: "\(target) Seiten lesen",
                detail: "Zählt nur, wenn du in Sessions Seiten einträgst.",
                targetValue: target
            )

        case (.weekly, .booksFinished):
            return GeneratedChallenge(
                metric: metric,
                title: "1 Buch beenden",
                detail: "Wenn du diese Woche ein Buch abschließt (mit Datum), ist die Challenge erfüllt.",
                targetValue: 1
            )

        case (.monthly, .booksFinished):
            let avgFinished = max(0, baseline.finishedBooks / 3)
            let target = clampInt(avgFinished + 1, min: 1, max: 6)
            return GeneratedChallenge(
                metric: metric,
                title: "\(target) Bücher beenden",
                detail: "Dieser Monat zählt abgeschlossene Bücher (Status „Gelesen“ + readTo).",
                targetValue: target
            )

        case (.monthly, .readingMinutes):
            let avgMinutes = max(0, baseline.minutes / 3)
            let base = max(300, avgMinutes)
            let target = roundUp(Int(Double(base) * 1.10), toMultipleOf: 30)
            return GeneratedChallenge(
                metric: metric,
                title: "\(target) Minuten lesen",
                detail: "Diesen Monat: Leseminuten aus Sessions sammeln. Kleine Sessions zählen mit.",
                targetValue: target
            )

        case (.monthly, .readingDays):
            let avgDays = max(0, baseline.activeDays / 3)
            let scaled = Int((Double(avgDays) * 1.05).rounded(.up))
            let target = clampInt(scaled, min: 6, max: 24)
            return GeneratedChallenge(
                metric: metric,
                title: "\(target) Lesetage sammeln",
                detail: "Ein Lesetag zählt, wenn du mindestens 1 Minute in einer Session geloggt hast.",
                targetValue: target
            )

        case (.monthly, .sessions):
            let avgSessions = max(0, baseline.sessions / 3)
            let scaled = Int((Double(max(6, avgSessions)) * 1.10).rounded(.up))
            let target = clampInt(scaled, min: 8, max: 60)
            return GeneratedChallenge(
                metric: metric,
                title: "\(target) Sessions loggen",
                detail: "Einfach regelmäßig kleine Lesesessions loggen – das bringt Konstanz.",
                targetValue: target
            )

        case (.monthly, .pagesRead):
            let avgPages = max(0, baseline.pagesRead / 3)
            let base = max(300, avgPages)
            let target = roundUp(Int(Double(base) * 1.10), toMultipleOf: 50)
            return GeneratedChallenge(
                metric: metric,
                title: "\(target) Seiten lesen",
                detail: "Zählt nur, wenn du in Sessions Seiten einträgst.",
                targetValue: target
            )
        }
    }
}

// MARK: - Metric selection + baselines

private nonisolated extension ChallengeEngine {

    static func pickMetric(kind: ChallengeKind, periodStart: Date, snapshot: Snapshot) -> ChallengeMetric {
        let baseline = baselineStats(kind: kind, baselineEnd: periodStart, snapshot: snapshot)
        let hasPages = baseline.pagesRead > 0

        if kind == .weekly {
            let avgDays = baseline.activeDays / 4
            let avgMinutes = baseline.minutes / 4

            if avgDays >= 3 { return .readingDays }
            if avgMinutes >= 90 { return .readingMinutes }
            return hasPages ? .sessions : .readingMinutes
        }

        let avgFinished = baseline.finishedBooks / 3
        if avgFinished >= 1 { return .booksFinished }
        return .readingMinutes
    }

    static func baselineStats(kind: ChallengeKind, baselineEnd: Date, snapshot: Snapshot) -> BaselineStats {
        let daysBack = (kind == .weekly) ? 28 : 90
        let start = engineCalendar().date(byAdding: .day, value: -daysBack, to: baselineEnd)
            ?? baselineEnd.addingTimeInterval(TimeInterval(-daysBack * 24 * 60 * 60))
        let range = start..<baselineEnd

        let seconds = totalReadingSeconds(in: range, snapshot: snapshot)
        let days = activeReadingDays(in: range, snapshot: snapshot)
        let sessions = sessionCount(in: range, snapshot: snapshot)
        let pages = totalPagesRead(in: range, snapshot: snapshot)
        let finished = finishedBooksCount(in: range, snapshot: snapshot)

        return BaselineStats(
            minutes: max(0, seconds / 60),
            activeDays: days.count,
            sessions: sessions,
            pagesRead: pages,
            finishedBooks: finished
        )
    }
}

// MARK: - Aggregations

private nonisolated extension ChallengeEngine {

    static func totalReadingSeconds(in range: Range<Date>, snapshot: Snapshot) -> Int {
        if snapshot.sessions.isEmpty { return 0 }

        var sum = 0
        for s in snapshot.sessions {
            sum += overlapSeconds(start: s.startedAt, end: s.endedAt, window: range)
        }
        return sum
    }

    static func activeReadingDays(in range: Range<Date>, snapshot: Snapshot) -> Set<Date> {
        if snapshot.sessions.isEmpty { return [] }

        let cal = engineCalendar()
        var days: Set<Date> = []

        for s in snapshot.sessions {
            let clamped = clampWindow(start: s.startedAt, end: s.endedAt, window: range)
            guard let cs = clamped.start, let ce = clamped.end, ce > cs else { continue }

            var cursor = cs
            while cursor < ce {
                let dayStart = cal.startOfDay(for: cursor)
                guard let nextDay = cal.date(byAdding: .day, value: 1, to: dayStart) else { break }
                let segEnd = min(ce, nextDay)
                let segSeconds = Int(max(0, segEnd.timeIntervalSince(cursor)).rounded(.down))
                if segSeconds >= 60 {
                    days.insert(dayStart)
                }
                cursor = segEnd
            }
        }

        return days
    }

    static func sessionCount(in range: Range<Date>, snapshot: Snapshot) -> Int {
        if snapshot.sessions.isEmpty { return 0 }

        var count = 0
        for s in snapshot.sessions {
            let secs = overlapSeconds(start: s.startedAt, end: s.endedAt, window: range)
            if secs >= 60 { count += 1 }
        }
        return count
    }

    static func totalPagesRead(in range: Range<Date>, snapshot: Snapshot) -> Int {
        if snapshot.sessions.isEmpty { return 0 }

        var sum = 0
        for s in snapshot.sessions {
            let secs = overlapSeconds(start: s.startedAt, end: s.endedAt, window: range)
            guard secs > 0 else { continue }
            sum += s.pagesRead
        }
        return sum
    }

    static func finishedBooksCount(in range: Range<Date>, snapshot: Snapshot) -> Int {
        if snapshot.finishedBookReadTo.isEmpty { return 0 }
        let start = range.lowerBound
        let end = range.upperBound
        return snapshot.finishedBookReadTo.filter { $0 >= start && $0 < end }.count
    }
}

// MARK: - Date math + helpers

private nonisolated extension ChallengeEngine {

    static func engineCalendar() -> Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }

    static func normalizedDates(_ a: Date, _ b: Date) -> (Date, Date) {
        if b < a { return (b, a) }
        return (a, b)
    }

    static func clampWindow(start: Date, end: Date, window: Range<Date>) -> (start: Date?, end: Date?) {
        let (s, e) = normalizedDates(start, end)
        let ws = window.lowerBound
        let we = window.upperBound

        let clampedStart = max(s, ws)
        let clampedEnd = min(e, we)
        if clampedEnd <= clampedStart { return (nil, nil) }
        return (clampedStart, clampedEnd)
    }

    static func overlapSeconds(start: Date, end: Date, window: Range<Date>) -> Int {
        let clamped = clampWindow(start: start, end: end, window: window)
        guard let cs = clamped.start, let ce = clamped.end, ce > cs else { return 0 }
        return Int(max(0, ce.timeIntervalSince(cs)).rounded(.down))
    }

    static func roundUp(_ value: Int, toMultipleOf step: Int) -> Int {
        guard step > 0 else { return value }
        let v = max(0, value)
        let rem = v % step
        if rem == 0 { return v }
        return v + (step - rem)
    }

    static func clampInt(_ value: Int, min: Int, max: Int) -> Int {
        Swift.max(min, Swift.min(max, value))
    }
}

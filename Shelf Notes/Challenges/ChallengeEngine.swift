//
//  ChallengeEngine.swift
//  Shelf Notes
//
//  Generates Weekly/Monthly challenges and computes progress from existing data.
//

import Foundation
import SwiftData

enum ChallengeEngine {

    // MARK: - Public API

    /// Ensures that there is an active weekly + monthly challenge for the current period.
    @MainActor
    static func ensureCurrentChallenges(modelContext: ModelContext) {
        let now = Date()

        ensureChallenge(kind: .weekly, now: now, modelContext: modelContext)
        ensureChallenge(kind: .monthly, now: now, modelContext: modelContext)
    }

    /// Refreshes completion timestamps for currently active challenges (if the user has reached the target).
    @MainActor
    static func refreshCompletionForActiveChallenges(modelContext: ModelContext) {
        let now = Date()
        let active = fetchActiveChallenges(now: now, modelContext: modelContext)
        guard !active.isEmpty else { return }

        var changed = false
        for ch in active {
            let progress = computeProgress(for: ch, modelContext: modelContext)
            if progress.value >= ch.targetValue, ch.completedAt == nil {
                ch.completedAt = now
                changed = true
            }
        }

        if changed {
            _ = modelContext.saveWithDiagnostics()
        }
    }

    /// Reroll a challenge (max 1 per period). Keeps the period, swaps the metric + recalculates the target.
    @MainActor
    static func reroll(_ challenge: ChallengeRecord, modelContext: ModelContext) {
        guard challenge.canReroll else { return }

        let kind = challenge.kind
        let periodStart = challenge.periodStart
        let periodEnd = challenge.periodEnd

        // Pick a different metric for the same kind.
        let candidates = allowedMetrics(for: kind)
        let current = challenge.metric
        let newMetric = candidates.first(where: { $0 != current }) ?? current

        let generated = generateChallenge(kind: kind, metric: newMetric, periodStart: periodStart, periodEnd: periodEnd, modelContext: modelContext)

        challenge.metric = generated.metric
        challenge.title = generated.title
        challenge.detail = generated.detail
        challenge.targetValue = generated.targetValue
        challenge.completedAt = nil
        challenge.acknowledgedAt = nil

        challenge.rerollsUsed += 1
        challenge.rerolledAt = Date()

        _ = modelContext.saveWithDiagnostics()
    }

    /// Marks a completed challenge as acknowledged ("claimed").
    @MainActor
    static func claim(_ challenge: ChallengeRecord, modelContext: ModelContext) {
        guard challenge.isCompleted, !challenge.isClaimed else { return }
        challenge.acknowledgedAt = Date()
        _ = modelContext.saveWithDiagnostics()
    }

    /// Computes progress for a challenge.
    ///
    /// Returns a value in the unit of the challenge metric (minutes, days, sessions, pages, books).
    @MainActor
    static func computeProgress(for challenge: ChallengeRecord, modelContext: ModelContext) -> ChallengeProgress {
        let windowStart = challenge.periodStart
        let windowEnd = challenge.periodEnd

        switch challenge.metric {
        case .readingMinutes:
            let seconds = totalReadingSeconds(in: windowStart..<windowEnd, modelContext: modelContext)
            return ChallengeProgress(value: max(0, seconds / 60), unitSuffix: challenge.metric.unitSuffix)

        case .readingDays:
            let days = activeReadingDays(in: windowStart..<windowEnd, modelContext: modelContext)
            return ChallengeProgress(value: days.count, unitSuffix: challenge.metric.unitSuffix)

        case .sessions:
            let count = sessionCount(in: windowStart..<windowEnd, modelContext: modelContext)
            return ChallengeProgress(value: count, unitSuffix: challenge.metric.unitSuffix)

        case .pagesRead:
            let pages = totalPagesRead(in: windowStart..<windowEnd, modelContext: modelContext)
            return ChallengeProgress(value: pages, unitSuffix: challenge.metric.unitSuffix)

        case .booksFinished:
            let books = finishedBooksCount(in: windowStart..<windowEnd, modelContext: modelContext)
            return ChallengeProgress(value: books, unitSuffix: challenge.metric.unitSuffix)
        }
    }

    // MARK: - Types

    struct ChallengeProgress {
        let value: Int
        let unitSuffix: String

        func fraction(target: Int) -> Double {
            guard target > 0 else { return 0 }
            return min(1.0, max(0.0, Double(value) / Double(target)))
        }

        func valueText(target: Int) -> String {
            if target > 0 {
                return "\(value)/\(target) \(unitSuffix)"
            }
            return "\(value) \(unitSuffix)"
        }

        func remainingText(target: Int) -> String? {
            guard target > 0 else { return nil }
            let remaining = max(0, target - value)
            guard remaining > 0 else { return nil }
            return "Noch \(remaining) \(unitSuffix)"
        }
    }

    // MARK: - Internal: ensure + generation

    @MainActor
    private static func ensureChallenge(kind: ChallengeKind, now: Date, modelContext: ModelContext) {
        let period = periodBounds(kind: kind, now: now)

        let existing = fetchChallenge(kind: kind, periodStart: period.start, modelContext: modelContext)
        if existing != nil { return }

        // Pick default metric based on the user's recent behavior.
        let metric = pickMetric(kind: kind, periodStart: period.start, modelContext: modelContext)
        let generated = generateChallenge(kind: kind, metric: metric, periodStart: period.start, periodEnd: period.end, modelContext: modelContext)

        let record = ChallengeRecord(
            kind: kind,
            metric: generated.metric,
            periodStart: period.start,
            periodEnd: period.end,
            title: generated.title,
            detail: generated.detail,
            targetValue: generated.targetValue
        )

        modelContext.insert(record)
        _ = modelContext.saveWithDiagnostics()
    }

    private struct GeneratedChallenge {
        let metric: ChallengeMetric
        let title: String
        let detail: String
        let targetValue: Int
    }

    @MainActor
    private static func generateChallenge(
        kind: ChallengeKind,
        metric: ChallengeMetric,
        periodStart: Date,
        periodEnd: Date,
        modelContext: ModelContext
    ) -> GeneratedChallenge {

        // Baselines: look back before the current period.
        let baseline = baselineStats(kind: kind, baselineEnd: periodStart, modelContext: modelContext)

        switch (kind, metric) {
        case (.weekly, .readingDays):
            let avgDays = max(0, baseline.activeDays / 4)
            let target = clampInt(avgDays + 1, min: 2, max: 6)
            let title = "Lies an \(target) Tagen"
            let detail = "Diese Woche zählt jeder Tag mit mindestens 1 Minute Lesesession." 
            return GeneratedChallenge(metric: metric, title: title, detail: detail, targetValue: target)

        case (.weekly, .readingMinutes):
            let avgMinutes = max(0, baseline.minutes / 4)
            let target = max(60, roundUp(avgMinutes > 0 ? Int(Double(avgMinutes) * 1.15) : 60, toMultipleOf: 10))
            let title = "\(target) Minuten lesen"
            let detail = "Diese Woche: Leseminuten aus deinen Sessions sammeln (auch kleine Häppchen zählen)."
            return GeneratedChallenge(metric: metric, title: title, detail: detail, targetValue: target)

        case (.weekly, .sessions):
            let avgSessions = max(0, baseline.sessions / 4)
            let target = max(3, min(14, Int((Double(max(1, avgSessions)) * 1.25).rounded(.up))))
            let title = "\(target) Sessions loggen"
            let detail = "Kurze Sessions zählen auch – Hauptsache du bleibst dran." 
            return GeneratedChallenge(metric: metric, title: title, detail: detail, targetValue: target)

        case (.weekly, .pagesRead):
            let avgPages = max(0, baseline.pagesRead / 4)
            let target = max(50, roundUp(avgPages > 0 ? Int(Double(avgPages) * 1.15) : 80, toMultipleOf: 10))
            let title = "\(target) Seiten lesen"
            let detail = "Zählt nur, wenn du in Sessions Seiten einträgst." 
            return GeneratedChallenge(metric: metric, title: title, detail: detail, targetValue: target)

        case (.weekly, .booksFinished):
            // Finishing books per week is often too swingy. Keep it mild.
            let target = 1
            let title = "1 Buch beenden"
            let detail = "Wenn du diese Woche ein Buch abschließt (mit Datum), ist die Challenge erfüllt." 
            return GeneratedChallenge(metric: metric, title: title, detail: detail, targetValue: target)

        case (.monthly, .booksFinished):
            let avgFinished = max(0, baseline.finishedBooks / 3)
            let target = clampInt(avgFinished + 1, min: 1, max: 6)
            let title = "\(target) Bücher beenden"
            let detail = "Dieser Monat zählt abgeschlossene Bücher (Status „Gelesen“ + readTo)."
            return GeneratedChallenge(metric: metric, title: title, detail: detail, targetValue: target)

        case (.monthly, .readingMinutes):
            let avgMinutes = max(0, baseline.minutes / 3)
            let base = max(300, avgMinutes)
            let target = roundUp(Int(Double(base) * 1.10), toMultipleOf: 30)
            let title = "\(target) Minuten lesen"
            let detail = "Diesen Monat: Leseminuten aus Sessions sammeln. Kleine Sessions zählen mit." 
            return GeneratedChallenge(metric: metric, title: title, detail: detail, targetValue: target)

        case (.monthly, .readingDays):
            let avgDays = max(0, baseline.activeDays / 3)
            let target = clampInt(Int((Double(avgDays) * 1.05).rounded(.up)), min: 6, max: 24)
            let title = "\(target) Lesetage sammeln"
            let detail = "Ein Lesetag zählt, wenn du mindestens 1 Minute in einer Session geloggt hast." 
            return GeneratedChallenge(metric: metric, title: title, detail: detail, targetValue: target)

        case (.monthly, .sessions):
            let avgSessions = max(0, baseline.sessions / 3)
            let target = clampInt(Int((Double(max(6, avgSessions)) * 1.10).rounded(.up)), min: 8, max: 60)
            let title = "\(target) Sessions loggen"
            let detail = "Einfach regelmäßig kleine Lesesessions loggen – das bringt Konstanz." 
            return GeneratedChallenge(metric: metric, title: title, detail: detail, targetValue: target)

        case (.monthly, .pagesRead):
            let avgPages = max(0, baseline.pagesRead / 3)
            let base = max(300, avgPages)
            let target = roundUp(Int(Double(base) * 1.10), toMultipleOf: 50)
            let title = "\(target) Seiten lesen"
            let detail = "Zählt nur, wenn du in Sessions Seiten einträgst." 
            return GeneratedChallenge(metric: metric, title: title, detail: detail, targetValue: target)
        }
    }

    @MainActor
    private static func pickMetric(kind: ChallengeKind, periodStart: Date, modelContext: ModelContext) -> ChallengeMetric {
        let baseline = baselineStats(kind: kind, baselineEnd: periodStart, modelContext: modelContext)

        // If the user has any page tracking, we may offer a pages challenge.
        let hasPages = baseline.pagesRead > 0

        if kind == .weekly {
            // Prefer consistency if the user already reads on multiple days.
            let avgDays = baseline.activeDays / 4
            let avgMinutes = baseline.minutes / 4

            if avgDays >= 3 {
                return .readingDays
            }

            if avgMinutes >= 90 {
                return .readingMinutes
            }

            // Early stage: sessions feel less intimidating.
            return hasPages ? .sessions : .readingMinutes
        } else {
            // Monthly: if the user finishes books, use that; otherwise minutes.
            let avgFinished = baseline.finishedBooks / 3
            if avgFinished >= 1 {
                return .booksFinished
            }

            return .readingMinutes
        }
    }

    private static func allowedMetrics(for kind: ChallengeKind) -> [ChallengeMetric] {
        switch kind {
        case .weekly:
            return [.readingDays, .readingMinutes, .sessions, .pagesRead]
        case .monthly:
            return [.readingMinutes, .booksFinished, .readingDays, .sessions, .pagesRead]
        }
    }

    // MARK: - Internal: fetching

    @MainActor
    private static func fetchChallenge(kind: ChallengeKind, periodStart: Date, modelContext: ModelContext) -> ChallengeRecord? {
        let kindRaw = kind.rawValue
        let start = periodStart

        let descriptor = FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate<ChallengeRecord> { $0.kindRawValue == kindRaw && $0.periodStart == start }
        )

        return (try? modelContext.fetch(descriptor))?.first
    }

    @MainActor
    private static func fetchActiveChallenges(now: Date, modelContext: ModelContext) -> [ChallengeRecord] {
        let nowVal = now
        let descriptor = FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate<ChallengeRecord> { $0.periodStart <= nowVal && $0.periodEnd > nowVal },
            sortBy: [SortDescriptor(\ChallengeRecord.periodStart, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Period helpers

    private static func calendar() -> Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        return cal
    }

    private static func periodBounds(kind: ChallengeKind, now: Date) -> (start: Date, end: Date) {
        var cal = calendar()

        switch kind {
        case .weekly:
            let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? cal.startOfDay(for: now)
            let start = cal.startOfDay(for: weekStart)
            let end = cal.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 24 * 60 * 60)
            return (start, end)

        case .monthly:
            let comps = cal.dateComponents([.year, .month], from: now)
            let monthStart = cal.date(from: DateComponents(year: comps.year, month: comps.month, day: 1)) ?? cal.startOfDay(for: now)
            let start = cal.startOfDay(for: monthStart)
            let end = cal.date(byAdding: .month, value: 1, to: start) ?? start.addingTimeInterval(30 * 24 * 60 * 60)
            return (start, end)
        }
    }

    // MARK: - Baselines

    private struct BaselineStats {
        var minutes: Int
        var activeDays: Int
        var sessions: Int
        var pagesRead: Int
        var finishedBooks: Int
    }

    /// Baseline window used to personalize targets.
    /// - weekly: last 28 days before the week starts
    /// - monthly: last 90 days before the month starts
    @MainActor
    private static func baselineStats(kind: ChallengeKind, baselineEnd: Date, modelContext: ModelContext) -> BaselineStats {
        var cal = calendar()
        let daysBack = (kind == .weekly) ? 28 : 90
        let start = cal.date(byAdding: .day, value: -daysBack, to: baselineEnd) ?? baselineEnd.addingTimeInterval(TimeInterval(-daysBack * 24 * 60 * 60))

        let range = start..<baselineEnd

        let seconds = totalReadingSeconds(in: range, modelContext: modelContext)
        let days = activeReadingDays(in: range, modelContext: modelContext)
        let sessions = sessionCount(in: range, modelContext: modelContext)
        let pages = totalPagesRead(in: range, modelContext: modelContext)
        let finished = finishedBooksCount(in: range, modelContext: modelContext)

        return BaselineStats(
            minutes: max(0, seconds / 60),
            activeDays: days.count,
            sessions: sessions,
            pagesRead: pages,
            finishedBooks: finished
        )
    }

    // MARK: - Aggregations (sessions)

    @MainActor
    private static func fetchSessions(in range: Range<Date>, modelContext: ModelContext) -> [ReadingSession] {
        let start = range.lowerBound
        let end = range.upperBound

        // Fetch potentially overlapping sessions.
        let descriptor = FetchDescriptor<ReadingSession>(
            predicate: #Predicate<ReadingSession> { $0.endedAt > start && $0.startedAt < end }
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    @MainActor
    private static func totalReadingSeconds(in range: Range<Date>, modelContext: ModelContext) -> Int {
        let sessions = fetchSessions(in: range, modelContext: modelContext)
        var sum = 0
        for s in sessions {
            sum += overlapSeconds(start: s.startedAt, end: s.endedAt, window: range)
        }
        return sum
    }

    @MainActor
    private static func activeReadingDays(in range: Range<Date>, modelContext: ModelContext) -> Set<Date> {
        let sessions = fetchSessions(in: range, modelContext: modelContext)
        var cal = calendar()

        var days: Set<Date> = []

        for s in sessions {
            let (start, end) = normalizedDates(s.startedAt, s.endedAt)
            let clamped = clampWindow(start: start, end: end, window: range)
            guard let cs = clamped.start, let ce = clamped.end, ce > cs else { continue }

            // Count a day if at least 60 seconds overlap on that day.
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

    @MainActor
    private static func sessionCount(in range: Range<Date>, modelContext: ModelContext) -> Int {
        let sessions = fetchSessions(in: range, modelContext: modelContext)
        var count = 0
        for s in sessions {
            let secs = overlapSeconds(start: s.startedAt, end: s.endedAt, window: range)
            if secs >= 60 { count += 1 }
        }
        return count
    }

    @MainActor
    private static func totalPagesRead(in range: Range<Date>, modelContext: ModelContext) -> Int {
        let sessions = fetchSessions(in: range, modelContext: modelContext)
        // Pages are not time-sliced. If a session overlaps at all, we count its pages.
        var sum = 0
        for s in sessions {
            let secs = overlapSeconds(start: s.startedAt, end: s.endedAt, window: range)
            guard secs > 0 else { continue }
            sum += (s.pagesReadNormalized ?? 0)
        }
        return sum
    }

    // MARK: - Aggregations (books)

    @MainActor
    private static func finishedBooksCount(in range: Range<Date>, modelContext: ModelContext) -> Int {
        let start = range.lowerBound
        let end = range.upperBound

        let statusFinished = ReadingStatus.finished.rawValue
        let legacyFinished = "Gelesen"

        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate<Book> {
                ($0.statusRawValue == statusFinished || $0.statusRawValue == legacyFinished) &&
                $0.readTo != nil &&
                $0.readTo! >= start &&
                $0.readTo! < end
            }
        )

        return (try? modelContext.fetch(descriptor))?.count ?? 0
    }

    // MARK: - Date math

    private static func normalizedDates(_ a: Date, _ b: Date) -> (Date, Date) {
        if b < a { return (b, a) }
        return (a, b)
    }

    private static func clampWindow(start: Date, end: Date, window: Range<Date>) -> (start: Date?, end: Date?) {
        let ws = window.lowerBound
        let we = window.upperBound
        let clampedStart = max(start, ws)
        let clampedEnd = min(end, we)
        if clampedEnd <= clampedStart { return (nil, nil) }
        return (clampedStart, clampedEnd)
    }

    private static func overlapSeconds(start: Date, end: Date, window: Range<Date>) -> Int {
        let (s, e) = normalizedDates(start, end)
        let clamped = clampWindow(start: s, end: e, window: window)
        guard let cs = clamped.start, let ce = clamped.end, ce > cs else { return 0 }
        return Int(max(0, ce.timeIntervalSince(cs)).rounded(.down))
    }

    // MARK: - Math helpers

    private static func roundUp(_ value: Int, toMultipleOf step: Int) -> Int {
        guard step > 0 else { return value }
        let v = max(0, value)
        let rem = v % step
        if rem == 0 { return v }
        return v + (step - rem)
    }

    private static func clampInt(_ value: Int, min: Int, max: Int) -> Int {
        Swift.max(min, Swift.min(max, value))
    }
}

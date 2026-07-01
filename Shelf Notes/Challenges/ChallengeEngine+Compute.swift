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
        let id: UUID
        let kind: ChallengeKind
        let metric: ChallengeMetric
        let periodStart: Date
        let periodEnd: Date
        let title: String
        let detail: String
        let targetValue: Int
    }

    struct EnsureCadenceInput: Sendable {
        let kind: ChallengeKind
        let period: PeriodBounds
        let existing: ChallengeRecordSnapshot?
        let recent: [ChallengeRecordSnapshot]

        init(
            kind: ChallengeKind,
            period: PeriodBounds,
            existing: ChallengeRecordSnapshot?,
            recent: [ChallengeRecordSnapshot] = []
        ) {
            self.kind = kind
            self.period = period
            self.existing = existing
            self.recent = recent
        }
    }

    struct CompletionPlan: Sendable {
        let challengeID: UUID
        let completedAt: Date
    }

    struct BaselineStats: Sendable, Equatable {
        var minutes: Int
        var activeDays: Int
        var sessions: Int
        var pagesRead: Int
        var finishedBooks: Int
        var shortSessions: Int
        var progressedBooks: Int
        var sessionNotes: Int
        var ratedFinishedBooks: Int
        var notedFinishedBooks: Int

        init(
            minutes: Int,
            activeDays: Int,
            sessions: Int,
            pagesRead: Int,
            finishedBooks: Int,
            shortSessions: Int = 0,
            progressedBooks: Int = 0,
            sessionNotes: Int = 0,
            ratedFinishedBooks: Int = 0,
            notedFinishedBooks: Int = 0
        ) {
            self.minutes = minutes
            self.activeDays = activeDays
            self.sessions = sessions
            self.pagesRead = pagesRead
            self.finishedBooks = finishedBooks
            self.shortSessions = shortSessions
            self.progressedBooks = progressedBooks
            self.sessionNotes = sessionNotes
            self.ratedFinishedBooks = ratedFinishedBooks
            self.notedFinishedBooks = notedFinishedBooks
        }
    }

    struct GeneratedChallenge: Equatable, Sendable {
        let metric: ChallengeMetric
        let title: String
        let detail: String
        let targetValue: Int
    }

    static func planEnsures(
        cadences: [EnsureCadenceInput],
        snapshot: Snapshot
    ) -> [EnsurePlan] {
        guard !cadences.isEmpty else { return [] }

        var plans: [EnsurePlan] = []
        plans.reserveCapacity(cadences.count)

        for cadence in cadences {
            guard cadence.kind.isKnownCadence else { continue }
            guard cadence.existing == nil else { continue }
            guard !ChallengeTemplateRegistry.templates(for: cadence.kind).isEmpty else { continue }

            let recentMetrics = cadence.recent.map(\.metric)
            let metric = pickMetric(
                kind: cadence.kind,
                periodStart: cadence.period.start,
                snapshot: snapshot,
                recentMetrics: recentMetrics
            )
            let generated = generateChallenge(
                kind: cadence.kind,
                metric: metric,
                periodStart: cadence.period.start,
                periodEnd: cadence.period.end,
                snapshot: snapshot
            )
            plans.append(
                EnsurePlan(
                    id: UUID(),
                    kind: cadence.kind,
                    metric: generated.metric,
                    periodStart: cadence.period.start,
                    periodEnd: cadence.period.end,
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

        case .shortSessions:
            let count = shortSessionCount(in: window, snapshot: snapshot)
            return ChallengeProgress(value: count, unitSuffix: metric.unitSuffix)

        case .booksProgressed:
            let count = progressedBooksCount(in: window, snapshot: snapshot)
            return ChallengeProgress(value: count, unitSuffix: metric.unitSuffix)

        case .sessionNotes:
            let count = sessionNotesCount(in: window, snapshot: snapshot)
            return ChallengeProgress(value: count, unitSuffix: metric.unitSuffix)

        case .finishedBooksRated:
            let count = ratedFinishedBooksCount(in: window, snapshot: snapshot)
            return ChallengeProgress(value: count, unitSuffix: metric.unitSuffix)

        case .finishedBooksNoted:
            let count = notedFinishedBooksCount(in: window, snapshot: snapshot)
            return ChallengeProgress(value: count, unitSuffix: metric.unitSuffix)
        }
    }

    static func allowedMetrics(for kind: ChallengeKind) -> [ChallengeMetric] {
        ChallengeTemplateRegistry.templates(for: kind).map(\.metric)
    }

    static func generateChallenge(
        kind: ChallengeKind,
        metric: ChallengeMetric,
        periodStart: Date,
        periodEnd: Date,
        snapshot: Snapshot
    ) -> GeneratedChallenge {
        let baseline = baselineStats(kind: kind, baselineEnd: periodStart, snapshot: snapshot)
        let template = ChallengeTemplateRegistry.template(kind: kind, metric: metric)
            ?? ChallengeTemplateSelector.selectTemplate(kind: kind, baseline: baseline, periodStart: periodStart)
        return ChallengeTemplateSelector.generatedChallenge(template: template, baseline: baseline)
    }

    static func rerollReplacement(
        kind: ChallengeKind,
        current: ChallengeMetric,
        periodStart: Date,
        periodEnd: Date,
        snapshot: Snapshot,
        challengeID: UUID,
        rerollsUsed: Int,
        recentMetrics: [ChallengeMetric] = []
    ) -> GeneratedChallenge {
        let baseline = baselineStats(kind: kind, baselineEnd: periodStart, snapshot: snapshot)
        let generatedOptions = replacementCandidates(
            kind: kind,
            current: current,
            baseline: baseline,
            recentMetrics: recentMetrics,
            challengeID: challengeID,
            rerollsUsed: rerollsUsed
        )

        guard !generatedOptions.isEmpty else {
            return generateChallenge(
                kind: kind,
                metric: current,
                periodStart: periodStart,
                periodEnd: periodEnd,
                snapshot: snapshot
            )
        }

        let unfinishedOptions = generatedOptions.filter { option in
            let progress = computeProgress(metric: option.metric, window: periodStart..<periodEnd, snapshot: snapshot)
            return progress.value < option.targetValue
        }
        let options = unfinishedOptions.isEmpty ? generatedOptions : unfinishedOptions
        let index = stableRerollIndex(challengeID: challengeID, rerollsUsed: rerollsUsed, optionCount: options.count)
        return options[index]
    }
}

// MARK: - Metric selection + baselines

private nonisolated extension ChallengeEngine {

    static func pickMetric(
        kind: ChallengeKind,
        periodStart: Date,
        snapshot: Snapshot,
        recentMetrics: [ChallengeMetric]
    ) -> ChallengeMetric {
        let baseline = baselineStats(kind: kind, baselineEnd: periodStart, snapshot: snapshot)
        let template = ChallengeTemplateSelector.selectTemplate(
            kind: kind,
            baseline: baseline,
            recentMetrics: recentMetrics,
            periodStart: periodStart
        )
        return template.metric
    }

    static func replacementCandidates(
        kind: ChallengeKind,
        current: ChallengeMetric,
        baseline: BaselineStats,
        recentMetrics: [ChallengeMetric],
        challengeID: UUID,
        rerollsUsed: Int
    ) -> [GeneratedChallenge] {
        let selected = ChallengeTemplateSelector.replacementTemplate(
            kind: kind,
            currentMetric: current,
            baseline: baseline,
            recentMetrics: recentMetrics,
            challengeID: challengeID,
            rerollsUsed: rerollsUsed
        )

        let candidates = ChallengeTemplateSelector.eligibleTemplates(kind: kind, baseline: baseline)
            .filter { $0.metric != current }

        let blocked = Set(recentMetrics.prefix(2))
        let nonRepeated = candidates.filter { !blocked.contains($0.metric) }
        let pool = nonRepeated.isEmpty ? candidates : nonRepeated
        let ordered = pool.sorted { lhs, rhs in
            let lhsMatches = lhs.difficulty == selected.difficulty
            let rhsMatches = rhs.difficulty == selected.difficulty
            if lhsMatches != rhsMatches { return lhsMatches }
            return lhs.id < rhs.id
        }

        return ordered.map { template in
            ChallengeTemplateSelector.generatedChallenge(template: template, baseline: baseline)
        }
    }

    static func baselineStats(kind: ChallengeKind, baselineEnd: Date, snapshot: Snapshot) -> BaselineStats {
        let start = ChallengeCadence.baselineStart(
            for: kind,
            baselineEnd: baselineEnd,
            calendar: engineCalendar()
        )
        let range = start..<baselineEnd

        let seconds = totalReadingSeconds(in: range, snapshot: snapshot)
        let days = activeReadingDays(in: range, snapshot: snapshot)
        let sessions = sessionCount(in: range, snapshot: snapshot)
        let pages = totalPagesRead(in: range, snapshot: snapshot)
        let finished = finishedBooksCount(in: range, snapshot: snapshot)
        let short = shortSessionCount(in: range, snapshot: snapshot)
        let progressed = progressedBooksCount(in: range, snapshot: snapshot)
        let notes = sessionNotesCount(in: range, snapshot: snapshot)
        let rated = ratedFinishedBooksCount(in: range, snapshot: snapshot)
        let noted = notedFinishedBooksCount(in: range, snapshot: snapshot)

        return BaselineStats(
            minutes: max(0, seconds / 60),
            activeDays: days.count,
            sessions: sessions,
            pagesRead: pages,
            finishedBooks: finished,
            shortSessions: short,
            progressedBooks: progressed,
            sessionNotes: notes,
            ratedFinishedBooks: rated,
            notedFinishedBooks: noted
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
        if snapshot.finishedBooks.isEmpty { return 0 }
        let start = range.lowerBound
        let end = range.upperBound
        return snapshot.finishedBooks.filter { $0.readTo >= start && $0.readTo < end }.count
    }

    static func shortSessionCount(in range: Range<Date>, snapshot: Snapshot) -> Int {
        if snapshot.sessions.isEmpty { return 0 }

        var count = 0
        for s in snapshot.sessions {
            let secs = overlapSeconds(start: s.startedAt, end: s.endedAt, window: range)
            if secs >= 5 * 60 && secs <= 25 * 60 {
                count += 1
            }
        }
        return count
    }

    static func progressedBooksCount(in range: Range<Date>, snapshot: Snapshot) -> Int {
        if snapshot.sessions.isEmpty { return 0 }

        var bookIDs: Set<UUID> = []
        var anonymousProgressSessions = 0

        for s in snapshot.sessions {
            let secs = overlapSeconds(start: s.startedAt, end: s.endedAt, window: range)
            guard secs > 0, s.pagesRead > 0 else { continue }
            if let bookID = s.bookID {
                bookIDs.insert(bookID)
            } else {
                anonymousProgressSessions += 1
            }
        }

        return bookIDs.count + anonymousProgressSessions
    }

    static func sessionNotesCount(in range: Range<Date>, snapshot: Snapshot) -> Int {
        if snapshot.sessions.isEmpty { return 0 }

        var count = 0
        for s in snapshot.sessions {
            let secs = overlapSeconds(start: s.startedAt, end: s.endedAt, window: range)
            if secs > 0 && s.hasNote {
                count += 1
            }
        }
        return count
    }

    static func ratedFinishedBooksCount(in range: Range<Date>, snapshot: Snapshot) -> Int {
        if snapshot.finishedBooks.isEmpty { return 0 }
        let start = range.lowerBound
        let end = range.upperBound
        return snapshot.finishedBooks.filter { book in
            book.readTo >= start && book.readTo < end && book.hasUserRating
        }.count
    }

    static func notedFinishedBooksCount(in range: Range<Date>, snapshot: Snapshot) -> Int {
        if snapshot.finishedBooks.isEmpty { return 0 }
        let start = range.lowerBound
        let end = range.upperBound
        return snapshot.finishedBooks.filter { book in
            book.readTo >= start && book.readTo < end && book.hasUserNote
        }.count
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

    static func stableRerollIndex(challengeID: UUID, rerollsUsed: Int, optionCount: Int) -> Int {
        guard optionCount > 0 else { return 0 }
        let seed = challengeID.uuidString.unicodeScalars.reduce(into: 17) { partialResult, scalar in
            partialResult = (partialResult &* 31) &+ Int(scalar.value)
        }
        let mixed = seed &+ (rerollsUsed &* 7)
        return abs(mixed % optionCount)
    }
}

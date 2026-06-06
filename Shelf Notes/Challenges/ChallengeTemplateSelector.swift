//
//  ChallengeTemplateSelector.swift
//  Shelf Notes
//
//  Deterministic, value-only template selection.
//

import Foundation

nonisolated enum ChallengeTemplateSelector {
    static func selectTemplate(
        kind: ChallengeKind,
        baseline: ChallengeEngine.BaselineStats,
        recentMetrics: [ChallengeMetric] = [],
        periodStart: Date
    ) -> ChallengeTemplate {
        let candidates = eligibleTemplates(kind: kind, baseline: baseline)
        let pool = nonRepeatedPool(candidates: candidates, recentMetrics: recentMetrics)
        return select(from: pool, baseline: baseline, seed: stableSeed(kind: kind, periodStart: periodStart))
    }

    static func replacementTemplate(
        kind: ChallengeKind,
        currentMetric: ChallengeMetric,
        baseline: ChallengeEngine.BaselineStats,
        recentMetrics: [ChallengeMetric] = [],
        challengeID: UUID,
        rerollsUsed: Int
    ) -> ChallengeTemplate {
        let currentDifficulty = ChallengeTemplateRegistry.difficulty(kind: kind, metric: currentMetric)
        let candidates = eligibleTemplates(kind: kind, baseline: baseline)
            .filter { $0.metric != currentMetric }

        let sameDifficulty = candidates.filter { template in
            if let currentDifficulty {
                return template.difficulty == currentDifficulty
            }
            return false
        }
        let difficultyPool = sameDifficulty.isEmpty ? candidates : sameDifficulty
        let pool = nonRepeatedPool(candidates: difficultyPool, recentMetrics: recentMetrics.filter { $0 != currentMetric })

        guard !pool.isEmpty else {
            return ChallengeTemplateRegistry.template(kind: kind, metric: currentMetric)
                ?? selectTemplate(kind: kind, baseline: baseline, recentMetrics: recentMetrics, periodStart: Date())
        }

        return select(
            from: pool,
            baseline: baseline,
            seed: stableSeed(challengeID: challengeID, rerollsUsed: rerollsUsed)
        )
    }

    static func generatedChallenge(template: ChallengeTemplate, baseline: ChallengeEngine.BaselineStats) -> ChallengeEngine.GeneratedChallenge {
        let baselineValue = baseline.value(for: template.metric, kind: template.kind)
        let target = template.target(from: baselineValue)
        return ChallengeEngine.GeneratedChallenge(
            metric: template.metric,
            title: template.title(target: target),
            detail: template.detail,
            targetValue: target
        )
    }

    static func eligibleTemplates(kind: ChallengeKind, baseline: ChallengeEngine.BaselineStats) -> [ChallengeTemplate] {
        let templates = ChallengeTemplateRegistry.templates(for: kind)
        let eligible = templates.filter { template in
            if template.requiresPageHistory && baseline.pagesRead <= 0 { return false }
            if template.requiresFinishedBookHistory && baseline.finishedBooks <= 0 { return false }
            return true
        }
        return eligible.isEmpty ? templates : eligible
    }

    private static func nonRepeatedPool(candidates: [ChallengeTemplate], recentMetrics: [ChallengeMetric]) -> [ChallengeTemplate] {
        guard !candidates.isEmpty else { return [] }
        let blocked = Set(recentMetrics.prefix(2))
        let filtered = candidates.filter { !blocked.contains($0.metric) }
        return filtered.isEmpty ? candidates : filtered
    }

    private static func select(from candidates: [ChallengeTemplate], baseline: ChallengeEngine.BaselineStats, seed: Int) -> ChallengeTemplate {
        let sorted = candidates.sorted { lhs, rhs in
            let lhsScore = score(template: lhs, baseline: baseline)
            let rhsScore = score(template: rhs, baseline: baseline)
            if lhsScore != rhsScore { return lhsScore > rhsScore }
            return lhs.id < rhs.id
        }
        guard !sorted.isEmpty else {
            return ChallengeTemplateRegistry.templates(for: .weekly)[0]
        }

        let topScore = score(template: sorted[0], baseline: baseline)
        let closePool = sorted.filter { topScore - score(template: $0, baseline: baseline) <= 12 }
        let pool = closePool.isEmpty ? sorted : closePool
        let index = abs(seed % pool.count)
        return pool[index]
    }

    private static func score(template: ChallengeTemplate, baseline: ChallengeEngine.BaselineStats) -> Int {
        let baselineValue = baseline.value(for: template.metric, kind: template.kind)
        var score = template.emptyBaselinePriority

        if baselineValue > 0 {
            score += 18
        }

        switch template.difficulty {
        case .gentle:
            score += baseline.sessions <= 2 ? 8 : 0
        case .steady:
            score += 6
        case .stretch:
            score += baseline.minutes >= 90 || baseline.pagesRead >= 100 ? 7 : -8
        }

        if template.metric == .booksFinished && baseline.finishedBooks > 0 {
            score += 8
        }
        if template.metric == .readingDays && baseline.activeDays >= 4 {
            score += 6
        }
        if template.metric == .shortSessions && baseline.shortSessions > 0 {
            score += 6
        }
        if template.metric == .sessionNotes && baseline.sessionNotes > 0 {
            score += 5
        }

        return score
    }

    private static func stableSeed(kind: ChallengeKind, periodStart: Date) -> Int {
        let daySeed = Int(periodStart.timeIntervalSince1970 / 86_400)
        switch kind {
        case .daily:
            return daySeed &* 31 &+ 3
        case .weekly:
            return daySeed &* 31 &+ 7
        case .monthly:
            return daySeed &* 31 &+ 19
        case .yearly:
            return daySeed &* 31 &+ 31
        case .unknown:
            return daySeed &* 31 &+ 43
        }
    }

    private static func stableSeed(challengeID: UUID, rerollsUsed: Int) -> Int {
        let seed = challengeID.uuidString.unicodeScalars.reduce(into: 17) { partialResult, scalar in
            partialResult = (partialResult &* 31) &+ Int(scalar.value)
        }
        return seed &+ (rerollsUsed &* 13)
    }
}

nonisolated extension ChallengeEngine.BaselineStats {
    func value(for metric: ChallengeMetric, kind: ChallengeKind) -> Int {
        let divisor = ChallengeCadence.baselineDivisor(for: kind)
        switch metric {
        case .readingMinutes:
            return max(0, minutes / divisor)
        case .readingDays:
            return max(0, activeDays / divisor)
        case .sessions:
            return max(0, sessions / divisor)
        case .pagesRead:
            return max(0, pagesRead / divisor)
        case .booksFinished:
            return max(0, finishedBooks / divisor)
        case .shortSessions:
            return max(0, shortSessions / divisor)
        case .booksProgressed:
            return max(0, progressedBooks / divisor)
        case .sessionNotes:
            return max(0, sessionNotes / divisor)
        case .finishedBooksRated:
            return max(0, ratedFinishedBooks / divisor)
        case .finishedBooksNoted:
            return max(0, notedFinishedBooks / divisor)
        }
    }
}

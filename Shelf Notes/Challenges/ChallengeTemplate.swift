//
//  ChallengeTemplate.swift
//  Shelf Notes
//
//  Value definitions for reusable challenge missions.
//

import Foundation

nonisolated enum ChallengeDifficulty: String, CaseIterable, Identifiable, Sendable {
    case gentle
    case steady
    case stretch

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gentle:
            return "Locker"
        case .steady:
            return "Dranbleiben"
        case .stretch:
            return "Stretch"
        }
    }
}

nonisolated struct ChallengeTemplate: Identifiable, Equatable, Sendable {
    let id: String
    let kind: ChallengeKind
    let metric: ChallengeMetric
    let difficulty: ChallengeDifficulty
    let minimumTarget: Int
    let maximumTarget: Int
    let targetStep: Int
    let fallbackTarget: Int
    let baselineMultiplier: Double
    let baselineOffset: Int
    let detail: String
    let rewardText: String
    let emptyBaselinePriority: Int
    let requiresPageHistory: Bool
    let requiresFinishedBookHistory: Bool

    init(
        kind: ChallengeKind,
        metric: ChallengeMetric,
        difficulty: ChallengeDifficulty,
        minimumTarget: Int,
        maximumTarget: Int,
        targetStep: Int,
        fallbackTarget: Int,
        baselineMultiplier: Double,
        baselineOffset: Int,
        detail: String,
        rewardText: String,
        emptyBaselinePriority: Int,
        requiresPageHistory: Bool = false,
        requiresFinishedBookHistory: Bool = false
    ) {
        self.id = "\(kind.rawValue).\(metric.rawValue)"
        self.kind = kind
        self.metric = metric
        self.difficulty = difficulty
        self.minimumTarget = minimumTarget
        self.maximumTarget = maximumTarget
        self.targetStep = targetStep
        self.fallbackTarget = fallbackTarget
        self.baselineMultiplier = baselineMultiplier
        self.baselineOffset = baselineOffset
        self.detail = detail
        self.rewardText = rewardText
        self.emptyBaselinePriority = emptyBaselinePriority
        self.requiresPageHistory = requiresPageHistory
        self.requiresFinishedBookHistory = requiresFinishedBookHistory
    }

    func title(target: Int) -> String {
        switch metric {
        case .readingMinutes:
            return "\(target) Minuten lesen"
        case .readingDays:
            if kind == .daily {
                return "Heute zum Lesetag machen"
            }
            if kind == .weekly {
                return "Lies an \(target) Tagen"
            }
            return "\(target) Lesetage sammeln"
        case .sessions:
            if target == 1 {
                return "1 Session loggen"
            }
            return "\(target) Sessions loggen"
        case .pagesRead:
            return "\(target) Seiten lesen"
        case .booksFinished:
            return target == 1 ? "1 Abschluss sammeln" : "\(target) Abschlüsse sammeln"
        case .shortSessions:
            return "\(target) kurze Sessions"
        case .booksProgressed:
            return target == 1 ? "1 Buch weiterbringen" : "\(target) Bücher weiterbringen"
        case .sessionNotes:
            return target == 1 ? "1 Session-Notiz schreiben" : "\(target) Session-Notizen schreiben"
        case .finishedBooksRated:
            return target == 1 ? "1 beendetes Buch bewerten" : "\(target) beendete Bücher bewerten"
        case .finishedBooksNoted:
            return target == 1 ? "1 beendetes Buch notieren" : "\(target) beendete Bücher notieren"
        }
    }

    func target(from baselineValue: Int) -> Int {
        let raw: Int
        if baselineValue > 0 {
            raw = ChallengeTemplateMath.scaledCeiling(
                baselineValue: baselineValue,
                multiplier: baselineMultiplier
            ) + baselineOffset
        } else {
            raw = fallbackTarget
        }

        let clamped = ChallengeTemplateMath.clamp(raw, minimum: minimumTarget, maximum: maximumTarget)
        return ChallengeTemplateMath.roundUp(clamped, toMultipleOf: targetStep)
    }
}

nonisolated enum ChallengeTemplateMath {
    static func scaledCeiling(baselineValue: Int, multiplier: Double) -> Int {
        let product = Double(baselineValue) * multiplier
        let tolerance = 0.000_000_001
        return Int((product - tolerance).rounded(.up))
    }

    static func roundUp(_ value: Int, toMultipleOf step: Int) -> Int {
        guard step > 1 else { return value }
        let safe = max(0, value)
        let remainder = safe % step
        if remainder == 0 { return safe }
        return safe + (step - remainder)
    }

    static func clamp(_ value: Int, minimum: Int, maximum: Int) -> Int {
        Swift.max(minimum, Swift.min(maximum, value))
    }
}

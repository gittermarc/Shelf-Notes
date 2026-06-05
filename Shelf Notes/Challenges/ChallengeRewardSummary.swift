//
//  ChallengeRewardSummary.swift
//  Shelf Notes
//
//  Derived achievement state for the challenge board.
//

import Foundation

nonisolated struct ChallengeRewardSummary: Equatable, Sendable {
    let completedCount: Int
    let claimedCount: Int
    let readyToClaimCount: Int
    let weeklyStreak: Int
    let monthlyStreak: Int
    let bestKindStreak: Int
    let highlightTitle: String
    let highlightText: String
    let highlightSystemImage: String

    static let empty = ChallengeRewardSummary(
        completedCount: 0,
        claimedCount: 0,
        readyToClaimCount: 0,
        weeklyStreak: 0,
        monthlyStreak: 0,
        bestKindStreak: 0,
        highlightTitle: "Noch keine Trophäen",
        highlightText: "Sobald du Challenges abschließt, baut Shelf Notes daraus deine kleine Erfolgsbilanz.",
        highlightSystemImage: "trophy"
    )
}

nonisolated enum ChallengeRewardSummaryBuilder {
    static func make(items: [ChallengeDashboardItem], now: Date = Date()) -> ChallengeRewardSummary {
        guard !items.isEmpty else { return .empty }

        let completed = items.filter(\.isCompleted)
        let claimed = completed.filter { $0.status == .claimed }
        let ready = items.filter(\.isRewardReady)
        let weeklyStreak = streak(kind: .weekly, items: items, now: now)
        let monthlyStreak = streak(kind: .monthly, items: items, now: now)
        let best = max(weeklyStreak, monthlyStreak)
        let highlight = makeHighlight(
            completedCount: completed.count,
            readyCount: ready.count,
            weeklyStreak: weeklyStreak,
            monthlyStreak: monthlyStreak
        )

        return ChallengeRewardSummary(
            completedCount: completed.count,
            claimedCount: claimed.count,
            readyToClaimCount: ready.count,
            weeklyStreak: weeklyStreak,
            monthlyStreak: monthlyStreak,
            bestKindStreak: best,
            highlightTitle: highlight.title,
            highlightText: highlight.text,
            highlightSystemImage: highlight.systemImage
        )
    }

    private static func streak(kind: ChallengeKind, items: [ChallengeDashboardItem], now: Date) -> Int {
        let relevant = items
            .filter { $0.kind == kind }
            .sorted { lhs, rhs in
                if lhs.periodEnd != rhs.periodEnd { return lhs.periodEnd > rhs.periodEnd }
                return lhs.periodStart > rhs.periodStart
            }

        var count = 0
        for item in relevant {
            if item.isCompleted {
                count += 1
                continue
            }
            if item.periodEnd <= now {
                break
            }
        }
        return count
    }

    private static func makeHighlight(
        completedCount: Int,
        readyCount: Int,
        weeklyStreak: Int,
        monthlyStreak: Int
    ) -> (title: String, text: String, systemImage: String) {
        if readyCount > 0 {
            return (
                "Belohnung wartet",
                readyCount == 1 ? "Eine Challenge ist erledigt und wartet auf deinen Haken." : "\(readyCount) Challenges sind erledigt und warten auf deinen Haken.",
                "sparkles"
            )
        }

        if weeklyStreak >= 3 {
            return (
                "Wochen-Serie läuft",
                "\(weeklyStreak) Wochen-Challenges in Folge. Das ist kein Zufall mehr.",
                "flame.fill"
            )
        }

        if monthlyStreak >= 2 {
            return (
                "Monatslauf stabil",
                "\(monthlyStreak) Monats-Challenges in Folge. Schön ruhig, schön stark.",
                "calendar.badge.checkmark"
            )
        }

        if completedCount > 0 {
            return (
                "\(completedCount) kleine Siege",
                "Deine erledigten Challenges sammeln sich hier zu einer Erfolgsbilanz.",
                "trophy.fill"
            )
        }

        return (
            "Noch keine Trophäen",
            "Starte mit einer Session. Die erste Challenge ist meistens näher, als sie aussieht.",
            "trophy"
        )
    }
}

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
    let dailyStreak: Int
    let weeklyStreak: Int
    let monthlyStreak: Int
    let yearlyStreak: Int
    let bestKindStreak: Int
    let highlightTitle: String
    let highlightText: String
    let highlightSystemImage: String

    static let empty = ChallengeRewardSummary(
        completedCount: 0,
        claimedCount: 0,
        readyToClaimCount: 0,
        dailyStreak: 0,
        weeklyStreak: 0,
        monthlyStreak: 0,
        yearlyStreak: 0,
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
        let dailyStreak = streak(kind: .daily, items: items, now: now)
        let weeklyStreak = streak(kind: .weekly, items: items, now: now)
        let monthlyStreak = streak(kind: .monthly, items: items, now: now)
        let yearlyStreak = streak(kind: .yearly, items: items, now: now)
        let best = [dailyStreak, weeklyStreak, monthlyStreak, yearlyStreak].max() ?? 0
        let highlight = makeHighlight(
            completedCount: completed.count,
            readyCount: ready.count,
            dailyStreak: dailyStreak,
            weeklyStreak: weeklyStreak,
            monthlyStreak: monthlyStreak,
            yearlyStreak: yearlyStreak
        )

        return ChallengeRewardSummary(
            completedCount: completed.count,
            claimedCount: claimed.count,
            readyToClaimCount: ready.count,
            dailyStreak: dailyStreak,
            weeklyStreak: weeklyStreak,
            monthlyStreak: monthlyStreak,
            yearlyStreak: yearlyStreak,
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
        dailyStreak: Int,
        weeklyStreak: Int,
        monthlyStreak: Int,
        yearlyStreak: Int
    ) -> (title: String, text: String, systemImage: String) {
        if readyCount > 0 {
            return (
                "Belohnung wartet",
                readyCount == 1 ? "Eine Challenge ist erledigt und wartet auf deinen Haken." : "\(readyCount) Challenges sind erledigt und warten auf deinen Haken.",
                "sparkles"
            )
        }

        if dailyStreak >= 5 {
            return (
                "Tages-Serie läuft",
                "\(dailyStreak) Tages-Challenges in Folge. Genau so bleibt Lesen im Alltag.",
                "flame.fill"
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

        if yearlyStreak > 0 {
            return (
                "Jahresquest geschafft",
                "Eine Jahres-Challenge abgeschlossen. Das ist kein kleiner Haken, das ist ein Brett.",
                "calendar.circle.fill"
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

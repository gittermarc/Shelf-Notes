//
//  ChallengeDashboardState.swift
//  Shelf Notes
//
//  Value state for the challenge board UI.
//

import Foundation

nonisolated struct ChallengeDashboardState: Equatable {
    var todayFocus: ChallengeDashboardTodayFocus?
    var hero: ChallengeDashboardHero?
    var activeItems: [ChallengeDashboardItem]
    var historyItems: [ChallengeDashboardItem]
    var completedCount: Int
    var unclaimedCount: Int
    var rewardSummary: ChallengeRewardSummary

    var isEmpty: Bool {
        todayFocus == nil && activeItems.isEmpty && historyItems.isEmpty
    }

    var sessionHintItems: [ChallengeDashboardItem] {
        var items: [ChallengeDashboardItem] = []
        if let todayFocus {
            items.append(todayFocus.item)
        }
        items.append(contentsOf: activeItems)
        return items
    }

    static let empty = ChallengeDashboardState(
        todayFocus: nil,
        hero: nil,
        activeItems: [],
        historyItems: [],
        completedCount: 0,
        unclaimedCount: 0,
        rewardSummary: .empty
    )
}

nonisolated struct ChallengeDashboardTodayFocus: Identifiable, Equatable {
    let item: ChallengeDashboardItem
    let headline: String
    let message: String
    let actionText: String
    let footnote: String

    var id: UUID { item.id }
}

nonisolated struct ChallengeDashboardHero: Equatable {
    let itemID: UUID
    let title: String
    let subtitle: String
    let systemImage: String
    let progressFraction: Double
    let progressText: String
    let actionText: String
    let isRewardReady: Bool
}

nonisolated struct ChallengeDashboardItem: Identifiable, Equatable {
    nonisolated enum Status: Equatable {
        case active
        case readyToClaim
        case claimed
        case expired
    }

    let id: UUID
    let kind: ChallengeKind
    let metric: ChallengeMetric
    let title: String
    let detail: String
    let targetValue: Int
    let periodLabel: String
    let periodStart: Date
    let periodEnd: Date
    let progress: ChallengeEngine.ChallengeProgress?
    let status: Status
    let canReroll: Bool
    let timeRemainingText: String
    let deadlineText: String
    let progressText: String
    let remainingText: String
    let motivationText: String
    let difficultyText: String
    let rewardText: String

    var progressFraction: Double {
        progress?.fraction(target: targetValue) ?? 0
    }

    var remainingValue: Int {
        max(0, targetValue - (progress?.value ?? 0))
    }

    var isRewardReady: Bool {
        status == .readyToClaim
    }

    var isCompleted: Bool {
        status == .readyToClaim || status == .claimed
    }

    var celebrationState: ChallengeCelebrationState {
        switch status {
        case .readyToClaim:
            return .readyToClaim
        case .claimed:
            return .claimed
        case .active, .expired:
            return .none
        }
    }

    var shouldHighlightCompletion: Bool {
        celebrationState.isHighlighted
    }

    var statusText: String {
        switch status {
        case .active:
            return "Aktiv"
        case .readyToClaim:
            return "Belohnung bereit"
        case .claimed:
            return "Gesichert"
        case .expired:
            return "Beendet"
        }
    }

    var statusSystemImage: String {
        switch status {
        case .active:
            return "bolt.fill"
        case .readyToClaim:
            return "sparkles"
        case .claimed:
            return "checkmark.seal.fill"
        case .expired:
            return "clock.badge.xmark"
        }
    }

    var primaryActionTitle: String {
        if isRewardReady { return "Belohnung abholen" }
        if canReroll { return "Alternative wählen" }
        return "Dranbleiben"
    }
}

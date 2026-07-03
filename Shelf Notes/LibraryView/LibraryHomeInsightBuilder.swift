//
//  LibraryHomeInsightBuilder.swift
//  Shelf Notes
//
//  Pure builder for lightweight Smart Shelf reading insights.
//

import Foundation

extension LibraryView {
    nonisolated enum LibraryHomeInsightBuilder {
        static let defaultMaxItems = 4

        static func makeSnapshot(
            progress: LibraryHomeInsightProgressInput? = nil,
            challenge: LibraryHomeInsightChallengeInput? = nil,
            maxItems: Int = defaultMaxItems
        ) -> LibraryHomeInsightSnapshot {
            let limit = max(0, maxItems)
            guard limit > 0 else { return .empty }

            var items: [LibraryHomeInsightItem] = []
            items.reserveCapacity(limit)

            if let challengeItem = makeChallengeItem(from: challenge) {
                items.append(challengeItem)
            }

            if let goalItem = makeGoalItem(from: progress) {
                items.append(goalItem)
            }

            if let minutesItem = makeWeeklyMinutesItem(from: progress) {
                items.append(minutesItem)
            }

            if let streakItem = makeStreakItem(from: progress) {
                items.append(streakItem)
            } else if let activeDaysItem = makeActiveDaysItem(from: progress) {
                items.append(activeDaysItem)
            }

            if items.isEmpty {
                return .empty
            }

            return LibraryHomeInsightSnapshot(items: Array(items.prefix(limit)))
        }

        static func makeChallengeInput(from dashboard: ChallengeDashboardState?) -> LibraryHomeInsightChallengeInput? {
            guard let dashboard else { return nil }

            if dashboard.unclaimedCount > 0 {
                return LibraryHomeInsightChallengeInput(
                    readyToClaimCount: dashboard.unclaimedCount,
                    title: "Belohnung wartet",
                    value: "\(dashboard.unclaimedCount)",
                    caption: dashboard.unclaimedCount == 1 ? "Challenge bereit" : "Challenges bereit",
                    systemImage: "sparkles",
                    progressFraction: 1,
                    isRewardReady: true
                )
            }

            if let todayFocus = dashboard.todayFocus {
                return LibraryHomeInsightChallengeInput(
                    readyToClaimCount: 0,
                    title: todayFocus.headline,
                    value: todayFocus.item.progressText,
                    caption: todayFocus.actionText,
                    systemImage: todayFocus.item.metric.systemImage,
                    progressFraction: todayFocus.item.progressFraction,
                    isRewardReady: false
                )
            }

            if let hero = dashboard.hero {
                return LibraryHomeInsightChallengeInput(
                    readyToClaimCount: 0,
                    title: hero.title,
                    value: hero.progressText,
                    caption: hero.actionText,
                    systemImage: hero.systemImage,
                    progressFraction: hero.progressFraction,
                    isRewardReady: hero.isRewardReady
                )
            }

            return nil
        }

        private static func makeChallengeItem(
            from input: LibraryHomeInsightChallengeInput?
        ) -> LibraryHomeInsightItem? {
            guard let input else { return nil }
            let title = normalized(input.title) ?? (input.isRewardReady ? "Belohnung wartet" : "Challenge")
            guard let value = normalized(input.value) else { return nil }
            let caption = normalized(input.caption) ?? "Aktuelle Mission"

            return LibraryHomeInsightItem(
                kind: .challenge,
                title: title,
                value: value,
                caption: caption,
                systemImage: normalized(input.systemImage) ?? "trophy",
                progressFraction: normalizedFraction(input.progressFraction),
                isProminent: input.isRewardReady || input.readyToClaimCount > 0
            )
        }

        private static func makeGoalItem(
            from input: LibraryHomeInsightProgressInput?
        ) -> LibraryHomeInsightItem? {
            guard let input, let target = input.goalTarget, target > 0 else { return nil }
            let finished = max(0, input.finishedThisYear)
            let fraction = min(1, Double(finished) / Double(target))

            return LibraryHomeInsightItem(
                kind: .yearGoal,
                title: "Jahresziel",
                value: "\(finished) / \(target)",
                caption: "\(input.year)",
                systemImage: "target",
                progressFraction: fraction,
                isProminent: finished >= target
            )
        }

        private static func makeWeeklyMinutesItem(
            from input: LibraryHomeInsightProgressInput?
        ) -> LibraryHomeInsightItem? {
            guard let input else { return nil }
            let minutes = max(0, input.minutesLast7)
            guard minutes > 0 else { return nil }

            return LibraryHomeInsightItem(
                kind: .weeklyMinutes,
                title: "Lesezeit",
                value: "\(minutes)",
                caption: "Min. letzte 7 Tage",
                systemImage: "clock",
                progressFraction: nil,
                isProminent: false
            )
        }

        private static func makeStreakItem(
            from input: LibraryHomeInsightProgressInput?
        ) -> LibraryHomeInsightItem? {
            guard let input else { return nil }
            let streak = max(0, input.currentStreak)
            guard streak > 0 else { return nil }

            return LibraryHomeInsightItem(
                kind: .readingStreak,
                title: "Serie",
                value: "\(streak)",
                caption: streak == 1 ? "Tag am Stück" : "Tage am Stück",
                systemImage: "flame",
                progressFraction: nil,
                isProminent: streak >= 3
            )
        }

        private static func makeActiveDaysItem(
            from input: LibraryHomeInsightProgressInput?
        ) -> LibraryHomeInsightItem? {
            guard let input else { return nil }
            let activeDays = max(0, input.activeDaysLast7)
            guard activeDays > 0 else { return nil }

            return LibraryHomeInsightItem(
                kind: .activeDays,
                title: "Lesetage",
                value: "\(activeDays)",
                caption: "letzte 7 Tage",
                systemImage: "calendar",
                progressFraction: nil,
                isProminent: false
            )
        }

        private static func normalized(_ value: String?) -> String? {
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        private static func normalizedFraction(_ value: Double?) -> Double? {
            guard let value, value.isFinite else { return nil }
            return min(1, max(0, value))
        }
    }
}

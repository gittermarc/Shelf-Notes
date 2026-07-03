//
//  LibraryHomeInsightSnapshot.swift
//  Shelf Notes
//
//  Value-only insight model for the Smart Shelf home area.
//

import Foundation

extension LibraryView {
    nonisolated struct LibraryHomeInsightSnapshot: Equatable {
        let items: [LibraryHomeInsightItem]

        static let empty = LibraryHomeInsightSnapshot(items: [])

        var isEmpty: Bool {
            items.isEmpty
        }
    }

    nonisolated struct LibraryHomeInsightProgressInput: Equatable, Sendable {
        let year: Int
        let finishedThisYear: Int
        let goalTarget: Int?
        let minutesLast7: Int
        let activeDaysLast7: Int
        let currentStreak: Int

        static let empty = LibraryHomeInsightProgressInput(
            year: 0,
            finishedThisYear: 0,
            goalTarget: nil,
            minutesLast7: 0,
            activeDaysLast7: 0,
            currentStreak: 0
        )
    }

    nonisolated struct LibraryHomeInsightChallengeInput: Equatable, Sendable {
        let readyToClaimCount: Int
        let title: String?
        let value: String?
        let caption: String?
        let systemImage: String?
        let progressFraction: Double?
        let isRewardReady: Bool

        static let empty = LibraryHomeInsightChallengeInput(
            readyToClaimCount: 0,
            title: nil,
            value: nil,
            caption: nil,
            systemImage: nil,
            progressFraction: nil,
            isRewardReady: false
        )
    }

    nonisolated struct LibraryHomeInsightItem: Equatable, Identifiable, Sendable {
        enum Kind: String, Sendable {
            case challenge
            case yearGoal
            case weeklyMinutes
            case readingStreak
            case activeDays
        }

        let kind: Kind
        let title: String
        let value: String
        let caption: String
        let systemImage: String
        let progressFraction: Double?
        let isProminent: Bool

        var id: String { kind.rawValue }

        var accessibilityLabel: String {
            var parts = [title, value, caption]
            if let progressFraction {
                let percent = Int((progressFraction * 100).rounded())
                parts.append("\(percent) Prozent")
            }
            return parts.joined(separator: ", ")
        }
    }
}

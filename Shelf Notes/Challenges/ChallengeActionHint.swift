//
//  ChallengeActionHint.swift
//  Shelf Notes
//
//  Lightweight presentation state for session-adjacent challenge hints.
//

import Foundation

nonisolated struct ChallengeActionHint: Identifiable, Equatable, Sendable {
    let id: UUID
    let challengeID: UUID
    let kind: ChallengeKind
    let metric: ChallengeMetric
    let title: String
    let message: String
    let detail: String
    let progressText: String
    let remainingText: String
    let progressFraction: Double
    let systemImage: String
    let priority: Int
}

nonisolated struct ChallengeSessionContribution: Equatable, Sendable {
    let bookID: UUID
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Int
    let pagesRead: Int
    let didMarkBookFinished: Bool
    let hasNote: Bool

    init(
        bookID: UUID,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int,
        pagesRead: Int?,
        didMarkBookFinished: Bool,
        hasNote: Bool = false
    ) {
        self.bookID = bookID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = max(0, durationSeconds)
        self.pagesRead = max(0, pagesRead ?? 0)
        self.didMarkBookFinished = didMarkBookFinished
        self.hasNote = hasNote
    }
}

nonisolated struct ChallengeSessionImpact: Identifiable, Equatable, Sendable {
    let id: UUID
    let bookID: UUID
    let createdAt: Date
    let title: String
    let subtitle: String
    let entries: [ChallengeSessionImpactEntry]

    var isEmpty: Bool {
        entries.isEmpty
    }

    var didCompleteChallenge: Bool {
        entries.contains(where: \.didComplete)
    }
}

nonisolated struct ChallengeSessionImpactEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let kind: ChallengeKind
    let metric: ChallengeMetric
    let title: String
    let contributionText: String
    let progressText: String
    let didComplete: Bool
    let progressFraction: Double
    let systemImage: String
}

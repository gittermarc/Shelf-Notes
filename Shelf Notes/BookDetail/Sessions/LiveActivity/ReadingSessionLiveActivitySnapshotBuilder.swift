//
//  ReadingSessionLiveActivitySnapshotBuilder.swift
//  Shelf Notes
//
//  Builds a small display snapshot for the Reading Live Activity.
//

import Foundation

@MainActor
enum ReadingSessionLiveActivitySnapshotBuilder {
    static func make(
        book: Book,
        allSessions: [ReadingSession],
        challengeHints: [ChallengeActionHint] = [],
        isPaused: Bool,
        hasCover: Bool,
        coverRevision: Int? = nil,
        accentHex: String? = nil
    ) -> ReadingSessionLiveActivitySnapshot {
        let progressSessions = ReadingAttemptSessionCoordinator.progressSessions(
            for: book,
            allSessions: allSessions
        )
        let pagesRead = ReadingSessionLogging.pagesReadTotal(in: progressSessions)
        let pageCount = ReadingSessionLogging.normalizedTotalPages(book.pageCount)
        let displayPagesRead = pageCount.map { min(pagesRead, $0) } ?? pagesRead
        let remainingPages = ReadingAttemptSessionCoordinator.currentRemainingPages(
            for: book,
            allSessions: allSessions
        )
        let progressFraction = ReadingSessionLogging.progressFraction(
            status: book.status,
            totalPages: book.pageCount,
            sessions: progressSessions
        )
        let challenge = makeChallengePayload(from: challengeHints)

        return ReadingSessionLiveActivitySnapshot(
            bookID: book.id,
            bookTitle: book.title,
            bookAuthor: book.author,
            attemptName: makeAttemptName(for: book),
            pageCount: pageCount,
            pagesRead: displayPagesRead > 0 ? displayPagesRead : nil,
            remainingPages: remainingPages,
            progressFraction: progressFraction,
            challengeTitle: challenge?.title,
            challengeDetail: challenge?.detail,
            challengeProgressFraction: challenge?.progressFraction,
            stateLabel: isPaused ? ReadingSessionLiveActivitySnapshot.pausedStateLabel : ReadingSessionLiveActivitySnapshot.runningStateLabel,
            hasCover: hasCover,
            coverRevision: coverRevision ?? (hasCover ? 1 : nil),
            accentHex: accentHex
        )
    }

    private struct ChallengePayload: Equatable {
        var title: String
        var detail: String?
        var progressFraction: Double
    }

    private static func makeAttemptName(for book: Book) -> String? {
        if let activeAttempt = book.activeReadingAttempt {
            return activeAttempt.displayName
        }

        if book.completedReadingAttemptCount > 1 {
            return book.completedReadingAttempts.last?.displayName
        }

        return nil
    }

    private static func makeChallengePayload(from hints: [ChallengeActionHint]) -> ChallengePayload? {
        guard let hint = hints.first else { return nil }

        let detail: String?
        if !hint.remainingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            detail = hint.remainingText
        } else if !hint.progressText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            detail = hint.progressText
        } else if !hint.detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            detail = hint.detail
        } else {
            detail = nil
        }

        return ChallengePayload(
            title: hint.title,
            detail: detail,
            progressFraction: hint.progressFraction
        )
    }
}

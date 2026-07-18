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
        let inputContext = ReadingSessionMutationService.makeProgressInputContext(
            book: book,
            allSessions: allSessions,
            origin: .timer
        )
        let source = makeSourceSnapshot(book: book, context: inputContext)
        let progress = makeProgressPayload(
            book: book,
            allSessions: allSessions,
            context: inputContext
        )
        let challenge = makeChallengePayload(from: challengeHints)

        return ReadingSessionLiveActivitySnapshot(
            bookID: book.id,
            bookTitle: book.title,
            bookAuthor: book.author,
            attemptName: makeAttemptName(for: book),
            pageCount: progress.pageCount,
            pagesRead: progress.pagesRead,
            remainingPages: progress.remainingPages,
            progressFraction: progress.progressFraction,
            locator: progress.locator,
            readingAttemptID: source.readingAttemptID,
            readingMedium: source.readingMedium,
            readingProvider: source.readingProvider,
            progressUnit: source.progressUnit,
            origin: source.origin,
            expectedExternalReading: source.expectedExternalReading,
            totalValue: source.totalValue,
            challengeTitle: challenge?.title,
            challengeDetail: challenge?.detail,
            challengeProgressFraction: challenge?.progressFraction,
            stateLabel: isPaused ? ReadingSessionLiveActivitySnapshot.pausedStateLabel : ReadingSessionLiveActivitySnapshot.runningStateLabel,
            hasCover: hasCover,
            coverRevision: coverRevision ?? (hasCover ? 1 : nil),
            accentHex: accentHex
        )
    }

    private struct ProgressPayload: Equatable {
        var pageCount: Int?
        var pagesRead: Int?
        var remainingPages: Int?
        var progressFraction: Double?
        var locator: String?
    }

    private struct ChallengePayload: Equatable {
        var title: String
        var detail: String?
        var progressFraction: Double
    }

    private static func makeSourceSnapshot(
        book: Book,
        context: ReadingSessionProgressInputContext
    ) -> ReadingTimerSessionSourceSnapshot {
        ReadingTimerSessionSourceSnapshot(
            readingAttemptID: book.activeReadingAttempt?.id,
            readingMedium: context.source.medium,
            readingProvider: context.source.provider,
            progressUnit: context.source.progressUnit,
            origin: context.source.origin,
            totalValue: context.source.totalValue
        )
    }

    private static func makeProgressPayload(
        book: Book,
        allSessions: [ReadingSession],
        context: ReadingSessionProgressInputContext
    ) -> ProgressPayload {
        switch context.source.progressUnit {
        case .pages:
            return makePageProgressPayload(book: book, allSessions: allSessions)
        case .percentage:
            return ProgressPayload(
                pageCount: nil,
                pagesRead: nil,
                remainingPages: nil,
                progressFraction: percentageProgressFraction(context.currentProgress),
                locator: nil
            )
        case .locator:
            return ProgressPayload(
                pageCount: nil,
                pagesRead: nil,
                remainingPages: nil,
                progressFraction: context.currentProgress.normalizedProgress,
                locator: context.currentProgress.locator
            )
        case .none:
            return ProgressPayload(
                pageCount: nil,
                pagesRead: nil,
                remainingPages: nil,
                progressFraction: nil,
                locator: nil
            )
        }
    }

    private static func makePageProgressPayload(
        book: Book,
        allSessions: [ReadingSession]
    ) -> ProgressPayload {
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

        return ProgressPayload(
            pageCount: pageCount,
            pagesRead: displayPagesRead > 0 ? displayPagesRead : nil,
            remainingPages: remainingPages,
            progressFraction: progressFraction,
            locator: nil
        )
    }

    private static func percentageProgressFraction(_ snapshot: ReadingProgressSnapshot) -> Double? {
        if let normalized = snapshot.normalizedProgress, normalized.isFinite {
            return min(1.0, max(0.0, normalized))
        }
        guard let nativeValue = snapshot.nativeValue,
              nativeValue.isFinite else {
            return nil
        }
        let totalValue = snapshot.totalValue ?? 100
        guard totalValue.isFinite, totalValue > 0 else { return nil }
        return min(1.0, max(0.0, nativeValue / totalValue))
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

//
//  ReadingSessionMutationService+ProgressInput.swift
//  Shelf Notes
//

import Foundation

@MainActor
extension ReadingSessionMutationService {
    static func makeProgressInputContext(
        book: Book,
        allSessions: [ReadingSession],
        origin: ReadingSessionOrigin
    ) -> ReadingSessionProgressInputContext {
        let activeAttempt = book.activeReadingAttempt
        let sourceDraft = ReadingSourceDraft.resolved(
            medium: activeAttempt?.readingMedium ?? .physical,
            provider: activeAttempt?.defaultProvider ?? .none,
            progressUnit: activeAttempt?.progressUnit ?? .pages
        )
        let source = ReadingSessionSource(
            medium: sourceDraft.medium,
            provider: sourceDraft.provider,
            progressUnit: sourceDraft.progressUnit,
            origin: origin,
            totalValue: activeAttempt?.totalValueSnapshot
                ?? sourceDraft.totalValue(bookPageCount: book.pageCount)
        )
        let sessionContext = ReadingSessionContext.resolved(
            readingAttempt: activeAttempt,
            requestedSource: source
        )
        let currentProgress = ReadingSessionProgressSnapshotBuilder.make(
            book: book,
            attempt: activeAttempt,
            context: sessionContext,
            sessions: allSessions
        )
        let presentation = ReadingSourcePresentation.make(
            medium: sessionContext.medium,
            provider: sessionContext.provider,
            progressUnit: sessionContext.progressUnit
        )

        return ReadingSessionProgressInputContext(
            source: source,
            currentProgress: currentProgress,
            configuration: ReadingProgressInputConfiguration(
                unit: sessionContext.progressUnit,
                currentProgress: currentProgress,
                remainingPages: sessionContext.progressUnit == .pages
                    ? currentProgress.remainingPages
                    : nil,
                allowsPageOverflow: book.status == .finished && activeAttempt == nil,
                sourceTitle: presentation.title,
                isManuallyTracked: sourceDraft.isManuallyTracked
            )
        )
    }
}

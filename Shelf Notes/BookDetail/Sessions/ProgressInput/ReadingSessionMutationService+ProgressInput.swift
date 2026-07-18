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
        let medium = activeAttempt?.readingMedium ?? .physical
        let provider = activeAttempt?.defaultProvider ?? .none
        let progressUnit = activeAttempt?.progressUnit ?? .pages
        let selection = ReadingSourceSelection.resolved(
            medium: medium,
            provider: provider,
            progressUnit: progressUnit
        )
        let source = ReadingSessionSource(
            medium: medium,
            provider: provider,
            progressUnit: progressUnit,
            origin: origin,
            totalValue: activeAttempt?.totalValueSnapshot
                ?? fallbackTotalValue(progressUnit: progressUnit, bookPageCount: book.pageCount)
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
                isManuallyTracked: selection.isManuallyTracked
            )
        )
    }

    private static func fallbackTotalValue(
        progressUnit: ReadingProgressUnit,
        bookPageCount: Int?
    ) -> Double? {
        switch progressUnit {
        case .pages:
            guard let bookPageCount, bookPageCount > 0 else { return nil }
            return Double(bookPageCount)
        case .percentage:
            return 100
        case .locator, .none:
            return nil
        }
    }
}

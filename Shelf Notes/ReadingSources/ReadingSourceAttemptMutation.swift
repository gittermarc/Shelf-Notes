//
//  ReadingSourceAttemptMutation.swift
//  Shelf Notes
//

import Foundation

@MainActor
enum ReadingSourceAttemptMutation {
    static func apply(
        _ draft: ReadingSourceDraft,
        to attempt: ReadingAttempt,
        book: Book,
        now: Date = Date()
    ) {
        attempt.readingMediumRawValue = draft.medium.rawValue
        attempt.defaultProviderRawValue = draft.provider.rawValue
        attempt.progressUnitRawValue = draft.progressUnit.rawValue
        attempt.totalValueSnapshot = draft.totalValue(bookPageCount: book.pageCount)

        if draft.progressUnit == .pages,
           attempt.pageCountSnapshot == nil,
           let pageCount = ReadingAttemptRepair.normalizedPageCount(book.pageCount) {
            attempt.pageCountSnapshot = pageCount
        }

        attempt.updatedAt = now
    }

    static func canChangeSource(of attempt: ReadingAttempt) -> Bool {
        attempt.sessionsSafe.isEmpty && attempt.progressEventsSafe.isEmpty
    }
}

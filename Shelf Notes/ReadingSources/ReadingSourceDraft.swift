//
//  ReadingSourceDraft.swift
//  Shelf Notes
//

import Foundation

nonisolated struct ReadingSourceDraft: Equatable, Sendable {
    var selection: ReadingSourceSelection

    init(selection: ReadingSourceSelection = .physical) {
        self.selection = selection
    }

    var medium: ReadingMedium { selection.medium }
    var provider: ReadingProvider { selection.provider }
    var progressUnit: ReadingProgressUnit { selection.progressUnit }
    var isAvailable: Bool { selection.isAvailable }
    var isManuallyTracked: Bool { selection.isManuallyTracked }

    func sessionSource(
        origin: ReadingSessionOrigin,
        bookPageCount: Int? = nil
    ) -> ReadingSessionSource {
        ReadingSessionSource(
            medium: medium,
            provider: provider,
            progressUnit: progressUnit,
            origin: origin,
            totalValue: totalValue(bookPageCount: bookPageCount)
        )
    }

    func totalValue(bookPageCount: Int?) -> Double? {
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

    static func resolved(
        medium: ReadingMedium,
        provider: ReadingProvider,
        progressUnit: ReadingProgressUnit
    ) -> ReadingSourceDraft {
        ReadingSourceDraft(
            selection: ReadingSourceSelection.resolved(
                medium: medium,
                provider: provider,
                progressUnit: progressUnit
            )
        )
    }
}

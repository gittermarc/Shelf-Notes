//
//  ReadingSessionContext.swift
//  Shelf Notes
//

import Foundation

nonisolated struct ReadingSessionSource: Equatable, Sendable {
    let medium: ReadingMedium
    let provider: ReadingProvider
    let progressUnit: ReadingProgressUnit
    let origin: ReadingSessionOrigin
    let totalValue: Double?

    init(
        medium: ReadingMedium = .physical,
        provider: ReadingProvider = .none,
        progressUnit: ReadingProgressUnit = .pages,
        origin: ReadingSessionOrigin,
        totalValue: Double? = nil
    ) {
        self.medium = medium
        self.provider = provider
        self.progressUnit = progressUnit
        self.origin = origin
        self.totalValue = totalValue
    }
}

@MainActor
struct ReadingSessionContext {
    let readingAttempt: ReadingAttempt?
    let medium: ReadingMedium
    let provider: ReadingProvider
    let progressUnit: ReadingProgressUnit
    let origin: ReadingSessionOrigin
    let totalValue: Double?

    init(
        readingAttempt: ReadingAttempt?,
        source: ReadingSessionSource
    ) {
        self.readingAttempt = readingAttempt
        self.medium = source.medium
        self.provider = source.provider
        self.progressUnit = source.progressUnit
        self.origin = source.origin
        self.totalValue = source.totalValue
    }

    static func resolved(
        readingAttempt: ReadingAttempt?,
        requestedSource: ReadingSessionSource
    ) -> ReadingSessionContext {
        guard let readingAttempt else {
            return ReadingSessionContext(
                readingAttempt: nil,
                source: requestedSource
            )
        }

        return ReadingSessionContext(
            readingAttempt: readingAttempt,
            source: ReadingSessionSource(
                medium: requestedSource.medium,
                provider: requestedSource.provider,
                progressUnit: readingAttempt.progressUnit,
                origin: requestedSource.origin,
                totalValue: readingAttempt.totalValueSnapshot ?? requestedSource.totalValue
            )
        )
    }
}

//
//  BookExternalReferenceFactory.swift
//  Shelf Notes
//

import Foundation

nonisolated enum BookExternalReferenceFactory {
    static func googleBooksReference(
        for book: Book,
        volumeID: String?,
        canonicalURL: String?
    ) -> BookExternalReference? {
        guard let providerItemIdentifier = normalizedText(volumeID) else { return nil }
        let validatedURL = ReadingProviderLaunchPolicy.validatedReadingURL(
            rawString: canonicalURL,
            provider: .googleBooks
        )?.absoluteString

        return BookExternalReference(
            book: book,
            provider: .googleBooks,
            providerItemIdentifier: providerItemIdentifier,
            canonicalURL: validatedURL
        )
    }

    private static func normalizedText(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return nil
        }
        return trimmed
    }
}
//
//  ReadingProviderLaunchReference+Models.swift
//  Shelf Notes
//

import Foundation

extension BookExternalReference {
    var launchReference: ReadingProviderLaunchReference {
        ReadingProviderLaunchReference(
            provider: provider,
            providerItemIdentifier: providerItemIdentifier,
            canonicalURL: canonicalURL
        )
    }
}

extension Book {
    var readingProviderLaunchReferences: [ReadingProviderLaunchReference] {
        externalReferencesSafe.map(\.launchReference)
    }

    func hasValidReadingLink(for provider: ReadingProvider) -> Bool {
        readingProviderLaunchReferences.contains { reference in
            reference.provider == provider
                && ReadingProviderLaunchPolicy.validatedReadingURL(
                    rawString: reference.canonicalURL,
                    provider: provider
                ) != nil
        }
    }
}
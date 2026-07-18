//
//  ReadingIntegrationRegistry.swift
//  Shelf Notes
//

import Foundation

nonisolated struct ReadingIntegrationRegistry: Sendable {
    static let `default` = ReadingIntegrationRegistry(
        integrations: [
            AppleBooksCompanionIntegration.integration,
            KindleCompanionIntegration.integration,
            OtherEbookCompanionIntegration.integration,
            GoogleBooksFutureIntegration.integration,
            LocalFileFutureReaderIntegration.integration
        ]
    )

    let integrations: [ReadingIntegration]

    init(integrations: [ReadingIntegration]) {
        var seen = Set<ReadingProvider>()
        self.integrations = integrations.filter { integration in
            seen.insert(integration.provider).inserted
        }
    }

    func integration(for provider: ReadingProvider) -> ReadingIntegration? {
        integrations.first { $0.provider == provider }
    }

    func capabilities(for provider: ReadingProvider) -> ReadingIntegrationCapabilities {
        integration(for: provider)?.capabilities ?? []
    }

    func supportsCompanionLaunch(for provider: ReadingProvider) -> Bool {
        integration(for: provider)?.supportsCompanionLaunch ?? false
    }
}
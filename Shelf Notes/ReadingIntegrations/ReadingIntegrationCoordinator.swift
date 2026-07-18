//
//  ReadingIntegrationCoordinator.swift
//  Shelf Notes
//

import Foundation

nonisolated struct ReadingIntegrationStartRequest: Equatable, Sendable {
    var sourceSnapshot: ReadingTimerSessionSourceSnapshot
    var references: [ReadingProviderLaunchReference]

    var provider: ReadingProvider { sourceSnapshot.readingProvider }

    init(
        sourceSnapshot: ReadingTimerSessionSourceSnapshot,
        references: [ReadingProviderLaunchReference]
    ) {
        self.sourceSnapshot = sourceSnapshot
        self.references = references
    }
}

nonisolated enum ReadingIntegrationStartResult: Equatable, Sendable {
    case startedWithoutExternalDestination
    case opened(URL)
    case missingReadingLink(ReadingProviderLaunchGuidance)
    case blockedReadingLink(String)
    case failedToStartTimer(String)

    var userMessage: String? {
        switch self {
        case .startedWithoutExternalDestination, .opened:
            return nil
        case .missingReadingLink(let guidance):
            return guidance.message
        case .blockedReadingLink(let message), .failedToStartTimer(let message):
            return message
        }
    }

    var isError: Bool {
        switch self {
        case .blockedReadingLink, .failedToStartTimer:
            return true
        case .startedWithoutExternalDestination, .opened, .missingReadingLink:
            return false
        }
    }
}

nonisolated enum ReadingIntegrationCoordinator {
    typealias TimerStart = () -> String?
    typealias OpenReadingURL = (URL) -> Void

    @MainActor
    static func startTimerAndOpenReadingDestinationIfPossible(
        request: ReadingIntegrationStartRequest,
        registry: ReadingIntegrationRegistry = .default,
        startTimer: TimerStart,
        openReadingURL: OpenReadingURL
    ) -> ReadingIntegrationStartResult {
        if let error = startTimer() {
            return .failedToStartTimer(error)
        }

        guard registry.supportsCompanionLaunch(for: request.provider) else {
            return .startedWithoutExternalDestination
        }

        switch ReadingProviderLaunchPolicy.decision(
            provider: request.provider,
            references: request.references,
            registry: registry
        ) {
        case .open(let url):
            openReadingURL(url)
            return .opened(url)
        case .missingReadingLink(let guidance):
            return .missingReadingLink(guidance)
        case .blocked(let message):
            return .blockedReadingLink(message)
        case .notAvailable:
            return .startedWithoutExternalDestination
        }
    }
}
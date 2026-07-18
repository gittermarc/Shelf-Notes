//
//  ReadingIntegration.swift
//  Shelf Notes
//

import Foundation

nonisolated enum ReadingIntegrationKind: String, Equatable, Sendable {
    case companion
    case futureSync
    case futureReader
}

nonisolated struct ReadingIntegration: Identifiable, Equatable, Sendable {
    var provider: ReadingProvider
    var title: String
    var subtitle: String
    var systemImage: String
    var kind: ReadingIntegrationKind
    var capabilities: ReadingIntegrationCapabilities
    var progressMode: ReadingIntegrationProgressMode
    var baseAvailability: ReadingIntegrationAvailability
    var manualSourceSelectable: Bool

    var id: ReadingProvider { provider }

    var supportsCompanionLaunch: Bool {
        kind == .companion && capabilities.contains(.canOpenReadingDestination)
    }
}

nonisolated enum ReadingIntegrationAvailabilityResolver {
    static func availability(
        for integration: ReadingIntegration,
        environment: ReadingIntegrationEnvironment = ReadingIntegrationEnvironment()
    ) -> ReadingIntegrationAvailability {
        switch integration.provider {
        case .appleBooks, .kindle, .other:
            if environment.hasStoredReadingLink {
                return .companionAvailable(detail: "Timer und Live Activity starten, danach wird ein geprüfter HTTPS-Leselink geöffnet.")
            }
            return integration.baseAvailability

        case .googleBooks:
            return integration.baseAvailability

        case .localFile:
            if environment.hasLocalPublication,
               environment.isLocalReaderFeatureEnabled,
               integration.capabilities.contains(.canReadLocally) {
                return .available(detail: "Lokale Publikation kann direkt in Shelf Notes gelesen werden.")
            }
            if environment.hasLocalPublication {
                return .comingSoon(detail: "Eine lokale Publikation ist vorhanden, der integrierte Reader ist aber noch nicht freigeschaltet.")
            }
            return integration.baseAvailability

        case .none:
            return .available(detail: "Physische Bücher werden direkt über manuelle Seiten-Sessions erfasst.")
        }
    }
}
//
//  ReadingIntegrationCapabilities.swift
//  Shelf Notes
//

import Foundation

nonisolated struct ReadingIntegrationCapabilities: OptionSet, Hashable, Sendable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let canOpenReadingDestination = ReadingIntegrationCapabilities(rawValue: 1 << 0)
    static let canReceiveShares = ReadingIntegrationCapabilities(rawValue: 1 << 1)
    static let canImportLibrary = ReadingIntegrationCapabilities(rawValue: 1 << 2)
    static let canSyncProgress = ReadingIntegrationCapabilities(rawValue: 1 << 3)
    static let canReadLocally = ReadingIntegrationCapabilities(rawValue: 1 << 4)
    static let requiresAuthorization = ReadingIntegrationCapabilities(rawValue: 1 << 5)

    static let companion: ReadingIntegrationCapabilities = [.canOpenReadingDestination]

    var orderedItems: [ReadingIntegrationCapabilityItem] {
        ReadingIntegrationCapabilityItem.allCases.filter { contains($0.capability) }
    }
}

nonisolated enum ReadingIntegrationCapabilityItem: String, CaseIterable, Identifiable, Hashable, Sendable {
    case canOpenReadingDestination
    case canReceiveShares
    case canImportLibrary
    case canSyncProgress
    case canReadLocally
    case requiresAuthorization

    var id: String { rawValue }

    var capability: ReadingIntegrationCapabilities {
        switch self {
        case .canOpenReadingDestination:
            return .canOpenReadingDestination
        case .canReceiveShares:
            return .canReceiveShares
        case .canImportLibrary:
            return .canImportLibrary
        case .canSyncProgress:
            return .canSyncProgress
        case .canReadLocally:
            return .canReadLocally
        case .requiresAuthorization:
            return .requiresAuthorization
        }
    }

    var title: String {
        switch self {
        case .canOpenReadingDestination:
            return "Leselink öffnen"
        case .canReceiveShares:
            return "Shares empfangen"
        case .canImportLibrary:
            return "Bibliothek importieren"
        case .canSyncProgress:
            return "Fortschritt synchronisieren"
        case .canReadLocally:
            return "Lokal lesen"
        case .requiresAuthorization:
            return "Konto erforderlich"
        }
    }
}
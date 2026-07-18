//
//  ReadingIntegrationAvailability.swift
//  Shelf Notes
//

import Foundation

nonisolated enum ReadingIntegrationAvailability: Equatable, Sendable {
    case available(detail: String)
    case companionAvailable(detail: String)
    case notConnected(detail: String)
    case comingSoon(detail: String)
    case unavailable(detail: String)

    var title: String {
        switch self {
        case .available:
            return "Verfügbar"
        case .companionAvailable:
            return "Begleitmodus"
        case .notConnected:
            return "Nicht verbunden"
        case .comingSoon:
            return "Folgt später"
        case .unavailable:
            return "Nicht verfügbar"
        }
    }

    var detail: String {
        switch self {
        case .available(let detail),
             .companionAvailable(let detail),
             .notConnected(let detail),
             .comingSoon(let detail),
             .unavailable(let detail):
            return detail
        }
    }

    var isUsableNow: Bool {
        switch self {
        case .available, .companionAvailable:
            return true
        case .notConnected, .comingSoon, .unavailable:
            return false
        }
    }

    var isConnectedPresentation: Bool {
        false
    }
}

nonisolated enum ReadingIntegrationProgressMode: String, CaseIterable, Identifiable, Equatable, Sendable {
    case manual
    case synchronized
    case directInShelfNotes
    case unavailable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual:
            return "Manuell erfasst"
        case .synchronized:
            return "Synchronisiert"
        case .directInShelfNotes:
            return "Direkt in Shelf Notes"
        case .unavailable:
            return "Noch nicht verfügbar"
        }
    }

    var detail: String {
        switch self {
        case .manual:
            return "Zeit läuft in Shelf Notes, Lesestand wird nach dem Lesen eingegeben."
        case .synchronized:
            return "Fortschritt käme aus einem verbundenen Anbieter."
        case .directInShelfNotes:
            return "Lesen und Fortschrittserfassung passieren vollständig in Shelf Notes."
        case .unavailable:
            return "Diese Erfassung ist in diesem Stand noch nicht aktiv."
        }
    }
}

nonisolated struct ReadingIntegrationEnvironment: Equatable, Sendable {
    var hasStoredReadingLink: Bool
    var hasLocalPublication: Bool
    var isLocalReaderFeatureEnabled: Bool
    var isAuthorized: Bool

    init(
        hasStoredReadingLink: Bool = false,
        hasLocalPublication: Bool = false,
        isLocalReaderFeatureEnabled: Bool = false,
        isAuthorized: Bool = false
    ) {
        self.hasStoredReadingLink = hasStoredReadingLink
        self.hasLocalPublication = hasLocalPublication
        self.isLocalReaderFeatureEnabled = isLocalReaderFeatureEnabled
        self.isAuthorized = isAuthorized
    }
}
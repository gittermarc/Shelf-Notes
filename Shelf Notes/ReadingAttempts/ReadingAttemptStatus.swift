//
//  ReadingAttemptStatus.swift
//  Shelf Notes
//

import Foundation

nonisolated enum ReadingAttemptStatus: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case active = "active"
    case finished = "finished"
    case abandoned = "abandoned"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .active:
            return "Läuft"
        case .finished:
            return "Abgeschlossen"
        case .abandoned:
            return "Abgebrochen"
        }
    }

    static func fromPersisted(_ value: String) -> ReadingAttemptStatus? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let status = ReadingAttemptStatus(rawValue: trimmed) {
            return status
        }

        switch trimmed {
        case "aktiv", "Aktiv", "Läuft":
            return .active
        case "abgeschlossen", "Abgeschlossen", "Gelesen", "finished":
            return .finished
        case "abgebrochen", "Abgebrochen":
            return .abandoned
        default:
            return nil
        }
    }
}

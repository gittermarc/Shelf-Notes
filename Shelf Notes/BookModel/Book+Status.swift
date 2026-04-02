//
//  Book+Status.swift
//  Shelf Notes
//

import Foundation

nonisolated enum ReadingStatus: String, Codable, CaseIterable, Identifiable {
    /// Stable persisted codes (do not localize).
    case toRead = "toRead"
    case reading = "reading"
    case finished = "finished"

    var id: String { rawValue }

    /// User-facing label (safe to change / localize).
    var displayName: String {
        switch self {
        case .toRead: return "Will ich lesen"
        case .reading: return "Lese ich gerade"
        case .finished: return "Gelesen"
        }
    }

    /// Maps both stable codes and legacy persisted display strings to a status.
    static func fromPersisted(_ value: String) -> ReadingStatus? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let status = ReadingStatus(rawValue: trimmed) {
            return status
        }

        switch trimmed {
        case "Will ich lesen", "Will lesen":
            return .toRead
        case "Lese ich gerade", "Lese ich":
            return .reading
        case "Gelesen":
            return .finished
        default:
            return nil
        }
    }
}

extension Book {
    var status: ReadingStatus {
        get { ReadingStatus.fromPersisted(statusRawValue) ?? .toRead }
        set {
            statusRawValue = newValue.rawValue

            if newValue != .finished {
                readFrom = nil
                readTo = nil
                clearUserRatings()
            }
        }
    }

    /// True only when the book is marked as finished.
    var canUserRate: Bool {
        status == .finished
    }
}

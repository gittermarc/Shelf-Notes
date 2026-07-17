//
//  ReadingProgressUnit.swift
//  Shelf Notes
//

import Foundation

nonisolated enum ReadingProgressUnit: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case pages = "pages"
    case percentage = "percentage"
    case locator = "locator"
    case none = "none"

    var id: String { rawValue }

    static func fromPersisted(_ value: String) -> ReadingProgressUnit {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return ReadingProgressUnit(rawValue: normalized) ?? .none
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = ReadingProgressUnit.fromPersisted(try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

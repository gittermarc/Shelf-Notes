//
//  ReadingMedium.swift
//  Shelf Notes
//

import Foundation

nonisolated enum ReadingMedium: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case physical = "physical"
    case ebook = "ebook"

    var id: String { rawValue }

    static func fromPersisted(_ value: String) -> ReadingMedium {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return ReadingMedium(rawValue: normalized) ?? .physical
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = ReadingMedium.fromPersisted(try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

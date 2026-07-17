//
//  ReadingProvider.swift
//  Shelf Notes
//

import Foundation

nonisolated enum ReadingProvider: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case none = "none"
    case appleBooks = "appleBooks"
    case kindle = "kindle"
    case googleBooks = "googleBooks"
    case localFile = "localFile"
    case other = "other"

    var id: String { rawValue }

    static func fromPersisted(_ value: String) -> ReadingProvider {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return ReadingProvider(rawValue: normalized) ?? .none
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = ReadingProvider.fromPersisted(try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

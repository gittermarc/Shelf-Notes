//
//  ReadingSessionOrigin.swift
//  Shelf Notes
//

import Foundation

nonisolated enum ReadingSessionOrigin: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case legacy = "legacy"
    case timer = "timer"
    case quickLog = "quickLog"
    case providerImport = "providerImport"
    case integratedReader = "integratedReader"
    case shareExtension = "shareExtension"

    var id: String { rawValue }

    static func fromPersisted(_ value: String) -> ReadingSessionOrigin {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return ReadingSessionOrigin(rawValue: normalized) ?? .legacy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = ReadingSessionOrigin.fromPersisted(try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

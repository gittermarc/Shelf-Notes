//
//  ReadingAnnotationKind.swift
//  Shelf Notes
//

import Foundation

nonisolated enum ReadingAnnotationKind: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case highlight = "highlight"
    case note = "note"
    case bookmark = "bookmark"

    var id: String { rawValue }

    static func fromPersisted(_ value: String) -> ReadingAnnotationKind {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return ReadingAnnotationKind(rawValue: normalized) ?? .note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = ReadingAnnotationKind.fromPersisted(try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

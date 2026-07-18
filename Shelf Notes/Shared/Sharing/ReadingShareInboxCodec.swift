//
//  ReadingShareInboxCodec.swift
//  Shelf Notes
//

import Foundation

nonisolated struct ReadingShareInboxFile: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var items: [ReadingShareInboxItem]

    init(
        schemaVersion: Int = ReadingShareInboxCodec.currentSchemaVersion,
        items: [ReadingShareInboxItem]
    ) {
        self.schemaVersion = schemaVersion
        self.items = items
    }
}

nonisolated enum ReadingShareInboxCodecError: Error, Equatable, Sendable {
    case unsupportedSchema(Int)
    case unsupportedItemSchema(Int)
}

nonisolated enum ReadingShareInboxCodec {
    static let currentSchemaVersion = 1

    static func encode(_ items: [ReadingShareInboxItem]) throws -> Data {
        let file = ReadingShareInboxFile(items: items)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }

    static func decode(_ data: Data) throws -> [ReadingShareInboxItem] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(ReadingShareInboxFile.self, from: data)
        guard file.schemaVersion <= currentSchemaVersion else {
            throw ReadingShareInboxCodecError.unsupportedSchema(file.schemaVersion)
        }
        if let futureItem = file.items.first(where: { item in
            item.schemaVersion > ReadingShareInboxItem.currentSchemaVersion
        }) {
            throw ReadingShareInboxCodecError.unsupportedItemSchema(futureItem.schemaVersion)
        }
        return file.items
    }
}

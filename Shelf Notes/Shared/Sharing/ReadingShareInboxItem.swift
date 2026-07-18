//
//  ReadingShareInboxItem.swift
//  Shelf Notes
//

import Foundation

nonisolated struct ReadingShareInboxItem: Codable, Identifiable, Equatable, Hashable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var id: String
    var createdAt: Date
    var sourceApplicationBundleIdentifier: String?
    var payload: ReadingSharePayload
    var contentFingerprint: String

    init(
        id: String? = nil,
        createdAt: Date = Date(),
        sourceApplicationBundleIdentifier: String? = nil,
        payload: ReadingSharePayload,
        contentFingerprint: String? = nil,
        schemaVersion: Int = ReadingShareInboxItem.currentSchemaVersion
    ) {
        let fingerprint = contentFingerprint ?? ReadingShareInboxItem.makeFingerprint(payload: payload)
        self.schemaVersion = schemaVersion
        self.id = id ?? "share-\(fingerprint)"
        self.createdAt = createdAt
        self.sourceApplicationBundleIdentifier = ReadingShareTextNormalizer.normalizedOptional(
            sourceApplicationBundleIdentifier,
            maxLength: 240
        )
        self.payload = payload
        self.contentFingerprint = fingerprint
    }

    static func makeFingerprint(payload: ReadingSharePayload) -> String {
        stableHash(payload.stableComponents.joined(separator: "\u{001F}"))
    }

    private static func stableHash(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }
}

//
//  ReadingProgressEventFingerprint.swift
//  Shelf Notes
//

import Foundation

/// Stable keys and value fingerprints used by the idempotent progress repair.
nonisolated struct ReadingProgressEventFingerprint: Hashable, Sendable {
    let deduplicationKey: String
    let bookID: UUID?
    let attemptID: UUID?
    let occurredAtBits: UInt64
    let mediumRawValue: String
    let providerRawValue: String
    let progressUnitRawValue: String
    let nativeValueBits: UInt64
    let totalValueBits: UInt64?
    let normalizedProgressBits: UInt64?
    let locator: String?
    let originRawValue: String
    let externalIdentifier: String?
    let sourceSessionID: UUID?
    let importedAtBits: UInt64?

    static func legacyBaselineKey(attemptID: UUID) -> String {
        "legacy-pages-baseline:\(attemptID.uuidString.lowercased())"
    }

    static func sessionProgressKey(sessionID: UUID) -> String {
        "session-progress:\(sessionID.uuidString.lowercased())"
    }

    static func importedProgressKey(
        provider: ReadingProvider,
        externalIdentifier: String
    ) -> String {
        let normalizedIdentifier = externalIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return "provider-progress:\(provider.rawValue):\(normalizedIdentifier)"
    }

    static func attemptID(fromLegacyBaselineKey key: String) -> UUID? {
        let prefix = "legacy-pages-baseline:"
        guard key.hasPrefix(prefix) else { return nil }
        return UUID(uuidString: String(key.dropFirst(prefix.count)))
    }

    static func dateBits(_ date: Date?) -> UInt64? {
        date?.timeIntervalSinceReferenceDate.bitPattern
    }
}

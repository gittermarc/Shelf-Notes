//
//  ReadingSessionLiveActivitySnapshot.swift
//  Shelf Notes
//
//  Shared, Codable display snapshot for the Reading Session Live Activity.
//

import Foundation

nonisolated struct ReadingSessionLiveActivitySnapshot: Codable, Hashable, Sendable {
    static let defaultTitle = "Buch"
    static let runningStateLabel = "Liest gerade"
    static let pausedStateLabel = "Pausiert"

    var bookID: UUID
    var bookTitle: String
    var bookAuthor: String?
    var attemptName: String?
    var pageCount: Int?
    var pagesRead: Int?
    var remainingPages: Int?
    var progressFraction: Double?
    var challengeTitle: String?
    var challengeDetail: String?
    var challengeProgressFraction: Double?
    var stateLabel: String
    var hasCover: Bool
    var coverRevision: Int?
    var accentHex: String?

    init(
        bookID: UUID,
        bookTitle: String,
        bookAuthor: String? = nil,
        attemptName: String? = nil,
        pageCount: Int? = nil,
        pagesRead: Int? = nil,
        remainingPages: Int? = nil,
        progressFraction: Double? = nil,
        challengeTitle: String? = nil,
        challengeDetail: String? = nil,
        challengeProgressFraction: Double? = nil,
        stateLabel: String = ReadingSessionLiveActivitySnapshot.runningStateLabel,
        hasCover: Bool = false,
        coverRevision: Int? = nil,
        accentHex: String? = nil
    ) {
        self.bookID = bookID
        self.bookTitle = Self.normalizedRequiredText(bookTitle, fallback: Self.defaultTitle, maxLength: 80)
        self.bookAuthor = Self.normalizedOptionalText(bookAuthor, maxLength: 80)
        self.attemptName = Self.normalizedOptionalText(attemptName, maxLength: 48)
        self.pageCount = Self.normalizedPositiveInt(pageCount)
        self.pagesRead = Self.normalizedNonNegativeInt(pagesRead)
        self.remainingPages = Self.normalizedNonNegativeInt(remainingPages)
        self.progressFraction = Self.normalizedFraction(progressFraction)
        self.challengeTitle = Self.normalizedOptionalText(challengeTitle, maxLength: 64)
        self.challengeDetail = Self.normalizedOptionalText(challengeDetail, maxLength: 96)
        self.challengeProgressFraction = Self.normalizedFraction(challengeProgressFraction)
        self.stateLabel = Self.normalizedRequiredText(stateLabel, fallback: Self.runningStateLabel, maxLength: 32)
        self.hasCover = hasCover
        self.coverRevision = Self.normalizedPositiveInt(coverRevision)
        self.accentHex = Self.normalizedHex(accentHex)
    }

    static func fallback(
        bookID: UUID,
        bookTitle: String,
        isPaused: Bool,
        hasCover: Bool = false
    ) -> ReadingSessionLiveActivitySnapshot {
        ReadingSessionLiveActivitySnapshot(
            bookID: bookID,
            bookTitle: bookTitle,
            stateLabel: isPaused ? pausedStateLabel : runningStateLabel,
            hasCover: hasCover
        )
    }

    private static func normalizedRequiredText(_ raw: String, fallback: String, maxLength: Int) -> String {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = normalized.isEmpty ? fallback : normalized
        return limited(value, maxLength: maxLength)
    }

    private static func normalizedOptionalText(_ raw: String?, maxLength: Int) -> String? {
        guard let raw else { return nil }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return limited(normalized, maxLength: maxLength)
    }

    private static func limited(_ value: String, maxLength: Int) -> String {
        guard maxLength > 0, value.count > maxLength else { return value }
        return String(value.prefix(maxLength))
    }

    private static func normalizedPositiveInt(_ raw: Int?) -> Int? {
        guard let raw, raw > 0 else { return nil }
        return raw
    }

    private static func normalizedNonNegativeInt(_ raw: Int?) -> Int? {
        guard let raw else { return nil }
        return max(0, raw)
    }

    private static func normalizedFraction(_ raw: Double?) -> Double? {
        guard let raw, raw.isFinite else { return nil }
        return min(1.0, max(0.0, raw))
    }

    private static func normalizedHex(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let withoutPrefix = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard withoutPrefix.count == 6 || withoutPrefix.count == 8 else { return nil }

        let allowed = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        guard withoutPrefix.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }

        return "#" + withoutPrefix.uppercased()
    }
}

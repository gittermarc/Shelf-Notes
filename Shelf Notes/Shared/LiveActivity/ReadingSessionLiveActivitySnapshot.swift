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
    var locator: String?
    var readingAttemptID: UUID?
    var readingMedium: ReadingMedium
    var readingProvider: ReadingProvider
    var progressUnit: ReadingProgressUnit
    var origin: ReadingSessionOrigin
    var expectedExternalReading: Bool
    var totalValue: Double?
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
        locator: String? = nil,
        readingAttemptID: UUID? = nil,
        readingMedium: ReadingMedium = .physical,
        readingProvider: ReadingProvider = .none,
        progressUnit: ReadingProgressUnit = .pages,
        origin: ReadingSessionOrigin = .legacy,
        expectedExternalReading: Bool? = nil,
        totalValue: Double? = nil,
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
        self.pageCount = progressUnit == .pages ? Self.normalizedPositiveInt(pageCount) : nil
        self.pagesRead = progressUnit == .pages ? Self.normalizedNonNegativeInt(pagesRead) : nil
        self.remainingPages = progressUnit == .pages ? Self.normalizedNonNegativeInt(remainingPages) : nil
        self.progressFraction = Self.normalizedFraction(progressFraction)
        self.locator = Self.normalizedOptionalText(locator, maxLength: 96)
        self.readingAttemptID = readingAttemptID
        self.readingMedium = readingMedium
        self.readingProvider = readingProvider
        self.progressUnit = progressUnit
        self.origin = origin
        self.expectedExternalReading = expectedExternalReading ?? ReadingTimerSessionSourceSnapshot.defaultExpectedExternalReading(
            medium: readingMedium,
            provider: readingProvider,
            origin: origin
        )
        self.totalValue = Self.normalizedPositiveDouble(totalValue)
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
        hasCover: Bool = false,
        source: ReadingTimerSessionSourceSnapshot = .legacyPhysical
    ) -> ReadingSessionLiveActivitySnapshot {
        ReadingSessionLiveActivitySnapshot(
            bookID: bookID,
            bookTitle: bookTitle,
            readingAttemptID: source.readingAttemptID,
            readingMedium: source.readingMedium,
            readingProvider: source.readingProvider,
            progressUnit: source.progressUnit,
            origin: source.origin,
            expectedExternalReading: source.expectedExternalReading,
            totalValue: source.totalValue,
            stateLabel: isPaused ? pausedStateLabel : runningStateLabel,
            hasCover: hasCover
        )
    }

    var sourceSnapshot: ReadingTimerSessionSourceSnapshot {
        ReadingTimerSessionSourceSnapshot(
            readingAttemptID: readingAttemptID,
            readingMedium: readingMedium,
            readingProvider: readingProvider,
            progressUnit: progressUnit,
            origin: origin,
            expectedExternalReading: expectedExternalReading,
            totalValue: totalValue
        )
    }

    mutating func applySourceSnapshot(_ source: ReadingTimerSessionSourceSnapshot) {
        let previousProgressUnit = progressUnit
        readingAttemptID = source.readingAttemptID
        readingMedium = source.readingMedium
        readingProvider = source.readingProvider
        progressUnit = source.progressUnit
        origin = source.origin
        expectedExternalReading = source.expectedExternalReading
        totalValue = source.totalValue

        if previousProgressUnit != source.progressUnit {
            pageCount = nil
            pagesRead = nil
            remainingPages = nil
            progressFraction = nil
            locator = nil
            return
        }

        if progressUnit != .pages {
            pageCount = nil
            pagesRead = nil
            remainingPages = nil
        }
        if progressUnit != .locator {
            locator = nil
        }
        if progressUnit == .none {
            progressFraction = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case bookID
        case bookTitle
        case bookAuthor
        case attemptName
        case pageCount
        case pagesRead
        case remainingPages
        case progressFraction
        case locator
        case readingAttemptID
        case readingMedium
        case readingProvider
        case progressUnit
        case origin
        case expectedExternalReading
        case totalValue
        case challengeTitle
        case challengeDetail
        case challengeProgressFraction
        case stateLabel
        case hasCover
        case coverRevision
        case accentHex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let bookID = try container.decode(UUID.self, forKey: .bookID)
        let readingMedium = (try? container.decode(ReadingMedium.self, forKey: .readingMedium)) ?? .physical
        let readingProvider = (try? container.decode(ReadingProvider.self, forKey: .readingProvider)) ?? .none
        let progressUnit = (try? container.decode(ReadingProgressUnit.self, forKey: .progressUnit)) ?? .pages
        let origin = (try? container.decode(ReadingSessionOrigin.self, forKey: .origin)) ?? .legacy
        let expectedExternalReading = try? container.decode(Bool.self, forKey: .expectedExternalReading)

        self.init(
            bookID: bookID,
            bookTitle: (try? container.decode(String.self, forKey: .bookTitle)) ?? Self.defaultTitle,
            bookAuthor: try? container.decode(String.self, forKey: .bookAuthor),
            attemptName: try? container.decode(String.self, forKey: .attemptName),
            pageCount: try? container.decode(Int.self, forKey: .pageCount),
            pagesRead: try? container.decode(Int.self, forKey: .pagesRead),
            remainingPages: try? container.decode(Int.self, forKey: .remainingPages),
            progressFraction: try? container.decode(Double.self, forKey: .progressFraction),
            locator: try? container.decode(String.self, forKey: .locator),
            readingAttemptID: try? container.decode(UUID.self, forKey: .readingAttemptID),
            readingMedium: readingMedium,
            readingProvider: readingProvider,
            progressUnit: progressUnit,
            origin: origin,
            expectedExternalReading: expectedExternalReading,
            totalValue: try? container.decode(Double.self, forKey: .totalValue),
            challengeTitle: try? container.decode(String.self, forKey: .challengeTitle),
            challengeDetail: try? container.decode(String.self, forKey: .challengeDetail),
            challengeProgressFraction: try? container.decode(Double.self, forKey: .challengeProgressFraction),
            stateLabel: (try? container.decode(String.self, forKey: .stateLabel)) ?? Self.runningStateLabel,
            hasCover: (try? container.decode(Bool.self, forKey: .hasCover)) ?? false,
            coverRevision: try? container.decode(Int.self, forKey: .coverRevision),
            accentHex: try? container.decode(String.self, forKey: .accentHex)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bookID, forKey: .bookID)
        try container.encode(bookTitle, forKey: .bookTitle)
        try container.encodeIfPresent(bookAuthor, forKey: .bookAuthor)
        try container.encodeIfPresent(attemptName, forKey: .attemptName)
        try container.encodeIfPresent(pageCount, forKey: .pageCount)
        try container.encodeIfPresent(pagesRead, forKey: .pagesRead)
        try container.encodeIfPresent(remainingPages, forKey: .remainingPages)
        try container.encodeIfPresent(progressFraction, forKey: .progressFraction)
        try container.encodeIfPresent(locator, forKey: .locator)
        try container.encodeIfPresent(readingAttemptID, forKey: .readingAttemptID)
        try container.encode(readingMedium, forKey: .readingMedium)
        try container.encode(readingProvider, forKey: .readingProvider)
        try container.encode(progressUnit, forKey: .progressUnit)
        try container.encode(origin, forKey: .origin)
        try container.encode(expectedExternalReading, forKey: .expectedExternalReading)
        try container.encodeIfPresent(totalValue, forKey: .totalValue)
        try container.encodeIfPresent(challengeTitle, forKey: .challengeTitle)
        try container.encodeIfPresent(challengeDetail, forKey: .challengeDetail)
        try container.encodeIfPresent(challengeProgressFraction, forKey: .challengeProgressFraction)
        try container.encode(stateLabel, forKey: .stateLabel)
        try container.encode(hasCover, forKey: .hasCover)
        try container.encodeIfPresent(coverRevision, forKey: .coverRevision)
        try container.encodeIfPresent(accentHex, forKey: .accentHex)
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

    private static func normalizedPositiveDouble(_ raw: Double?) -> Double? {
        guard let raw, raw.isFinite, raw > 0 else { return nil }
        return raw
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

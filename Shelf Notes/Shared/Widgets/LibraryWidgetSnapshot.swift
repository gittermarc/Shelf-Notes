//
//  LibraryWidgetSnapshot.swift
//  Shelf Notes
//
//  Small Codable value model for the future Library Home Screen widget.
//  The widget extension reads this snapshot from the App Group and never touches SwiftData.
//

import Foundation

nonisolated enum LibraryWidgetSnapshotState: String, Codable, Hashable, Sendable {
    case emptyLibrary
    case ready
}

nonisolated enum LibraryWidgetShelfItemKind: String, Codable, Hashable, Sendable {
    case currentReading
    case recentlyFinished
    case recentlyAdded
}

nonisolated struct LibraryWidgetBookSnapshot: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var title: String
    var author: String?
    var kind: LibraryWidgetShelfItemKind
    var statusRawValue: String
    var pageCount: Int?
    var pagesRead: Int?
    var remainingPages: Int?
    var progressFraction: Double?
    var referenceDate: Date?
    var hasCover: Bool
    var coverRevision: Int?

    init(
        id: UUID,
        title: String,
        author: String? = nil,
        kind: LibraryWidgetShelfItemKind,
        statusRawValue: String,
        pageCount: Int? = nil,
        pagesRead: Int? = nil,
        remainingPages: Int? = nil,
        progressFraction: Double? = nil,
        referenceDate: Date? = nil,
        hasCover: Bool = false,
        coverRevision: Int? = nil
    ) {
        self.id = id
        self.title = Self.normalizedRequiredText(title, fallback: "Buch", maxLength: 90)
        self.author = Self.normalizedOptionalText(author, maxLength: 90)
        self.kind = kind
        self.statusRawValue = Self.normalizedRequiredText(statusRawValue, fallback: "toRead", maxLength: 40)
        self.pageCount = Self.normalizedPositiveInt(pageCount)
        self.pagesRead = Self.normalizedNonNegativeInt(pagesRead)
        self.remainingPages = Self.normalizedNonNegativeInt(remainingPages)
        self.progressFraction = Self.normalizedFraction(progressFraction)
        self.referenceDate = referenceDate
        self.hasCover = hasCover
        self.coverRevision = Self.normalizedPositiveInt(coverRevision)
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
}

nonisolated struct LibraryWidgetYearlyGoalSnapshot: Codable, Hashable, Sendable {
    var year: Int
    var targetCount: Int
    var finishedCount: Int
    var remainingCount: Int
    var progressFraction: Double

    init(
        year: Int,
        targetCount: Int,
        finishedCount: Int
    ) {
        let normalizedTarget = max(0, targetCount)
        let normalizedFinished = max(0, finishedCount)

        self.year = year
        self.targetCount = normalizedTarget
        self.finishedCount = normalizedFinished
        self.remainingCount = max(0, normalizedTarget - normalizedFinished)

        if normalizedTarget > 0 {
            self.progressFraction = min(1.0, max(0.0, Double(normalizedFinished) / Double(normalizedTarget)))
        } else {
            self.progressFraction = 0
        }
    }
}

nonisolated struct LibraryWidgetPrivacySnapshot: Codable, Hashable, Sendable {
    var showsBookTitles: Bool
    var showsCovers: Bool
    var usesReducedMode: Bool

    init(
        showsBookTitles: Bool = true,
        showsCovers: Bool = true,
        usesReducedMode: Bool = false
    ) {
        self.usesReducedMode = usesReducedMode

        if usesReducedMode {
            self.showsBookTitles = false
            self.showsCovers = false
        } else {
            self.showsBookTitles = showsBookTitles
            self.showsCovers = showsCovers
        }
    }

    static let full = LibraryWidgetPrivacySnapshot()

    var hidesBookTitles: Bool {
        !showsBookTitles || usesReducedMode
    }

    var hidesCovers: Bool {
        !showsCovers || usesReducedMode
    }
}

nonisolated struct LibraryWidgetSnapshot: Codable, Hashable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var generatedAt: Date
    var state: LibraryWidgetSnapshotState
    var totalBooks: Int
    var readBooks: Int
    var readingBooks: Int
    var wantToReadBooks: Int
    var currentBook: LibraryWidgetBookSnapshot?
    var yearlyGoal: LibraryWidgetYearlyGoalSnapshot?
    var last7DaysReadingMinutes: Int
    var last7DaysReadingDays: Int
    var currentReadingStreakDays: Int
    var recentShelfItems: [LibraryWidgetBookSnapshot]
    var privacy: LibraryWidgetPrivacySnapshot?

    init(
        schemaVersion: Int = LibraryWidgetSnapshot.currentSchemaVersion,
        generatedAt: Date,
        state: LibraryWidgetSnapshotState,
        totalBooks: Int,
        readBooks: Int,
        readingBooks: Int,
        wantToReadBooks: Int,
        currentBook: LibraryWidgetBookSnapshot? = nil,
        yearlyGoal: LibraryWidgetYearlyGoalSnapshot? = nil,
        last7DaysReadingMinutes: Int = 0,
        last7DaysReadingDays: Int = 0,
        currentReadingStreakDays: Int = 0,
        recentShelfItems: [LibraryWidgetBookSnapshot] = [],
        privacy: LibraryWidgetPrivacySnapshot? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.state = state
        self.totalBooks = max(0, totalBooks)
        self.readBooks = max(0, readBooks)
        self.readingBooks = max(0, readingBooks)
        self.wantToReadBooks = max(0, wantToReadBooks)
        self.currentBook = currentBook
        self.yearlyGoal = yearlyGoal
        self.last7DaysReadingMinutes = max(0, last7DaysReadingMinutes)
        self.last7DaysReadingDays = max(0, last7DaysReadingDays)
        self.currentReadingStreakDays = max(0, currentReadingStreakDays)
        self.recentShelfItems = Array(recentShelfItems.prefix(6))
        self.privacy = privacy
    }

    static func empty(generatedAt: Date) -> LibraryWidgetSnapshot {
        LibraryWidgetSnapshot(
            generatedAt: generatedAt,
            state: .emptyLibrary,
            totalBooks: 0,
            readBooks: 0,
            readingBooks: 0,
            wantToReadBooks: 0
        )
    }

    var hasSupportedSchemaVersion: Bool {
        schemaVersion > 0 && schemaVersion <= Self.currentSchemaVersion
    }

    var hasBooks: Bool {
        totalBooks > 0
    }

    var hasCurrentBook: Bool {
        currentBook != nil
    }

    var hasYearlyGoal: Bool {
        yearlyGoal != nil
    }

    var hasRecentActivity: Bool {
        last7DaysReadingMinutes > 0 || last7DaysReadingDays > 0 || currentReadingStreakDays > 0
    }

    var effectivePrivacy: LibraryWidgetPrivacySnapshot {
        privacy ?? .full
    }

    func hasSameRenderableContent(as other: LibraryWidgetSnapshot) -> Bool {
        schemaVersion == other.schemaVersion &&
        state == other.state &&
        totalBooks == other.totalBooks &&
        readBooks == other.readBooks &&
        readingBooks == other.readingBooks &&
        wantToReadBooks == other.wantToReadBooks &&
        currentBook == other.currentBook &&
        yearlyGoal == other.yearlyGoal &&
        last7DaysReadingMinutes == other.last7DaysReadingMinutes &&
        last7DaysReadingDays == other.last7DaysReadingDays &&
        currentReadingStreakDays == other.currentReadingStreakDays &&
        recentShelfItems == other.recentShelfItems &&
        privacy == other.privacy
    }
}

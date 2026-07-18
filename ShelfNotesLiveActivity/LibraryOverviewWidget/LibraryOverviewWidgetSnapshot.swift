//
//  LibraryOverviewWidgetSnapshot.swift
//  ShelfNotesLiveActivity
//
//  Widget-extension mirror DTOs for LibraryWidgetSnapshot.json.
//  Kept local to the extension so this PR does not require project-file target changes.
//

import Foundation

enum LibraryOverviewSnapshotState: String, Codable, Hashable, Sendable {
    case emptyLibrary
    case ready
}

enum LibraryOverviewShelfItemKind: String, Codable, Hashable, Sendable {
    case currentReading
    case recentlyFinished
    case recentlyAdded
}

struct LibraryOverviewBookSnapshot: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var title: String
    var author: String?
    var kind: LibraryOverviewShelfItemKind
    var statusRawValue: String
    var pageCount: Int?
    var pagesRead: Int?
    var remainingPages: Int?
    var progressFraction: Double?
    var progressNativeValue: Double? = nil
    var progressLocator: String? = nil
    var mediumRawValue: String? = nil
    var providerRawValue: String? = nil
    var progressUnitRawValue: String? = nil
    var referenceDate: Date?
    var hasCover: Bool
    var coverRevision: Int?
}

struct LibraryOverviewYearlyGoalSnapshot: Codable, Hashable, Sendable {
    var year: Int
    var targetCount: Int
    var finishedCount: Int
    var remainingCount: Int
    var progressFraction: Double
}

struct LibraryOverviewPrivacySnapshot: Codable, Hashable, Sendable {
    var showsBookTitles: Bool
    var showsCovers: Bool
    var usesReducedMode: Bool

    static let full = LibraryOverviewPrivacySnapshot(
        showsBookTitles: true,
        showsCovers: true,
        usesReducedMode: false
    )
}

struct LibraryOverviewWidgetSnapshot: Codable, Hashable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var generatedAt: Date
    var state: LibraryOverviewSnapshotState
    var totalBooks: Int
    var readBooks: Int
    var readingBooks: Int
    var wantToReadBooks: Int
    var currentBook: LibraryOverviewBookSnapshot?
    var yearlyGoal: LibraryOverviewYearlyGoalSnapshot?
    var last7DaysReadingMinutes: Int
    var last7DaysReadingDays: Int
    var currentReadingStreakDays: Int
    var recentShelfItems: [LibraryOverviewBookSnapshot]
    var privacy: LibraryOverviewPrivacySnapshot?

    var hasSupportedSchemaVersion: Bool {
        schemaVersion > 0 && schemaVersion <= Self.currentSchemaVersion
    }

    var hasBooks: Bool {
        totalBooks > 0 && state == .ready
    }

    var hasRecentActivity: Bool {
        last7DaysReadingMinutes > 0 || last7DaysReadingDays > 0 || currentReadingStreakDays > 0
    }

    var effectivePrivacy: LibraryOverviewPrivacySnapshot {
        privacy ?? .full
    }

    static func empty(generatedAt: Date) -> LibraryOverviewWidgetSnapshot {
        LibraryOverviewWidgetSnapshot(
            schemaVersion: currentSchemaVersion,
            generatedAt: generatedAt,
            state: .emptyLibrary,
            totalBooks: 0,
            readBooks: 0,
            readingBooks: 0,
            wantToReadBooks: 0,
            currentBook: nil,
            yearlyGoal: nil,
            last7DaysReadingMinutes: 0,
            last7DaysReadingDays: 0,
            currentReadingStreakDays: 0,
            recentShelfItems: [],
            privacy: nil
        )
    }

    static func placeholder(generatedAt: Date = Date()) -> LibraryOverviewWidgetSnapshot {
        let currentBookID = UUID(uuidString: "00000000-0000-0000-0000-000000000101") ?? UUID()
        let shelfIDs = [201, 202, 203, 204].map { value in
            UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
        }
        return LibraryOverviewWidgetSnapshot(
            schemaVersion: currentSchemaVersion,
            generatedAt: generatedAt,
            state: .ready,
            totalBooks: 128,
            readBooks: 42,
            readingBooks: 3,
            wantToReadBooks: 83,
            currentBook: LibraryOverviewBookSnapshot(
                id: currentBookID,
                title: "Der Graf von Monte Christo",
                author: "Alexandre Dumas",
                kind: .currentReading,
                statusRawValue: "reading",
                pageCount: 1280,
                pagesRead: 420,
                remainingPages: 860,
                progressFraction: 0.328,
                progressNativeValue: 420,
                mediumRawValue: "physical",
                providerRawValue: "none",
                progressUnitRawValue: "pages",
                referenceDate: generatedAt,
                hasCover: false,
                coverRevision: nil
            ),
            yearlyGoal: LibraryOverviewYearlyGoalSnapshot(
                year: 2026,
                targetCount: 24,
                finishedCount: 12,
                remainingCount: 12,
                progressFraction: 0.5
            ),
            last7DaysReadingMinutes: 185,
            last7DaysReadingDays: 4,
            currentReadingStreakDays: 3,
            recentShelfItems: shelfIDs.enumerated().map { index, id in
                LibraryOverviewBookSnapshot(
                    id: id,
                    title: ["Dune", "Project Hail Mary", "Die Therapie", "Stoner"][index],
                    author: nil,
                    kind: index < 2 ? .recentlyFinished : .recentlyAdded,
                    statusRawValue: index < 2 ? "finished" : "toRead",
                    pageCount: nil,
                    pagesRead: nil,
                    remainingPages: nil,
                    progressFraction: nil,
                    referenceDate: generatedAt.addingTimeInterval(Double(-index * 86_400)),
                    hasCover: false,
                    coverRevision: nil
                )
            },
            privacy: .full
        )
    }
}

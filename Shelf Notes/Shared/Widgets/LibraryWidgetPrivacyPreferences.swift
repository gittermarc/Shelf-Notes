//
//  LibraryWidgetPrivacyPreferences.swift
//  Shelf Notes
//
//  User-controlled privacy preferences for the Library Home Screen widget.
//  The main app applies these settings before writing the App Group snapshot.
//

import Foundation

nonisolated enum LibraryWidgetPrivacyPreferenceStorageKey {
    static let showsBookTitles = "library_widget_shows_book_titles_v1"
    static let showsCovers = "library_widget_shows_covers_v1"
    static let usesReducedMode = "library_widget_uses_reduced_mode_v1"
}

nonisolated struct LibraryWidgetPrivacyPreferences: Hashable, Sendable {
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

    static let full = LibraryWidgetPrivacyPreferences()

    static func load(from defaults: UserDefaults = .standard) -> LibraryWidgetPrivacyPreferences {
        let showsBookTitles = boolValue(
            forKey: LibraryWidgetPrivacyPreferenceStorageKey.showsBookTitles,
            defaultValue: true,
            defaults: defaults
        )
        let showsCovers = boolValue(
            forKey: LibraryWidgetPrivacyPreferenceStorageKey.showsCovers,
            defaultValue: true,
            defaults: defaults
        )
        let usesReducedMode = boolValue(
            forKey: LibraryWidgetPrivacyPreferenceStorageKey.usesReducedMode,
            defaultValue: false,
            defaults: defaults
        )

        return LibraryWidgetPrivacyPreferences(
            showsBookTitles: showsBookTitles,
            showsCovers: showsCovers,
            usesReducedMode: usesReducedMode
        )
    }

    var snapshot: LibraryWidgetPrivacySnapshot {
        LibraryWidgetPrivacySnapshot(
            showsBookTitles: showsBookTitles,
            showsCovers: showsCovers,
            usesReducedMode: usesReducedMode
        )
    }

    private static func boolValue(
        forKey key: String,
        defaultValue: Bool,
        defaults: UserDefaults
    ) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }
}

nonisolated enum LibraryWidgetPrivacyApplier {
    static func applying(
        _ preferences: LibraryWidgetPrivacyPreferences,
        to snapshot: LibraryWidgetSnapshot
    ) -> LibraryWidgetSnapshot {
        applying(preferences.snapshot, to: snapshot)
    }

    static func applying(
        _ privacy: LibraryWidgetPrivacySnapshot,
        to snapshot: LibraryWidgetSnapshot
    ) -> LibraryWidgetSnapshot {
        let currentBook: LibraryWidgetBookSnapshot?
        let recentShelfItems: [LibraryWidgetBookSnapshot]

        if privacy.usesReducedMode {
            currentBook = nil
            recentShelfItems = []
        } else {
            currentBook = snapshot.currentBook.map { maskedBook($0, privacy: privacy, fallbackTitle: "Aktuelles Buch") }
            recentShelfItems = snapshot.recentShelfItems.enumerated().map { index, book in
                maskedBook(book, privacy: privacy, fallbackTitle: "Buch \(index + 1)")
            }
        }

        return LibraryWidgetSnapshot(
            schemaVersion: snapshot.schemaVersion,
            generatedAt: snapshot.generatedAt,
            state: snapshot.state,
            totalBooks: snapshot.totalBooks,
            readBooks: snapshot.readBooks,
            readingBooks: snapshot.readingBooks,
            wantToReadBooks: snapshot.wantToReadBooks,
            currentBook: currentBook,
            yearlyGoal: snapshot.yearlyGoal,
            last7DaysReadingMinutes: snapshot.last7DaysReadingMinutes,
            last7DaysReadingDays: snapshot.last7DaysReadingDays,
            currentReadingStreakDays: snapshot.currentReadingStreakDays,
            recentShelfItems: recentShelfItems,
            privacy: privacy
        )
    }

    private static func maskedBook(
        _ book: LibraryWidgetBookSnapshot,
        privacy: LibraryWidgetPrivacySnapshot,
        fallbackTitle: String
    ) -> LibraryWidgetBookSnapshot {
        LibraryWidgetBookSnapshot(
            id: book.id,
            title: privacy.hidesBookTitles ? fallbackTitle : book.title,
            author: privacy.hidesBookTitles ? nil : book.author,
            kind: book.kind,
            statusRawValue: book.statusRawValue,
            pageCount: book.pageCount,
            pagesRead: book.pagesRead,
            remainingPages: book.remainingPages,
            progressFraction: book.progressFraction,
            progressNativeValue: book.progressNativeValue,
            progressLocator: book.progressLocator,
            mediumRawValue: book.mediumRawValue,
            providerRawValue: book.providerRawValue,
            progressUnitRawValue: book.progressUnitRawValue,
            referenceDate: book.referenceDate,
            hasCover: privacy.hidesCovers ? false : book.hasCover,
            coverRevision: privacy.hidesCovers ? nil : book.coverRevision
        )
    }
}

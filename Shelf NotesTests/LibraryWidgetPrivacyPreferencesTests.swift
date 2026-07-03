import Foundation
import Testing
@testable import Shelf_Notes

struct LibraryWidgetPrivacyPreferencesTests {
    @Test func defaultPreferencesShowTitlesAndCovers() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: defaultsSuiteName) }

        let preferences = LibraryWidgetPrivacyPreferences.load(from: defaults)

        #expect(preferences.showsBookTitles)
        #expect(preferences.showsCovers)
        #expect(!preferences.usesReducedMode)
    }

    @Test func reducedModeForcesTitlesAndCoversOff() {
        let preferences = LibraryWidgetPrivacyPreferences(
            showsBookTitles: true,
            showsCovers: true,
            usesReducedMode: true
        )

        #expect(!preferences.showsBookTitles)
        #expect(!preferences.showsCovers)
        #expect(preferences.usesReducedMode)
        #expect(preferences.snapshot.usesReducedMode)
    }

    @Test func privacyApplierMasksTitlesAndAuthors() {
        let snapshot = makeSnapshot()
        let preferences = LibraryWidgetPrivacyPreferences(
            showsBookTitles: false,
            showsCovers: true,
            usesReducedMode: false
        )

        let privateSnapshot = LibraryWidgetPrivacyApplier.applying(preferences, to: snapshot)

        #expect(privateSnapshot.currentBook?.title == "Aktuelles Buch")
        #expect(privateSnapshot.currentBook?.author == nil)
        #expect(privateSnapshot.currentBook?.hasCover == true)
        #expect(privateSnapshot.recentShelfItems.map(\.title) == ["Buch 1"])
        #expect(privateSnapshot.privacy?.showsBookTitles == false)
    }

    @Test func privacyApplierHidesCovers() {
        let snapshot = makeSnapshot()
        let preferences = LibraryWidgetPrivacyPreferences(
            showsBookTitles: true,
            showsCovers: false,
            usesReducedMode: false
        )

        let privateSnapshot = LibraryWidgetPrivacyApplier.applying(preferences, to: snapshot)

        #expect(privateSnapshot.currentBook?.title == "Dune")
        #expect(privateSnapshot.currentBook?.hasCover == false)
        #expect(privateSnapshot.currentBook?.coverRevision == nil)
        #expect(privateSnapshot.recentShelfItems.allSatisfy { !$0.hasCover })
    }

    @Test func reducedModeKeepsStatsButRemovesIdentifiableBooks() {
        let snapshot = makeSnapshot()
        let preferences = LibraryWidgetPrivacyPreferences(
            showsBookTitles: true,
            showsCovers: true,
            usesReducedMode: true
        )

        let privateSnapshot = LibraryWidgetPrivacyApplier.applying(preferences, to: snapshot)

        #expect(privateSnapshot.totalBooks == 2)
        #expect(privateSnapshot.readBooks == 1)
        #expect(privateSnapshot.currentBook == nil)
        #expect(privateSnapshot.recentShelfItems.isEmpty)
        #expect(privateSnapshot.privacy?.usesReducedMode == true)
    }

    @Test func renderableContentComparisonIncludesPrivacy() {
        let first = makeSnapshot()
        let second = LibraryWidgetPrivacyApplier.applying(
            LibraryWidgetPrivacyPreferences(showsBookTitles: false, showsCovers: true),
            to: first
        )

        #expect(!first.hasSameRenderableContent(as: second))
    }

    private var defaultsSuiteName: String {
        "LibraryWidgetPrivacyPreferencesTests"
    }

    private func makeDefaults() -> UserDefaults {
        let name = defaultsSuiteName
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makeSnapshot() -> LibraryWidgetSnapshot {
        LibraryWidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_000),
            state: .ready,
            totalBooks: 2,
            readBooks: 1,
            readingBooks: 1,
            wantToReadBooks: 0,
            currentBook: LibraryWidgetBookSnapshot(
                id: fixedID(1),
                title: "Dune",
                author: "Frank Herbert",
                kind: .currentReading,
                statusRawValue: ReadingStatus.reading.rawValue,
                pageCount: 500,
                pagesRead: 125,
                remainingPages: 375,
                progressFraction: 0.25,
                hasCover: true,
                coverRevision: 12
            ),
            recentShelfItems: [
                LibraryWidgetBookSnapshot(
                    id: fixedID(2),
                    title: "Finished Book",
                    author: "Author",
                    kind: .recentlyFinished,
                    statusRawValue: ReadingStatus.finished.rawValue,
                    hasCover: true,
                    coverRevision: 13
                )
            ]
        )
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
    }
}

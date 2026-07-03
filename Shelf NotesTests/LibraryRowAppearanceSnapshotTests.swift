import Testing
@testable import Shelf_Notes

struct LibraryRowAppearanceSnapshotTests {
    @Test func rawInitializerFallsBackToStableDefaults() {
        let snapshot = LibraryRowAppearanceSnapshot(
            showCovers: true,
            coverSizeRaw: "unknown-cover-size",
            coverCornerRadius: 10,
            coverContentModeRaw: "unknown-mode",
            coverShadowEnabled: true,
            showAuthor: false,
            showStatus: false,
            showReadDate: false,
            showRating: false,
            showReadingProgress: false,
            showTags: false,
            maxTags: -4,
            tagStyleRaw: "unknown-tag-style",
            rowContentSpacing: 5
        )

        #expect(snapshot.showCovers)
        #expect(snapshot.coverSize.rawValue == LibraryCoverSizeOption.standard.rawValue)
        #expect(snapshot.coverCornerRadius == 10)
        #expect(snapshot.coverContentMode.rawValue == LibraryCoverContentModeOption.fit.rawValue)
        #expect(snapshot.coverShadowEnabled)
        #expect(!snapshot.showAuthor)
        #expect(!snapshot.showStatus)
        #expect(!snapshot.showReadDate)
        #expect(!snapshot.showRating)
        #expect(!snapshot.showReadingProgress)
        #expect(!snapshot.showTags)
        #expect(snapshot.maxTags == 0)
        #expect(snapshot.tagStyle.rawValue == LibraryTagStyleOption.hashtags.rawValue)
        #expect(snapshot.rowContentSpacing == 5)
    }

    @Test func explicitInitializerPreservesResolvedLibraryPreferences() {
        let snapshot = LibraryRowAppearanceSnapshot(
            showCovers: false,
            coverSize: .large,
            coverCornerRadius: 12,
            coverContentMode: .fill,
            coverShadowEnabled: true,
            showAuthor: true,
            showStatus: false,
            showReadDate: true,
            showRating: false,
            showReadingProgress: true,
            showTags: true,
            maxTags: 4,
            tagStyle: .chips,
            rowContentSpacing: 3
        )

        #expect(!snapshot.showCovers)
        #expect(snapshot.coverSize.rawValue == LibraryCoverSizeOption.large.rawValue)
        #expect(snapshot.coverCornerRadius == 12)
        #expect(snapshot.coverContentMode.rawValue == LibraryCoverContentModeOption.fill.rawValue)
        #expect(snapshot.coverShadowEnabled)
        #expect(snapshot.showAuthor)
        #expect(!snapshot.showStatus)
        #expect(snapshot.showReadDate)
        #expect(!snapshot.showRating)
        #expect(snapshot.showReadingProgress)
        #expect(snapshot.showTags)
        #expect(snapshot.maxTags == 4)
        #expect(snapshot.tagStyle.rawValue == LibraryTagStyleOption.chips.rawValue)
        #expect(snapshot.rowContentSpacing == 3)
    }

    @Test func explicitInitializerShowsReadingProgressByDefault() {
        let snapshot = LibraryRowAppearanceSnapshot()

        #expect(snapshot.showReadingProgress)
    }
}

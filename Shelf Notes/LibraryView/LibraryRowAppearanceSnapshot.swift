import SwiftUI

struct LibraryRowAppearanceSnapshot {
    let showCovers: Bool
    let coverSize: LibraryCoverSizeOption
    let coverCornerRadius: Double
    let coverContentMode: LibraryCoverContentModeOption
    let coverShadowEnabled: Bool
    let showAuthor: Bool
    let showStatus: Bool
    let showReadDate: Bool
    let showRating: Bool
    let showReadingProgress: Bool
    let showTags: Bool
    let maxTags: Int
    let tagStyle: LibraryTagStyleOption
    let rowContentSpacing: Double

    init(
        showCovers: Bool = true,
        coverSize: LibraryCoverSizeOption = .standard,
        coverCornerRadius: Double = 8,
        coverContentMode: LibraryCoverContentModeOption = .fit,
        coverShadowEnabled: Bool = false,
        showAuthor: Bool = true,
        showStatus: Bool = true,
        showReadDate: Bool = true,
        showRating: Bool = true,
        showReadingProgress: Bool = true,
        showTags: Bool = true,
        maxTags: Int = 2,
        tagStyle: LibraryTagStyleOption = .hashtags,
        rowContentSpacing: Double = 2
    ) {
        self.showCovers = showCovers
        self.coverSize = coverSize
        self.coverCornerRadius = coverCornerRadius
        self.coverContentMode = coverContentMode
        self.coverShadowEnabled = coverShadowEnabled
        self.showAuthor = showAuthor
        self.showStatus = showStatus
        self.showReadDate = showReadDate
        self.showRating = showRating
        self.showReadingProgress = showReadingProgress
        self.showTags = showTags
        self.maxTags = max(0, maxTags)
        self.tagStyle = tagStyle
        self.rowContentSpacing = rowContentSpacing
    }

    init(
        showCovers: Bool,
        coverSizeRaw: String,
        coverCornerRadius: Double,
        coverContentModeRaw: String,
        coverShadowEnabled: Bool,
        showAuthor: Bool,
        showStatus: Bool,
        showReadDate: Bool,
        showRating: Bool,
        showReadingProgress: Bool = true,
        showTags: Bool,
        maxTags: Int,
        tagStyleRaw: String,
        rowContentSpacing: Double
    ) {
        self.init(
            showCovers: showCovers,
            coverSize: LibraryCoverSizeOption(rawValue: coverSizeRaw) ?? .standard,
            coverCornerRadius: coverCornerRadius,
            coverContentMode: LibraryCoverContentModeOption(rawValue: coverContentModeRaw) ?? .fit,
            coverShadowEnabled: coverShadowEnabled,
            showAuthor: showAuthor,
            showStatus: showStatus,
            showReadDate: showReadDate,
            showRating: showRating,
            showReadingProgress: showReadingProgress,
            showTags: showTags,
            maxTags: maxTags,
            tagStyle: LibraryTagStyleOption(rawValue: tagStyleRaw) ?? .hashtags,
            rowContentSpacing: rowContentSpacing
        )
    }

    var resolvedCoverSize: CGSize {
        coverSize.size
    }

    var resolvedCoverCornerRadius: CGFloat {
        CGFloat(coverCornerRadius)
    }

    var resolvedCoverContentMode: ContentMode {
        coverContentMode.contentMode
    }

    var resolvedRowContentSpacing: CGFloat {
        CGFloat(rowContentSpacing)
    }
}

struct LibraryRowAppearanceReader<Content: View>: View {
    @AppStorage(AppearanceStorageKey.libraryShowCovers) private var showCovers: Bool = true
    @AppStorage(AppearanceStorageKey.libraryCoverSize) private var coverSizeRaw: String = LibraryCoverSizeOption.standard.rawValue
    @AppStorage(AppearanceStorageKey.libraryCoverCornerRadius) private var coverCornerRadius: Double = 8
    @AppStorage(AppearanceStorageKey.libraryCoverContentMode) private var coverContentModeRaw: String = LibraryCoverContentModeOption.fit.rawValue
    @AppStorage(AppearanceStorageKey.libraryCoverShadowEnabled) private var coverShadowEnabled: Bool = false

    @AppStorage(AppearanceStorageKey.libraryRowShowAuthor) private var showAuthor: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowStatus) private var showStatus: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowReadDate) private var showReadDate: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowRating) private var showRating: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowReadingProgress) private var showReadingProgress: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowTags) private var showTags: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowMaxTags) private var maxTags: Int = 2
    @AppStorage(AppearanceStorageKey.libraryTagStyle) private var tagStyleRaw: String = LibraryTagStyleOption.hashtags.rawValue
    @AppStorage(AppearanceStorageKey.libraryRowContentSpacing) private var rowContentSpacing: Double = 2

    private let content: (LibraryRowAppearanceSnapshot) -> Content

    init(@ViewBuilder content: @escaping (LibraryRowAppearanceSnapshot) -> Content) {
        self.content = content
    }

    var body: some View {
        content(snapshot)
    }

    private var snapshot: LibraryRowAppearanceSnapshot {
        LibraryRowAppearanceSnapshot(
            showCovers: showCovers,
            coverSizeRaw: coverSizeRaw,
            coverCornerRadius: coverCornerRadius,
            coverContentModeRaw: coverContentModeRaw,
            coverShadowEnabled: coverShadowEnabled,
            showAuthor: showAuthor,
            showStatus: showStatus,
            showReadDate: showReadDate,
            showRating: showRating,
            showReadingProgress: showReadingProgress,
            showTags: showTags,
            maxTags: maxTags,
            tagStyleRaw: tagStyleRaw,
            rowContentSpacing: rowContentSpacing
        )
    }
}

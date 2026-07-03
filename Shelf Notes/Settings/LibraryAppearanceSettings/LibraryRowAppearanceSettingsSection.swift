//
//  LibraryRowAppearanceSettingsSection.swift
//  Shelf Notes
//
//  Library row / cover style customization.
//

import SwiftUI

/// Appearance settings for list rows (covers + which details to show).
///
/// Stored via `@AppStorage` so changes apply immediately app-wide.
struct LibraryRowAppearanceSettingsSection: View {
    // Layout mode
    @AppStorage(AppearanceStorageKey.libraryLayoutMode) private var layoutModeRaw: String = LibraryLayoutModeOption.list.rawValue

    // Header style
    @AppStorage(AppearanceStorageKey.libraryHeaderStyle) private var headerStyleRaw: String = LibraryHeaderStyleOption.standard.rawValue
    @AppStorage(AppearanceStorageKey.libraryHeaderDefaultExpanded) private var headerDefaultExpanded: Bool = false
    @AppStorage(AppearanceStorageKey.libraryHomeMode) private var homeModeRaw: String = LibraryHomeModeOption.compact.rawValue
    @AppStorage(AppearanceStorageKey.libraryHomeShowsMaintenance) private var homeShowsMaintenance: Bool = true
    @AppStorage(AppearanceStorageKey.libraryHomeShowsRoulette) private var homeShowsRoulette: Bool = true

    // Cover style
    @AppStorage(AppearanceStorageKey.libraryShowCovers) private var showCovers: Bool = true
    @AppStorage(AppearanceStorageKey.libraryCoverSize) private var coverSizeRaw: String = LibraryCoverSizeOption.standard.rawValue
    @AppStorage(AppearanceStorageKey.libraryCoverCornerRadius) private var coverCornerRadius: Double = 8
    @AppStorage(AppearanceStorageKey.libraryCoverContentMode) private var coverContentModeRaw: String = LibraryCoverContentModeOption.fit.rawValue
    @AppStorage(AppearanceStorageKey.libraryCoverShadowEnabled) private var coverShadowEnabled: Bool = false

    // Row details
    @AppStorage(AppearanceStorageKey.libraryRowShowAuthor) private var showAuthor: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowStatus) private var showStatus: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowReadDate) private var showReadDate: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowRating) private var showRating: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowReadingProgress) private var showReadingProgress: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowShowTags) private var showTags: Bool = true
    @AppStorage(AppearanceStorageKey.libraryRowMaxTags) private var maxTags: Int = 2

    // Tag style
    @AppStorage(AppearanceStorageKey.libraryTagStyle) private var tagStyleRaw: String = LibraryTagStyleOption.hashtags.rawValue

    // Row spacing
    @AppStorage(AppearanceStorageKey.libraryRowVerticalInset) private var rowVerticalInset: Double = 8
    @AppStorage(AppearanceStorageKey.libraryRowContentSpacing) private var rowContentSpacing: Double = 2

    private var layoutModeBinding: Binding<LibraryLayoutModeOption> {
        Binding(
            get: { LibraryLayoutModeOption(rawValue: layoutModeRaw) ?? .list },
            set: { layoutModeRaw = $0.rawValue }
        )
    }

    private var resolvedLayoutMode: LibraryLayoutModeOption {
        LibraryLayoutModeOption(rawValue: layoutModeRaw) ?? .list
    }

    private var coverSizeBinding: Binding<LibraryCoverSizeOption> {
        Binding(
            get: { LibraryCoverSizeOption(rawValue: coverSizeRaw) ?? .standard },
            set: { coverSizeRaw = $0.rawValue }
        )
    }

    private var headerStyleBinding: Binding<LibraryHeaderStyleOption> {
        Binding(
            get: { LibraryHeaderStyleOption(rawValue: headerStyleRaw) ?? .standard },
            set: { headerStyleRaw = $0.rawValue }
        )
    }

    private var homeModeBinding: Binding<LibraryHomeModeOption> {
        Binding(
            get: { LibraryHomeModeOption(rawValue: homeModeRaw) ?? .compact },
            set: { homeModeRaw = $0.rawValue }
        )
    }

    private var tagStyleBinding: Binding<LibraryTagStyleOption> {
        Binding(
            get: { LibraryTagStyleOption(rawValue: tagStyleRaw) ?? .hashtags },
            set: { tagStyleRaw = $0.rawValue }
        )
    }

    private var resolvedHeaderStyle: LibraryHeaderStyleOption {
        LibraryHeaderStyleOption(rawValue: headerStyleRaw) ?? .standard
    }

    private var resolvedTagStyle: LibraryTagStyleOption {
        LibraryTagStyleOption(rawValue: tagStyleRaw) ?? .hashtags
    }

    private var coverContentModeBinding: Binding<LibraryCoverContentModeOption> {
        Binding(
            get: { LibraryCoverContentModeOption(rawValue: coverContentModeRaw) ?? .fit },
            set: { coverContentModeRaw = $0.rawValue }
        )
    }

    private var resolvedCoverSize: CGSize {
        (LibraryCoverSizeOption(rawValue: coverSizeRaw) ?? .standard).size
    }

    private var resolvedContentMode: ContentMode {
        (LibraryCoverContentModeOption(rawValue: coverContentModeRaw) ?? .fit).contentMode
    }

    var body: some View {
        Section {
            Picker("Ansicht", selection: layoutModeBinding) {
                ForEach(LibraryLayoutModeOption.allCases) { option in
                    Label(option.title, systemImage: option.systemImage)
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)

            if resolvedLayoutMode == .grid {
                Text("Hinweis: Im Grid gibt’s kein Swipe-to-Delete. Du kannst ein Buch per Long-Press über das Kontextmenü löschen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            LibraryRowAppearanceSettingsHeaderSection(
                headerStyle: headerStyleBinding,
                headerDefaultExpanded: $headerDefaultExpanded,
                resolvedHeaderStyle: resolvedHeaderStyle
            )

            LibraryHomeAppearanceSettingsSection(
                homeMode: homeModeBinding,
                showsMaintenance: $homeShowsMaintenance,
                showsRoulette: $homeShowsRoulette,
                resolvedHeaderStyle: resolvedHeaderStyle
            )

            Divider()

            LibraryRowAppearanceSettingsCoverSection(
                showCovers: $showCovers,
                coverSize: coverSizeBinding,
                coverContentMode: coverContentModeBinding,
                coverCornerRadius: $coverCornerRadius,
                coverShadowEnabled: $coverShadowEnabled
            )

            Divider()

            LibraryRowAppearanceSettingsSpacingSection(
                rowVerticalInset: $rowVerticalInset,
                rowContentSpacing: $rowContentSpacing
            )

            Divider()

            LibraryRowAppearanceSettingsRowDetailsSection(
                showAuthor: $showAuthor,
                showStatus: $showStatus,
                showReadDate: $showReadDate,
                showRating: $showRating,
                showReadingProgress: $showReadingProgress,
                showTags: $showTags,
                tagStyle: tagStyleBinding,
                maxTags: $maxTags
            )

            LibraryRowAppearanceSettingsPreviewSection(
                showCovers: showCovers,
                coverSize: resolvedCoverSize,
                coverCornerRadius: CGFloat(coverCornerRadius),
                contentMode: resolvedContentMode,
                coverShadowEnabled: coverShadowEnabled,
                showAuthor: showAuthor,
                showStatus: showStatus,
                showReadDate: showReadDate,
                showRating: showRating,
                showReadingProgress: showReadingProgress,
                showTags: showTags,
                tagStyle: resolvedTagStyle,
                maxTags: maxTags,
                rowContentSpacing: rowContentSpacing
            )

            LibraryRowAppearanceSettingsResetSection(resetToDefaults: resetToDefaults)
        } header: {
            Text("Bibliothek")
        } footer: {
            Text("Passe Cover-Darstellung und Zeilen-Details an. Standardwerte entsprechen dem bisherigen Look – du kannst also gefahrlos rumspielen.")
        }
    }

    private func resetToDefaults() {
        layoutModeRaw = LibraryLayoutModeOption.list.rawValue

        headerStyleRaw = LibraryHeaderStyleOption.standard.rawValue
        headerDefaultExpanded = false
        homeModeRaw = LibraryHomeModeOption.compact.rawValue
        homeShowsMaintenance = true
        homeShowsRoulette = true

        showCovers = true
        coverSizeRaw = LibraryCoverSizeOption.standard.rawValue
        coverCornerRadius = 8
        coverContentModeRaw = LibraryCoverContentModeOption.fit.rawValue
        coverShadowEnabled = false

        rowVerticalInset = 8
        rowContentSpacing = 2

        showAuthor = true
        showStatus = true
        showReadDate = true
        showRating = true
        showReadingProgress = true
        showTags = true
        tagStyleRaw = LibraryTagStyleOption.hashtags.rawValue
        maxTags = 2
    }
}

#Preview {
    NavigationStack {
        List {
            LibraryRowAppearanceSettingsSection()
        }
        .navigationTitle("Darstellung")
    }
}

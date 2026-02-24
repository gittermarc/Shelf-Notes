//
//  AppearanceSettingsView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 01.02.26.
//

import SwiftUI

/// Settings screen for basic UI customization.
///
/// v1: Custom text color (global foreground style) via ColorPicker.
/// v2: Typography + density + tint (accent) + presets.
/// v3: Better structure (scan-friendly) via grouped sections + disclosure groups.
struct AppearanceSettingsView: View {
    // Color scheme
    @AppStorage(AppearanceStorageKey.colorScheme) var colorSchemeRaw: String = AppColorSchemeOption.system.rawValue

    // Existing: Text color
    @AppStorage(AppearanceStorageKey.useSystemTextColor) var useSystemTextColor: Bool = true
    @AppStorage(AppearanceStorageKey.textColorHex) var textColorHex: String = "#007AFF"

    // Typography / density
    @AppStorage(AppearanceStorageKey.fontDesign) var fontDesignRaw: String = AppFontDesignOption.system.rawValue
    @AppStorage(AppearanceStorageKey.textSize) var textSizeRaw: String = AppTextSizeOption.standard.rawValue
    @AppStorage(AppearanceStorageKey.density) var densityRaw: String = AppDensityOption.standard.rawValue

    // Tint
    @AppStorage(AppearanceStorageKey.useSystemTint) var useSystemTint: Bool = true
    @AppStorage(AppearanceStorageKey.tintColorHex) var tintColorHex: String = "#007AFF"

    // Library (for summary only)
    @AppStorage(AppearanceStorageKey.libraryLayoutMode) var libraryLayoutModeRaw: String = LibraryLayoutModeOption.list.rawValue
    @AppStorage(AppearanceStorageKey.libraryShowCovers) var libraryShowCovers: Bool = true

    // Presets (UI state only)
    @State var selectedPreset: AppAppearancePreset = .classic

    // Collapsible groups
    @State var textColorExpanded: Bool = false
    @State var tintExpanded: Bool = false
    @State var typographyExpanded: Bool = false

    var body: some View {
        Form {
            presetsSection
            colorsSection
            typographySection
            librarySection
            previewSection
        }
        .navigationTitle("Darstellung")
        .onAppear {
            // Make the preset cards feel "right" when entering the screen.
            selectedPreset = currentPresetMatch ?? .classic
        }
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}

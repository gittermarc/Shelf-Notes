//
//  LibraryHomeAppearanceSettingsSection.swift
//  Shelf Notes
//
//  Appearance options for the Smart Shelf library home area.
//

import SwiftUI

struct LibraryHomeAppearanceSettingsSection: View {
    let homeMode: Binding<LibraryHomeModeOption>
    let resolvedHeaderStyle: LibraryHeaderStyleOption

    var body: some View {
        Picker("Smart Shelf", selection: homeMode) {
            ForEach(LibraryHomeModeOption.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.menu)

        Text(homeMode.wrappedValue.subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)

        if resolvedHeaderStyle == .hidden, homeMode.wrappedValue != .hidden {
            Text("Bei ausgeschaltetem Header bleibt auch Smart Shelf verborgen, damit die Bibliothek bewusst ruhig bleibt.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

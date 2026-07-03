//
//  LibraryHomeAppearanceSettingsSection.swift
//  Shelf Notes
//
//  Appearance options for the Smart Shelf library home area.
//

import SwiftUI

struct LibraryHomeAppearanceSettingsSection: View {
    let homeMode: Binding<LibraryHomeModeOption>
    let showsMaintenance: Binding<Bool>
    let showsRoulette: Binding<Bool>
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

        Toggle(isOn: showsMaintenance) {
            Label("Regalpflege-Hinweise", systemImage: "wand.and.sparkles")
        }
        .disabled(homeMode.wrappedValue == .hidden)

        Toggle(isOn: showsRoulette) {
            Label("Buchroulette", systemImage: "die.face.5")
        }
        .disabled(homeMode.wrappedValue == .hidden)

        if showsMaintenance.wrappedValue, homeMode.wrappedValue != .hidden {
            Text("Zeigt kurze Hinweise für Bücher ohne Cover, Tags, Seitenzahl oder Bewertung.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if showsRoulette.wrappedValue, homeMode.wrappedValue != .hidden {
            Text("Zeigt im Smart Shelf eine kleine Zufallsauswahl aus deinem Stapel ungelesener Bücher.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if resolvedHeaderStyle == .hidden, homeMode.wrappedValue != .hidden {
            Text("Bei ausgeschaltetem Header bleibt auch Smart Shelf verborgen, damit die Bibliothek bewusst ruhig bleibt.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

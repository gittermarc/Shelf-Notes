//
//  LibraryWidgetPrivacySettingsSection.swift
//  Shelf Notes
//
//  Small Settings section for Home Screen widget privacy controls.
//

import SwiftUI

struct LibraryWidgetPrivacySettingsSection: View {
    @AppStorage(LibraryWidgetPrivacyPreferenceStorageKey.showsBookTitles)
    private var showsBookTitles = true

    @AppStorage(LibraryWidgetPrivacyPreferenceStorageKey.showsCovers)
    private var showsCovers = true

    @AppStorage(LibraryWidgetPrivacyPreferenceStorageKey.usesReducedMode)
    private var usesReducedMode = false

    var body: some View {
        Section("Widget") {
            Toggle(isOn: $showsBookTitles) {
                Label("Buchtitel anzeigen", systemImage: "textformat")
            }
            .disabled(usesReducedMode)

            Toggle(isOn: $showsCovers) {
                Label("Cover anzeigen", systemImage: "photo")
            }
            .disabled(usesReducedMode)

            Toggle(isOn: $usesReducedMode) {
                Label("Privater Modus", systemImage: "lock.shield")
            }

            Text(descriptionText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onChange(of: showsBookTitles) { _, _ in
            notifyWidgetPrivacyChanged()
        }
        .onChange(of: showsCovers) { _, _ in
            notifyWidgetPrivacyChanged()
        }
        .onChange(of: usesReducedMode) { _, newValue in
            if newValue {
                showsBookTitles = false
                showsCovers = false
            }
            notifyWidgetPrivacyChanged()
        }
    }

    private var descriptionText: String {
        if usesReducedMode {
            return "Das Widget zeigt nur Zahlen und Fortschritt. Buchtitel, Autoren, Cover und Regal-Highlights bleiben privat."
        }

        if !showsBookTitles && !showsCovers {
            return "Das Widget zeigt Statistiken und Fortschritt ohne konkrete Buchdetails."
        }

        if !showsBookTitles {
            return "Buchtitel und Autoren werden im Widget ersetzt. Cover können ein Buch trotzdem erkennbar machen."
        }

        if !showsCovers {
            return "Das Widget zeigt Buchtitel und Fortschritt, aber keine Cover."
        }

        return "Steuere, wie viel dein Home-Screen-Widget über konkrete Bücher verrät."
    }

    private func notifyWidgetPrivacyChanged() {
        LibraryWidgetSnapshotRefreshNotification.post()
    }
}

//
//  SettingsView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Split from ContentView.swift on 05.01.26.
//

import SwiftUI
import SwiftData
import StoreKit
import Combine

#if canImport(PhotosUI)
import PhotosUI
#endif

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Settings
struct SettingsView: View {
    @EnvironmentObject private var pro: ProManager
    @State private var showingPaywall = false

    @State private var confirmClearCoverCache = false
    @State private var cacheInfoText: String? = nil
    @State private var coverCacheSizeText: String = "…"

    // ✅ Lesesessions: Auto-Stop nach Inaktivität (verhindert 6h-Schlaf-Sessions 😄)
    @AppStorage("session_autostop_enabled_v1") private var autoStopEnabled: Bool = true
    @AppStorage("session_autostop_minutes_v1") private var autoStopMinutes: Int = 45

    var body: some View {
        NavigationStack {
            List {
                Section("Import / Export") {
                    NavigationLink {
                        CSVImportExportView(showExportSection: true, showDoneButton: false)
                    } label: {
                        Label("CSV Import/Export", systemImage: "tablecells")
                    }

                    Text("PDF-Export (kommt)")
                    Text("Markdown-Export (kommt)")
                }

                Section("Sync") {
                    Text("iCloud-Sync ist aktiv (CloudKit).")
                        .foregroundStyle(.secondary)
                }

                Section("Lesesessions") {
                    Toggle(isOn: $autoStopEnabled) {
                        Label("Auto-Stop nach Inaktivität", systemImage: "moon.zzz")
                    }

                    Stepper(value: $autoStopMinutes, in: 5...240, step: 5) {
                        HStack {
                            Text("Inaktivität")
                            Spacer()
                            Text("\(autoStopMinutes) Min.")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .disabled(!autoStopEnabled)

                    Text("Wenn du die App verlässt und länger inaktiv bist, wird eine laufende Timer-Session automatisch beendet. Sonst wird aus „kurz lesen“ schnell „6 Stunden“ – Klassiker 😄")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Cover") {
                    Button(role: .destructive) {
                        confirmClearCoverCache = true
                    } label: {
                        Label("Cover-Cache löschen", systemImage: "trash")
                    }

                    Text("Löscht lokal gespeicherte Cover auf diesem Gerät. Beim nächsten Anzeigen werden sie bei Bedarf neu geladen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Aktuell belegt")
                        Spacer()
                        Text(coverCacheSizeText)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)

                    if let cacheInfoText {
                        Text(cacheInfoText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Pro") {
                    if pro.hasPro {
                        Label("Pro ist aktiv", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.secondary)

                        Text("Unbegrenzte Listen sind freigeschaltet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Du kannst kostenlos bis zu \(ProManager.maxFreeCollections) Listen anlegen. Für weitere Listen brauchst du den Einmalkauf.")
                            .font(.subheadline)

                        Button {
                            showingPaywall = true
                        } label: {
                            Label("Einmalkauf freischalten", systemImage: "sparkles")
                        }
                    }

                    Button {
                        Task { await pro.restore() }
                    } label: {
                        Label("Käufe wiederherstellen", systemImage: "arrow.clockwise")
                    }

                    if let err = pro.lastError, !err.isEmpty {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .alert("Cover-Cache löschen?", isPresented: $confirmClearCoverCache) {
                Button("Löschen", role: .destructive) {
                    ImageDiskCache.shared.clearAll()
                    ImageMemoryCache.shared.clear()
                    cacheInfoText = "Cache gelöscht: \(Date().formatted(date: .numeric, time: .shortened))"
                    Task { await refreshCoverCacheSize() }
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Die App lädt Cover bei Bedarf erneut aus dem Netz.")
            }
            .sheet(isPresented: $showingPaywall) {
                ProPaywallView()
            }
            .task {
                await pro.refreshEntitlements()
                await pro.loadProductIfNeeded()
                await refreshCoverCacheSize()
            }
        }
    }

    @MainActor
    private func refreshCoverCacheSize() async {
        let text = await Task.detached(priority: .utility) {
            await ImageDiskCache.shared.diskUsageString()
        }.value

        coverCacheSizeText = text
    }
}


// MARK: - UI: removable chip

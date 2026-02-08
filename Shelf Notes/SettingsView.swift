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
    private enum SettingsRoute: String, Hashable, Codable {
        case appearance
    }

    @EnvironmentObject private var pro: ProManager
    @State private var showingPaywall = false

    @ObservedObject private var sync = SyncDiagnostics.shared

    @State private var confirmClearCoverCache = false
    @State private var cacheInfoText: String? = nil
    @State private var coverCacheSizeText: String = "…"

    // ✅ Lesesessions: Auto-Stop nach Inaktivität (verhindert 6h-Schlaf-Sessions 😄)
    @AppStorage("session_autostop_enabled_v1") private var autoStopEnabled: Bool = true
    @AppStorage("session_autostop_minutes_v1") private var autoStopMinutes: Int = 45

    // ✅ Buchsuche: Standardsprache für Google Books
    @AppStorage(BookSearchLanguagePreference.storageKey) private var bookSearchLanguagePreferenceRaw: String = BookSearchLanguagePreference.device.rawValue

    // Keep Settings navigation stable across global appearance updates.
    // Some appearance changes trigger a rebuild of the tab hierarchy; without an explicit path,
    // the NavigationStack may reset and pop back to the root.
    @State private var path = NavigationPath()

    // IMPORTANT: SceneStorage works reliably with non-optional storage types.
    // We use empty Data() as "no stored path".
    @SceneStorage("settings_nav_path_data_v1") private var pathData: Data = Data()

    private var bookSearchLanguagePreference: BookSearchLanguagePreference {
        BookSearchLanguagePreference(rawValue: bookSearchLanguagePreferenceRaw) ?? .device
    }

    private var bookSearchLanguageBinding: Binding<BookSearchLanguagePreference> {
        Binding(
            get: { BookSearchLanguagePreference(rawValue: bookSearchLanguagePreferenceRaw) ?? .device },
            set: { bookSearchLanguagePreferenceRaw = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Darstellung") {
                    NavigationLink(value: SettingsRoute.appearance) {
                        Label("Darstellung", systemImage: "paintpalette")
                    }

                    Text("Passe Schrift, Textdichte sowie Text- und Akzentfarben an – inkl. Presets. Tipp: Im Dark Mode können sehr dunkle Farben schwer lesbar sein.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Buchsuche") {
                    Picker("Standardsprache", selection: bookSearchLanguageBinding) {
                        ForEach(BookSearchLanguagePreference.allCases) { opt in
                            Text(opt.title).tag(opt)
                        }
                    }
                    .pickerStyle(.menu)

                    if bookSearchLanguagePreference == .device {
                        HStack {
                            Text("Gerät")
                            Spacer()
                            Text(BookSearchLanguagePreference.resolvedDeviceLanguageOptionTitle())
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }

                    Text("Diese Einstellung setzt die Standardsprache für die Google-Books-Suche. Beim Öffnen der Suche ist der Sprachfilter direkt passend voreingestellt – du kannst ihn dort aber jederzeit ändern.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Import / Export") {
                    NavigationLink {
                        CSVImportExportView(showExportSection: true, showDoneButton: false)
                    } label: {
                        Label("CSV Import/Export", systemImage: "tablecells")
                    }
                }

                Section("Sync") {
                    NavigationLink {
                        SyncDiagnosticsView()
                    } label: {
                        Label("Sync-Diagnose", systemImage: "icloud.and.arrow.up")
                    }

                    LabeledContent("iCloud", value: sync.accountStatusShort)
                    LabeledContent("Netzwerk", value: sync.networkStatusShort)
                    LabeledContent("Letzter lokaler Save", value: sync.lastLocalSaveShort)

                    if sync.offlineSaveCount > 0 {
                        Text("Offline gespeicherte Änderungen: " + String(sync.offlineSaveCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let hint = sync.accountStatusHint {
                        Text(hint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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

                Section("Info") {
                    LabeledContent("Version", value: appVersionString)
                        .monospacedDigit()
                    LabeledContent("Build", value: appBuildString)
                        .monospacedDigit()
                }
            }
            .navigationTitle("Einstellungen")
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .appearance:
                    AppearanceSettingsView()
                }
            }
            .onAppear {
                restoreNavigationPathIfPossible()
            }
            .onChange(of: path) { _, newValue in
                persistNavigationPath(newValue)
            }
            .alert("Cover-Cache löschen?", isPresented: $confirmClearCoverCache) {
                Button("Löschen", role: .destructive) {
                    ImageDiskCache.shared.clearAll()
                    ImageMemoryCache.shared.clear()
                    #if canImport(UIKit)
                    SyncedThumbnailMemoryCache.shared.removeAll()
                    #endif
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
                await sync.refreshIfStale()
            }
        }
    }

    // MARK: - Navigation persistence

    private func restoreNavigationPathIfPossible() {
        guard path.isEmpty else { return }
        guard !pathData.isEmpty else { return }

        guard let representation = try? JSONDecoder().decode(NavigationPath.CodableRepresentation.self, from: pathData) else {
            // Stored data is invalid -> reset
            pathData = Data()
            return
        }

        path = NavigationPath(representation)
    }

    private func persistNavigationPath(_ path: NavigationPath) {
        guard let representation = path.codable else {
            pathData = Data()
            return
        }

        pathData = (try? JSONEncoder().encode(representation)) ?? Data()
    }

    // MARK: - App Info

    private var appVersionString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    private var appBuildString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
    }

    @MainActor
    private func refreshCoverCacheSize() async {
        let text = await Task.detached(priority: .utility) {
            await ImageDiskCache.shared.diskUsageString()
        }.value

        coverCacheSizeText = text
    }
}

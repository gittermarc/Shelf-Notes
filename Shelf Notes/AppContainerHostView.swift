//
//  AppContainerHostView.swift
//  Shelf Notes
//
//  Robust SwiftData container bootstrap:
//  - No fatalError on launch
//  - Clear error screen with retry
//  - Optional explicit "local-only" fallback (no iCloud/CloudKit)
//

import SwiftUI
import SwiftData
import Combine

@MainActor
final class AppBootstrapper: ObservableObject {
    enum StorageMode: Equatable {
        case cloudKit
        case localOnly
        case inMemory
    }

    enum Phase {
        case loading
        case ready(container: ModelContainer, mode: StorageMode)
        case failed(error: Error)
    }

    @Published private(set) var phase: Phase = .loading

    init() {
        // We try CloudKit first. If it fails, we show a non-crashing error screen.
        start(mode: .cloudKit)
    }

    func retryCloudKit() {
        start(mode: .cloudKit)
    }

    func startLocalOnly() {
        start(mode: .localOnly)
    }

    func startInMemory() {
        start(mode: .inMemory)
    }

    private func start(mode: StorageMode) {
        phase = .loading

        do {
            let container = try ModelContainerFactory.makeContainer(mode: mode)
            phase = .ready(container: container, mode: mode)
        } catch {
            phase = .failed(error: error)
        }
    }
}

enum ModelContainerFactory {
    static var schema: Schema {
        Schema([
            Book.self,
            ReadingSession.self,
            ReadingGoal.self,
            BookCollection.self
        ])
    }

    // MARK: - Store separation

    /// We intentionally keep the CloudKit-backed store and the explicit local-only store
    /// in *separate* persistent stores. This avoids accidental "store mixing" when a user
    /// launches the app in local-only fallback mode (e.g. iCloud issues) and later goes
    /// back to CloudKit.
    ///
    /// This does mean local-only mode has its own local data set.
    private enum StoreName {
        static let cloud = "ShelfNotesCloud"
        static let local = "ShelfNotesLocal"
    }

    private static func storeURL(for storeBaseName: String) throws -> URL {
        // SwiftData uses a directory-based store in Application Support.
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        // Keep our SwiftData stores in an app-scoped folder to avoid clutter.
        let dir = appSupport
            .appendingPathComponent("ShelfNotes", isDirectory: true)
            .appendingPathComponent("SwiftData", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)

        return dir.appendingPathComponent("\(storeBaseName).store")
    }

    static func makeContainer(mode: AppBootstrapper.StorageMode) throws -> ModelContainer {
        switch mode {
        case .cloudKit:
            // CloudKit sync via iCloud (uses the container from your entitlements)
            let cloudURL = try storeURL(for: StoreName.cloud)
            let config = ModelConfiguration(
                StoreName.cloud,
                schema: schema,
                url: cloudURL,
                allowsSave: true,
                cloudKitDatabase: .automatic
            )
            return try ModelContainer(for: schema, configurations: [config])

        case .localOnly:
            // Local persistent store *without* CloudKit.
            // IMPORTANT: This is an explicit, user-chosen fallback to avoid silent data divergence.
            let localURL = try storeURL(for: StoreName.local)
            let config = ModelConfiguration(
                StoreName.local,
                schema: schema,
                url: localURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [config])

        case .inMemory:
            // Emergency fallback: runs in-memory only.
            let config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [config])
        }
    }
}

struct AppContainerHostView: View {
    @StateObject private var bootstrapper = AppBootstrapper()
    @State private var showingLocalOnlyNotice = false

    var body: some View {
        switch bootstrapper.phase {
        case .loading:
            ProgressView("Shelf Notes wird vorbereitet …")
                .padding()

        case .ready(let container, let mode):
            RootView()
                .modelContainer(container)
                .overlay(alignment: .top) {
                    if mode == .localOnly {
                        LocalOnlyBanner()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .onAppear {
                    showingLocalOnlyNotice = (mode == .localOnly)
                }
                .alert("Offline-Modus", isPresented: $showingLocalOnlyNotice) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Du nutzt Shelf Notes aktuell ohne iCloud/CloudKit. Änderungen werden lokal gespeichert und nicht synchronisiert. Wichtig: Das ist ein eigener lokaler Datenstand (separat vom iCloud-Speicher).")
                }

        case .failed(let error):
            ModelContainerFailureView(
                error: error,
                retry: { bootstrapper.retryCloudKit() },
                startLocalOnly: { bootstrapper.startLocalOnly() },
                startInMemory: { bootstrapper.startInMemory() }
            )
        }
    }
}

private struct LocalOnlyBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "icloud.slash")
            Text("Offline-Modus: iCloud-Sync deaktiviert")
                .font(.footnote)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.top, 10)
        .padding(.horizontal, 12)
        .shadow(radius: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Offline-Modus. iCloud-Synchronisation deaktiviert")
    }
}

struct ModelContainerFailureView: View {
    let error: Error
    let retry: () -> Void
    let startLocalOnly: () -> Void
    let startInMemory: () -> Void

    @State private var showDetails = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.icloud")
                            .font(.system(size: 34, weight: .semibold))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Datenbank konnte nicht gestartet werden")
                                .font(.title2.weight(.semibold))
                            Text("Shelf Notes konnte den SwiftData-Speicher nicht initialisieren. Häufige Ursachen sind iCloud/CloudKit-Setup, Signierung/Entitlements oder ein temporäres iCloud-Problem.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Was du jetzt tun kannst")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Prüfe, ob du in iCloud eingeloggt bist", systemImage: "person.crop.circle")
                            Label("Aktiviere iCloud Drive", systemImage: "icloud")
                            Label("Stelle sicher, dass die App Zugriff auf iCloud hat", systemImage: "checkmark.shield")
                            Label("Wenn du gerade offline bist: kurz warten und erneut versuchen", systemImage: "wifi.slash")
                        }
                        .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 10) {
                        Button(action: retry) {
                            Label("Erneut versuchen", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: startLocalOnly) {
                            Label("Ohne iCloud starten (lokal)", systemImage: "internaldrive")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(action: startInMemory) {
                            Label("Nur temporär starten (In‑Memory)", systemImage: "bolt")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    DisclosureGroup("Technische Details", isExpanded: $showDetails) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(describing: error))
                                .font(.footnote)
                                .textSelection(.enabled)

                            #if DEBUG
                            Text("Hinweis: Im Release solltest du hier keine sensiblen Details anzeigen. Für Debug/Support ist das aber Gold wert.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            #endif
                        }
                        .padding(.top, 6)
                    }
                    .padding(.top, 6)
                }
                .padding()
            }
            .navigationTitle("Startproblem")
        }
    }
}

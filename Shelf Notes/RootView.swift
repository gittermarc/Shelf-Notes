//
//  RootView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 12.12.25.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var books: [Book]
    @StateObject private var pro = ProManager()
    @StateObject private var timer = ReadingTimerManager()
    // Persist across launches: the initial backfill is meant to bring legacy books up to date.
    // New/edited books get thumbnails via their respective flows.
    @AppStorage("did_run_cover_backfill_v2") private var didRunCoverBackfill: Bool = false
    @State private var coverBackfillTask: Task<Void, Never>? = nil

    @AppStorage("did_offer_csv_import_v1") private var didOfferCSVImport: Bool = false
    @State private var showingCSVFirstRun = false

    // MARK: - Appearance
    @AppStorage(AppearanceStorageKey.useSystemTextColor) private var useSystemTextColor: Bool = true
    @AppStorage(AppearanceStorageKey.textColorHex) private var textColorHex: String = "#007AFF"

    @AppStorage(AppearanceStorageKey.fontDesign) private var fontDesignRaw: String = AppFontDesignOption.system.rawValue
    @AppStorage(AppearanceStorageKey.textSize) private var textSizeRaw: String = AppTextSizeOption.standard.rawValue
    @AppStorage(AppearanceStorageKey.density) private var densityRaw: String = AppDensityOption.standard.rawValue

    @AppStorage(AppearanceStorageKey.useSystemTint) private var useSystemTint: Bool = true
    @AppStorage(AppearanceStorageKey.tintColorHex) private var tintColorHex: String = "#007AFF"

    // Keep the currently selected tab stable across any appearance changes.
    // Without an explicit selection binding, a TabView can snap back to the first tab
    // when the view hierarchy rebuilds after @AppStorage updates (e.g. toggling tint).
    @SceneStorage("root_selected_tab_v1") private var selectedTab: Int = 0

    var body: some View {
        let appTextColor = resolvedTextColor
        let design = resolvedFontDesignOption.fontDesign
        let textSize = resolvedTextSizeOption.dynamicTypeSize
        let density = resolvedDensityOption
        let tintColor = resolvedEffectiveTint

        TabView(selection: $selectedTab) {
            LibraryView()
                .tabItem {
                    Label("Bibliothek", systemImage: "books.vertical")
                }
                .tag(0)

            ProgressHubView()
                .tabItem {
                    Label("Fortschritt", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)

            CollectionsView()
                .tabItem {
                    Label("Listen", systemImage: "rectangle.stack")
                }
                .tag(2)

            TagsView()
                .tabItem {
                    Label("Tags", systemImage: "tag")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gear")
                }
                .tag(4)
        }
        // Global look & feel
        .foregroundStyle(appTextColor)
        .fontDesign(design)
        .dynamicTypeSize(textSize)
        .environment(\.controlSize, density.controlSize)
        .environment(\.defaultMinListRowHeight, density.minListRowHeight)
        // Always apply a tint modifier to keep the view hierarchy stable.
        // If we conditionally add/remove `.tint(...)`, SwiftUI can rebuild parts of the
        // hierarchy and accidentally reset navigation state in the Settings tab.
        .tint(tintColor)
        .environmentObject(pro)
        .environmentObject(timer)
        .onChange(of: scenePhase) { _, newPhase in
            timer.handleScenePhaseChange(newPhase)

            // Backfill should never run while the app is not active.
            if newPhase != .active {
                coverBackfillTask?.cancel()
                coverBackfillTask = nil
            } else {
                scheduleCoverBackfillIfNeeded()
            }
        }
        .onAppear {
            // One-time first-run hint: offer CSV import if the library is empty.
            if !didOfferCSVImport && books.isEmpty {
                didOfferCSVImport = true
                showingCSVFirstRun = true
            }
        }
        .sheet(isPresented: $showingCSVFirstRun) {
            NavigationStack {
                CSVImportExportView(title: "Erstimport", showExportSection: false, showDoneButton: true)
            }
        }
        .task {
            // One-time: migrate legacy ReadingStatus strings to stable codes
            await ReadingStatusMigrator.migrateIfNeeded(modelContext: modelContext)

            // One-time: make sure existing books get synced thumbnails.
            // Important: schedule this "idle" (deferred + chunked), do not block launch.
            scheduleCoverBackfillIfNeeded()
        }
        .sheet(item: $timer.pendingCompletion) { pending in
            TimerSessionCompletionSheet(
                book: bookForPending(pending),
                pending: pending
            )
            .environmentObject(timer)
        }
    }

    private var resolvedTextColor: Color {
        guard !useSystemTextColor, let color = Color(hex: textColorHex) else {
            return .primary
        }
        return color
    }

    private var resolvedFontDesignOption: AppFontDesignOption {
        AppFontDesignOption(rawValue: fontDesignRaw) ?? .system
    }

    private var resolvedTextSizeOption: AppTextSizeOption {
        AppTextSizeOption(rawValue: textSizeRaw) ?? .standard
    }

    private var resolvedDensityOption: AppDensityOption {
        AppDensityOption(rawValue: densityRaw) ?? .standard
    }

    private var resolvedEffectiveTint: Color {
        if useSystemTint {
            return .accentColor
        }

        return Color(hex: tintColorHex) ?? .accentColor
    }

    private func bookForPending(_ pending: ReadingTimerManager.PendingCompletion) -> Book? {
        // Fast path: use already queried list if possible
        if let match = books.first(where: { $0.id == pending.bookID }) {
            return match
        }

        // Fallback: fetch directly from SwiftData (avoids any “Query hasn’t refreshed yet” edge cases)
        let bookID = pending.bookID
        let descriptor = FetchDescriptor<Book>(
            predicate: #Predicate<Book> { $0.id == bookID }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    // MARK: - Deferred cover thumbnail backfill

    @MainActor
    private func scheduleCoverBackfillIfNeeded() {
        guard scenePhase == .active else { return }
        guard !didRunCoverBackfill else { return }
        guard coverBackfillTask == nil else { return }

        // Run with low priority and in small bursts so the UI stays responsive.
        coverBackfillTask = Task(priority: .utility) { @MainActor in
            // Give SwiftUI one beat to get fully interactive.
            try? await Task.sleep(nanoseconds: 1_250_000_000)
            if Task.isCancelled { return }
            guard scenePhase == .active else { return }

            await CoverThumbnailer.backfillAllBooksIfNeeded(
                modelContext: modelContext,
                batchSize: 4,
                interBatchDelayNanoseconds: 650_000_000
            )

            if Task.isCancelled { return }
            didRunCoverBackfill = true
            coverBackfillTask = nil
        }
    }
}

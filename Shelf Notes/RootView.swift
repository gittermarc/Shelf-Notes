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
    @StateObject private var pro = ProManager()
    @StateObject private var timer = ReadingTimerManager()
    @StateObject private var tagsIndexStore = TagsIndexStore()
    // Persist across launches: the initial backfill is meant to bring legacy books up to date.
    // New/edited books get thumbnails via their respective flows.
    @AppStorage("did_run_cover_backfill_v2") private var didRunCoverBackfill: Bool = false
    @State private var coverBackfillTask: Task<Void, Never>? = nil

    @AppStorage("did_offer_csv_import_v1") private var didOfferCSVImport: Bool = false
    @State private var showingCSVFirstRun = false
    @State private var lastKnownBookCount: Int? = nil

    // MARK: - Appearance
    @AppStorage(AppearanceStorageKey.colorScheme) private var colorSchemeRaw: String = AppColorSchemeOption.system.rawValue
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
        let preferredScheme = resolvedColorSchemeOption.preferredColorScheme
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
        .preferredColorScheme(preferredScheme)
        .foregroundStyle(appTextColor)
        .fontDesign(design)
        .dynamicTypeSize(textSize)
        .environment(\.controlSize, density.controlSize)
        .environment(\.defaultMinListRowHeight, density.minListRowHeight)
        // Always apply a tint modifier to keep the view hierarchy stable.
        // If we conditionally add/remove the tint modifier, SwiftUI can rebuild parts of the
        // hierarchy and accidentally reset navigation state in the Settings tab.
        .tint(tintColor)
        .environmentObject(pro)
        .environmentObject(timer)
        .environmentObject(tagsIndexStore)
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .sheet(isPresented: $showingCSVFirstRun) {
            NavigationStack {
                CSVImportExportView(title: "Erstimport", showExportSection: false, showDoneButton: true)
            }
        }
        .task {
            await runStartupMaintenance()
        }
        .sheet(item: $timer.pendingCompletion) { pending in
            TimerSessionCompletionSheet(
                book: AppStartupMaintenanceService.bookForPending(
                    pending,
                    modelContext: modelContext
                ),
                pending: pending
            )
            .environmentObject(timer)
            .environmentObject(tagsIndexStore)
        }
    }

    private var resolvedColorSchemeOption: AppColorSchemeOption {
        AppColorSchemeOption(rawValue: colorSchemeRaw) ?? .system
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

    private var maintenanceState: AppStartupMaintenanceState {
        AppStartupMaintenanceService.state(
            scenePhase: scenePhase,
            didRunCoverBackfill: didRunCoverBackfill,
            coverBackfillTask: coverBackfillTask,
            didOfferCSVImport: didOfferCSVImport,
            bookCount: lastKnownBookCount
        )
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        timer.handleScenePhaseChange(newPhase)

        let state = AppStartupMaintenanceService.state(
            scenePhase: newPhase,
            didRunCoverBackfill: didRunCoverBackfill,
            coverBackfillTask: coverBackfillTask,
            didOfferCSVImport: didOfferCSVImport,
            bookCount: lastKnownBookCount
        )

        if state.shouldRefreshLibraryCaches {
            refreshBookCountAndTagsIndex(shouldOfferCSVImport: false)
        }

        if state.shouldCancelCoverBackfill {
            cancelCoverBackfill()
        } else {
            scheduleCoverBackfillIfNeeded()
        }
    }

    private func runStartupMaintenance() async {
        await AppStartupMaintenanceService.migrateReadingStatusIfNeeded(modelContext: modelContext)
        refreshBookCountAndTagsIndex(shouldOfferCSVImport: true)
        scheduleCoverBackfillIfNeeded()
    }

    private func refreshBookCountAndTagsIndex(shouldOfferCSVImport: Bool) {
        let bookCount = AppStartupMaintenanceService.fetchBookCount(modelContext: modelContext)
        lastKnownBookCount = bookCount
        AppStartupMaintenanceService.refreshTagsIndex(modelContext: modelContext, store: tagsIndexStore)

        guard shouldOfferCSVImport else { return }
        offerCSVImportOnFirstRunIfNeeded(bookCount: bookCount)
    }

    private func offerCSVImportOnFirstRunIfNeeded(bookCount: Int?) {
        let state = AppStartupMaintenanceService.state(
            scenePhase: scenePhase,
            didRunCoverBackfill: didRunCoverBackfill,
            coverBackfillTask: coverBackfillTask,
            didOfferCSVImport: didOfferCSVImport,
            bookCount: bookCount
        )

        guard state.shouldOfferCSVImport else { return }
        didOfferCSVImport = true
        showingCSVFirstRun = true
    }

    private func cancelCoverBackfill() {
        coverBackfillTask?.cancel()
        coverBackfillTask = nil
    }

    // MARK: - Deferred cover thumbnail backfill

    private func scheduleCoverBackfillIfNeeded() {
        guard maintenanceState.shouldScheduleCoverBackfill else { return }

        coverBackfillTask = AppStartupMaintenanceService.makeCoverBackfillTask(
            modelContext: modelContext,
            shouldContinue: { scenePhase == .active },
            markDidRunCoverBackfill: { didRunCoverBackfill = true },
            clearCoverBackfillTask: { coverBackfillTask = nil }
        )
    }
}

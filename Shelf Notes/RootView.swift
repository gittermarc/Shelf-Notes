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

    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Bibliothek", systemImage: "books.vertical")
                }

            // ✅ Neu: Visuelle Lese-Zeitleiste (gelesene Bücher als horizontaler Zeitstrahl)
            ReadingTimelineView()
                .tabItem {
                    Label("Zeitleiste", systemImage: "clock")
                }

            CollectionsView()
                .tabItem {
                    Label("Listen", systemImage: "rectangle.stack")
                }

            GoalsView()
                .tabItem {
                    Label("Ziele", systemImage: "target")
                }

            // ✅ Neu: Dashboard / Statistiken
            StatisticsView()
                .tabItem {
                    Label("Statistiken", systemImage: "chart.bar.xaxis")
                }

            TagsView()
                .tabItem {
                    Label("Tags", systemImage: "tag")
                }

            SettingsView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gear")
                }
        }
        .environmentObject(pro)
        .environmentObject(timer)
        .onChange(of: scenePhase) { newPhase in
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

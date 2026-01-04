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
    @Query private var books: [Book]
    @StateObject private var pro = ProManager()
    @State private var didRunCoverBackfill = false

    @AppStorage("did_offer_csv_import_v1") private var didOfferCSVImport: Bool = false
    @State private var showingCSVFirstRun = false

    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Bibliothek", systemImage: "books.vertical")
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
            // One-time: make sure existing books get synced thumbnails
            guard !didRunCoverBackfill else { return }
            didRunCoverBackfill = true
            await CoverThumbnailer.backfillAllBooksIfNeeded(modelContext: modelContext)
        }
    }
}

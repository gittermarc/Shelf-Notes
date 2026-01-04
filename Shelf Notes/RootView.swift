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
    @StateObject private var pro = ProManager()
    @State private var didRunCoverBackfill = false

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
        .task {
            // One-time: make sure existing books get synced thumbnails
            guard !didRunCoverBackfill else { return }
            didRunCoverBackfill = true
            await CoverThumbnailer.backfillAllBooksIfNeeded(modelContext: modelContext)
        }
    }
}

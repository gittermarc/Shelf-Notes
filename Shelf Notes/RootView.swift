//
//  RootView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 12.12.25.
//

import SwiftUI

struct RootView: View {
    @StateObject private var pro = ProManager()

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
    }
}

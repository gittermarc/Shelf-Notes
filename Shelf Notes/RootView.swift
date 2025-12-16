//
//  RootView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 12.12.25.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            LibraryView()
                .tabItem {
                    Label("Bibliothek", systemImage: "books.vertical")
                }

            GoalsView()
                .tabItem {
                    Label("Ziele", systemImage: "target")
                }

            TagsView()
                .tabItem {
                    Label("Tags", systemImage: "tag")
                }
        }
    }
}

//
//  TagsView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Split from ContentView.swift on 05.01.26.
//

import SwiftUI

// MARK: - Tags Tab (counts + tap to filter)
struct TagsView: View {
    @EnvironmentObject private var tagsIndexStore: TagsIndexStore

    var body: some View {
        NavigationStack {
            List {
                if tagsIndexStore.tagCounts.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Tags",
                        systemImage: "tag",
                        description: Text("Füge Tags bei einem Buch hinzu, dann tauchen sie hier auf.")
                    )
                } else {
                    ForEach(tagsIndexStore.tagCounts) { entry in
                        NavigationLink {
                            LibraryView(initialTag: entry.tag)
                        } label: {
                            HStack {
                                Text("#\(entry.tag)")
                                Spacer()
                                Text("\(entry.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tags")
        }
    }
}

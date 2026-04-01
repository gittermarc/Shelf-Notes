//
//  TagsView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Split from ContentView.swift on 05.01.26.
//

import SwiftUI
import SwiftData

// MARK: - Tags Tab (counts + tap to filter)
struct TagsView: View {
    @Query private var books: [Book]
    @StateObject private var indexModel = TagsIndexModel()

    var body: some View {
        let signature = TagsIndexModel.taskSignature(books: books)

        NavigationStack {
            List {
                if indexModel.tagCounts.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Tags",
                        systemImage: "tag",
                        description: Text("Füge Tags bei einem Buch hinzu, dann tauchen sie hier auf.")
                    )
                } else {
                    ForEach(indexModel.tagCounts) { entry in
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
        .task(id: signature) {
            // Build the snapshot off the render path (inside the task).
            let snapshot = TagsIndexBuilder.makeSnapshot(books: books)
            indexModel.update(snapshot: snapshot, signature: signature)
        }
    }
}

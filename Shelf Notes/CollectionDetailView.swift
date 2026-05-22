//
//  CollectionDetailView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Split from ContentView.swift on 05.01.26.
//

import SwiftUI
import SwiftData
import StoreKit
import Combine

#if canImport(PhotosUI)
import PhotosUI
#endif

#if canImport(UIKit)
import UIKit
#endif

struct CollectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var collection: BookCollection

    @State private var nameDraft: String = ""
    @State private var saveDebouncer = ModelContextSaveDebouncer()

    var body: some View {
        List {
            Section("Name") {
                TextField("Listenname", text: nameDraftBinding)
            }

            Section("Bücher") {
                if (collection.books ?? []).isEmpty {
                    ContentUnavailableView(
                        "Noch leer",
                        systemImage: "book",
                        description: Text("Öffne ein Buch → „Listen“ → Haken setzen.")
                    )
                } else {
                    ForEach(sortedBooks) { b in
                        NavigationLink {
                            BookDetailView(book: b)
                        } label: {
                            BookRowView(book: b)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                flushPendingNameSave()
                                var current = b.collections ?? []
                                current.removeAll(where: { $0.id == collection.id })
                                b.collections = current
                                modelContext.saveWithDiagnostics()
                            } label: {
                                Label("Entfernen", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(collection.name.isEmpty ? "Liste" : collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { nameDraft = collection.name }
        .onDisappear { flushPendingNameSave() }
    }

    private var nameDraftBinding: Binding<String> {
        Binding(
            get: { nameDraft },
            set: { newValue in
                updateNameDraft(newValue)
            }
        )
    }

    private func updateNameDraft(_ newValue: String) {
        nameDraft = newValue

        let trimmedName = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard collection.name != trimmedName else {
            return
        }

        collection.name = trimmedName
        collection.updatedAt = Date()
        saveDebouncer.schedule {
            modelContext.saveWithDiagnostics()
        }
    }

    private func flushPendingNameSave() {
        saveDebouncer.flush()
    }

    private var sortedBooks: [Book] {
        (collection.books ?? []).sorted { a, b in
            let ta = a.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let tb = b.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return ta.localizedCaseInsensitiveCompare(tb) == .orderedAscending
        }
    }

}


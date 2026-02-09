//
//  CollectionsView.swift
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

// MARK: - Collections (Phase 1)

struct CollectionsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BookCollection.createdAt, order: .reverse)
    private var collections: [BookCollection]

    @State private var showingNew = false
    @State private var showingPaywall = false

    @EnvironmentObject private var pro: ProManager

    var body: some View {
        NavigationStack {
            List {
                if collections.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Listen",
                        systemImage: "rectangle.stack",
                        description: Text("Lege Listen an – z.B. „NYC“, „Justizthriller“, „KI“, „2025 Highlights“…")
                    )
                } else {
                    ForEach(collections) { c in
                        NavigationLink {
                            CollectionDetailView(collection: c)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.name.isEmpty ? "Ohne Namen" : c.name)

                                    // ✅ books ist optional -> safe count
                                    Text("\((c.books ?? []).count) Bücher")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .onDelete(perform: deleteCollections)
                }
            }
            .navigationTitle("Listen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        requestNewCollection()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Neue Liste")
                }
            }
            .sheet(isPresented: $showingNew) {
                NewCollectionSheet { name in
                    let col = BookCollection(name: name)
                    modelContext.insert(col)
                    modelContext.saveWithDiagnostics()
                }
            }
            .sheet(isPresented: $showingPaywall) {
                ProPaywallView(onPurchased: {
                    showingNew = true
                })
            }
        }
    }


    private func requestNewCollection() {
        let count = collections.count
        if pro.hasPro || count < ProManager.maxFreeCollections {
            showingNew = true
        } else {
            showingPaywall = true
        }
    }

    private func deleteCollections(at offsets: IndexSet) {
        for index in offsets {
            let col = collections[index]

            // ✅ books ist optional
            let booksInCol = col.books ?? []

            // defensive: remove relation explicitly (CloudKit kann sonst manchmal zicken)
            for b in booksInCol {
                var current = b.collections ?? []
                current.removeAll(where: { $0.id == col.id })
                b.collections = current
            }

            modelContext.delete(col)
        }
        modelContext.saveWithDiagnostics()
    }
}

// ✅ OUTSIDE now: can be linked from anywhere

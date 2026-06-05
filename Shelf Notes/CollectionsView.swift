//
//  CollectionsView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Split from ContentView.swift on 05.01.26.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Collections

struct CollectionsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BookCollection.createdAt, order: .reverse)
    private var collections: [BookCollection]

    @Query(sort: \Book.createdAt, order: .reverse)
    private var books: [Book]

    @State private var searchText: String = ""
    @State private var sortMode: CollectionsDashboardSortMode = .recentActivity
    @State private var showingNew = false
    @State private var showingPaywall = false
    @State private var deleteCandidate: BookCollection?

    @EnvironmentObject private var pro: ProManager

    var body: some View {
        let bookSnapshots = CollectionsDashboardBuilder.makeBookSnapshots(books: books)
        let collectionSnapshots = CollectionsDashboardBuilder.makeCollectionSnapshots(collections: collections)
        let dashboard = CollectionsDashboardBuilder.build(
            collections: collectionSnapshots,
            allBooks: bookSnapshots
        )
        let visibleEntries = CollectionsDashboardBuilder.filteredEntries(
            dashboard.entries,
            searchText: searchText,
            sortMode: sortMode
        )
        let booksByID = Dictionary(uniqueKeysWithValues: books.map { ($0.id, $0) })

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CollectionsHeroCard(
                        summary: dashboard.summary,
                        hasPro: pro.hasPro,
                        freeCollectionLimit: ProManager.maxFreeCollections
                    )

                    if dashboard.entries.isEmpty {
                        CollectionsEmptyState(
                            hasBooks: !books.isEmpty,
                            onCreate: requestNewCollection
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                    } else {
                        CollectionsExplorerControls(sortMode: $sortMode)

                        if visibleEntries.isEmpty {
                            ContentUnavailableView(
                                "Keine Listen gefunden",
                                systemImage: "magnifyingglass",
                                description: Text("Für deine Suche gibt es aktuell keine passende Liste.")
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                        } else {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 300), spacing: 12)],
                                alignment: .leading,
                                spacing: 12
                            ) {
                                ForEach(visibleEntries) { entry in
                                    if let collection = collection(for: entry) {
                                        NavigationLink {
                                            CollectionDetailView(collection: collection)
                                        } label: {
                                            CollectionCardView(
                                                entry: entry,
                                                coverBooks: coverBooks(for: entry, booksByID: booksByID)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                deleteCandidate = collection
                                            } label: {
                                                Label("Liste löschen", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .navigationTitle("Listen")
            .searchable(text: $searchText, prompt: "Listen suchen")
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
                    let collection = BookCollection(name: name)
                    modelContext.insert(collection)
                    modelContext.saveWithDiagnostics()
                }
            }
            .sheet(isPresented: $showingPaywall) {
                ProPaywallView(onPurchased: {
                    showingNew = true
                })
            }
            .alert(
                "Liste löschen?",
                isPresented: isDeleteAlertPresented,
                presenting: deleteCandidate
            ) { collection in
                Button("Löschen", role: .destructive) {
                    deleteCollection(collection)
                    deleteCandidate = nil
                }

                Button("Abbrechen", role: .cancel) {
                    deleteCandidate = nil
                }
            } message: { collection in
                Text("\(collection.name.isEmpty ? "Diese Liste" : collection.name) wird entfernt. Die Bücher bleiben in deiner Bibliothek erhalten.")
            }
        }
    }

    private var isDeleteAlertPresented: Binding<Bool> {
        Binding(
            get: { deleteCandidate != nil },
            set: { isPresented in
                if !isPresented {
                    deleteCandidate = nil
                }
            }
        )
    }

    private func requestNewCollection() {
        let count = collections.count
        if pro.hasPro || count < ProManager.maxFreeCollections {
            showingNew = true
        } else {
            showingPaywall = true
        }
    }

    private func collection(for entry: CollectionsDashboardEntry) -> BookCollection? {
        collections.first { $0.id == entry.id }
    }

    private func coverBooks(
        for entry: CollectionsDashboardEntry,
        booksByID: [UUID: Book]
    ) -> [Book] {
        entry.representativeBookIDs.compactMap { booksByID[$0] }
    }

    private func deleteCollection(_ collection: BookCollection) {
        let booksInCollection = collection.booksSafe

        for book in booksInCollection {
            var current = book.collectionsSafe
            current.removeAll { $0.id == collection.id }
            book.collectionsSafe = current
        }

        modelContext.delete(collection)
        modelContext.saveWithDiagnostics()
    }
}

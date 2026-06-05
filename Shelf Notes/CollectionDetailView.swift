//
//  CollectionDetailView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Split from ContentView.swift on 05.01.26.
//

import SwiftUI
import SwiftData

struct CollectionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var collection: BookCollection

    @State private var nameDraft: String = ""
    @State private var searchText: String = ""
    @State private var statusFilter: CollectionDetailStatusFilter = .all
    @State private var sortMode: CollectionDetailSortMode = .title
    @State private var showingBookPicker = false
    @State private var saveDebouncer = ModelContextSaveDebouncer()

    var body: some View {
        let books = collection.booksSafe
        let bookSnapshots = CollectionDetailBuilder.makeBookSnapshots(books: books)
        let detailState = CollectionDetailBuilder.build(
            collectionName: collection.name,
            books: bookSnapshots
        )
        let visibleSnapshots = CollectionDetailBuilder.filteredBooks(
            bookSnapshots,
            searchText: searchText,
            statusFilter: statusFilter,
            sortMode: sortMode
        )
        let booksByID = Dictionary(books.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let visibleBooks = visibleSnapshots.compactMap { booksByID[$0.id] }
        let coverBooks = detailState.representativeBookIDs.compactMap { booksByID[$0] }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CollectionDetailHeaderView(
                    state: detailState,
                    coverBooks: coverBooks,
                    nameDraft: nameDraftBinding,
                    onAddBooks: openBookPicker
                )

                if detailState.isEmpty {
                    CollectionDetailEmptyState(onAddBooks: openBookPicker)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 14)
                } else {
                    CollectionDetailBookFilterBar(
                        searchText: $searchText,
                        statusFilter: $statusFilter,
                        sortMode: $sortMode
                    )

                    if visibleBooks.isEmpty {
                        ContentUnavailableView(
                            "Keine Bücher gefunden",
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text("Passe Suche, Status oder Sortierung an, um deine Bücher wiederzufinden.")
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 18)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(visibleBooks) { book in
                                CollectionDetailBookCardView(book: book) {
                                    remove(book)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .navigationTitle(collection.name.isEmpty ? "Liste" : collection.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: openBookPicker) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Bücher hinzufügen")
            }
        }
        .sheet(isPresented: $showingBookPicker) {
            CollectionBookPickerSheet(collection: collection)
        }
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

    private func openBookPicker() {
        flushPendingNameSave()
        showingBookPicker = true
    }

    private func remove(_ book: Book) {
        flushPendingNameSave()

        guard CollectionMembershipMutation.remove(book, from: collection) else {
            return
        }

        modelContext.saveWithDiagnostics()
    }
}

private struct CollectionDetailEmptyState: View {
    let onAddBooks: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("Diese Liste wartet auf Bücher")
                    .font(.headline)

                Text("Füge passende Titel direkt hier hinzu und mache daraus ein kuratiertes Regal statt einer leeren Hülle.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onAddBooks) {
                Label("Bücher hinzufügen", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

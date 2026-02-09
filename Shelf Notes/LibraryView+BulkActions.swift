//
//  LibraryView+BulkActions.swift
//  Shelf Notes
//
//  Multi-select + bulk actions for the library.
//

import Foundation
import SwiftUI
import SwiftData

extension LibraryView {

    // MARK: - Selection helpers

    var currentDisplayedBooks: [Book] {
        derivedReady ? cachedDisplayedBooks : displayedBooks
    }

    var isAllDisplayedSelected: Bool {
        let displayed = currentDisplayedBooks
        guard !displayed.isEmpty else { return false }
        let displayedIDs = Set(displayed.map(\.id))
        return selectedBookIDs == displayedIDs
    }

    func beginSelectionMode() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isSelectionMode = true
        }
        selectedBookIDs.removeAll()
    }

    func endSelectionMode() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isSelectionMode = false
        }
        selectedBookIDs.removeAll()
        bulkTagDraft = ""
        bulkRemoveTagOptions = []
        showingBulkAddTagAlert = false
        showingBulkRemoveTagDialog = false
        showingBulkDeleteConfirm = false
    }

    func isSelected(_ book: Book) -> Bool {
        selectedBookIDs.contains(book.id)
    }

    func toggleSelection(_ book: Book) {
        if selectedBookIDs.contains(book.id) {
            selectedBookIDs.remove(book.id)
        } else {
            selectedBookIDs.insert(book.id)
        }
    }

    func toggleSelectAllDisplayed() {
        let displayed = currentDisplayedBooks
        guard !displayed.isEmpty else { return }

        let ids = Set(displayed.map(\.id))
        if selectedBookIDs == ids {
            selectedBookIDs.removeAll()
        } else {
            selectedBookIDs = ids
        }
    }

    @ViewBuilder
    func selectableListRow(_ book: Book) -> some View {
        Button {
            toggleSelection(book)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                selectionIndicator(isSelected(book))
                    .padding(.top, 6)

                BookRowView(book: book)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(book.title.isEmpty ? "Ohne Titel" : book.title)
        .accessibilityHint("Tippen zum Auswählen")
    }

    private func selectionIndicator(_ selected: Bool) -> some View {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
            .font(.title3.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .accessibilityLabel(selected ? "Ausgewählt" : "Nicht ausgewählt")
    }

    // MARK: - Bulk actions

    private func selectedBooks() -> [Book] {
        guard !selectedBookIDs.isEmpty else { return [] }
        let ids = selectedBookIDs
        return books.filter { ids.contains($0.id) }
    }

    func bulkSetStatus(_ status: ReadingStatus) {
        let targets = selectedBooks()
        guard !targets.isEmpty else { return }

        for b in targets {
            b.status = status
        }
        modelContext.saveWithDiagnostics()
    }

    func bulkAddTagsFromDraft() {
        let tagsToAdd = parseTagsForBulk(bulkTagDraft)
        bulkTagDraft = ""

        guard !tagsToAdd.isEmpty else { return }
        let targets = selectedBooks()
        guard !targets.isEmpty else { return }

        for b in targets {
            var current = b.tags.map(normalizeTagString).filter { !$0.isEmpty }

            for t in tagsToAdd {
                if !current.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                    current.append(t)
                }
            }

            // dedupe case-insensitive, preserve order
            var out: [String] = []
            for t in current {
                if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                    out.append(t)
                }
            }
            b.tags = out
        }
        modelContext.saveWithDiagnostics()
    }

    func bulkRemovableTags() -> [String] {
        let targets = selectedBooks()
        guard !targets.isEmpty else { return [] }

        var map: [String: String] = [:] // lowercased -> display
        for b in targets {
            for t in b.tags {
                let n = normalizeTagString(t)
                let key = n.lowercased()
                guard !key.isEmpty else { continue }
                if map[key] == nil { map[key] = n }
            }
        }

        return map.values.sorted { a, b in
            a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
    }

    func bulkPrepareRemoveTagDialog() {
        let options = bulkRemovableTags()
        bulkRemoveTagOptions = options
        showingBulkRemoveTagDialog = !options.isEmpty
    }

    func bulkRemoveTag(_ tag: String) {
        let n = normalizeTagString(tag)
        guard !n.isEmpty else { return }

        let targets = selectedBooks()
        guard !targets.isEmpty else { return }

        for b in targets {
            var current = b.tags.map(normalizeTagString).filter { !$0.isEmpty }
            current.removeAll { $0.caseInsensitiveCompare(n) == .orderedSame }

            var out: [String] = []
            for t in current {
                if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                    out.append(t)
                }
            }
            b.tags = out
        }
        modelContext.saveWithDiagnostics()
    }

    func bulkAddSelectedBooks(to collection: BookCollection) {
        let targets = selectedBooks()
        guard !targets.isEmpty else { return }

        var collectionBooks = collection.booksSafe
        var didChange = false

        for b in targets {
            // Book -> Collection
            var cols = b.collectionsSafe
            if !cols.contains(where: { $0.id == collection.id }) {
                cols.append(collection)
                b.collectionsSafe = cols
                didChange = true
            }

            // Collection -> Book
            if !collectionBooks.contains(where: { $0.id == b.id }) {
                collectionBooks.append(b)
                didChange = true
            }
        }

        guard didChange else { return }
        collection.booksSafe = collectionBooks
        collection.updatedAt = Date()
        modelContext.saveWithDiagnostics()
    }

    func bulkDeleteSelectedBooks() {
        let targets = selectedBooks()
        guard !targets.isEmpty else {
            showingBulkDeleteConfirm = false
            return
        }

        for b in targets {
            if let old = b.userCoverFileName {
                UserCoverStore.delete(filename: old)
            }
            modelContext.delete(b)
        }
        modelContext.saveWithDiagnostics()
        endSelectionMode()
    }

    private func parseTagsForBulk(_ input: String) -> [String] {
        let raw = input
            .split(separator: ",")
            .map { normalizeTagString(String($0)) }
            .filter { !$0.isEmpty }

        let single = normalizeTagString(input)
        let candidates = raw.isEmpty ? ([single].filter { !$0.isEmpty }) : raw

        var out: [String] = []
        for t in candidates {
            if !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                out.append(t)
            }
        }
        return out
    }
}

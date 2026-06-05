import SwiftData
import SwiftUI

struct CollectionBookPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var collection: BookCollection

    @Query(sort: \Book.title, order: .forward)
    private var allBooks: [Book]

    @State private var searchText: String = ""
    @State private var statusFilter: CollectionDetailStatusFilter = .all
    @State private var selectedBookIDs: Set<UUID> = []

    private var existingBookIDs: Set<UUID> {
        Set(collection.booksSafe.map(\.id))
    }

    private var availableBooks: [Book] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return allBooks.filter { book in
            guard statusFilter.includes(statusRawValue: book.statusRawValue) else { return false }
            guard !query.isEmpty else { return true }

            return book.title.lowercased().localizedStandardContains(query)
                || book.author.lowercased().localizedStandardContains(query)
        }
    }

    private var selectedBooks: [Book] {
        allBooks.filter { selectedBookIDs.contains($0.id) }
    }

    private var addButtonTitle: String {
        selectedBookIDs.count == 1 ? "1 Buch hinzufügen" : "\(selectedBookIDs.count) Bücher hinzufügen"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField("Titel oder Autor suchen", text: $searchText)
                            .textFieldStyle(.plain)
                            .submitLabel(.search)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Suche löschen")
                        }
                    }
                    .padding(.vertical, 4)

                    Picker("Status", selection: $statusFilter) {
                        ForEach(CollectionDetailStatusFilter.allCases) { filter in
                            Text(filter.label).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if availableBooks.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "Keine Bücher gefunden",
                            systemImage: "magnifyingglass",
                            description: Text("Passe Suche oder Statusfilter an, um weitere Bücher zu sehen.")
                        )
                    }
                } else {
                    Section("Bücher") {
                        ForEach(availableBooks) { book in
                            CollectionBookPickerRow(
                                book: book,
                                isAlreadyInCollection: existingBookIDs.contains(book.id),
                                isSelected: selectedBookIDs.contains(book.id)
                            ) {
                                toggleSelection(for: book)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bücher hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(addButtonTitle) {
                        addSelectedBooks()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedBookIDs.isEmpty)
                }
            }
        }
    }

    private func toggleSelection(for book: Book) {
        guard !existingBookIDs.contains(book.id) else { return }

        if selectedBookIDs.contains(book.id) {
            selectedBookIDs.remove(book.id)
        } else {
            selectedBookIDs.insert(book.id)
        }
    }

    private func addSelectedBooks() {
        let targets = selectedBooks
        guard !targets.isEmpty else { return }

        let changedCount = CollectionMembershipMutation.add(targets, to: collection)
        guard changedCount > 0 else {
            dismiss()
            return
        }

        modelContext.saveWithDiagnostics()
        dismiss()
    }
}

private struct CollectionBookPickerRow: View {
    let book: Book
    let isAlreadyInCollection: Bool
    let isSelected: Bool
    let onToggle: () -> Void

    private var statusText: String {
        book.status.displayName
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selectionImageName)
                    .font(.title3.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isAlreadyInCollection ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                    .padding(.top, 3)

                VStack(alignment: .leading, spacing: 3) {
                    Text(book.title.isEmpty ? "Ohne Titel" : book.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if !book.author.isEmpty {
                        Text(book.author)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 6) {
                        Text(statusText)

                        if isAlreadyInCollection {
                            Text("•")
                            Text("schon in der Liste")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAlreadyInCollection)
        .accessibilityLabel(book.title.isEmpty ? "Ohne Titel" : book.title)
        .accessibilityHint(isAlreadyInCollection ? "Bereits in dieser Liste" : "Tippen zum Auswählen")
    }

    private var selectionImageName: String {
        if isAlreadyInCollection {
            return "checkmark.circle.fill"
        }

        return isSelected ? "checkmark.circle.fill" : "circle"
    }
}

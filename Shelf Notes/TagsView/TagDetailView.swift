import SwiftUI
import SwiftData

struct TagDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let books: [Book]

    @State private var currentTag: String
    @State private var editorMode: TagMutationEditorMode?
    @State private var deletePlan: TagDetailDeletePlan?

    init(tag: String, books: [Book]) {
        self.books = books
        _currentTag = State(initialValue: tag)
    }

    private var snapshots: [TagsDashboardBookSnapshot] {
        TagsDashboardBuilder.makeSnapshots(books: books)
    }

    private var matchingBooks: [Book] {
        let matchingIDs = Set(TagsDashboardBuilder.bookIDs(matching: currentTag, snapshots: snapshots))
        return books
            .filter { matchingIDs.contains($0.id) }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private var relatedTags: [TagsDashboardRelatedTag] {
        TagsDashboardBuilder.relatedTags(for: currentTag, snapshots: snapshots, limit: 12)
    }

    private var statusCounts: TagsDashboardStatusCounts {
        var counts = TagsDashboardStatusCounts()
        for book in matchingBooks {
            counts.increment(statusRawValue: book.statusRawValue)
        }
        return counts
    }

    var body: some View {
        List {
            Section {
                TagDetailHeaderCard(
                    tag: currentTag,
                    bookCount: matchingBooks.count,
                    statusCounts: statusCounts
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }

            Section {
                NavigationLink {
                    LibraryView(initialTag: currentTag)
                } label: {
                    Label("In der Bibliothek öffnen", systemImage: "books.vertical")
                }
            }

            Section("Tag verwalten") {
                Button {
                    editorMode = .rename(sourceTag: currentTag)
                } label: {
                    Label("Umbenennen", systemImage: "pencil")
                }

                Button {
                    editorMode = .merge(sourceTag: currentTag)
                } label: {
                    Label("Zusammenführen", systemImage: "arrow.triangle.merge")
                }

                Button(role: .destructive) {
                    prepareDelete()
                } label: {
                    Label("Von allen Büchern entfernen", systemImage: "trash")
                }
            }

            if !relatedTags.isEmpty {
                Section("Verwandte Tags") {
                    ForEach(relatedTags) { relatedTag in
                        NavigationLink {
                            TagDetailView(tag: relatedTag.tag, books: books)
                        } label: {
                            HStack {
                                Text("#\(relatedTag.tag)")
                                Spacer()
                                Text("\(relatedTag.sharedBookCount)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }

            Section(matchingBooks.count == 1 ? "Buch" : "Bücher") {
                if matchingBooks.isEmpty {
                    ContentUnavailableView(
                        "Keine Bücher gefunden",
                        systemImage: "tag.slash",
                        description: Text("Dieses Tag ist aktuell keinem Buch zugeordnet.")
                    )
                } else {
                    ForEach(matchingBooks) { book in
                        NavigationLink {
                            BookDetailView(book: book)
                        } label: {
                            BookRowView(book: book)
                        }
                    }
                }
            }
        }
        .navigationTitle("#\(currentTag)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        editorMode = .rename(sourceTag: currentTag)
                    } label: {
                        Label("Umbenennen", systemImage: "pencil")
                    }

                    Button {
                        editorMode = .merge(sourceTag: currentTag)
                    } label: {
                        Label("Zusammenführen", systemImage: "arrow.triangle.merge")
                    }

                    Button(role: .destructive) {
                        prepareDelete()
                    } label: {
                        Label("Entfernen", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $editorMode) { mode in
            TagMutationEditorSheet(mode: mode, books: books) { result in
                applyMutation(result)
            }
        }
        .alert(
            "Tag entfernen?",
            isPresented: isDeleteAlertPresented,
            presenting: deletePlan
        ) { plan in
            Button("Entfernen", role: .destructive) {
                applyMutation(plan.result)
                deletePlan = nil
                dismiss()
            }

            Button("Abbrechen", role: .cancel) {
                deletePlan = nil
            }
        } message: { plan in
            Text("#\(plan.tag) wird von \(plan.result.changedBooksCount) Büchern entfernt.")
        }
    }

    private var isDeleteAlertPresented: Binding<Bool> {
        Binding(
            get: { deletePlan != nil },
            set: { isPresented in
                if !isPresented {
                    deletePlan = nil
                }
            }
        )
    }

    private func prepareDelete() {
        let result = TagLibraryMutation.delete(
            tag: currentTag,
            in: TagLibraryMutation.makeSnapshots(books: books)
        )
        let normalizedTag = normalizeTagString(currentTag)
        guard !normalizedTag.isEmpty, result.hasChanges else { return }
        deletePlan = TagDetailDeletePlan(tag: normalizedTag, result: result)
    }

    private func applyMutation(_ result: TagLibraryMutationResult) {
        guard result.hasChanges else { return }

        withAnimation(.snappy) {
            _ = TagLibraryMutation.apply(result, to: books)
            if let targetTag = result.targetTag, !targetTag.isEmpty {
                currentTag = targetTag
            }
        }

        _ = modelContext.saveWithDiagnostics()
    }
}

private struct TagDetailDeletePlan: Identifiable, Hashable {
    let tag: String
    let result: TagLibraryMutationResult

    var id: String {
        tag.lowercased()
    }
}

struct UntaggedBooksView: View {
    let books: [Book]

    private var untaggedBooks: [Book] {
        let snapshots = TagsDashboardBuilder.makeSnapshots(books: books)
        let untaggedIDs = Set(snapshots.filter(TagsDashboardBuilder.isUntagged).map(\.id))

        return books
            .filter { untaggedIDs.contains($0.id) }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    var body: some View {
        List {
            if untaggedBooks.isEmpty {
                ContentUnavailableView(
                    "Alles sauber getaggt",
                    systemImage: "checkmark.seal",
                    description: Text("Aktuell gibt es keine Bücher ohne Tags.")
                )
            } else {
                Section("Bücher ohne Tags") {
                    ForEach(untaggedBooks) { book in
                        NavigationLink {
                            BookDetailView(book: book)
                        } label: {
                            BookRowView(book: book)
                        }
                    }
                }
            }
        }
        .navigationTitle("Ohne Tags")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TagDetailHeaderCard: View {
    let tag: String
    let bookCount: Int
    let statusCounts: TagsDashboardStatusCounts

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "tag.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(tag)")
                        .font(.title2.weight(.bold))
                        .lineLimit(2)

                    Text(statusCounts.compactLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                TagDetailMetric(title: "Bücher", value: bookCount, systemImage: "books.vertical")
                TagDetailMetric(title: "Gelesen", value: statusCounts.finished, systemImage: "checkmark.circle")
                TagDetailMetric(title: "Aktiv", value: statusCounts.reading, systemImage: "book")
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct TagDetailMetric: View {
    let title: String
    let value: Int
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(value)")
                .font(.headline)
                .monospacedDigit()

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

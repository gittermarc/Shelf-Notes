//
//  TagsView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Split from ContentView.swift on 05.01.26.
//

import SwiftUI
import SwiftData

// MARK: - Tags Tab
struct TagsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.createdAt, order: .reverse) private var books: [Book]
    @State private var searchText: String = ""
    @State private var sortMode: TagsDashboardSortMode = .mostUsed
    @State private var editorMode: TagMutationEditorMode?
    @State private var deletePlan: TagDeletePlan?

    var body: some View {
        let dashboard = TagsDashboardBuilder.build(
            snapshots: TagsDashboardBuilder.makeSnapshots(books: books)
        )
        let visibleEntries = TagsDashboardBuilder.filteredEntries(
            dashboard.entries,
            searchText: searchText,
            sortMode: sortMode
        )

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TagsDashboardHero(summary: dashboard.summary)

                    if dashboard.summary.untaggedBooksCount > 0 {
                        NavigationLink {
                            UntaggedBooksView(books: books)
                        } label: {
                            UntaggedBooksCallout(count: dashboard.summary.untaggedBooksCount)
                        }
                        .buttonStyle(.plain)
                    }

                    if dashboard.entries.isEmpty {
                        TagsEmptyState(hasBooks: !books.isEmpty)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    } else {
                        TagsExplorerControls(sortMode: $sortMode)

                        if visibleEntries.isEmpty {
                            ContentUnavailableView(
                                "Keine Tags gefunden",
                                systemImage: "magnifyingglass",
                                description: Text("Für deine Suche gibt es aktuell keine passenden Tags.")
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                        } else {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 260), spacing: 12)],
                                alignment: .leading,
                                spacing: 12
                            ) {
                                ForEach(visibleEntries) { entry in
                                    NavigationLink {
                                        TagDetailView(tag: entry.tag, books: books)
                                    } label: {
                                        TagCardView(entry: entry)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        tagActionsMenu(for: entry.tag)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .navigationTitle("Tags")
            .searchable(text: $searchText, prompt: "Tags suchen")
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
                }

                Button("Abbrechen", role: .cancel) {
                    deletePlan = nil
                }
            } message: { plan in
                Text("#\(plan.tag) wird von \(plan.result.changedBooksCount) Büchern entfernt.")
            }
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

    @ViewBuilder
    private func tagActionsMenu(for tag: String) -> some View {
        Button {
            editorMode = .rename(sourceTag: tag)
        } label: {
            Label("Umbenennen", systemImage: "pencil")
        }

        Button {
            editorMode = .merge(sourceTag: tag)
        } label: {
            Label("Zusammenführen", systemImage: "arrow.triangle.merge")
        }

        Button(role: .destructive) {
            prepareDelete(tag: tag)
        } label: {
            Label("Von allen Büchern entfernen", systemImage: "trash")
        }
    }

    private func prepareDelete(tag: String) {
        let result = TagLibraryMutation.delete(
            tag: tag,
            in: TagLibraryMutation.makeSnapshots(books: books)
        )
        let normalizedTag = normalizeTagString(tag)
        guard !normalizedTag.isEmpty, result.hasChanges else { return }
        deletePlan = TagDeletePlan(tag: normalizedTag, result: result)
    }

    private func applyMutation(_ result: TagLibraryMutationResult) {
        guard result.hasChanges else { return }
        withAnimation(.snappy) {
            _ = TagLibraryMutation.apply(result, to: books)
        }
        _ = modelContext.saveWithDiagnostics()
    }
}

private struct TagDeletePlan: Identifiable, Hashable {
    let tag: String
    let result: TagLibraryMutationResult

    var id: String {
        tag.lowercased()
    }
}

private struct TagsDashboardHero: View {
    let summary: TagsDashboardSummary

    private var topTagLabel: String {
        guard let topTag = summary.topTag else { return "Noch keiner" }
        return "#\(topTag.tag)"
    }

    private var topTagDetail: String {
        guard let topTag = summary.topTag else { return "Füge Tags bei Büchern hinzu" }
        return "\(topTag.count) " + (topTag.count == 1 ? "Buch" : "Bücher")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "tag.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Tag Explorer")
                        .font(.title2.weight(.bold))

                    Text("Ordne deine Bibliothek nach Themen, Stimmungen, Genres und allem, was für dich beim Lesen zählt.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 142), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                TagsHeroMetric(
                    title: "Tags",
                    value: "\(summary.totalTags)",
                    detail: "gesamt",
                    systemImage: "tag"
                )

                TagsHeroMetric(
                    title: "Getaggt",
                    value: "\(summary.taggedBooksCount)",
                    detail: "Bücher",
                    systemImage: "books.vertical"
                )

                TagsHeroMetric(
                    title: "Ohne Tags",
                    value: "\(summary.untaggedBooksCount)",
                    detail: "Bücher",
                    systemImage: "tag.slash"
                )

                TagsHeroMetric(
                    title: "Top Tag",
                    value: topTagLabel,
                    detail: topTagDetail,
                    systemImage: "star"
                )
            }
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct TagsHeroMetric: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .monospacedDigit()

            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct TagsExplorerControls: View {
    @Binding var sortMode: TagsDashboardSortMode

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags durchsuchen")
                .font(.headline)

            Picker("Sortierung", selection: $sortMode) {
                ForEach(TagsDashboardSortMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

private struct UntaggedBooksCallout: View {
    let count: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tag.slash")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(10)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("\(count) " + (count == 1 ? "Buch ohne Tags" : "Bücher ohne Tags"))
                    .font(.subheadline.weight(.semibold))

                Text("Guter Einstieg, um deine Bibliothek nachträglich sauberer zu organisieren.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct TagsEmptyState: View {
    let hasBooks: Bool

    var body: some View {
        ContentUnavailableView(
            "Noch keine Tags",
            systemImage: "tag",
            description: Text(description)
        )
    }

    private var description: String {
        if hasBooks {
            return "Öffne ein Buch und füge Tags hinzu. Danach wird dieser Bereich zum Explorer für deine Bibliothek."
        }

        return "Füge zuerst Bücher hinzu. Tags werden sichtbar, sobald du deine Bücher organisierst."
    }
}

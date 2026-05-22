import SwiftUI

struct TagDetailView: View {
    let tag: String
    let books: [Book]

    private var snapshots: [TagsDashboardBookSnapshot] {
        TagsDashboardBuilder.makeSnapshots(books: books)
    }

    private var matchingBooks: [Book] {
        let matchingIDs = Set(TagsDashboardBuilder.bookIDs(matching: tag, snapshots: snapshots))
        return books
            .filter { matchingIDs.contains($0.id) }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private var relatedTags: [TagsDashboardRelatedTag] {
        TagsDashboardBuilder.relatedTags(for: tag, snapshots: snapshots, limit: 12)
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
                    tag: tag,
                    bookCount: matchingBooks.count,
                    statusCounts: statusCounts
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }

            Section {
                NavigationLink {
                    LibraryView(initialTag: tag)
                } label: {
                    Label("In der Bibliothek öffnen", systemImage: "books.vertical")
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
        .navigationTitle("#\(tag)")
        .navigationBarTitleDisplayMode(.inline)
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

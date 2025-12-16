//
//  BookImportView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//

import SwiftUI

struct ImportedBook {
    let googleVolumeID: String
    let title: String
    let author: String
    let isbn13: String?
    let thumbnailURL: String?
    let publisher: String?
    let publishedDate: String?
    let pageCount: Int?
    let language: String?
    let categories: [String]
    let description: String
}

struct BookImportView: View {
    @Environment(\.dismiss) private var dismiss
    let onPick: (ImportedBook) -> Void

    // Persisted search history (simple JSON array of strings)
    @AppStorage("gb_search_history_json") private var historyJSON: String = "[]"

    @State private var queryText: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var results: [GoogleBookVolume] = []

    @FocusState private var searchFocused: Bool

    private let maxHistoryItems = 10

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    searchSection

                    if isLoading {
                        ProgressView("Suche läuft …")
                            .padding(.top, 4)
                    }

                    if let errorMessage {
                        errorCard(errorMessage)
                    }

                    if results.isEmpty, !isLoading, errorMessage == nil {
                        emptyState
                            .padding(.top, 8)
                    } else {
                        resultsList
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .navigationTitle("Google Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .onAppear {
                // Don’t auto-search. Just focus if empty.
                if queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        searchFocused = true
                    }
                }
            }
        }
    }

    // MARK: - UI

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suche nach Titel, Autor oder ISBN")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            searchBar

            if !history.isEmpty {
                historyChips
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Titel, Autor oder ISBN …", text: $queryText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .focused($searchFocused)
                    .onSubmit { Task { await search() } }

                if !queryText.isEmpty {
                    Button {
                        queryText = ""
                        errorMessage = nil
                        results = []
                        searchFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Suche löschen")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Button {
                Task { await search() }
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
            }
            .disabled(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            .buttonStyle(.plain)
            .accessibilityLabel("Suchen")
        }
    }

    private var historyChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Letzte Suchen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Löschen") {
                    clearHistory()
                }
                .font(.caption)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(history, id: \.self) { term in
                        Button {
                            queryText = term
                            Task { await search() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.caption2)
                                Text(term)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var resultsList: some View {
        LazyVStack(spacing: 10) {
            ForEach(results) { volume in
                Button {
                    pick(volume)
                } label: {
                    ResultCard(volume: volume)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "books.vertical")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)

            Text(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Starte eine Suche" : "Keine Treffer")
                .font(.headline)

            Text(queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                 ? "Gib z.B. „Stephen King“ oder eine ISBN ein."
                 : "Versuch’s mit einem anderen Begriff oder nur dem Nachnamen.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Fehler")
                    .font(.headline)
            }
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Search

    private func normalizedQuery(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.filter(\.isNumber)
        if digits.count == 10 || digits.count == 13 {
            return "isbn:\(digits)"
        }
        return trimmed
    }

    private func search() async {
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Save to history (dedup + most recent first)
        addToHistory(trimmed)

        await MainActor.run {
            errorMessage = nil
            results = []
            isLoading = true
        }

        do {
            // Keep your current client API (debug-capable), but we ignore debug UI.
            let res = try await GoogleBooksClient.shared.searchVolumesWithDebug(query: normalizedQuery(trimmed), maxResults: 20)

            await MainActor.run {
                results = res.volumes
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    // MARK: - Pick

    private func pick(_ volume: GoogleBookVolume) {
        let info = volume.volumeInfo

        let imported = ImportedBook(
            googleVolumeID: volume.id,
            title: volume.bestTitle,
            author: volume.bestAuthors,
            isbn13: volume.isbn13,
            thumbnailURL: volume.bestThumbnailURLString,
            publisher: info.publisher,
            publishedDate: info.publishedDate,
            pageCount: info.pageCount,
            language: info.language,
            categories: info.categories ?? [],
            description: info.description ?? ""
        )

        onPick(imported)
        dismiss()
    }

    // MARK: - History persistence

    private var history: [String] {
        guard let data = historyJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }

    private func saveHistory(_ items: [String]) {
        let trimmed = Array(items.prefix(maxHistoryItems))
        if let data = try? JSONEncoder().encode(trimmed),
           let json = String(data: data, encoding: .utf8) {
            historyJSON = json
        }
    }

    private func addToHistory(_ term: String) {
        let normalized = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        var items = history

        // Remove existing (case-insensitive) to dedupe
        items.removeAll { $0.compare(normalized, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }

        items.insert(normalized, at: 0)
        saveHistory(items)
    }

    private func clearHistory() {
        saveHistory([])
    }
}

// MARK: - Result Card UI

private struct ResultCard: View {
    let volume: GoogleBookVolume

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            cover

            VStack(alignment: .leading, spacing: 6) {
                Text(volume.bestTitle)
                    .font(.headline)
                    .lineLimit(2)

                if !volume.bestAuthors.isEmpty {
                    Text(volume.bestAuthors)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    if let isbn = volume.isbn13 {
                        metaPill(text: "ISBN \(isbn)", systemImage: "barcode")
                    }

                    if let year = volume.volumeInfo.publishedDate, !year.isEmpty {
                        metaPill(text: year, systemImage: "calendar")
                    }
                }
                .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var cover: some View {
        if let urlString = volume.bestThumbnailURLString,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 10)
                    .opacity(0.12)
                    .overlay(ProgressView())
            }
            .frame(width: 54, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            RoundedRectangle(cornerRadius: 10)
                .frame(width: 54, height: 78)
                .opacity(0.12)
                .overlay(Image(systemName: "book").opacity(0.6))
        }
    }

    private func metaPill(text: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .foregroundStyle(.secondary)
    }
}

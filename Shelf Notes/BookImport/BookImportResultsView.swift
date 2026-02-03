//
/*  BookImportResultsView.swift
    Shelf Notes

    Results list + meta + empty/error states for BookImportView.
*/

import SwiftUI

struct BookImportResultsView: View {
    @ObservedObject var vm: BookImportViewModel

    let onDetails: (GoogleBookVolume) -> Void
    let onQuickAdd: (GoogleBookVolume, ReadingStatus) -> Void

    var body: some View {
        VStack(spacing: 12) {
            if vm.isLoading {
                ProgressView("Suche läuft …")
                    .padding(.top, 4)
            }

            if let error = vm.errorMessage {
                errorCard(error)
            }

            if vm.results.isEmpty, !vm.isLoading, vm.errorMessage == nil {
                emptyState
                    .padding(.top, 8)
            } else {
                if !vm.results.isEmpty {
                    resultsMeta
                        .padding(.top, 6)
                }

                resultsList
                    .padding(.top, 4)
            }
        }
    }

    private var resultsMeta: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("Zeige \(vm.resultsCount)\(vm.totalItemsText) Ergebnisse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(vm.activeFiltersSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if !vm.effectiveQueryForUI.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Google-Query:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(vm.effectiveQueryForUI)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(4)
                }
            }

            if let dbg = vm.lastRequestDebugSummary {
                Text(dbg)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resultsList: some View {
        LazyVStack(spacing: 10) {
            ForEach(vm.results) { volume in
                let already = vm.isAlreadyAdded(volume)
                BookImportResultCard(
                    volume: volume,
                    isAlreadyInLibrary: already,
                    onDetails: { onDetails(volume) },
                    onQuickAdd: { status in
                        onQuickAdd(volume, status)
                    }
                )
                .onAppear {
                    Task { await vm.handleResultAppeared(volumeID: volume.id) }
                }
            }

            if vm.shouldShowLoadMore {
                loadMoreRow
                    .padding(.top, 6)
            }
        }
    }

    private var loadMoreRow: some View {
        HStack {
            Spacer()
            if vm.isLoadingMore {
                ProgressView()
                    .padding(.vertical, 10)
            } else {
                Button {
                    Task { await vm.loadMore() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                        Text("Mehr laden")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    private var emptyState: some View {
        let trimmedQuery = vm.queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasQuery = !trimmedQuery.isEmpty
        let isLocalFilterEmpty = vm.isEmptyBecauseOfLocalFilters

        return VStack(spacing: 10) {
            Image(systemName: "books.vertical")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)

            Text(!hasQuery ? "Starte eine Suche" : (isLocalFilterEmpty ? "Keine Treffer – Filter blenden alles aus" : "Keine Treffer bei Google"))
                .font(.headline)

            Text(!hasQuery
                 ? "Gib z.B. „Stephen King“ oder eine ISBN ein."
                 : (isLocalFilterEmpty
                    ? "Google hat Treffer geliefert, aber deine lokalen Qualitätsfilter lassen am Ende 0 übrig."
                    : "Google meldet 0 Treffer. Prüfe ggf. Filter oder probier’s mit einem anderen Begriff."))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)

            if hasQuery {
                VStack(spacing: 8) {
                    Button {
                        vm.resetFiltersToDefaults()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Filter zurücksetzen")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    if isLocalFilterEmpty, !vm.activeLocalQualityFilters.isEmpty {
                        Text("Aktive lokale Filter: \(vm.activeLocalQualityFilters.joined(separator: " • "))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                Divider()
                    .padding(.top, 6)

                emptyStateDiagnostics
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }


    private var emptyStateDiagnostics: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(vm.activeFiltersSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if !vm.effectiveQueryForUI.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Google-Query:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(vm.effectiveQueryForUI)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(6)
                }
                .padding(.top, 2)
            }

            if vm.isEmptyBecauseOfLocalFilters {
                Text("Google geladen: \(vm.fetchedVolumesCount) • angezeigt: 0")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let dbg = vm.lastRequestDebugSummary {
                Text(dbg)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("totalItems: \(vm.lastReportedTotalItems)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let hasError = vm.lastResponseHasErrorObject {
                Text("error: \(hasError ? "ja" : "nein")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let url = vm.lastRequestURLSanitized {
                VStack(alignment: .leading, spacing: 2) {
                    Text("URL (ohne Key):")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(url)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(5)
                }
                .padding(.top, 2)
            }

            if let snippet = vm.lastResponseSnippet, !snippet.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Antwort (Snippet):")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(snippet)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(6)
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
}

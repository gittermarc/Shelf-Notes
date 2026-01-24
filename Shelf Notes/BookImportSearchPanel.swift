//
/*  BookImportSearchPanel.swift
    Shelf Notes

    Top panel (search field + filters + history chips) for BookImportView.
*/

import SwiftUI

struct BookImportSearchPanel: View {
    @ObservedObject var vm: BookImportViewModel
    let searchFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Suche nach Titel, Autor oder ISBN")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            searchBar

            filtersSection

            if !vm.history.isEmpty {
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

                TextField("Titel, Autor oder ISBN …", text: $vm.queryText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .focused(searchFocused)
                    .onSubmit { Task { await vm.search() } }

                if !vm.queryText.isEmpty {
                    Button {
                        vm.clearQueryAndResults()
                        searchFocused.wrappedValue = true
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
                Task { await vm.search() }
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
            }
            .disabled(vm.queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading || vm.isLoadingMore)
            .buttonStyle(.plain)
            .accessibilityLabel("Suchen")
        }
    }

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.snappy) { vm.showFilters.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("Filter & Qualität")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: vm.showFilters ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if vm.showFilters {
                VStack(alignment: .leading, spacing: 12) {
                    // API filters
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Filter (Google)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            Picker("Sprache", selection: $vm.language) {
                                ForEach(BookImportLanguageOption.allCases) { opt in
                                    Text(opt.title).tag(opt)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Sortierung", selection: $vm.orderBy) {
                                ForEach(GoogleBooksOrderBy.allCases) { opt in
                                    Text(opt.title).tag(opt)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Typ", selection: $vm.apiFilter) {
                                ForEach(GoogleBooksFilter.allCases) { opt in
                                    Text(opt.title).tag(opt)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    Divider()

                    // Local quality filters
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Qualität (lokal)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Toggle("Nur mit Cover", isOn: $vm.onlyWithCover)
                        Toggle("Nur mit ISBN", isOn: $vm.onlyWithISBN)
                        Toggle("Bereits in Bibliothek ausblenden", isOn: $vm.hideAlreadyInLibrary)
                    }
                    .font(.subheadline)
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var historyChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Letzte Suchen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Löschen") { vm.clearHistory() }
                    .font(.caption)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.history, id: \.self) { term in
                        Button {
                            Task { await vm.useHistoryTerm(term) }
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
}

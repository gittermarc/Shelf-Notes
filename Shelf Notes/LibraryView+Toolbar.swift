//
//  LibraryView+Toolbar.swift
//  Shelf Notes
//
//  Extracted from LibraryView.swift to reduce file size and improve maintainability.
//

import SwiftUI

extension LibraryView {

    var libraryToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {

            Menu {
                // --- View mode ---
                Section("Ansicht") {
                    Picker("Layout", selection: Binding(
                        get: { libraryLayoutMode },
                        set: { libraryLayoutModeRaw = $0.rawValue }
                    )) {
                        ForEach(LibraryLayoutModeOption.allCases) { opt in
                            Label(opt.title, systemImage: opt.systemImage)
                                .tag(opt)
                        }
                    }
                }

                // --- Sort ---
                Section("Sortieren") {
                    Picker("Feld", selection: Binding(
                        get: { sortField.rawValue },
                        set: { sortFieldRaw = $0 }
                    )) {
                        ForEach(SortField.allCases) { f in
                            Text(f.rawValue).tag(f.rawValue)
                        }
                    }

                    Toggle(isOn: $sortAscending) {
                        Text(sortAscendingLabel)
                    }
                }

                // --- Filter ---
                Section("Filter") {
                    Picker("Status", selection: Binding(
                        get: { selectedStatus?.rawValue ?? "__all__" },
                        set: { newValue in
                            if newValue == "__all__" {
                                selectedStatus = nil
                            } else {
                                selectedStatus = ReadingStatus.fromPersisted(newValue)
                            }
                        }
                    )) {
                        Text("Alle").tag("__all__")
                        ForEach(ReadingStatus.allCases) { status in
                            Text(status.displayName).tag(status.rawValue)
                        }
                    }

                    Toggle("Nur mit Notizen", isOn: $onlyWithNotes)

                    if selectedTag != nil || selectedStatus != nil || onlyWithNotes || !searchText.isEmpty {
                        Button("Filter zurücksetzen") {
                            withAnimation {
                                selectedTag = nil
                                selectedStatus = nil
                                onlyWithNotes = false
                                searchText = ""
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .accessibilityLabel("Filter & Sortierung")

            Button {
                showingAddSheet = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Buch hinzufügen")
        }
    }

    var sortAscendingLabel: String {
        switch sortField {
        case .createdAt, .readDate:
            return sortAscending ? "Alt → Neu" : "Neu → Alt"
        case .rating:
            return sortAscending ? "Niedrig → Hoch" : "Hoch → Niedrig"
        case .title, .author:
            return sortAscending ? "A → Z" : "Z → A"
        }
    }
}

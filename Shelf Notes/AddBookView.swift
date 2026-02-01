//
//  AddBookView.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 11.12.25.
//  Split from ContentView.swift on 05.01.26.
//  Refactored into smaller building blocks on 31.01.26.
//

import SwiftUI
import SwiftData

// MARK: - Add Book
struct AddBookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject var vm = AddBookViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    heroCard
                    importActionsCard
                    if vm.shouldShowDetailsCard {
                        basicsCard
                    }

                    if vm.hasAnyImportedMetadata {
                        metadataCard
                    }

                    if !vm.trimmedDescription.isEmpty {
                        descriptionCard
                    }

                    if vm.hasAnyLinks {
                        linksCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Buch hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveAndDismiss()
                    }
                    .disabled(vm.trimmedTitle.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                primaryActionBar
            }
        }
        .sheet(item: $vm.activeSheet, onDismiss: handleSheetDismiss) { sheet in
            switch sheet {
            case .importBooks(let initialQuery):
                BookImportView(
                    onPick: { imported in
                        vm.applyImportedBook(imported)
                    },
                    initialQuery: initialQuery,
                    autoSearchOnAppear: true,
                    onQuickAddHappened: {
                        vm.quickAddActive = true
                    },
                    onQuickAddActiveChanged: { isActive in
                        vm.quickAddActive = isActive
                    }
                )

            case .scanner:
                BarcodeScannerSheet { isbn in
                    vm.queueImportAfterDismiss(query: isbn)
                }

            case .inspiration:
                InspirationSeedPickerView(onSelect: { query in
                    vm.queueImportAfterDismiss(query: query)
                })

            case .manualAdd:
                ManualBookAddSheet(onBookAdded: {
                    // Manual import is a "Notfall" flow – after saving, we can close the whole add screen.
                    dismiss()
                })
            }
        }
    }


    private var primaryActionBar: some View {
        VStack(spacing: 10) {
            Divider()

            Button {
                saveAndDismiss()
            } label: {
                Label("In Bibliothek aufnehmen", systemImage: "tray.and.arrow.down.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(vm.trimmedTitle.isEmpty)

            if vm.trimmedTitle.isEmpty {
                Text("Titel fehlt noch – ohne Titel landet das Buch sonst als \"Neues Buch\" in deiner Bibliothek. (Und das wäre wirklich… mutig.)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }
    private func handleSheetDismiss() {
        let outcome = vm.handleSheetDismiss()
        if outcome.shouldDismissAddBookView {
            dismiss()
        }
    }

    private func saveAndDismiss() {
        vm.save(modelContext: modelContext)
        dismiss()
    }
}

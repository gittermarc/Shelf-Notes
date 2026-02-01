//
/*  BookImportView.swift
    Shelf Notes

    Google Books import sheet.
    Refactored: heavy UI + logic moved into smaller files (ViewModel + subviews).
*/

import SwiftUI
import SwiftData

struct BookImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var existingBooks: [Book]

    let onPick: (ImportedBook) -> Void

    // ✅ Optional: prefill search (e.g. ISBN from barcode scan)
    var initialQuery: String? = nil
    var autoSearchOnAppear: Bool = true

    /// Legacy: called once on the first Quick-Add in this sheet session
    var onQuickAddHappened: (() -> Void)? = nil

    /// true once there is at least 1 Quick-Add in this session (and false again when undone)
    var onQuickAddActiveChanged: ((Bool) -> Void)? = nil

    @StateObject private var vm: BookImportViewModel
    @FocusState private var searchFocused: Bool

    @State private var didApplyDefaultLanguagePreference: Bool = false

    init(
        onPick: @escaping (ImportedBook) -> Void,
        initialQuery: String? = nil,
        autoSearchOnAppear: Bool = true,
        onQuickAddHappened: (() -> Void)? = nil,
        onQuickAddActiveChanged: ((Bool) -> Void)? = nil
    ) {
        self.onPick = onPick
        self.initialQuery = initialQuery
        self.autoSearchOnAppear = autoSearchOnAppear
        self.onQuickAddHappened = onQuickAddHappened
        self.onQuickAddActiveChanged = onQuickAddActiveChanged

        _vm = StateObject(wrappedValue: BookImportViewModel(
            onQuickAddHappened: onQuickAddHappened,
            onQuickAddActiveChanged: onQuickAddActiveChanged
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 12) {
                        BookImportSearchPanel(vm: vm, searchFocused: $searchFocused)

                        BookImportResultsView(
                            vm: vm,
                            onDetails: { volume in
                                pick(volume)
                            },
                            onQuickAdd: { volume, status in
                                Task { await vm.quickAdd(volume, status: status, modelContext: modelContext) }
                            }
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }

                if let payload = vm.undoPayload {
                    BookImportUndoToastView(
                        title: payload.title,
                        status: payload.status,
                        thumbnailURL: payload.thumbnailURL,
                        onUndo: {
                            Task { await vm.undoLastAdd(payload, modelContext: modelContext) }
                        },
                        onDismiss: {
                            vm.hideUndo()
                        }
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Google Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .onAppear {
                if !didApplyDefaultLanguagePreference {
                    vm.applyDefaultLanguagePreferenceIfNeeded()
                    didApplyDefaultLanguagePreference = true
                }

                vm.updateExistingBooks(existingBooks)

                // 1) initialQuery => auto-search
                if autoSearchOnAppear,
                   let initialQuery,
                   !initialQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   vm.queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    vm.queryText = initialQuery
                    Task { await vm.search() }
                    return
                }

                // 2) otherwise focus search field
                if vm.queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        searchFocused = true
                    }
                }
            }
            .onChange(of: existingBooks) { _, newValue in
                vm.updateExistingBooks(newValue)
            }
            .onDisappear {
                vm.cancelTasks()
            }
        }
    }

    // MARK: - Pick (Detail flow)

    private func pick(_ volume: GoogleBookVolume) {
        onPick(ImportedBook(volume: volume))
        dismiss()
    }
}

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct BookNotesEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEditorFocused: Bool

    let book: Book
    let initialText: String
    let onSave: (String) -> Void

    @State private var draftText: String
    @State private var showingDiscardDialog = false
    @State private var showingClearDialog = false

    init(book: Book, initialText: String, onSave: @escaping (String) -> Void) {
        self.book = book
        self.initialText = initialText
        self.onSave = onSave
        _draftText = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    BookNotesEditorHeader(book: book, metrics: metrics)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Deine Gedanken, Zitate und Eindrücke")
                            .font(.subheadline.weight(.semibold))

                        Text(metrics.summaryLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    BookNotesPromptChips(onApply: applyTemplate)

                    editorCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 18)
            }
            .background(sheetBackground)
            .navigationTitle("Notiz")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(hasUnsavedChanges)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") {
                        handleCloseTapped()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Speichern") {
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                }

                BookNotesEditorToolbar(
                    onApply: applyTemplate,
                    onClear: { showingClearDialog = true }
                )
            }
            .confirmationDialog(
                "Änderungen verwerfen?",
                isPresented: $showingDiscardDialog,
                titleVisibility: .visible
            ) {
                Button("Änderungen verwerfen", role: .destructive) {
                    dismiss()
                }
                Button("Speichern") {
                    saveAndDismiss()
                }
                Button("Weiter bearbeiten", role: .cancel) { }
            } message: {
                Text("Deine Änderungen sind noch nicht gespeichert.")
            }
            .confirmationDialog(
                "Notiz leeren?",
                isPresented: $showingClearDialog,
                titleVisibility: .visible
            ) {
                Button("Leeren", role: .destructive) {
                    draftText = ""
                    isEditorFocused = true
                }
                Button("Abbrechen", role: .cancel) { }
            } message: {
                Text("Der aktuelle Entwurf wird entfernt.")
            }
            .onAppear {
                isEditorFocused = true
            }
        }
    }

    private var metrics: BookNotesMetrics {
        BookNotesMetrics(text: draftText)
    }

    private var hasUnsavedChanges: Bool {
        draftText != initialText
    }

    private var sheetBackground: some View {
        #if canImport(UIKit)
        Color(uiColor: .systemGroupedBackground)
        #else
        Color(.systemBackground)
        #endif
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
                    )

                TextEditor(text: $draftText)
                    .focused($isEditorFocused)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .frame(minHeight: 260)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)

                if draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Was hat dich überrascht? Was willst du dir merken? Ein Zitat, ein Gedanke, ein kleiner Rant – alles erlaubt.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }

            Text("Tipp: Über die Chips und die Tastaturleiste kannst du dir kleine Strukturen einfügen lassen.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func handleCloseTapped() {
        if hasUnsavedChanges {
            showingDiscardDialog = true
        } else {
            dismiss()
        }
    }

    private func applyTemplate(_ template: BookNotesTemplate) {
        draftText = BookNotesInsertion.applying(template: template, to: draftText)
        isEditorFocused = true
    }

    private func saveAndDismiss() {
        onSave(draftText)
        dismiss()
    }
}

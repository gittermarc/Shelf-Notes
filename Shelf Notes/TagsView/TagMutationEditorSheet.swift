import SwiftUI

enum TagMutationEditorMode: Identifiable, Hashable {
    case rename(sourceTag: String)
    case merge(sourceTag: String)

    var id: String {
        switch self {
        case .rename(let sourceTag):
            return "rename-\(sourceTag.lowercased())"
        case .merge(let sourceTag):
            return "merge-\(sourceTag.lowercased())"
        }
    }

    var sourceTag: String {
        switch self {
        case .rename(let sourceTag), .merge(let sourceTag):
            return sourceTag
        }
    }

    var title: String {
        switch self {
        case .rename:
            return "Tag umbenennen"
        case .merge:
            return "Tags zusammenführen"
        }
    }

    var fieldTitle: String {
        switch self {
        case .rename:
            return "Neuer Name"
        case .merge:
            return "Ziel-Tag"
        }
    }

    var actionTitle: String {
        switch self {
        case .rename:
            return "Umbenennen"
        case .merge:
            return "Zusammenführen"
        }
    }

    func result(targetTag: String, books: [Book]) -> TagLibraryMutationResult {
        let snapshots = TagLibraryMutation.makeSnapshots(books: books)

        switch self {
        case .rename(let sourceTag):
            return TagLibraryMutation.rename(tag: sourceTag, to: targetTag, in: snapshots)
        case .merge(let sourceTag):
            return TagLibraryMutation.merge(sourceTags: [sourceTag], into: targetTag, in: snapshots)
        }
    }
}

struct TagMutationEditorSheet: View {
    let mode: TagMutationEditorMode
    let books: [Book]
    let onApply: (TagLibraryMutationResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: String

    init(
        mode: TagMutationEditorMode,
        books: [Book],
        onApply: @escaping (TagLibraryMutationResult) -> Void
    ) {
        self.mode = mode
        self.books = books
        self.onApply = onApply

        switch mode {
        case .rename(let sourceTag):
            _draft = State(initialValue: sourceTag)
        case .merge:
            _draft = State(initialValue: "")
        }
    }

    private var normalizedTarget: String {
        normalizeTagString(draft)
    }

    private var previewResult: TagLibraryMutationResult {
        mode.result(targetTag: normalizedTarget, books: books)
    }

    private var canApply: Bool {
        !normalizedTarget.isEmpty && previewResult.hasChanges
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Ausgangs-Tag", value: "#\(mode.sourceTag)")
                    TextField(mode.fieldTitle, text: $draft)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                } footer: {
                    Text(helpText)
                }

                Section("Vorschau") {
                    LabeledContent("Ziel", value: normalizedTarget.isEmpty ? "Noch leer" : "#\(normalizedTarget)")
                    LabeledContent("Betroffene Bücher", value: "\(previewResult.changedBooksCount)")

                    if !previewResult.hasChanges, !normalizedTarget.isEmpty {
                        Text("Es gibt aktuell keine Bücher, die durch diese Änderung angepasst würden.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.actionTitle) {
                        let result = previewResult
                        guard result.hasChanges else { return }
                        onApply(result)
                        dismiss()
                    }
                    .disabled(!canApply)
                }
            }
        }
    }

    private var helpText: String {
        switch mode {
        case .rename:
            return "Alle Bücher mit diesem Tag erhalten den neuen Namen. Doppelte Tags am selben Buch werden vermieden."
        case .merge:
            return "Das Ausgangs-Tag wird in das Ziel-Tag überführt. Wenn ein Buch beide Tags hat, bleibt nur das Ziel-Tag erhalten."
        }
    }
}

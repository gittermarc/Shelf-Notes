import SwiftUI
import SwiftData

// MARK: - Card Container

struct BookDetailCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            content
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Sheets

struct NotesEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var notes: String
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $notes)
                    .padding(12)
            }
            .navigationTitle("Notiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct CollectionsPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let allCollections: [BookCollection]
    let membershipBinding: (BookCollection) -> Binding<Bool>
    let onCreateNew: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if allCollections.isEmpty {
                    Text("Noch keine Listen.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allCollections) { col in
                        Toggle(isOn: membershipBinding(col)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(col.name.isEmpty ? "Ohne Namen" : col.name)
                                Text("\(col.booksSafe.count) Bücher")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                Section {
                    Button {
                        onCreateNew()
                    } label: {
                        Label("Neue Liste …", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Listen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

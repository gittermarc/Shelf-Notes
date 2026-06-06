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

struct CollectionsPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let allCollections: [BookCollection]
    @Binding var draft: CollectionMembershipDraft
    let onApply: (CollectionMembershipDraft) -> Void
    let onCreateNew: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if allCollections.isEmpty {
                    Text("Noch keine Listen.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(allCollections) { col in
                        Toggle(isOn: draftBinding(for: col)) {
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
                        applyDraft()
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
                        applyDraft()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onDisappear {
                applyDraft()
            }
        }
    }

    private func draftBinding(for collection: BookCollection) -> Binding<Bool> {
        Binding(
            get: { draft.contains(collection.id) },
            set: { isOn in
                draft.setMembership(isOn, for: collection.id)
            }
        )
    }

    private func applyDraft() {
        onApply(draft)
    }
}

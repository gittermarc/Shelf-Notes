import SwiftUI

struct TagHygieneCleanupConfirmationSheet: View {
    let plan: TagHygieneCleanupPlan
    let onConfirm: (TagLibraryMutationResult) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(plan.title, systemImage: plan.kind.systemImage)
                            .font(.headline)

                        Text(plan.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }

                Section("Änderung") {
                    LabeledContent("Betroffene Bücher", value: "\(plan.affectedBooksCount)")

                    if let targetTag = plan.targetTag {
                        LabeledContent("Ziel-Tag", value: "#\(targetTag)")
                    }

                    if !plan.sourceTags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Betroffene Tags")
                                .font(.subheadline.weight(.semibold))

                            TagHygieneCleanupTagList(tags: plan.sourceTags)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section {
                    if plan.isDestructive {
                        Text("Diese Änderung entfernt nur Tag-Zuordnungen. Bücher, Notizen und Lesedaten werden nicht gelöscht.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Diese Änderung vereinheitlicht Tag-Namen. Doppelte Tags am selben Buch werden automatisch vermieden.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Änderung prüfen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(plan.actionTitle, role: plan.isDestructive ? .destructive : nil) {
                        onConfirm(plan.result)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct TagHygieneCleanupTagList: View {
    let tags: [String]

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 92), spacing: 6, alignment: .leading)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text("#\(tag)")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }
        }
    }
}

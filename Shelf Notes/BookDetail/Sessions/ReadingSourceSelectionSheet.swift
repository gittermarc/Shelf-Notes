//
//  ReadingSourceSelectionSheet.swift
//  Shelf Notes
//

import SwiftUI

struct ReadingSourceSelectionSheet: View {
    let title: String
    let initialDraft: ReadingSourceDraft
    let onSave: (ReadingSourceDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: ReadingSourceDraft

    init(
        title: String = "Lesequelle",
        initialDraft: ReadingSourceDraft,
        onSave: @escaping (ReadingSourceDraft) -> Void
    ) {
        self.title = title
        self.initialDraft = initialDraft
        self.onSave = onSave
        _draft = State(initialValue: initialDraft)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ReadingSourceSelection.allCases) { selection in
                        sourceRow(selection)
                    }
                } footer: {
                    Text("Externe E-Book-Quellen werden in diesem Schritt ausschließlich manuell getrackt. Es findet keine Kontoverknüpfung oder automatische Synchronisierung statt.")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.isAvailable == false)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func sourceRow(_ selection: ReadingSourceSelection) -> some View {
        if selection.isAvailable {
            Button {
                draft.selection = selection
            } label: {
                rowLabel(selection)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(draft.selection == selection ? [.isSelected] : [])
        } else {
            rowLabel(selection)
                .opacity(0.62)
                .accessibilityLabel("\(selection.title), noch nicht verfügbar")
        }
    }

    private func rowLabel(_ selection: ReadingSourceSelection) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: selection.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(selection.isAvailable ? Color.accentColor : Color.secondary)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(selection.title)
                        .foregroundStyle(.primary)

                    if selection.isAvailable == false {
                        Text("Folgt später")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                    }
                }

                Text(selection.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if selection.isAvailable,
               draft.selection == selection {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 3)
    }
}

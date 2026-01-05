//
//  BookDetailComponents.swift
//  Shelf Notes
//
//  Created by Marc Fechner on 05.01.26.
//

import SwiftUI

// MARK: - Tags UI

struct SelectedTagPill: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.caption)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Tag \(text)"))
        .accessibilityHint(Text("Entfernen"))
    }
}

struct TagPickPill: View {
    let text: String
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(text)
                    .font(.caption)
                    .lineLimit(1)

                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                isSelected
                ? AnyShapeStyle(.thinMaterial)
                : AnyShapeStyle(.ultraThinMaterial.opacity(0.55))
            )
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? Color.primary.opacity(0.25) : Color.secondary.opacity(0.18),
                    lineWidth: 1
                )
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(text), \(count) mal genutzt"))
        .accessibilityHint(Text(isSelected ? "Tippen zum Entfernen" : "Tippen zum Hinzufügen"))
    }
}

// MARK: - Inline New Collection Sheet

struct InlineNewCollectionSheet: View {
    let onCreate: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Neue Liste") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .onSubmit { create() }

                    Text("Tipp: Kurzer, eindeutiger Name wie „2026 Must Reads“ oder „NYC-Vibes“.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Liste anlegen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Anlegen") { create() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onCreate(trimmed)
        dismiss()
    }
}

//
//  ReReadStartSheet.swift
//  Shelf Notes
//

import SwiftUI

struct ReReadStartSheet: View {
    let bookTitle: String
    let nextAttemptName: String
    let onStartNewAttempt: () -> Void
    let onSupplementExistingCompletion: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Nochmal lesen?", systemImage: "arrow.triangle.2.circlepath")
                        .font(.title3.weight(.bold))

                    Text("Dein bisheriger Abschluss bleibt erhalten. Ein neuer Lesedurchgang startet bei 0 % und bekommt eigene Sessions.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    Button {
                        onStartNewAttempt()
                        dismiss()
                    } label: {
                        ReReadStartOptionRow(
                            title: "Neuen Durchgang starten",
                            subtitle: "Startet \(nextAttemptName) für „\(bookTitle)“.",
                            systemImage: "play.circle.fill"
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        onSupplementExistingCompletion()
                        dismiss()
                    } label: {
                        ReReadStartOptionRow(
                            title: "Nur Session ergänzen",
                            subtitle: "Speichert eine zusätzliche Session, ohne einen neuen Fortschritt zu starten.",
                            systemImage: "plus.circle"
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
            .navigationTitle("Lesedurchgang")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct ReReadStartOptionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 3)
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}

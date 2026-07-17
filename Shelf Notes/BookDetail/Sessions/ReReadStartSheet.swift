//
//  ReReadStartSheet.swift
//  Shelf Notes
//

import SwiftUI

struct ReReadStartSheet: View {
    let bookTitle: String
    let nextAttemptName: String
    let initialSourceDraft: ReadingSourceDraft
    let onStartNewAttempt: (ReadingSourceDraft) -> Void
    let onSupplementExistingCompletion: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var sourceDraft: ReadingSourceDraft
    @State private var showingSourceSelection = false

    init(
        bookTitle: String,
        nextAttemptName: String,
        initialSourceDraft: ReadingSourceDraft = ReadingSourceDraft(),
        onStartNewAttempt: @escaping (ReadingSourceDraft) -> Void,
        onSupplementExistingCompletion: @escaping () -> Void
    ) {
        self.bookTitle = bookTitle
        self.nextAttemptName = nextAttemptName
        self.initialSourceDraft = initialSourceDraft
        self.onStartNewAttempt = onStartNewAttempt
        self.onSupplementExistingCompletion = onSupplementExistingCompletion
        _sourceDraft = State(initialValue: initialSourceDraft)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Nochmal lesen?", systemImage: "arrow.triangle.2.circlepath")
                            .font(.title3.weight(.bold))

                        Text("Dein bisheriger Abschluss bleibt erhalten. Ein neuer Lesedurchgang startet bei 0 % und bekommt eine eigene Lesequelle und eigene Sessions.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        showingSourceSelection = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: sourceDraft.selection.systemImage)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.tint)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Lesequelle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(sourceDraft.selection.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(sourceDraft.selection.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Lesequelle, \(sourceDraft.selection.title)")
                    .accessibilityHint("Öffnet die Auswahl für den neuen Lesedurchgang.")

                    VStack(spacing: 10) {
                        Button {
                            onStartNewAttempt(sourceDraft)
                            dismiss()
                        } label: {
                            ReReadStartOptionRow(
                                title: "Neuen Durchgang starten",
                                subtitle: "Startet \(nextAttemptName) für „\(bookTitle)“ mit \(sourceDraft.selection.title).",
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
                                subtitle: "Speichert eine zusätzliche physische Legacy-Session, ohne einen neuen Fortschritt zu starten.",
                                systemImage: "plus.circle"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Lesedurchgang")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingSourceSelection) {
            ReadingSourceSelectionSheet(
                title: "Lesequelle für \(nextAttemptName)",
                initialDraft: sourceDraft
            ) { selectedDraft in
                sourceDraft = selectedDraft
            }
        }
        .presentationDetents([.medium, .large])
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

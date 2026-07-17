//
//  QuickSessionLogSheet.swift
//  Shelf Notes
//

import SwiftUI

struct QuickSessionLogSheet: View {
    let bookTitle: String
    let progressConfiguration: ReadingProgressInputConfiguration
    let onCreate: (_ minutes: Int, _ progress: ReadingProgressInputSubmission, _ note: String?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var minutes: Int = 20
    @State private var progressState = ReadingProgressInputState()
    @State private var noteText: String = ""
    @State private var localError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $minutes, in: 1...600, step: 5) {
                        HStack {
                            Text("Dauer")
                            Spacer()
                            Text("\(minutes) Min.")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .accessibilityLabel("Dauer der Lesesession")
                    .accessibilityValue("\(minutes) Minuten")
                } header: {
                    Text("Quick-Log")
                } footer: {
                    Text("Die Session wird von jetzt minus Dauer bis jetzt gespeichert.")
                }

                ReadingProgressInputView(
                    state: $progressState,
                    configuration: progressConfiguration,
                    errorMessage: localError
                )

                Section("Notiz") {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 90)
                        .accessibilityLabel("Notiz zur Lesesession")
                }
            }
            .navigationTitle(bookTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .disabled(minutes <= 0)
                }
            }
            .onChange(of: progressState) { _, _ in
                localError = nil
            }
        }
    }

    private func save() {
        localError = nil
        let occurredAt = Date()

        switch ReadingProgressInputBuilder.makeSubmission(
            state: progressState,
            configuration: progressConfiguration,
            occurredAt: occurredAt
        ) {
        case .failure(let error):
            localError = error.message
        case .success(let submission):
            let note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
            onCreate(minutes, submission, note.isEmpty ? nil : note)
            dismiss()
        }
    }
}

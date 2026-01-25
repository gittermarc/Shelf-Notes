//
//  QuickSessionLogSheet.swift
//  Shelf Notes
//
//  Split out of the former BookDetailSessionsViews.swift
//  (No functional changes)
//

import SwiftUI

struct QuickSessionLogSheet: View {
    let bookTitle: String
    let remainingPages: Int?
    let totalPages: Int?
    let onCreate: (_ minutes: Int, _ pages: Int?, _ note: String?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var minutes: Int = 20
    @State private var pagesText: String = ""
    @State private var noteText: String = ""
    @State private var localError: String? = nil

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
                } header: {
                    Text("Quick-Log")
                } footer: {
                    if let remainingPages, let totalPages {
                        Text("Hier wird eine Session als „jetzt minus Dauer“ bis „jetzt“ gespeichert. Du kannst maximal \(remainingPages) von insgesamt \(totalPages) Seiten loggen.")
                    } else {
                        Text("Hier wird eine Session als „jetzt minus Dauer“ bis „jetzt“ gespeichert.")
                    }
                }

                Section("Optional") {
                    TextField(remainingPlaceholder, text: $pagesText)
                        .keyboardType(.numberPad)

                    if let err = localError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("Notiz") {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 90)
                }
            }
            .navigationTitle(bookTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        save()
                    }
                    .disabled(minutes <= 0)
                }
            }
            .onChange(of: pagesText) { _, _ in
                // Clear local error while user edits.
                if localError != nil { localError = nil }
            }
        }
    }

    private var remainingPlaceholder: String {
        if let remainingPages {
            return "Seiten gelesen (max. \(remainingPages))"
        }
        return "Seiten gelesen"
    }

    private func save() {
        localError = nil

        let pages = parsePositiveInt(pagesText)

        if let maxPages = remainingPages, let p = pages {
            if maxPages <= 0 {
                localError = "Dieses Buch hat keine Seiten mehr übrig (laut Log)."
                return
            }
            if p > maxPages {
                localError = "Zu viele Seiten: Maximal \(maxPages) möglich."
                return
            }
        }

        let note = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        onCreate(minutes, pages, note.isEmpty ? nil : note)
        dismiss()
    }

    private func parsePositiveInt(_ s: String) -> Int? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let val = Int(trimmed), val > 0 else { return nil }
        return val
    }
}

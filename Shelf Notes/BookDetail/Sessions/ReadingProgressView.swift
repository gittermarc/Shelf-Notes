//
//  ReadingProgressView.swift
//  Shelf Notes
//
//  Split out of the former BookDetailSessionsViews.swift
//  (No functional changes)
//

import SwiftUI
import SwiftData

struct ReadingProgressView: View {
    @Environment(\.modelContext) private var modelContext

    let book: Book
    let sessions: [ReadingSession]

    @State private var showingPageCountPrompt: Bool = false
    @State private var pageCountText: String = ""
    @State private var inlineError: String? = nil

    private var pageCountPromptTitle: String {
        // Vorher gab es diese Option nur, wenn `pageCount` fehlte/0 war.
        // Da die API auch falsche Werte liefern kann, darf der Nutzer die Seitenzahl immer anpassen.
        return (totalPages == nil) ? "Seitenzahl nachtragen" : "Seitenzahl bearbeiten"
    }

    private var pageCountPromptMessage: String {
        if totalPages == nil {
            return "Ohne Gesamtseiten kann die App den Fortschritt nicht korrekt berechnen."
        }
        return "Wenn die API danebenliegt (andere Ausgabe, anderes Format), kannst du hier die Seitenzahl korrigieren."
    }

    private var totalPages: Int? {
        guard let t = book.pageCount, t > 0 else { return nil }
        return t
    }

    private var pagesRead: Int {
        sessions
            .compactMap { $0.pagesReadNormalized }
            .reduce(0, +)
    }

    private var isFinished: Bool {
        book.status == .finished
    }

    /// Returns nil when we can't compute progress (no pageCount) and the book isn't finished.
    private var progressFraction: Double? {
        if isFinished { return 1.0 }
        guard let totalPages else { return nil }
        return min(1.0, max(0.0, Double(pagesRead) / Double(totalPages)))
    }

    private var percentText: String {
        if isFinished { return "100%" }
        guard let fraction = progressFraction else { return "—" }
        let pct = Int((fraction * 100.0).rounded())
        return "\(pct)%"
    }

    private var detailLine: String {
        if isFinished {
            if let totalPages {
                return "Gelesen · \(totalPages) Seiten"
            } else {
                return "Als gelesen markiert"
            }
        }

        if let totalPages {
            let clampedRead = min(max(0, pagesRead), totalPages)
            let remaining = max(0, totalPages - clampedRead)
            return "\(clampedRead)/\(totalPages) Seiten · Noch \(remaining)"
        }

        // No pageCount
        if pagesRead > 0 {
            return "\(pagesRead) Seiten geloggt · Gesamtseiten unbekannt"
        }
        return "Gesamtseiten unbekannt"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Fortschritt")
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 8)

                // ✏️ Seitenzahl immer bearbeitbar (auch wenn ein Wert vorhanden ist)
                Button {
                    inlineError = nil
                    if let current = totalPages {
                        pageCountText = String(current)
                    } else {
                        pageCountText = ""
                    }
                    showingPageCountPrompt = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(totalPages == nil ? "Seitenzahl nachtragen" : "Seitenzahl bearbeiten")

                Text(percentText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if let progressFraction {
                ProgressView(value: progressFraction)
                    .progressViewStyle(.linear)
            } else {
                // Unknown total pages → keep the UI stable.
                ProgressView(value: 0)
                    .progressViewStyle(.linear)
                    .opacity(0.35)
            }

            Text(detailLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let err = inlineError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fortschritt")
        .accessibilityValue(percentText)
        .alert(pageCountPromptTitle, isPresented: $showingPageCountPrompt) {
            TextField("z.B. 384", text: $pageCountText)
                .keyboardType(.numberPad)

            Button("Speichern") {
                savePageCount()
            }

            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text(pageCountPromptMessage)
        }
    }

    private func savePageCount() {
        inlineError = nil

        let trimmed = pageCountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let val = Int(trimmed), val > 0 else {
            inlineError = "Bitte eine gültige Seitenzahl (> 0) eingeben."
            return
        }

        book.pageCount = val

        if let error = modelContext.saveWithDiagnostics() {
            inlineError = "Konnte Seitenzahl nicht speichern: " + error.localizedDescription
        } else {
            inlineError = nil
        }
    }
}

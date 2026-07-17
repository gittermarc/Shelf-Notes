//
//  ReadingProgressView.swift
//  Shelf Notes
//

import SwiftUI
import SwiftData

struct ReadingProgressView: View {
    @Environment(\.modelContext) private var modelContext

    let book: Book
    let sessions: [ReadingSession]

    @State private var showingPageCountPrompt = false
    @State private var showingSourceSelection = false
    @State private var pageCountText = ""
    @State private var inlineError: String?

    private var displayedAttempt: ReadingAttempt? {
        book.activeReadingAttempt ?? book.orderedReadingAttempts.last
    }

    private var progressSnapshot: ReadingProgressSnapshot {
        book.currentReadingProgressSnapshot
    }

    private var readingMedium: ReadingMedium {
        displayedAttempt?.readingMedium ?? .physical
    }

    private var readingProvider: ReadingProvider {
        displayedAttempt?.defaultProvider ?? .none
    }

    private var presentation: ReadingProgressPresentation {
        ReadingProgressPresentationBuilder.make(
            snapshot: progressSnapshot,
            medium: readingMedium,
            provider: readingProvider,
            status: book.status
        )
    }

    private var sourceDraft: ReadingSourceDraft {
        ReadingSourceDraft.resolved(
            medium: readingMedium,
            provider: readingProvider,
            progressUnit: progressSnapshot.unit
        )
    }

    private var canChangeSource: Bool {
        guard let attempt = book.activeReadingAttempt else { return false }
        return ReadingSourceAttemptMutation.canChangeSource(of: attempt)
    }

    private var pageCountPromptTitle: String {
        normalizedPageCount == nil ? "Seitenzahl nachtragen" : "Seitenzahl bearbeiten"
    }

    private var pageCountPromptMessage: String {
        if normalizedPageCount == nil {
            return "Ohne Gesamtseiten kann Shelf Notes den Seitenfortschritt nicht korrekt berechnen."
        }
        return "Wenn Metadaten zu einer anderen Ausgabe gehören, kannst du die Seitenzahl hier korrigieren."
    }

    private var normalizedPageCount: Int? {
        ReadingSessionLogging.normalizedTotalPages(book.pageCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Fortschritt")
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 8)

                if presentation.canEditPageCount {
                    Button {
                        inlineError = nil
                        pageCountText = normalizedPageCount.map(String.init) ?? ""
                        showingPageCountPrompt = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(normalizedPageCount == nil ? "Seitenzahl nachtragen" : "Seitenzahl bearbeiten")
                }

                Text(presentation.percentText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            sourceLine

            if let progress = presentation.normalizedProgress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .accessibilityLabel("Lesefortschritt")
                    .accessibilityValue(presentation.percentText)
            }

            Text(presentation.detailText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let supportingText = presentation.supportingText {
                Text(supportingText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let inlineError {
                Text(inlineError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fortschritt, \(presentation.source.title)")
        .accessibilityValue(presentation.accessibilityValue)
        .alert(pageCountPromptTitle, isPresented: $showingPageCountPrompt) {
            TextField("z.B. 384", text: $pageCountText)
                .keyboardType(.numberPad)

            Button("Speichern") { savePageCount() }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text(pageCountPromptMessage)
        }
        .sheet(isPresented: $showingSourceSelection) {
            ReadingSourceSelectionSheet(
                title: "Lesequelle ändern",
                initialDraft: sourceDraft
            ) { draft in
                saveSource(draft)
            }
        }
    }

    private var sourceLine: some View {
        HStack(spacing: 8) {
            Image(systemName: presentation.source.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(presentation.source.title)
                .font(.caption.weight(.semibold))

            Spacer(minLength: 8)

            if canChangeSource {
                Button("Ändern") {
                    inlineError = nil
                    showingSourceSelection = true
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .accessibilityLabel("Lesequelle ändern")
            }
        }
    }

    private func savePageCount() {
        inlineError = nil
        let trimmed = pageCountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value > 0 else {
            inlineError = "Bitte eine gültige Seitenzahl größer als 0 eingeben."
            return
        }

        book.pageCount = value
        if let attempt = book.activeReadingAttempt,
           attempt.progressUnit == .pages {
            attempt.pageCountSnapshot = value
            attempt.totalValueSnapshot = Double(value)
            attempt.updatedAt = Date()
        }

        if let error = modelContext.saveWithDiagnostics() {
            inlineError = "Konnte Seitenzahl nicht speichern: " + error.localizedDescription
        }
    }

    private func saveSource(_ draft: ReadingSourceDraft) {
        inlineError = nil
        guard draft.isAvailable else {
            inlineError = "Diese Lesequelle ist noch nicht verfügbar."
            return
        }
        guard let attempt = book.activeReadingAttempt else {
            inlineError = "Die Lesequelle kann erst für einen aktiven Lesedurchgang gespeichert werden."
            return
        }
        guard ReadingSourceAttemptMutation.canChangeSource(of: attempt) else {
            inlineError = "Nach der ersten Session bleibt die Lesequelle dieses Durchgangs unverändert."
            return
        }

        ReadingSourceAttemptMutation.apply(draft, to: attempt, book: book)
        if let error = modelContext.saveWithDiagnostics() {
            inlineError = "Konnte Lesequelle nicht speichern: " + error.localizedDescription
        }
    }
}

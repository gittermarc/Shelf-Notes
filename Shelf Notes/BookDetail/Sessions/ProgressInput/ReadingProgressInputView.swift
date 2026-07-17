//
//  ReadingProgressInputView.swift
//  Shelf Notes
//

import SwiftUI

struct ReadingProgressInputView: View {
    @Binding var state: ReadingProgressInputState

    let configuration: ReadingProgressInputConfiguration
    let errorMessage: String?

    private var requiresCorrectionConfirmation: Bool {
        ReadingProgressInputBuilder.requiresCorrectionConfirmation(
            state: state,
            configuration: configuration
        )
    }

    var body: some View {
        Section {
            sourceSummary
            progressFields

            Toggle("Buch als beendet markieren", isOn: $state.marksBookFinished)
                .accessibilityHint("Schließt den aktuellen Lesedurchgang beim Speichern ab.")

            if requiresCorrectionConfirmation {
                Toggle("Niedrigeren Stand als Korrektur speichern", isOn: $state.confirmsCorrection)
                    .tint(.orange)
                    .accessibilityHint("Bestätigt, dass der bisherige Fortschritt bewusst nach unten korrigiert wird.")
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Fehler: \(errorMessage)")
            }
        } header: {
            Text("Fortschritt")
        } footer: {
            Text(footerText)
        }
        .onChange(of: state.pagesText) { _, _ in clearCorrectionIfNotNeeded() }
        .onChange(of: state.percentageText) { _, _ in clearCorrectionIfNotNeeded() }
        .onChange(of: state.locatorText) { _, _ in clearCorrectionIfNotNeeded() }
        .onChange(of: state.locatorPercentageText) { _, _ in clearCorrectionIfNotNeeded() }
        .onChange(of: state.marksBookFinished) { _, _ in clearCorrectionIfNotNeeded() }
    }

    private var sourceSummary: some View {
        HStack(spacing: 10) {
            Image(systemName: "book.pages")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(configuration.sourceTitle)
                    .font(.subheadline.weight(.semibold))

                if configuration.isManuallyTracked {
                    Text("Fortschritt wird manuell in Shelf Notes gepflegt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var progressFields: some View {
        switch configuration.unit {
        case .pages:
            TextField(pagesPlaceholder, text: $state.pagesText)
                .keyboardType(.numberPad)
                .accessibilityLabel("Gelesene Seiten")
                .accessibilityHint(pagesAccessibilityHint)

        case .percentage:
            TextField("Aktueller Lesestand in Prozent", text: $state.percentageText)
                .keyboardType(.decimalPad)
                .accessibilityLabel("Aktueller Lesestand in Prozent")
                .accessibilityHint("Gib einen absoluten Wert zwischen 0 und 100 ein.")

        case .locator:
            TextField("Kapitel oder Leseposition", text: $state.locatorText)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .accessibilityLabel("Kapitel oder Leseposition")

            TextField("Optionaler Prozentwert", text: $state.locatorPercentageText)
                .keyboardType(.decimalPad)
                .accessibilityLabel("Optionaler Prozentwert")
                .accessibilityHint("Shelf Notes interpretiert die Leseposition nicht automatisch.")

        case .none:
            Text("Für diese Quelle wird in der Session nur Dauer und Notiz erfasst.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var pagesPlaceholder: String {
        if let remainingPages = configuration.remainingPages,
           configuration.allowsPageOverflow == false {
            return "Gelesene Seiten, maximal \(remainingPages)"
        }
        return "Gelesene Seiten"
    }

    private var pagesAccessibilityHint: String {
        if let remainingPages = configuration.remainingPages,
           configuration.allowsPageOverflow == false {
            return "Du kannst höchstens \(remainingPages) Seiten erfassen oder das Feld leer lassen."
        }
        return "Lass das Feld leer, wenn du nur Zeit oder eine Notiz speichern möchtest."
    }

    private var footerText: String {
        switch configuration.unit {
        case .pages:
            return "Die Seitenzahl ist die Differenz dieser Session. Eine leere Angabe ist erlaubt."
        case .percentage:
            return "Der Prozentwert ist der absolute aktuelle Lesestand, nicht die Differenz dieser Session."
        case .locator:
            return "Die Leseposition wird unverändert gespeichert. Ein Prozentwert wird nur verwendet, wenn du ihn selbst angibst."
        case .none:
            return "Eine Session ohne messbaren Fortschritt ist zulässig."
        }
    }

    private func clearCorrectionIfNotNeeded() {
        if requiresCorrectionConfirmation == false {
            state.confirmsCorrection = false
        }
    }
}

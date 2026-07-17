//
//  ReadingProgressPresentation.swift
//  Shelf Notes
//

import Foundation

nonisolated struct ReadingProgressPresentation: Equatable, Sendable {
    let source: ReadingSourcePresentation
    let percentText: String
    let detailText: String
    let supportingText: String?
    let normalizedProgress: Double?
    let canEditPageCount: Bool
    let accessibilityValue: String
}

nonisolated enum ReadingProgressPresentationBuilder {
    static func make(
        snapshot: ReadingProgressSnapshot,
        medium: ReadingMedium,
        provider: ReadingProvider,
        status: ReadingStatus
    ) -> ReadingProgressPresentation {
        let source = ReadingSourcePresentation.make(
            medium: medium,
            provider: provider,
            progressUnit: snapshot.unit
        )
        let completed = snapshot.isCompleted || status == .finished
        let normalized = completed ? 1 : snapshot.normalizedProgress

        switch snapshot.unit {
        case .pages:
            return pagePresentation(
                snapshot: snapshot,
                source: source,
                completed: completed,
                normalized: normalized
            )
        case .percentage:
            return percentagePresentation(
                snapshot: snapshot,
                source: source,
                completed: completed,
                normalized: normalized
            )
        case .locator:
            return locatorPresentation(
                snapshot: snapshot,
                source: source,
                completed: completed,
                normalized: normalized
            )
        case .none:
            let detail = completed
                ? "Als gelesen markiert"
                : "Kein messbarer Fortschritt"
            return ReadingProgressPresentation(
                source: source,
                percentText: completed ? "100%" : "—",
                detailText: detail,
                supportingText: "Für diesen Lesedurchgang werden nur Zeit und Notizen erfasst.",
                normalizedProgress: normalized,
                canEditPageCount: false,
                accessibilityValue: completed ? "Abgeschlossen" : "Kein messbarer Fortschritt"
            )
        }
    }

    private static func pagePresentation(
        snapshot: ReadingProgressSnapshot,
        source: ReadingSourcePresentation,
        completed: Bool,
        normalized: Double?
    ) -> ReadingProgressPresentation {
        let read = max(0, snapshot.pagesRead ?? integral(snapshot.nativeValue) ?? 0)
        let total = positiveIntegral(snapshot.totalValue)
        let percent = completed ? "100%" : formattedPercent(normalized)
        let detail: String

        if let total {
            let clampedRead = completed ? total : min(read, total)
            let remaining = max(0, total - clampedRead)
            detail = "\(clampedRead) / \(total) Seiten · noch \(remaining)"
        } else if read > 0 {
            detail = "\(read) Seiten geloggt · Gesamtseiten unbekannt"
        } else if completed {
            detail = "Als gelesen markiert"
        } else {
            detail = "Noch kein Seitenfortschritt"
        }

        return ReadingProgressPresentation(
            source: source,
            percentText: percent,
            detailText: detail,
            supportingText: nil,
            normalizedProgress: normalized,
            canEditPageCount: true,
            accessibilityValue: percent == "—" ? detail : "\(percent), \(detail)"
        )
    }

    private static func percentagePresentation(
        snapshot: ReadingProgressSnapshot,
        source: ReadingSourcePresentation,
        completed: Bool,
        normalized: Double?
    ) -> ReadingProgressPresentation {
        let percent = completed ? "100%" : formattedPercent(normalized)
        let detail = percent == "—"
            ? "Aktueller Lesestand noch nicht erfasst"
            : "Aktueller Lesestand \(percent)"

        return ReadingProgressPresentation(
            source: source,
            percentText: percent,
            detailText: detail,
            supportingText: source.manualTrackingText,
            normalizedProgress: normalized,
            canEditPageCount: false,
            accessibilityValue: detail
        )
    }

    private static func locatorPresentation(
        snapshot: ReadingProgressSnapshot,
        source: ReadingSourcePresentation,
        completed: Bool,
        normalized: Double?
    ) -> ReadingProgressPresentation {
        let percent = completed ? "100%" : formattedPercent(normalized)
        let locator = normalizedLocator(snapshot.locator)
        let detail: String
        let supporting: String?

        if let locator {
            detail = "Leseposition: \(locator)"
            supporting = percent == "—"
                ? "Prozentwert nicht verfügbar"
                : source.manualTrackingText
        } else if source.title == ReadingSourceSelection.localFile.title {
            detail = "Fortschritt noch nicht automatisch verfügbar"
            supporting = "Der integrierte EPUB- und PDF-Reader folgt in einem späteren Update."
        } else {
            detail = "Leseposition noch nicht erfasst"
            supporting = source.manualTrackingText
        }

        let accessibility = percent == "—" ? detail : "\(percent), \(detail)"
        return ReadingProgressPresentation(
            source: source,
            percentText: percent,
            detailText: detail,
            supportingText: supporting,
            normalizedProgress: normalized,
            canEditPageCount: false,
            accessibilityValue: accessibility
        )
    }

    private static func formattedPercent(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        let clamped = min(1, max(0, value))
        return "\(Int((clamped * 100).rounded()))%"
    }

    private static func integral(_ value: Double?) -> Int? {
        guard let value,
              value.isFinite,
              value >= 0,
              value <= Double(Int.max),
              value.rounded(.towardZero) == value else {
            return nil
        }
        return Int(value)
    }

    private static func positiveIntegral(_ value: Double?) -> Int? {
        guard let value = integral(value), value > 0 else { return nil }
        return value
    }

    private static func normalizedLocator(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.isEmpty == false else {
            return nil
        }
        return value
    }
}

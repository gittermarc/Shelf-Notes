//
//  ReadingSessionPresentation.swift
//  Shelf Notes
//

import Foundation

nonisolated struct ReadingSessionPresentation: Equatable, Sendable {
    let primaryLine: String
    let metadataLine: String
    let note: String?
}

@MainActor
enum ReadingSessionPresentationBuilder {
    static func make(session: ReadingSession) -> ReadingSessionPresentation {
        let when = whenFormatter.string(from: session.startedAt)
        let minutes = max(1, Int(round(Double(max(0, session.durationSeconds)) / 60)))
        let source = ReadingSourcePresentation.make(
            medium: session.medium,
            provider: session.provider,
            progressUnit: session.progressUnit
        )

        var metadata: [String] = []
        if let progress = progressText(session: session) {
            metadata.append(progress)
        }
        metadata.append(source.title)
        if let origin = originText(session.origin) {
            metadata.append(origin)
        }

        let note = normalizedText(session.note)
        return ReadingSessionPresentation(
            primaryLine: "\(when) · \(minutes) Min.",
            metadataLine: metadata.joined(separator: " · "),
            note: note
        )
    }

    private static func progressText(session: ReadingSession) -> String? {
        switch session.progressUnit {
        case .pages:
            return session.pagesReadNormalized.map { "\($0) Seiten" }

        case .percentage:
            if let normalized = finite(session.endNormalizedProgress) {
                return "Lesestand \(Int((min(1, max(0, normalized)) * 100).rounded())) %"
            }
            if let value = finite(session.endValue) {
                return "Lesestand \(formatted(value)) %"
            }
            return nil

        case .locator:
            guard let locator = normalizedText(session.endLocator) else { return nil }
            if let normalized = finite(session.endNormalizedProgress) {
                let percent = Int((min(1, max(0, normalized)) * 100).rounded())
                return "\(locator) · \(percent) %"
            }
            return locator

        case .none:
            return nil
        }
    }

    private static func originText(_ origin: ReadingSessionOrigin) -> String? {
        switch origin {
        case .quickLog:
            return "Quick-Log"
        case .timer:
            return nil
        case .providerImport:
            return "Import"
        case .integratedReader:
            return "Shelf Notes Reader"
        case .shareExtension:
            return "Geteilt"
        case .legacy:
            return nil
        }
    }

    private static func normalizedText(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.isEmpty == false else {
            return nil
        }
        return value
    }

    private static func finite(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return value
    }

    private static func formatted(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private static let whenFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

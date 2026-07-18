//
//  ReadingSessionLiveActivityPresentation.swift
//  Shelf Notes
//
//  Pure presentation values shared by the app tests and the Live Activity extension.
//

import Foundation

nonisolated struct ReadingSessionLiveActivityPresentation: Hashable, Sendable {
    let title: String
    let compactTitle: String
    let authorText: String?
    let attemptText: String?
    let sourceText: String?
    let statusText: String
    let timerCaption: String
    let progressText: String?
    let progressDetailText: String?
    let remainingPagesText: String?
    let progressFraction: Double?
    let challengeTitle: String?
    let challengeDetail: String?
    let challengeProgressFraction: Double?
    let hasStoredCover: Bool
    let compactStatusText: String
    let compactProgressText: String?
    let minimalSystemImage: String
    let toggleTitle: String
    let toggleSystemImage: String
    let toggleAccessibilityLabel: String
    let stopAccessibilityLabel: String
    let coverAccessibilityLabel: String
    let progressAccessibilityLabel: String?
    let challengeAccessibilityLabel: String?
    let timerAccessibilityLabel: String
    let accentHex: String?

    init(
        attributes: ReadingSessionActivityAttributes,
        state: ReadingSessionActivityAttributes.ContentState
    ) {
        let normalizedTitle = Self.normalizedRequiredText(
            attributes.bookTitle,
            fallback: ReadingSessionLiveActivitySnapshot.defaultTitle,
            maxLength: 80
        )
        let author = Self.normalizedOptionalText(attributes.bookAuthor, maxLength: 80)
        let attempt = Self.normalizedOptionalText(attributes.attemptName, maxLength: 48)
        let stateText = Self.normalizedRequiredText(
            state.stateLabel,
            fallback: state.isPaused ? ReadingSessionLiveActivitySnapshot.pausedStateLabel : ReadingSessionLiveActivitySnapshot.runningStateLabel,
            maxLength: 32
        )
        let progress = Self.normalizedFraction(state.progressFraction)
        let pagesRead = Self.normalizedNonNegativeInt(state.pagesRead)
        let pageCount = Self.normalizedPositiveInt(state.pageCount)
        let remainingPages = Self.normalizedNonNegativeInt(state.remainingPages)
        let locator = Self.normalizedOptionalText(state.locator, maxLength: 96)
        let progressPayload = Self.makeProgressPayload(
            unit: state.progressUnit,
            progress: progress,
            pagesRead: pagesRead,
            pageCount: pageCount,
            remainingPages: remainingPages,
            locator: locator
        )
        let challengeTitle = Self.normalizedOptionalText(state.challengeTitle, maxLength: 64)
        let challengeDetail = Self.normalizedOptionalText(state.challengeDetail, maxLength: 96)
        let challengeProgress = Self.normalizedFraction(state.challengeProgressFraction)
        let hasStoredCover = state.hasCover ?? attributes.hasCover ?? false

        self.title = normalizedTitle
        self.compactTitle = Self.limited(normalizedTitle, maxLength: 28)
        self.authorText = author
        self.attemptText = attempt
        self.sourceText = Self.makeSourceText(
            medium: state.readingMedium,
            provider: state.readingProvider
        )
        self.statusText = stateText
        self.timerCaption = state.isPaused ? "Angehalten" : "Lesezeit"
        self.progressText = progressPayload.progressText
        self.progressDetailText = progressPayload.detailText
        self.remainingPagesText = progressPayload.remainingPagesText
        self.progressFraction = progressPayload.progressFraction
        self.challengeTitle = challengeTitle
        self.challengeDetail = challengeDetail
        self.challengeProgressFraction = challengeProgress
        self.hasStoredCover = hasStoredCover
        self.compactStatusText = state.isPaused ? "Pause" : "Live"
        self.compactProgressText = progressPayload.compactProgressText
        self.minimalSystemImage = state.isPaused ? "pause.fill" : "book.closed.fill"
        self.toggleTitle = state.isPaused ? "Weiter" : "Pause"
        self.toggleSystemImage = state.isPaused ? "play.fill" : "pause.fill"
        self.toggleAccessibilityLabel = state.isPaused ? "Lesesession fortsetzen" : "Lesesession pausieren"
        self.stopAccessibilityLabel = "Lesesession beenden"
        self.coverAccessibilityLabel = hasStoredCover ? "Cover von \(normalizedTitle)" : "Cover-Platzhalter für \(normalizedTitle)"
        self.progressAccessibilityLabel = progressPayload.accessibilityLabel
        self.challengeAccessibilityLabel = Self.makeChallengeAccessibilityLabel(
            title: challengeTitle,
            detail: challengeDetail
        )
        self.timerAccessibilityLabel = state.isPaused ? "Pausierte Lesezeit" : "Laufende Lesezeit"
        self.accentHex = Self.normalizedHex(state.accentHex ?? attributes.accentHex)
    }

    var hasProgress: Bool {
        progressText != nil || progressDetailText != nil
    }

    var hasChallenge: Bool {
        challengeTitle != nil || challengeDetail != nil
    }

    private struct ProgressPayload: Hashable, Sendable {
        var progressText: String?
        var detailText: String?
        var remainingPagesText: String?
        var progressFraction: Double?
        var compactProgressText: String?
        var accessibilityLabel: String?
    }

    private static func makeProgressPayload(
        unit: ReadingProgressUnit,
        progress: Double?,
        pagesRead: Int?,
        pageCount: Int?,
        remainingPages: Int?,
        locator: String?
    ) -> ProgressPayload {
        switch unit {
        case .pages:
            let detail = makePageProgressDetailText(
                pagesRead: pagesRead,
                pageCount: pageCount,
                remainingPages: remainingPages
            )
            let text = makeProgressText(progress)
            return ProgressPayload(
                progressText: text,
                detailText: detail,
                remainingPagesText: makeRemainingPagesText(remainingPages),
                progressFraction: progress,
                compactProgressText: makeCompactProgressText(progress),
                accessibilityLabel: makeProgressAccessibilityLabel(progressText: text, detailText: detail)
            )

        case .percentage:
            let text = makeProgressText(progress)
            return ProgressPayload(
                progressText: text,
                detailText: text == nil ? nil : "Prozentstand",
                remainingPagesText: nil,
                progressFraction: progress,
                compactProgressText: makeCompactProgressText(progress),
                accessibilityLabel: makeProgressAccessibilityLabel(progressText: text, detailText: nil)
            )

        case .locator:
            let detail = locator.map { "Position: \($0)" }
            let text = makeProgressText(progress)
            return ProgressPayload(
                progressText: text,
                detailText: detail,
                remainingPagesText: nil,
                progressFraction: progress,
                compactProgressText: makeCompactProgressText(progress),
                accessibilityLabel: makeProgressAccessibilityLabel(progressText: text, detailText: detail)
            )

        case .none:
            return ProgressPayload(
                progressText: nil,
                detailText: nil,
                remainingPagesText: nil,
                progressFraction: nil,
                compactProgressText: nil,
                accessibilityLabel: nil
            )
        }
    }

    private static func makeProgressText(_ fraction: Double?) -> String? {
        guard let fraction else { return nil }
        let percent = Int((fraction * 100).rounded())
        return "\(percent) % gelesen"
    }

    private static func makeCompactProgressText(_ fraction: Double?) -> String? {
        guard let fraction else { return nil }
        let percent = Int((fraction * 100).rounded())
        return "\(percent) %"
    }

    private static func makePageProgressDetailText(
        pagesRead: Int?,
        pageCount: Int?,
        remainingPages: Int?
    ) -> String? {
        if let pagesRead, let pageCount {
            return "\(pagesRead) von \(pageCount) Seiten"
        }

        if let remainingPages {
            return makeRemainingPagesText(remainingPages)
        }

        if let pagesRead {
            return "\(pagesRead) Seiten gelesen"
        }

        return nil
    }

    private static func makeRemainingPagesText(_ remainingPages: Int?) -> String? {
        guard let remainingPages else { return nil }
        if remainingPages == 1 {
            return "noch 1 Seite"
        }
        return "noch \(remainingPages) Seiten"
    }

    private static func makeSourceText(
        medium: ReadingMedium,
        provider: ReadingProvider
    ) -> String? {
        if medium == .physical {
            return "Physisch"
        }

        switch provider {
        case .appleBooks:
            return "Apple Books"
        case .kindle:
            return "Kindle"
        case .googleBooks:
            return "Google Books"
        case .localFile:
            return "Lokale Datei"
        case .other:
            return "E-Book-App"
        case .none:
            return "E-Book"
        }
    }

    private static func makeProgressAccessibilityLabel(
        progressText: String?,
        detailText: String?
    ) -> String? {
        switch (progressText, detailText) {
        case let (progress?, detail?):
            return "Fortschritt: \(progress), \(detail)"
        case let (progress?, nil):
            return "Fortschritt: \(progress)"
        case let (nil, detail?):
            return "Fortschritt: \(detail)"
        case (nil, nil):
            return nil
        }
    }

    private static func makeChallengeAccessibilityLabel(title: String?, detail: String?) -> String? {
        switch (title, detail) {
        case let (title?, detail?):
            return "Motivation: \(title), \(detail)"
        case let (title?, nil):
            return "Motivation: \(title)"
        case let (nil, detail?):
            return "Motivation: \(detail)"
        case (nil, nil):
            return nil
        }
    }

    private static func normalizedRequiredText(_ raw: String?, fallback: String, maxLength: Int) -> String {
        let normalized = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let value = normalized.isEmpty ? fallback : normalized
        return limited(value, maxLength: maxLength)
    }

    private static func normalizedOptionalText(_ raw: String?, maxLength: Int) -> String? {
        guard let raw else { return nil }
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return limited(normalized, maxLength: maxLength)
    }

    private static func limited(_ value: String, maxLength: Int) -> String {
        guard maxLength > 0, value.count > maxLength else { return value }
        return String(value.prefix(maxLength))
    }

    private static func normalizedPositiveInt(_ raw: Int?) -> Int? {
        guard let raw, raw > 0 else { return nil }
        return raw
    }

    private static func normalizedNonNegativeInt(_ raw: Int?) -> Int? {
        guard let raw else { return nil }
        return max(0, raw)
    }

    private static func normalizedFraction(_ raw: Double?) -> Double? {
        guard let raw, raw.isFinite else { return nil }
        return min(1.0, max(0.0, raw))
    }

    private static func normalizedHex(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let withoutPrefix = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard withoutPrefix.count == 6 || withoutPrefix.count == 8 else { return nil }

        let allowed = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        guard withoutPrefix.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }

        return "#" + withoutPrefix.uppercased()
    }
}

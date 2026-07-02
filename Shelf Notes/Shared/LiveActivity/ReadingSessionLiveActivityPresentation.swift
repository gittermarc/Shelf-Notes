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
    let statusText: String
    let timerCaption: String
    let progressText: String?
    let progressDetailText: String?
    let remainingPagesText: String?
    let progressFraction: Double?
    let challengeTitle: String?
    let challengeDetail: String?
    let challengeProgressFraction: Double?
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
        let challengeTitle = Self.normalizedOptionalText(state.challengeTitle, maxLength: 64)
        let challengeDetail = Self.normalizedOptionalText(state.challengeDetail, maxLength: 96)
        let challengeProgress = Self.normalizedFraction(state.challengeProgressFraction)

        self.title = normalizedTitle
        self.compactTitle = Self.limited(normalizedTitle, maxLength: 28)
        self.authorText = author
        self.attemptText = attempt
        self.statusText = stateText
        self.timerCaption = state.isPaused ? "Angehalten" : "Lesezeit"
        self.progressText = Self.makeProgressText(progress)
        self.progressDetailText = Self.makeProgressDetailText(
            pagesRead: pagesRead,
            pageCount: pageCount,
            remainingPages: remainingPages
        )
        self.remainingPagesText = Self.makeRemainingPagesText(remainingPages)
        self.progressFraction = progress
        self.challengeTitle = challengeTitle
        self.challengeDetail = challengeDetail
        self.challengeProgressFraction = challengeProgress
        self.compactStatusText = state.isPaused ? "Pause" : "Live"
        self.compactProgressText = Self.makeCompactProgressText(progress)
        self.minimalSystemImage = state.isPaused ? "pause.fill" : "book.closed.fill"
        self.toggleTitle = state.isPaused ? "Weiter" : "Pause"
        self.toggleSystemImage = state.isPaused ? "play.fill" : "pause.fill"
        self.toggleAccessibilityLabel = state.isPaused ? "Lesesession fortsetzen" : "Lesesession pausieren"
        self.stopAccessibilityLabel = "Lesesession beenden"
        self.coverAccessibilityLabel = "Cover von \(normalizedTitle)"
        self.progressAccessibilityLabel = Self.makeProgressAccessibilityLabel(
            progressText: Self.makeProgressText(progress),
            detailText: Self.makeProgressDetailText(pagesRead: pagesRead, pageCount: pageCount, remainingPages: remainingPages)
        )
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

    private static func makeProgressDetailText(
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

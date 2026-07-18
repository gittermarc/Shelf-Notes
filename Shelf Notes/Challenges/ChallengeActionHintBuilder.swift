//
//  ChallengeActionHintBuilder.swift
//  Shelf Notes
//
//  Pure presentation builders for showing challenges near reading actions.
//

import Foundation

nonisolated enum ChallengeActionHintBuilder {
    static func makeSessionHints(
        from items: [ChallengeDashboardItem],
        bookTitle: String,
        remainingPages: Int?,
        progressUnit: ReadingProgressUnit = .pages,
        limit: Int = 2
    ) -> [ChallengeActionHint] {
        items
            .filter { item in
                item.status == .active && isSessionRelevant(
                    item.metric,
                    remainingPages: remainingPages,
                    progressUnit: progressUnit
                )
            }
            .map { item in
                makeHint(
                    item: item,
                    bookTitle: bookTitle,
                    remainingPages: remainingPages,
                    progressUnit: progressUnit
                )
            }
            .sorted { lhs, rhs in
                if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
                if lhs.kind != rhs.kind { return lhs.kind.sortOrder < rhs.kind.sortOrder }
                if lhs.progressFraction != rhs.progressFraction { return lhs.progressFraction > rhs.progressFraction }
                return lhs.title < rhs.title
            }
            .prefix(max(0, limit))
            .map { $0 }
    }

    private static func isSessionRelevant(
        _ metric: ChallengeMetric,
        remainingPages: Int?,
        progressUnit: ReadingProgressUnit
    ) -> Bool {
        switch metric {
        case .readingMinutes, .readingDays, .sessions, .shortSessions, .sessionNotes:
            return true
        case .pagesRead:
            return progressUnit == .pages && remainingPages != 0
        case .booksProgressed:
            return progressUnit != .none && (progressUnit != .pages || remainingPages != 0)
        case .booksFinished:
            return progressUnit != .pages || remainingPages == nil || (remainingPages ?? 0) > 0
        case .finishedBooksRated, .finishedBooksNoted:
            return false
        }
    }

    private static func makeHint(
        item: ChallengeDashboardItem,
        bookTitle: String,
        remainingPages: Int?,
        progressUnit: ReadingProgressUnit
    ) -> ChallengeActionHint {
        let safeBookTitle = bookTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "dieses Buch"
            : bookTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        return ChallengeActionHint(
            id: item.id,
            challengeID: item.id,
            kind: item.kind,
            metric: item.metric,
            title: item.title,
            message: makeMessage(
                item: item,
                bookTitle: safeBookTitle,
                remainingPages: remainingPages,
                progressUnit: progressUnit
            ),
            detail: makeDetail(
                item: item,
                remainingPages: remainingPages,
                progressUnit: progressUnit
            ),
            progressText: item.progressText,
            remainingText: item.remainingText,
            progressFraction: item.progressFraction,
            systemImage: item.metric.systemImage,
            priority: makePriority(item: item)
        )
    }

    private static func makePriority(item: ChallengeDashboardItem) -> Int {
        if item.kind == .daily && item.progressFraction >= 0.60 { return 0 }
        if item.progressFraction >= 0.85 { return 0 }
        if item.kind.sortOrder <= ChallengeKind.weekly.sortOrder && item.progressFraction >= 0.60 { return 1 }
        if item.metric == .readingMinutes || item.metric == .sessions || item.metric == .shortSessions { return 2 }
        if item.kind.sortOrder <= ChallengeKind.weekly.sortOrder { return 3 }
        return 4
    }

    private static func makeMessage(
        item: ChallengeDashboardItem,
        bookTitle: String,
        remainingPages: Int?,
        progressUnit: ReadingProgressUnit
    ) -> String {
        switch item.metric {
        case .readingMinutes:
            if item.kind == .daily {
                return "Noch \(item.remainingValue) Minuten bis zur Tagesmission. „\(bookTitle)“ ist der schnellste Weg dahin."
            }
            return "Jede Minute mit „\(bookTitle)“ bringt diese Challenge sichtbar weiter."
        case .readingDays:
            return "Eine kurze Session reicht, damit heute als Lesetag zählt."
        case .sessions:
            if item.kind == .daily {
                return "Eine Session mit „\(bookTitle)“ kann den heutigen Haken setzen."
            }
            return "Speichere eine Session und der Zähler springt direkt nach oben."
        case .pagesRead:
            if let remainingPages {
                if item.kind == .daily {
                    return "Noch \(item.remainingValue) Seiten bis zur Tagesmission. In diesem Buch sind noch \(remainingPages) Seiten offen."
                }
                return "Trag gelesene Seiten ein. In diesem Buch sind noch \(remainingPages) Seiten offen."
            }
            return "Trag gelesene Seiten ein, damit diese Challenge Fortschritt bekommt."
        case .booksFinished:
            if progressUnit == .pages, let remainingPages {
                return "Noch \(remainingPages) Seiten im Buch. Ein Abschluss kann diese Challenge knacken."
            }
            return "Wenn du dieses Buch abschließt, kann das direkt auf die Challenge einzahlen."
        case .shortSessions:
            if item.kind == .daily {
                return "Eine kurze Session mit „\(bookTitle)“ reicht heute vielleicht schon."
            }
            return "Eine kurze Session mit „\(bookTitle)“ kann diese Mission direkt weiterbringen."
        case .booksProgressed:
            if progressUnit == .pages, let remainingPages {
                return "Logge Seitenfortschritt. Für dieses Buch sind noch \(remainingPages) Seiten offen."
            }
            switch progressUnit {
            case .percentage:
                return "Aktualisiere den Prozentstand von „\(bookTitle)“, damit dieses Buch für die Mission zählt."
            case .locator:
                return "Erfasse einen belastbaren Fortschrittsstand für „\(bookTitle)“, damit dieses Buch für die Mission zählt."
            case .pages:
                return "Logge Seitenfortschritt, damit dieses Buch für die Mission zählt."
            case .none:
                return "Ein messbarer Fortschrittsstand ist für diese Mission erforderlich."
            }
        case .sessionNotes:
            if item.kind == .daily {
                return "Speichere heute eine Session mit kurzer Notiz. Ein Satz reicht."
            }
            return "Schreib zur Session eine kurze Notiz. Ein Satz reicht schon."
        case .finishedBooksRated:
            return "Bewertungen zählen im Challenge Board, nicht während der Session."
        case .finishedBooksNoted:
            return "Buchnotizen zählen im Challenge Board, nicht während der Session."
        }
    }

    private static func makeDetail(
        item: ChallengeDashboardItem,
        remainingPages: Int?,
        progressUnit: ReadingProgressUnit
    ) -> String {
        if item.progressFraction >= 0.85 {
            return "Fast erledigt: \(item.remainingText)."
        }

        if item.kind == .daily {
            return "Tagesmission zuerst: kleiner Aufwand, schneller Lesesieg."
        }

        if item.kind == .yearly {
            return "Zahlt ruhig auf deine Jahresquest ein. Kein Sprint nötig."
        }

        switch item.metric {
        case .readingMinutes, .readingDays, .sessions:
            return "Timer oder manuelle Session zählen beide."
        case .shortSessions:
            return "5 bis 25 Minuten reichen für diese Mission."
        case .pagesRead:
            return remainingPages == nil ? "Ohne Seitenangabe bleibt diese Mission blind." : "Seitenangaben machen deinen Fortschritt messbar."
        case .booksProgressed:
            switch progressUnit {
            case .pages:
                return remainingPages == nil ? "Ohne Seitenangabe bleibt diese Mission blind." : "Seitenangaben machen deinen Fortschritt messbar."
            case .percentage:
                return "Ein höherer Prozentstand zählt dieses Buch genau einmal im Zeitraum."
            case .locator:
                return "Nur ein belastbarer Fortschrittsanstieg zählt, nicht ein unbekanntes Locator-Format."
            case .none:
                return "Diese Quelle liefert aktuell keinen messbaren Fortschritt."
            }
        case .booksFinished:
            return "Zählt, sobald das Buch wirklich abgeschlossen ist."
        case .sessionNotes:
            return "Session speichern und Notiz nicht leer lassen."
        case .finishedBooksRated, .finishedBooksNoted:
            return "Diese Mission wird über beendete Bücher ausgewertet."
        }
    }
}

//
//  ChallengeTemplateRegistry.swift
//  Shelf Notes
//
//  Central registry for challenge mission templates.
//

import Foundation

nonisolated enum ChallengeTemplateRegistry {
    static let weekly: [ChallengeTemplate] = [
        ChallengeTemplate(
            kind: .weekly,
            metric: .readingDays,
            difficulty: .steady,
            minimumTarget: 2,
            maximumTarget: 6,
            targetStep: 1,
            fallbackTarget: 2,
            baselineMultiplier: 1.0,
            baselineOffset: 1,
            detail: "Diese Woche zählt jeder Tag mit mindestens 1 Minute Lesesession.",
            rewardText: "Konstanz schlägt Perfektion. Mehrere Lesetage in einer Woche sind genau der Stoff, aus dem Routinen entstehen.",
            emptyBaselinePriority: 90
        ),
        ChallengeTemplate(
            kind: .weekly,
            metric: .readingMinutes,
            difficulty: .steady,
            minimumTarget: 60,
            maximumTarget: 600,
            targetStep: 10,
            fallbackTarget: 60,
            baselineMultiplier: 1.15,
            baselineOffset: 0,
            detail: "Diese Woche: Leseminuten aus deinen Sessions sammeln. Auch kleine Häppchen zählen.",
            rewardText: "Das war echte Lesezeit. Keine Theorie, kein Vorsatz, sondern erledigt.",
            emptyBaselinePriority: 85
        ),
        ChallengeTemplate(
            kind: .weekly,
            metric: .sessions,
            difficulty: .gentle,
            minimumTarget: 3,
            maximumTarget: 14,
            targetStep: 1,
            fallbackTarget: 3,
            baselineMultiplier: 1.25,
            baselineOffset: 0,
            detail: "Kurze Sessions zählen auch. Hauptsache, du bleibst sichtbar dran.",
            rewardText: "Mehrere Sessions bedeuten: Du bist wirklich zurück zum Buch gekommen.",
            emptyBaselinePriority: 80
        ),
        ChallengeTemplate(
            kind: .weekly,
            metric: .shortSessions,
            difficulty: .gentle,
            minimumTarget: 2,
            maximumTarget: 10,
            targetStep: 1,
            fallbackTarget: 2,
            baselineMultiplier: 1.2,
            baselineOffset: 1,
            detail: "Zählt Sessions zwischen 5 und 25 Minuten. Perfekt für kleine Lese-Fenster.",
            rewardText: "Kurze Sessions sind kein Trostpreis. Sie sind der Cheatcode gegen Ausreden.",
            emptyBaselinePriority: 72
        ),
        ChallengeTemplate(
            kind: .weekly,
            metric: .pagesRead,
            difficulty: .stretch,
            minimumTarget: 50,
            maximumTarget: 1_000,
            targetStep: 10,
            fallbackTarget: 80,
            baselineMultiplier: 1.15,
            baselineOffset: 0,
            detail: "Zählt nur, wenn du in Sessions gelesene Seiten einträgst.",
            rewardText: "Seiten eingetragen, Fortschritt sichtbar. Genau dafür ist Shelf Notes gebaut.",
            emptyBaselinePriority: 55,
            requiresPageHistory: true
        ),
        ChallengeTemplate(
            kind: .weekly,
            metric: .booksProgressed,
            difficulty: .steady,
            minimumTarget: 1,
            maximumTarget: 4,
            targetStep: 1,
            fallbackTarget: 1,
            baselineMultiplier: 1.0,
            baselineOffset: 1,
            detail: "Ein Buch zählt, sobald du in dieser Woche Seitenfortschritt dafür loggst.",
            rewardText: "Nicht nur gelesen, sondern ein Buch wirklich vorangebracht. Sehr sauber.",
            emptyBaselinePriority: 52,
            requiresPageHistory: true
        ),
        ChallengeTemplate(
            kind: .weekly,
            metric: .sessionNotes,
            difficulty: .gentle,
            minimumTarget: 1,
            maximumTarget: 6,
            targetStep: 1,
            fallbackTarget: 1,
            baselineMultiplier: 1.15,
            baselineOffset: 1,
            detail: "Zählt Lesesessions mit einer kurzen Session-Notiz.",
            rewardText: "Du hast nicht nur gelesen, sondern Spuren hinterlassen. Das macht dein Lesetagebuch wertvoller.",
            emptyBaselinePriority: 48
        )
    ]

    static let monthly: [ChallengeTemplate] = [
        ChallengeTemplate(
            kind: .monthly,
            metric: .readingMinutes,
            difficulty: .steady,
            minimumTarget: 300,
            maximumTarget: 3_000,
            targetStep: 30,
            fallbackTarget: 300,
            baselineMultiplier: 1.1,
            baselineOffset: 0,
            detail: "Diesen Monat: Leseminuten aus Sessions sammeln. Kleine Sessions zählen mit.",
            rewardText: "Ein ganzer Monat Leseminuten. Das ist kein Zufall mehr, das ist ein Muster.",
            emptyBaselinePriority: 90
        ),
        ChallengeTemplate(
            kind: .monthly,
            metric: .booksFinished,
            difficulty: .steady,
            minimumTarget: 1,
            maximumTarget: 6,
            targetStep: 1,
            fallbackTarget: 1,
            baselineMultiplier: 1.0,
            baselineOffset: 1,
            detail: "Dieser Monat zählt abgeschlossene Lesedurchgänge mit Abschlussdatum.",
            rewardText: "Ein Lesedurchgang wirklich beendet. Der schönste Haken in jeder Bibliothek.",
            emptyBaselinePriority: 86
        ),
        ChallengeTemplate(
            kind: .monthly,
            metric: .readingDays,
            difficulty: .stretch,
            minimumTarget: 6,
            maximumTarget: 24,
            targetStep: 1,
            fallbackTarget: 6,
            baselineMultiplier: 1.05,
            baselineOffset: 0,
            detail: "Ein Lesetag zählt, wenn du mindestens 1 Minute in einer Session geloggt hast.",
            rewardText: "Viele Lesetage in einem Monat. Das ist die Art von Routine, die bleibt.",
            emptyBaselinePriority: 78
        ),
        ChallengeTemplate(
            kind: .monthly,
            metric: .sessions,
            difficulty: .steady,
            minimumTarget: 8,
            maximumTarget: 60,
            targetStep: 1,
            fallbackTarget: 8,
            baselineMultiplier: 1.1,
            baselineOffset: 0,
            detail: "Regelmäßig kleine Lesesessions loggen. Das bringt Konstanz.",
            rewardText: "Du bist immer wieder zum Lesen zurückgekommen. Genau das zählt.",
            emptyBaselinePriority: 74
        ),
        ChallengeTemplate(
            kind: .monthly,
            metric: .pagesRead,
            difficulty: .stretch,
            minimumTarget: 300,
            maximumTarget: 5_000,
            targetStep: 50,
            fallbackTarget: 300,
            baselineMultiplier: 1.1,
            baselineOffset: 0,
            detail: "Zählt nur, wenn du in Sessions gelesene Seiten einträgst.",
            rewardText: "Das ist messbarer Fortschritt. Seiten für Seiten, nicht nur Gefühl.",
            emptyBaselinePriority: 58,
            requiresPageHistory: true
        ),
        ChallengeTemplate(
            kind: .monthly,
            metric: .shortSessions,
            difficulty: .gentle,
            minimumTarget: 4,
            maximumTarget: 30,
            targetStep: 1,
            fallbackTarget: 4,
            baselineMultiplier: 1.15,
            baselineOffset: 1,
            detail: "Zählt Sessions zwischen 5 und 25 Minuten. Kleine Lese-Fenster werden sichtbar.",
            rewardText: "Der Monat hatte kleine Leseinseln. Genau daraus wird eine Gewohnheit.",
            emptyBaselinePriority: 62
        ),
        ChallengeTemplate(
            kind: .monthly,
            metric: .booksProgressed,
            difficulty: .steady,
            minimumTarget: 2,
            maximumTarget: 12,
            targetStep: 1,
            fallbackTarget: 2,
            baselineMultiplier: 1.0,
            baselineOffset: 1,
            detail: "Ein Buch zählt, sobald du in diesem Monat Seitenfortschritt dafür loggst.",
            rewardText: "Mehr als ein Buch bewegt. Dein Regal ist nicht nur hübsch, es lebt.",
            emptyBaselinePriority: 54,
            requiresPageHistory: true
        ),
        ChallengeTemplate(
            kind: .monthly,
            metric: .sessionNotes,
            difficulty: .gentle,
            minimumTarget: 2,
            maximumTarget: 12,
            targetStep: 1,
            fallbackTarget: 2,
            baselineMultiplier: 1.1,
            baselineOffset: 1,
            detail: "Zählt Lesesessions mit einer kurzen Session-Notiz.",
            rewardText: "Notizen machen aus Sessions Erinnerungen. Das zahlt langfristig ein.",
            emptyBaselinePriority: 50
        ),
        ChallengeTemplate(
            kind: .monthly,
            metric: .finishedBooksRated,
            difficulty: .gentle,
            minimumTarget: 1,
            maximumTarget: 4,
            targetStep: 1,
            fallbackTarget: 1,
            baselineMultiplier: 1.0,
            baselineOffset: 0,
            detail: "Zählt in diesem Monat beendete Bücher, bei denen du eine Bewertung gepflegt hast.",
            rewardText: "Bewertet und abgeschlossen. Dein zukünftiges Ich wird diese Einschätzung feiern.",
            emptyBaselinePriority: 44,
            requiresFinishedBookHistory: true
        ),
        ChallengeTemplate(
            kind: .monthly,
            metric: .finishedBooksNoted,
            difficulty: .gentle,
            minimumTarget: 1,
            maximumTarget: 4,
            targetStep: 1,
            fallbackTarget: 1,
            baselineMultiplier: 1.0,
            baselineOffset: 0,
            detail: "Zählt in diesem Monat beendete Bücher mit eigener Buchnotiz.",
            rewardText: "Ein Buch mit Notiz ist mehr als erledigt. Es ist festgehalten.",
            emptyBaselinePriority: 42,
            requiresFinishedBookHistory: true
        )
    ]

    static func templates(for kind: ChallengeKind) -> [ChallengeTemplate] {
        switch kind {
        case .daily:
            return []
        case .weekly:
            return weekly
        case .monthly:
            return monthly
        case .yearly:
            return []
        case .unknown:
            return []
        }
    }

    static func template(kind: ChallengeKind, metric: ChallengeMetric) -> ChallengeTemplate? {
        templates(for: kind).first { $0.metric == metric }
    }

    static func rewardText(kind: ChallengeKind, metric: ChallengeMetric) -> String {
        template(kind: kind, metric: metric)?.rewardText ?? fallbackRewardText(metric: metric)
    }

    static func difficulty(kind: ChallengeKind, metric: ChallengeMetric) -> ChallengeDifficulty? {
        template(kind: kind, metric: metric)?.difficulty
    }

    private static func fallbackRewardText(metric: ChallengeMetric) -> String {
        switch metric {
        case .readingMinutes:
            return "Das war echte Lesezeit. Stark durchgezogen."
        case .readingDays:
            return "Konstanz gewonnen. Genau so entsteht Routine."
        case .sessions:
            return "Mehrfach drangeblieben. Das zählt."
        case .pagesRead:
            return "Seiten gemacht, Fortschritt sichtbar."
        case .booksFinished:
            return "Ein Lesedurchgang abgeschlossen. Sauberer Haken."
        case .shortSessions:
            return "Kleine Fenster genutzt. Stark."
        case .booksProgressed:
            return "Ein Buch wirklich weitergebracht."
        case .sessionNotes:
            return "Gelesen und festgehalten. Sehr gut."
        case .finishedBooksRated:
            return "Bewertet und archiviert. Das hilft später."
        case .finishedBooksNoted:
            return "Abgeschlossen und notiert. Das bleibt."
        }
    }
}

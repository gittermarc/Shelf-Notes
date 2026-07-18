//
//  ChallengeTemplateRegistry.swift
//  Shelf Notes
//
//  Central registry for challenge mission templates.
//

import Foundation

nonisolated enum ChallengeTemplateRegistry {
    static let daily: [ChallengeTemplate] = [
        ChallengeTemplate(
            kind: .daily,
            metric: .readingMinutes,
            difficulty: .gentle,
            minimumTarget: 10,
            maximumTarget: 90,
            targetStep: 5,
            fallbackTarget: 15,
            baselineMultiplier: 1.1,
            baselineOffset: 0,
            detail: "Heute: ein kleines, machbares Lese-Fenster sichern. Timer oder manuelle Session zählen beide.",
            rewardText: "Tagesmission erledigt. Genau so wird Lesen wieder Teil des Tages, ohne großes Drama.",
            emptyBaselinePriority: 95
        ),
        ChallengeTemplate(
            kind: .daily,
            metric: .sessions,
            difficulty: .gentle,
            minimumTarget: 1,
            maximumTarget: 4,
            targetStep: 1,
            fallbackTarget: 1,
            baselineMultiplier: 1.0,
            baselineOffset: 0,
            detail: "Heute zählt jede gespeicherte Lesesession ab einer Minute. Kurz lesen ist ausdrücklich erlaubt.",
            rewardText: "Eine Session ist ein echter Kontakt mit dem Buch. Genau dieser kleine Einstieg zählt.",
            emptyBaselinePriority: 92
        ),
        ChallengeTemplate(
            kind: .daily,
            metric: .readingDays,
            difficulty: .gentle,
            minimumTarget: 1,
            maximumTarget: 1,
            targetStep: 1,
            fallbackTarget: 1,
            baselineMultiplier: 1.0,
            baselineOffset: 0,
            detail: "Mach den heutigen Tag zu einem Lesetag. Eine Session mit mindestens einer Minute reicht.",
            rewardText: "Heute gelesen. Nicht geplant, nicht nur vorgenommen, sondern sichtbar gemacht.",
            emptyBaselinePriority: 88
        ),
        ChallengeTemplate(
            kind: .daily,
            metric: .pagesRead,
            difficulty: .steady,
            minimumTarget: 10,
            maximumTarget: 150,
            targetStep: 5,
            fallbackTarget: 20,
            baselineMultiplier: 1.1,
            baselineOffset: 0,
            detail: "Heute gelesene Seiten eintragen. Diese Mission zählt nur mit gepflegtem Seitenfortschritt.",
            rewardText: "Seiten gelesen und festgehalten. Dein Fortschritt ist heute nicht nur Gefühl, sondern sichtbar.",
            emptyBaselinePriority: 60,
            requiresPageHistory: true
        ),
        ChallengeTemplate(
            kind: .daily,
            metric: .sessionNotes,
            difficulty: .gentle,
            minimumTarget: 1,
            maximumTarget: 2,
            targetStep: 1,
            fallbackTarget: 1,
            baselineMultiplier: 1.0,
            baselineOffset: 0,
            detail: "Schreib heute zu einer Lesesession eine kurze Notiz. Ein Satz reicht völlig.",
            rewardText: "Heute nicht nur gelesen, sondern einen Gedanken gerettet. Das macht Shelf Notes lebendig.",
            emptyBaselinePriority: 54
        )
    ]

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
            detail: "Ein Buch zählt, sobald du in dieser Woche einen echten Fortschrittsanstieg dafür erfasst.",
            rewardText: "Nicht nur gelesen, sondern ein Buch wirklich vorangebracht. Sehr sauber.",
            emptyBaselinePriority: 52
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
            detail: "Ein Buch zählt, sobald du in diesem Monat einen echten Fortschrittsanstieg dafür erfasst.",
            rewardText: "Mehr als ein Buch bewegt. Dein Regal ist nicht nur hübsch, es lebt.",
            emptyBaselinePriority: 54
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

    static let yearly: [ChallengeTemplate] = [
        ChallengeTemplate(
            kind: .yearly,
            metric: .readingDays,
            difficulty: .steady,
            minimumTarget: 60,
            maximumTarget: 280,
            targetStep: 5,
            fallbackTarget: 100,
            baselineMultiplier: 1.05,
            baselineOffset: 5,
            detail: "Dieses Jahr zählt jeder Tag mit mindestens einer Minute Lesesession. Es geht um Routine, nicht um Perfektion.",
            rewardText: "Ein Jahr voller Lesetage. Das ist keine Laune mehr, das ist echte Lese-DNA.",
            emptyBaselinePriority: 96
        ),
        ChallengeTemplate(
            kind: .yearly,
            metric: .booksFinished,
            difficulty: .steady,
            minimumTarget: 6,
            maximumTarget: 80,
            targetStep: 1,
            fallbackTarget: 12,
            baselineMultiplier: 1.0,
            baselineOffset: 2,
            detail: "Dieses Jahr zählt jeder abgeschlossene Lesedurchgang mit Abschlussdatum.",
            rewardText: "Ein Jahresquest mit echten Abschlüssen. Dein Regal hat dieses Jahr geliefert.",
            emptyBaselinePriority: 92
        ),
        ChallengeTemplate(
            kind: .yearly,
            metric: .readingMinutes,
            difficulty: .steady,
            minimumTarget: 3_000,
            maximumTarget: 60_000,
            targetStep: 300,
            fallbackTarget: 5_000,
            baselineMultiplier: 1.05,
            baselineOffset: 0,
            detail: "Dieses Jahr werden deine geloggten Leseminuten gesammelt. Kleine Sessions zahlen genauso ein.",
            rewardText: "So viel echte Lesezeit in einem Jahr. Das sieht nicht nur gut aus, das fühlt sich auch verdient an.",
            emptyBaselinePriority: 88
        ),
        ChallengeTemplate(
            kind: .yearly,
            metric: .sessions,
            difficulty: .steady,
            minimumTarget: 50,
            maximumTarget: 600,
            targetStep: 10,
            fallbackTarget: 100,
            baselineMultiplier: 1.05,
            baselineOffset: 10,
            detail: "Dieses Jahr zählt jede gespeicherte Lesesession ab einer Minute.",
            rewardText: "Immer wieder zum Buch zurückgekommen. Genau daraus entsteht ein Lesejahr, auf das man schaut.",
            emptyBaselinePriority: 84
        ),
        ChallengeTemplate(
            kind: .yearly,
            metric: .pagesRead,
            difficulty: .stretch,
            minimumTarget: 2_000,
            maximumTarget: 60_000,
            targetStep: 500,
            fallbackTarget: 5_000,
            baselineMultiplier: 1.05,
            baselineOffset: 0,
            detail: "Dieses Jahr zählen geloggte Seiten aus deinen Sessions. Perfekt, wenn du Seitenfortschritt konsequent pflegst.",
            rewardText: "Seiten über ein ganzes Jahr sichtbar gemacht. Das ist Lesefortschritt mit Beleg.",
            emptyBaselinePriority: 68,
            requiresPageHistory: true
        ),
        ChallengeTemplate(
            kind: .yearly,
            metric: .sessionNotes,
            difficulty: .gentle,
            minimumTarget: 12,
            maximumTarget: 200,
            targetStep: 5,
            fallbackTarget: 25,
            baselineMultiplier: 1.05,
            baselineOffset: 2,
            detail: "Dieses Jahr zählen Lesesessions mit einer kurzen Session-Notiz.",
            rewardText: "Ein Jahr mit Lese-Spuren. Deine Notizen machen aus Statistik Erinnerung.",
            emptyBaselinePriority: 64
        ),
        ChallengeTemplate(
            kind: .yearly,
            metric: .finishedBooksRated,
            difficulty: .gentle,
            minimumTarget: 3,
            maximumTarget: 40,
            targetStep: 1,
            fallbackTarget: 6,
            baselineMultiplier: 1.0,
            baselineOffset: 1,
            detail: "Dieses Jahr zählen beendete Bücher, bei denen du eine Bewertung gepflegt hast.",
            rewardText: "Abgeschlossen und bewertet. Dein Jahresrückblick wird dadurch deutlich hilfreicher.",
            emptyBaselinePriority: 52,
            requiresFinishedBookHistory: true
        ),
        ChallengeTemplate(
            kind: .yearly,
            metric: .finishedBooksNoted,
            difficulty: .gentle,
            minimumTarget: 3,
            maximumTarget: 40,
            targetStep: 1,
            fallbackTarget: 6,
            baselineMultiplier: 1.0,
            baselineOffset: 1,
            detail: "Dieses Jahr zählen beendete Bücher mit eigener Buchnotiz.",
            rewardText: "Nicht nur beendet, sondern festgehalten. So bleibt dein Lesejahr greifbar.",
            emptyBaselinePriority: 50,
            requiresFinishedBookHistory: true
        )
    ]

    static func templates(for kind: ChallengeKind) -> [ChallengeTemplate] {
        switch kind {
        case .daily:
            return daily
        case .weekly:
            return weekly
        case .monthly:
            return monthly
        case .yearly:
            return yearly
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

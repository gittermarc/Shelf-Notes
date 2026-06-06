//
//  ChallengeDashboardBuilder.swift
//  Shelf Notes
//
//  Builds lightweight presentation state from persisted challenge records.
//

import Foundation

@MainActor
enum ChallengeDashboardBuilder {
    static func make(
        sourceSnapshot: ChallengeSourceSnapshot,
        progressByID: [UUID: ChallengeEngine.ChallengeProgress],
        now: Date = Date(),
        calendar: Calendar = .current,
        historyLimit: Int = 12,
        enabledKinds: [ChallengeKind] = ChallengeCadence.supportedKinds
    ) -> ChallengeDashboardState {
        make(
            challenges: sourceSnapshot.dashboardRecords,
            progressByID: progressByID,
            now: now,
            calendar: calendar,
            historyLimit: historyLimit,
            enabledKinds: enabledKinds
        )
    }

    static func make(
        challenges: [ChallengeRecord],
        progressByID: [UUID: ChallengeEngine.ChallengeProgress],
        now: Date = Date(),
        calendar: Calendar = .current,
        historyLimit: Int = 12,
        enabledKinds: [ChallengeKind] = ChallengeCadence.supportedKinds
    ) -> ChallengeDashboardState {
        guard !challenges.isEmpty else { return .empty }

        let visibleChallenges = ChallengeDuplicateResolver.deduplicatedRecords(challenges)
        guard !visibleChallenges.isEmpty else { return .empty }

        let enabledKindSet = Set(ChallengePreferences.normalizedKinds(enabledKinds))

        let items = visibleChallenges.map { record in
            makeItem(
                record: record,
                progress: progressByID[record.id],
                now: now,
                calendar: calendar
            )
        }

        let visibleActiveItems = items
            .filter { item in
                item.isRewardReady || (item.periodStart <= now && item.periodEnd > now && isActiveItemVisible(item, enabledKindSet: enabledKindSet))
            }
            .sorted { lhs, rhs in
                if lhs.isRewardReady != rhs.isRewardReady { return lhs.isRewardReady }
                if lhs.kind != rhs.kind { return lhs.kind.sortOrder < rhs.kind.sortOrder }
                return lhs.periodStart < rhs.periodStart
            }

        let todayFocus = makeTodayFocus(from: visibleActiveItems)
        let activeItems = visibleActiveItems.filter { item in
            guard let todayFocus else { return true }
            return item.id != todayFocus.item.id
        }
        let activeIDs = Set(visibleActiveItems.map(\.id))

        let historyItems = items
            .filter { $0.periodEnd <= now && !activeIDs.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.periodEnd != rhs.periodEnd { return lhs.periodEnd > rhs.periodEnd }
                return lhs.kind.sortOrder < rhs.kind.sortOrder
            }
            .prefix(historyLimit)
            .map { $0 }

        let completedCount = items.filter(\.isCompleted).count
        let unclaimedCount = items.filter(\.isRewardReady).count
        let hero = makeHero(from: activeItems)
        let rewardSummary = ChallengeRewardSummaryBuilder.make(items: items, now: now)

        return ChallengeDashboardState(
            todayFocus: todayFocus,
            hero: hero,
            activeItems: activeItems,
            historyItems: historyItems,
            completedCount: completedCount,
            unclaimedCount: unclaimedCount,
            rewardSummary: rewardSummary
        )
    }


    private static func isActiveItemVisible(_ item: ChallengeDashboardItem, enabledKindSet: Set<ChallengeKind>) -> Bool {
        enabledKindSet.contains(item.kind) || item.isRewardReady
    }

    private static func makeItem(
        record: ChallengeRecord,
        progress: ChallengeEngine.ChallengeProgress?,
        now: Date,
        calendar: Calendar
    ) -> ChallengeDashboardItem {
        let isCurrent = record.periodStart <= now && record.periodEnd > now
        let status = makeStatus(record: record, isCurrent: isCurrent)
        let progressText = progress?.valueText(target: record.targetValue) ?? "Fortschritt wird geladen"
        let remainingText = progress?.remainingText(target: record.targetValue) ?? "Ziel erreicht"
        let timeRemaining = makeTimeRemainingText(record: record, now: now, calendar: calendar)
        let deadline = makeDeadlineText(record: record, calendar: calendar)
        let motivation = makeMotivationText(record: record, progress: progress, status: status, now: now, calendar: calendar)
        let difficultyText = ChallengeTemplateRegistry.difficulty(kind: record.kind, metric: record.metric)?.displayName ?? "Mission"
        let rewardText = ChallengeTemplateRegistry.rewardText(kind: record.kind, metric: record.metric)

        return ChallengeDashboardItem(
            id: record.id,
            kind: record.kind,
            metric: record.metric,
            title: record.title,
            detail: record.detail,
            targetValue: record.targetValue,
            periodLabel: record.periodLabel,
            periodStart: record.periodStart,
            periodEnd: record.periodEnd,
            progress: progress,
            status: status,
            canReroll: record.canReroll,
            timeRemainingText: timeRemaining,
            deadlineText: deadline,
            progressText: progressText,
            remainingText: remainingText,
            motivationText: motivation,
            difficultyText: difficultyText,
            rewardText: rewardText
        )
    }

    private static func makeStatus(record: ChallengeRecord, isCurrent: Bool) -> ChallengeDashboardItem.Status {
        if record.isCompleted && !record.isClaimed { return .readyToClaim }
        if record.isCompleted && record.isClaimed { return .claimed }
        if isCurrent { return .active }
        return .expired
    }

    private static func makeHero(from activeItems: [ChallengeDashboardItem]) -> ChallengeDashboardHero? {
        if let reward = activeItems.first(where: \.isRewardReady) {
            return ChallengeDashboardHero(
                itemID: reward.id,
                title: "Belohnung bereit",
                subtitle: "\(reward.kind.displayName)-Challenge geschafft: \(reward.title)",
                systemImage: "trophy.fill",
                progressFraction: reward.progressFraction,
                progressText: reward.progressText,
                actionText: "Jetzt abholen",
                isRewardReady: true
            )
        }

        guard let next = activeItems
            .filter({ !$0.isCompleted })
            .sorted(by: { lhs, rhs in
                if lhs.progressFraction != rhs.progressFraction { return lhs.progressFraction > rhs.progressFraction }
                if lhs.periodEnd != rhs.periodEnd { return lhs.periodEnd < rhs.periodEnd }
                return lhs.kind.sortOrder < rhs.kind.sortOrder
            })
            .first
        else {
            return nil
        }

        return ChallengeDashboardHero(
            itemID: next.id,
            title: "Nächster Sieg",
            subtitle: "\(next.remainingText) bis \(next.title)",
            systemImage: next.metric.systemImage,
            progressFraction: next.progressFraction,
            progressText: next.progressText,
            actionText: next.timeRemainingText,
            isRewardReady: false
        )
    }

    private static func makeTodayFocus(from activeItems: [ChallengeDashboardItem]) -> ChallengeDashboardTodayFocus? {
        guard let item = activeItems.first(where: { $0.kind == .daily && $0.status == .active && !$0.isCompleted }) else {
            return nil
        }

        return ChallengeDashboardTodayFocus(
            item: item,
            headline: "Heute im Fokus",
            message: makeTodayFocusMessage(item: item),
            actionText: makeTodayFocusActionText(item: item),
            footnote: makeTodayFocusFootnote(item: item)
        )
    }

    private static func makeTodayFocusMessage(item: ChallengeDashboardItem) -> String {
        if item.remainingValue <= 0 {
            return "Tagesmission geschafft. Hol dir deinen kleinen Sieg ab."
        }

        switch item.metric {
        case .readingMinutes:
            return "Noch \(item.remainingValue) Minuten bis zur Tagesmission. Das passt sogar zwischen Kaffee und Alltag."
        case .readingDays:
            return "Eine Mini-Session reicht, damit heute als Lesetag zählt."
        case .sessions:
            return "Noch \(item.remainingValue) Session(s) und dein Tag hat einen Haken."
        case .pagesRead:
            return "Noch \(item.remainingValue) Seiten bis zur Tagesmission. Ein Kapitel kann reichen."
        case .booksFinished:
            return "Wenn du heute abschließt, knackt diese Tagesmission."
        case .shortSessions:
            return "Noch \(item.remainingValue) kurze Session(s). 5 bis 25 Minuten zählen."
        case .booksProgressed:
            return "Noch \(item.remainingValue) Buch/Bücher mit Seitenfortschritt. Ein Eintrag genügt."
        case .sessionNotes:
            return "Noch \(item.remainingValue) Session-Notiz(en). Ein Satz reicht."
        case .finishedBooksRated:
            return "Noch \(item.remainingValue) Bewertung(en) für beendete Bücher."
        case .finishedBooksNoted:
            return "Noch \(item.remainingValue) Buchnotiz(en) für beendete Bücher."
        }
    }

    private static func makeTodayFocusActionText(item: ChallengeDashboardItem) -> String {
        if item.isRewardReady { return "Belohnung abholen" }
        if item.remainingValue <= 0 { return "Mission sichern" }

        switch item.metric {
        case .readingMinutes:
            return "Session starten oder Minuten nachtragen"
        case .readingDays, .sessions, .shortSessions:
            return "Kurze Session loggen"
        case .pagesRead, .booksProgressed:
            return "Seitenfortschritt eintragen"
        case .booksFinished:
            return "Buch abschließen"
        case .sessionNotes:
            return "Session mit Notiz speichern"
        case .finishedBooksRated:
            return "Beendetes Buch bewerten"
        case .finishedBooksNoted:
            return "Buchnotiz ergänzen"
        }
    }

    private static func makeTodayFocusFootnote(item: ChallengeDashboardItem) -> String {
        if item.progressFraction >= 0.85 { return "Fast geschafft" }
        if item.progressFraction > 0 { return "Heute schon im Flow" }
        return "Heute noch offen"
    }

    private static func makeTimeRemainingText(record: ChallengeRecord, now: Date, calendar: Calendar) -> String {
        guard record.periodEnd > now else { return "Zeitraum beendet" }

        let startOfToday = calendar.startOfDay(for: now)
        let endDay = calendar.startOfDay(for: record.periodEnd)
        let days = max(0, calendar.dateComponents([.day], from: startOfToday, to: endDay).day ?? 0)

        if days <= 1 { return "endet heute" }
        if days == 2 { return "noch 1 Tag" }
        return "noch \(days - 1) Tage"
    }

    private static func makeDeadlineText(record: ChallengeRecord, calendar: Calendar) -> String {
        let visibleEnd = calendar.date(byAdding: .day, value: -1, to: record.periodEnd) ?? record.periodEnd
        return "bis \(visibleEnd.formatted(date: .abbreviated, time: .omitted))"
    }

    private static func makeMotivationText(
        record: ChallengeRecord,
        progress: ChallengeEngine.ChallengeProgress?,
        status: ChallengeDashboardItem.Status,
        now: Date,
        calendar: Calendar
    ) -> String {
        switch status {
        case .readyToClaim:
            return "Sauber. Das Ding ist durch und wartet nur noch auf deinen Haken."
        case .claimed:
            return "Erfolg gesichert. Genau solche kleinen Siege bauen Momentum auf."
        case .expired:
            if record.isCompleted { return "Abgeschlossen und archiviert." }
            return "Nicht eingesammelt, aber der nächste Lauf kommt."
        case .active:
            break
        }

        guard let progress else { return "Fortschritt wird gerade aktualisiert." }

        let remaining = max(0, record.targetValue - progress.value)
        guard remaining > 0 else { return "Ziel erreicht. Jetzt nur noch die Belohnung einsammeln." }

        let startOfToday = calendar.startOfDay(for: now)
        let endDay = calendar.startOfDay(for: record.periodEnd)
        let daysLeft = max(1, calendar.dateComponents([.day], from: startOfToday, to: endDay).day ?? 1)

        if record.kind == .daily {
            return makeDailyMotivationText(metric: record.metric, remaining: remaining)
        }

        if record.kind == .yearly {
            return makeYearlyMotivationText(metric: record.metric, remaining: remaining)
        }

        switch record.metric {
        case .readingMinutes:
            let perDay = Int((Double(remaining) / Double(daysLeft)).rounded(.up))
            return "\(perDay) Minuten pro Tag reichen ab jetzt. Das ist machbar."
        case .readingDays:
            return "Noch \(remaining) Lesetag(e). Eine Mini-Session reicht schon."
        case .sessions:
            return "Noch \(remaining) Session(s). Kurz lesen zählt auch."
        case .pagesRead:
            return "Noch \(remaining) Seiten. Ein Kapitel bringt dich sichtbar näher ran."
        case .booksFinished:
            return "Noch \(remaining) Buch/Bücher. Das aktuelle Buch ist dein bester Hebel."
        case .shortSessions:
            return "Noch \(remaining) kurze Session(s). 5 bis 25 Minuten reichen."
        case .booksProgressed:
            return "Noch \(remaining) Buch/Bücher mit Seitenfortschritt. Ein Eintrag genügt."
        case .sessionNotes:
            return "Noch \(remaining) Session-Notiz(en). Ein kurzer Gedanke reicht."
        case .finishedBooksRated:
            return "Noch \(remaining) Bewertung(en) für beendete Bücher."
        case .finishedBooksNoted:
            return "Noch \(remaining) Buchnotiz(en) für beendete Bücher."
        }
    }

    private static func makeDailyMotivationText(metric: ChallengeMetric, remaining: Int) -> String {
        switch metric {
        case .readingMinutes:
            return "Noch \(remaining) Minuten bis zur Tagesmission. Kurz lesen zählt."
        case .readingDays:
            return "Eine Mini-Session macht heute zum Lesetag."
        case .sessions:
            return "Noch \(remaining) Session(s). Der heutige Haken ist nah."
        case .pagesRead:
            return "Noch \(remaining) Seiten. Ein kleiner Abschnitt reicht oft."
        case .booksFinished:
            return "Heute abschließen und die Tagesmission ist durch."
        case .shortSessions:
            return "Noch \(remaining) kurze Session(s). Kein Marathon nötig."
        case .booksProgressed:
            return "Noch \(remaining) Buch/Bücher mit Fortschritt. Ein Eintrag genügt."
        case .sessionNotes:
            return "Noch \(remaining) Session-Notiz(en). Ein Gedanke reicht."
        case .finishedBooksRated:
            return "Noch \(remaining) Bewertung(en). Schnell erledigt, sauber dokumentiert."
        case .finishedBooksNoted:
            return "Noch \(remaining) Buchnotiz(en). Kurz festhalten, was bleibt."
        }
    }

    private static func makeYearlyMotivationText(metric: ChallengeMetric, remaining: Int) -> String {
        switch metric {
        case .readingMinutes:
            return "Jahresquest läuft. Noch \(remaining) Minuten, aber ohne Stress: jeder Monat zahlt ein."
        case .readingDays:
            return "Noch \(remaining) Lesetag(e) für die Jahresquest. Konsistenz gewinnt."
        case .sessions:
            return "Noch \(remaining) Session(s) im Jahr. Kleine Einheiten machen hier den Unterschied."
        case .pagesRead:
            return "Noch \(remaining) Seiten für die Jahresquest. Das wächst Kapitel für Kapitel."
        case .booksFinished:
            return "Noch \(remaining) Abschluss/Abschlüsse. Langstrecke, kein Sprint."
        case .shortSessions:
            return "Noch \(remaining) kurze Session(s). Auch kleine Lesefenster zählen fürs Jahr."
        case .booksProgressed:
            return "Noch \(remaining) Buch/Bücher mit Fortschritt. Breite Lesespur statt Endspurt."
        case .sessionNotes:
            return "Noch \(remaining) Session-Notiz(en). Deine Jahresquest bekommt dadurch Substanz."
        case .finishedBooksRated:
            return "Noch \(remaining) Bewertung(en). Dein Lesejahr wird dadurch greifbarer."
        case .finishedBooksNoted:
            return "Noch \(remaining) Buchnotiz(en). Ein ruhiger Jahresanker."
        }
    }
}


//
//  LibraryOverviewWidgetPresentation.swift
//  ShelfNotesLiveActivity
//
//  View-facing presentation values for the Library Overview widget.
//

import Foundation

struct LibraryOverviewWidgetPresentation: Hashable, Sendable {
    struct Metric: Hashable, Identifiable, Sendable {
        var id: String
        var title: String
        var value: String
        var symbolName: String
    }

    var snapshot: LibraryOverviewWidgetSnapshot
    var isSnapshotUnavailable: Bool
    var isEmpty: Bool
    var isStale: Bool
    var usesReducedMode: Bool
    var showsCovers: Bool
    var heroSubtitle: String
    var metrics: [Metric]
    var currentTitle: String
    var currentDetail: String
    var currentProgressText: String?
    var currentProgressFraction: Double?
    var goalTitle: String
    var goalDetail: String
    var goalProgressFraction: Double?
    var activityDetail: String
    var shelfItems: [LibraryOverviewBookSnapshot]

    init(
        snapshot: LibraryOverviewWidgetSnapshot,
        isSnapshotUnavailable: Bool = false,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let privacy = snapshot.effectivePrivacy

        self.snapshot = snapshot
        self.isSnapshotUnavailable = isSnapshotUnavailable
        isEmpty = !snapshot.hasBooks
        isStale = now.timeIntervalSince(snapshot.generatedAt) > 60 * 60 * 24
        usesReducedMode = privacy.usesReducedMode
        showsCovers = privacy.showsCovers && !privacy.usesReducedMode
        heroSubtitle = Self.heroSubtitle(snapshot: snapshot, isSnapshotUnavailable: isSnapshotUnavailable)
        metrics = [
            Metric(id: "read", title: "Gelesen", value: "\(snapshot.readBooks)", symbolName: "checkmark.circle.fill"),
            Metric(id: "reading", title: "Lese ich", value: "\(snapshot.readingBooks)", symbolName: "book.pages.fill"),
            Metric(id: "toRead", title: "Stapel", value: "\(snapshot.wantToReadBooks)", symbolName: "books.vertical.fill")
        ]

        if isSnapshotUnavailable {
            currentTitle = "Öffne Shelf Notes"
            currentDetail = "Dann aktualisiert sich dein Widget automatisch."
            currentProgressText = nil
            currentProgressFraction = nil
        } else if privacy.usesReducedMode, !isEmpty {
            currentTitle = "Privater Widget-Modus"
            currentDetail = "Buchtitel und Cover sind ausgeblendet."
            currentProgressText = nil
            currentProgressFraction = nil
        } else if let currentBook = snapshot.currentBook {
            currentTitle = currentBook.title
            currentDetail = Self.currentDetail(for: currentBook, privacy: privacy)
            currentProgressText = Self.progressText(for: currentBook)
            currentProgressFraction = currentBook.progressFraction
        } else if isEmpty {
            currentTitle = "Dein Regal wartet"
            currentDetail = "Füge dein erstes Buch hinzu und starte deine Bibliothek."
            currentProgressText = nil
            currentProgressFraction = nil
        } else {
            currentTitle = "Gerade kein aktives Buch"
            currentDetail = "Dein Lesestapel ist bereit für das nächste Kapitel."
            currentProgressText = nil
            currentProgressFraction = nil
        }

        if let yearlyGoal = snapshot.yearlyGoal {
            goalTitle = "Jahresziel \(yearlyGoal.year)"
            goalDetail = "\(yearlyGoal.finishedCount) von \(yearlyGoal.targetCount) gelesen"
            goalProgressFraction = yearlyGoal.progressFraction
        } else {
            let year = calendar.component(.year, from: now)
            goalTitle = "Jahresziel \(year)"
            goalDetail = isSnapshotUnavailable ? "Nach App-Start verfügbar" : "Noch kein Ziel gesetzt"
            goalProgressFraction = nil
        }

        if isSnapshotUnavailable {
            activityDetail = "Noch keine lokalen Widget-Daten"
        } else if snapshot.hasRecentActivity {
            activityDetail = "\(snapshot.last7DaysReadingMinutes) min · \(snapshot.last7DaysReadingDays) Tage · \(snapshot.currentReadingStreakDays) Streak"
        } else {
            activityDetail = "Noch keine Lesesessions erfasst"
        }

        shelfItems = privacy.usesReducedMode ? [] : Array(snapshot.recentShelfItems.prefix(5))
    }

    private static func heroSubtitle(
        snapshot: LibraryOverviewWidgetSnapshot,
        isSnapshotUnavailable: Bool
    ) -> String {
        if isSnapshotUnavailable {
            return "Noch kein Überblick gespeichert"
        }

        if !snapshot.hasBooks {
            return "Bereit für dein erstes Buch"
        }

        if snapshot.readingBooks > 0 {
            return "\(snapshot.readingBooks) aktuell in Arbeit"
        }

        if snapshot.wantToReadBooks > 0 {
            return "\(snapshot.wantToReadBooks) warten auf dich"
        }

        return "Alles gelesen, starkes Regal"
    }

    private static func currentDetail(
        for book: LibraryOverviewBookSnapshot,
        privacy: LibraryOverviewPrivacySnapshot
    ) -> String {
        if !privacy.showsBookTitles {
            return "Details ausgeblendet"
        }

        if let author = book.author, !author.isEmpty {
            return author
        }

        return "Aktuelles Buch"
    }

    private static func progressText(for book: LibraryOverviewBookSnapshot) -> String? {
        guard let pagesRead = book.pagesRead, let pageCount = book.pageCount else { return nil }

        if let remainingPages = book.remainingPages {
            return "\(pagesRead) von \(pageCount) Seiten · noch \(remainingPages)"
        }

        return "\(pagesRead) von \(pageCount) Seiten"
    }
}

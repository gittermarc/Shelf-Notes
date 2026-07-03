//
//  LibraryWidgetSnapshotPresentation.swift
//  Shelf Notes
//
//  Pure presentation values for the Library Home Screen widget snapshot.
//  This file is app-test friendly and independent from WidgetKit.
//

import Foundation

nonisolated struct LibraryWidgetSnapshotPresentation: Hashable, Sendable {
    struct Metric: Hashable, Sendable {
        var title: String
        var value: String
        var detail: String
    }

    struct ShelfItem: Hashable, Sendable {
        var id: UUID
        var title: String
        var author: String?
        var hasCover: Bool
    }

    var isEmpty: Bool
    var isStale: Bool
    var heroTitle: String
    var heroValue: String
    var heroSubtitle: String
    var metrics: [Metric]
    var currentBookTitle: String
    var currentBookDetail: String
    var currentBookProgressText: String?
    var hasCurrentBookCover: Bool
    var yearlyGoalTitle: String
    var yearlyGoalDetail: String
    var yearlyGoalProgressFraction: Double?
    var activityTitle: String
    var activityDetail: String
    var shelfItems: [ShelfItem]

    init(
        snapshot: LibraryWidgetSnapshot,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        isEmpty = snapshot.state == .emptyLibrary || snapshot.totalBooks == 0
        isStale = now.timeIntervalSince(snapshot.generatedAt) > 60 * 60 * 24
        heroTitle = "Dein Regal"
        heroValue = String(snapshot.totalBooks)
        heroSubtitle = Self.heroSubtitle(for: snapshot)
        metrics = [
            Metric(title: "Gelesen", value: String(snapshot.readBooks), detail: "fertig"),
            Metric(title: "Lese ich", value: String(snapshot.readingBooks), detail: "aktiv"),
            Metric(title: "Stapel", value: String(snapshot.wantToReadBooks), detail: "offen")
        ]

        if let currentBook = snapshot.currentBook {
            currentBookTitle = currentBook.title
            currentBookDetail = Self.bookDetailText(for: currentBook)
            currentBookProgressText = Self.progressText(for: currentBook)
            hasCurrentBookCover = currentBook.hasCover
        } else if isEmpty {
            currentBookTitle = "Dein Regal wartet"
            currentBookDetail = "Füge dein erstes Buch hinzu und starte deine Bibliothek."
            currentBookProgressText = nil
            hasCurrentBookCover = false
        } else {
            currentBookTitle = "Gerade kein aktives Buch"
            currentBookDetail = "Dein Lesestapel ist bereit für das nächste Kapitel."
            currentBookProgressText = nil
            hasCurrentBookCover = false
        }

        if let goal = snapshot.yearlyGoal {
            yearlyGoalTitle = "Jahresziel \(goal.year)"
            yearlyGoalDetail = "\(goal.finishedCount) von \(goal.targetCount) gelesen"
            yearlyGoalProgressFraction = goal.progressFraction
        } else {
            let year = calendar.component(.year, from: now)
            yearlyGoalTitle = "Jahresziel \(year)"
            yearlyGoalDetail = "Noch kein Ziel gesetzt"
            yearlyGoalProgressFraction = nil
        }

        activityTitle = "Letzte 7 Tage"
        if snapshot.hasRecentActivity {
            activityDetail = "\(snapshot.last7DaysReadingMinutes) min · \(snapshot.last7DaysReadingDays) Tage · \(snapshot.currentReadingStreakDays) Streak"
        } else {
            activityDetail = "Noch keine Lesesessions erfasst"
        }

        shelfItems = snapshot.recentShelfItems.prefix(5).map { item in
            ShelfItem(
                id: item.id,
                title: item.title,
                author: item.author,
                hasCover: item.hasCover
            )
        }
    }

    private static func heroSubtitle(for snapshot: LibraryWidgetSnapshot) -> String {
        if snapshot.totalBooks == 0 {
            return "Bereit für dein erstes Buch"
        }

        if snapshot.readingBooks > 0 {
            return "\(snapshot.readingBooks) aktuell in Arbeit"
        }

        if snapshot.wantToReadBooks > 0 {
            return "\(snapshot.wantToReadBooks) warten auf dich"
        }

        return "Alles gelesen, sehr stark"
    }

    private static func bookDetailText(for book: LibraryWidgetBookSnapshot) -> String {
        if let author = book.author, !author.isEmpty {
            return author
        }
        return "Aktuelles Buch"
    }

    private static func progressText(for book: LibraryWidgetBookSnapshot) -> String? {
        guard let pagesRead = book.pagesRead, let pageCount = book.pageCount else {
            return nil
        }

        if let remainingPages = book.remainingPages {
            return "\(pagesRead) von \(pageCount) Seiten · noch \(remainingPages)"
        }

        return "\(pagesRead) von \(pageCount) Seiten"
    }
}

import Foundation
import Testing
@testable import Shelf_Notes

struct LibraryWidgetSnapshotPresentationTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    @Test func completeSnapshotBuildsReadableDashboardPresentation() {
        let generatedAt = date(2026, 4, 15)
        let currentBookID = fixedID(1)
        let snapshot = LibraryWidgetSnapshot(
            generatedAt: generatedAt,
            state: .ready,
            totalBooks: 12,
            readBooks: 4,
            readingBooks: 1,
            wantToReadBooks: 7,
            currentBook: LibraryWidgetBookSnapshot(
                id: currentBookID,
                title: "Dune",
                author: "Frank Herbert",
                kind: .currentReading,
                statusRawValue: ReadingStatus.reading.rawValue,
                pageCount: 500,
                pagesRead: 125,
                remainingPages: 375,
                progressFraction: 0.25,
                referenceDate: generatedAt,
                hasCover: true,
                coverRevision: 99
            ),
            yearlyGoal: LibraryWidgetYearlyGoalSnapshot(
                year: 2026,
                targetCount: 20,
                finishedCount: 4
            ),
            last7DaysReadingMinutes: 95,
            last7DaysReadingDays: 3,
            currentReadingStreakDays: 2,
            recentShelfItems: [
                LibraryWidgetBookSnapshot(
                    id: fixedID(2),
                    title: "Finished",
                    kind: .recentlyFinished,
                    statusRawValue: ReadingStatus.finished.rawValue,
                    hasCover: false
                )
            ]
        )

        let presentation = LibraryWidgetSnapshotPresentation(
            snapshot: snapshot,
            now: date(2026, 4, 15, 12),
            calendar: calendar
        )

        #expect(!presentation.isEmpty)
        #expect(!presentation.isStale)
        #expect(presentation.heroValue == "12")
        #expect(presentation.heroSubtitle == "1 aktuell in Arbeit")
        #expect(presentation.metrics.map(\.value) == ["4", "1", "7"])
        #expect(presentation.currentBookTitle == "Dune")
        #expect(presentation.currentBookDetail == "Frank Herbert")
        #expect(presentation.currentBookProgressText == "125 von 500 Seiten · noch 375")
        #expect(presentation.hasCurrentBookCover)
        #expect(presentation.yearlyGoalDetail == "4 von 20 gelesen")
        #expect(presentation.yearlyGoalProgressFraction == 0.2)
        #expect(presentation.activityDetail == "95 min · 3 Tage · 2 Streak")
        #expect(presentation.shelfItems.count == 1)
    }

    @Test func emptySnapshotKeepsWidgetFriendlyFallbackTexts() {
        let snapshot = LibraryWidgetSnapshot.empty(generatedAt: date(2026, 4, 15))
        let presentation = LibraryWidgetSnapshotPresentation(
            snapshot: snapshot,
            now: date(2026, 4, 15, 12),
            calendar: calendar
        )

        #expect(presentation.isEmpty)
        #expect(presentation.heroSubtitle == "Bereit für dein erstes Buch")
        #expect(presentation.currentBookTitle == "Dein Regal wartet")
        #expect(presentation.currentBookProgressText == nil)
        #expect(!presentation.hasCurrentBookCover)
        #expect(presentation.yearlyGoalDetail == "Noch kein Ziel gesetzt")
        #expect(presentation.activityDetail == "Noch keine Lesesessions erfasst")
        #expect(presentation.shelfItems.isEmpty)
    }

    @Test func missingCurrentBookUsesReadingFallbackWithoutGoal() {
        let snapshot = LibraryWidgetSnapshot(
            generatedAt: date(2026, 4, 15),
            state: .ready,
            totalBooks: 5,
            readBooks: 2,
            readingBooks: 0,
            wantToReadBooks: 3
        )

        let presentation = LibraryWidgetSnapshotPresentation(
            snapshot: snapshot,
            now: date(2026, 4, 15, 12),
            calendar: calendar
        )

        #expect(!presentation.isEmpty)
        #expect(presentation.heroSubtitle == "3 warten auf dich")
        #expect(presentation.currentBookTitle == "Gerade kein aktives Buch")
        #expect(presentation.currentBookDetail == "Dein Lesestapel ist bereit für das nächste Kapitel.")
        #expect(presentation.yearlyGoalTitle == "Jahresziel 2026")
        #expect(presentation.yearlyGoalProgressFraction == nil)
    }

    @Test func missingCoversStayHiddenInPresentation() {
        let snapshot = LibraryWidgetSnapshot(
            generatedAt: date(2026, 4, 15),
            state: .ready,
            totalBooks: 2,
            readBooks: 0,
            readingBooks: 1,
            wantToReadBooks: 1,
            currentBook: LibraryWidgetBookSnapshot(
                id: fixedID(1),
                title: "No Cover",
                kind: .currentReading,
                statusRawValue: ReadingStatus.reading.rawValue,
                hasCover: false
            ),
            recentShelfItems: [
                LibraryWidgetBookSnapshot(
                    id: fixedID(2),
                    title: "Also No Cover",
                    kind: .recentlyAdded,
                    statusRawValue: ReadingStatus.toRead.rawValue,
                    hasCover: false
                )
            ]
        )

        let presentation = LibraryWidgetSnapshotPresentation(
            snapshot: snapshot,
            now: date(2026, 4, 15, 12),
            calendar: calendar
        )

        #expect(!presentation.hasCurrentBookCover)
        #expect(presentation.shelfItems.allSatisfy { !$0.hasCover })
    }

    @Test func staleSnapshotIsMarkedAfterOneDay() {
        let snapshot = LibraryWidgetSnapshot(
            generatedAt: date(2026, 4, 14, 8),
            state: .ready,
            totalBooks: 1,
            readBooks: 0,
            readingBooks: 1,
            wantToReadBooks: 0
        )

        let presentation = LibraryWidgetSnapshotPresentation(
            snapshot: snapshot,
            now: date(2026, 4, 15, 9),
            calendar: calendar
        )

        #expect(presentation.isStale)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute
            )
        ) ?? .distantPast
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
    }
}

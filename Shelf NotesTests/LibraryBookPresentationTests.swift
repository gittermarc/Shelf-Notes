import Foundation
import Testing
@testable import Shelf_Notes

struct LibraryBookPresentationTests {
    @Test func readingBookBuildsFormattedProgressTexts() {
        let snapshot = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            id: fixedID(1),
            title: "Dune",
            statusRawValue: ReadingStatus.reading.rawValue,
            pageCount: 300,
            pagesReadTotal: 126,
            readingProgressFraction: 0.42,
            lastSessionAt: date(2026, 1, 7)
        )

        let presentation = LibraryBookPresentation(snapshot: snapshot)

        #expect(presentation.id == snapshot.id)
        #expect(presentation.shouldShowReadingProgress)
        #expect(presentation.progressFraction == 0.42)
        #expect(presentation.progressText == "42 %")
        #expect(presentation.pageProgressText == "126 von 300 Seiten")
        #expect(presentation.remainingPagesText == "noch 174 Seiten")
        #expect(presentation.lastActivityText != nil)
    }

    @Test func missingPageCountKeepsKnownPageProgressWithoutInventingPercentage() {
        let snapshot = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            title: "Unknown Pages",
            statusRawValue: ReadingStatus.reading.rawValue,
            pageCount: nil,
            pagesReadTotal: 42,
            readingProgressFraction: nil
        )

        let presentation = LibraryBookPresentation(snapshot: snapshot)

        #expect(presentation.shouldShowReadingProgress)
        #expect(presentation.progressFraction == nil)
        #expect(presentation.progressText == nil)
        #expect(presentation.pageProgressText == "42 Seiten gelesen")
        #expect(presentation.remainingPagesText == nil)
    }

    @Test func finishedBookDoesNotShowActiveProgressCue() {
        let snapshot = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            title: "Finished",
            statusRawValue: ReadingStatus.finished.rawValue,
            pageCount: 300,
            pagesReadTotal: 300,
            readingProgressFraction: 1.0
        )

        let presentation = LibraryBookPresentation(snapshot: snapshot)

        #expect(presentation.progressText == "100 %")
        #expect(presentation.pageProgressText == "300 von 300 Seiten")
        #expect(presentation.remainingPagesText == nil)
        #expect(presentation.shouldShowReadingProgress == false)
    }

    @Test func rereadHintUsesPreparedAttemptDisplayName() {
        let snapshot = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            title: "Again",
            statusRawValue: ReadingStatus.reading.rawValue,
            pageCount: 200,
            pagesReadTotal: 50,
            readingProgressFraction: 0.25,
            isRereading: true,
            completedReadingAttemptCount: 1,
            currentReadingAttemptDisplayName: "2. Durchgang"
        )

        let presentation = LibraryBookPresentation(snapshot: snapshot)

        #expect(presentation.rereadBadgeText == "2. Durchgang")
        #expect(presentation.accessibilitySummary.contains("2. Durchgang"))
    }

    @Test func pageTextClampsReadPagesToKnownPageCount() {
        let snapshot = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            title: "Overread",
            statusRawValue: ReadingStatus.reading.rawValue,
            pageCount: 100,
            pagesReadTotal: 140,
            readingProgressFraction: 1.2
        )

        let presentation = LibraryBookPresentation(snapshot: snapshot)

        #expect(presentation.progressFraction == 1.0)
        #expect(presentation.progressText == "100 %")
        #expect(presentation.pageProgressText == "100 von 100 Seiten")
        #expect(presentation.remainingPagesText == nil)
    }

    @Test func percentageEbookShowsIndividualProgressWithoutPageValues() {
        let snapshot = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            title: "Digital",
            statusRawValue: ReadingStatus.reading.rawValue,
            pageCount: 450,
            readingProgressFraction: 0.4,
            readingMediumRawValue: ReadingMedium.ebook.rawValue,
            readingProviderRawValue: ReadingProvider.kindle.rawValue,
            progressUnitRawValue: ReadingProgressUnit.percentage.rawValue,
            progressNativeValue: 40,
            progressTotalValue: 100
        )

        let presentation = LibraryBookPresentation(snapshot: snapshot)

        #expect(presentation.shouldShowReadingProgress)
        #expect(presentation.progressText == "40 %")
        #expect(presentation.pageProgressText == nil)
        #expect(presentation.remainingPagesText == nil)
        #expect(presentation.detailText == "Aktueller Lesestand 40%")
        #expect(presentation.sourceText == "Kindle")
        #expect(presentation.accessibilitySummary.contains("Kindle"))
    }

    @Test func locatorWithoutPercentageShowsPositionButNoSyntheticProgressBar() {
        let snapshot = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            title: "Position",
            statusRawValue: ReadingStatus.reading.rawValue,
            readingProgressFraction: nil,
            readingMediumRawValue: ReadingMedium.ebook.rawValue,
            readingProviderRawValue: ReadingProvider.appleBooks.rawValue,
            progressUnitRawValue: ReadingProgressUnit.locator.rawValue,
            progressLocator: "Kapitel 7"
        )

        let presentation = LibraryBookPresentation(snapshot: snapshot)

        #expect(presentation.shouldShowReadingProgress)
        #expect(presentation.progressFraction == nil)
        #expect(presentation.progressText == nil)
        #expect(presentation.pageProgressText == nil)
        #expect(presentation.detailText == "Leseposition: Kapitel 7")
        #expect(presentation.sourceText == "Apple Books")
    }

    @Test func legacyPhysicalPresentationStaysCompact() {
        let snapshot = LibraryView.LibrarySourceSnapshot.BookSnapshot(
            title: "Paper",
            statusRawValue: ReadingStatus.reading.rawValue,
            pageCount: 200,
            pagesReadTotal: 50,
            readingProgressFraction: 0.25
        )

        let presentation = LibraryBookPresentation(snapshot: snapshot)

        #expect(presentation.sourceText == nil)
        #expect(presentation.pageProgressText == "50 von 200 Seiten")
        #expect(presentation.remainingPagesText == "noch 150 Seiten")
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private func fixedID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value)) ?? UUID()
    }
}
